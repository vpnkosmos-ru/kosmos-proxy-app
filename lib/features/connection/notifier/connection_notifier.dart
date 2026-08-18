import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/router/dialog/widgets/connection_failed_dialog.dart';
import 'package:hiddify/core/router/go_router/go_router_notifier.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_recovery.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/model/connection_stop_reason.dart';
import 'package:hiddify/features/network/base_network_transport.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/subscription_expiry/subscription_access_state.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'connection_notifier.g.dart';

@Riverpod(keepAlive: true)
class ConnectionNotifier extends _$ConnectionNotifier with AppLogger {
  static const _platformChannel = MethodChannel('ru.kosmosproxy.app/method');
  bool _presentingFailure = false;
  bool _confirmedConnected = false;
  bool _unexpectedStopHandled = false;
  ConnectionStopReason? _expectedStopReason;
  int _consecutiveNetworkFailures = 0;
  bool _appPaused = false;
  bool _resumeRebinding = false;
  ConnectionFailure? _resumeDisconnectedFailure;
  Timer? _resumeGraceTimer;
  Timer? _failureDebounceTimer;
  ConnectionFailure? _pendingFailure;
  bool _userInitiatedAttempt = false;
  bool _handoverInProgress = false;
  int _connectionAttemptId = 0;
  int _lifecycleEpoch = 0;

  static const _failureGracePeriod = Duration(seconds: 4);

  @override
  Stream<ConnectionStatus> build() async* {
    Timer? connectionWatchdog;
    Timer? networkWatchdog;
    Timer? wifiPolicyWatchdog;
    ref.onDispose(() {
      connectionWatchdog?.cancel();
      networkWatchdog?.cancel();
      wifiPolicyWatchdog?.cancel();
      _resumeGraceTimer?.cancel();
      _failureDebounceTimer?.cancel();
    });
    if (Platform.isIOS) {
      await _connectionRepo.setup().mapLeft((l) {
        loggy.error("error setting up connection repository", l);
      }).run();
    }

    listenSelf((previous, next) async {
      if (previous == next) return;
      if (previous case AsyncData(:final value) when !value.isConnected) {
        if (next case AsyncData(value: final Connected _)) {
          await ref.read(hapticServiceProvider.notifier).heavyImpact();

          if (Platform.isAndroid && !ref.read(Preferences.storeReviewedByUser)) {
            if (await InAppReview.instance.isAvailable()) {
              InAppReview.instance.requestReview();
              ref.read(Preferences.storeReviewedByUser.notifier).update(true);
            }
          }
        }
      }
    });

    ref.listen(activeProfileProvider.select((value) => value.asData?.value), (previous, next) async {
      if (previous == null) return;
      final shouldReconnect = next == null || previous.id != next.id;
      if (shouldReconnect) {
        await reconnect(next);
      }
    });
    ref.watch(coreRestartSignalProvider);
    ref.listen(baseNetworkTransportProvider, (previous, next) async {
      final current = next.valueOrNull;
      if (current != BaseNetworkTransport.wifi && current != BaseNetworkTransport.cellular) return;
      if (previous?.valueOrNull == current) return;
      await _rebuildRuntimeForBaseTransportHandover(current!);
    });

    yield* _connectionRepo.watchConnectionStatus().doOnData((event) {
      if (event is Connecting) {
        connectionWatchdog?.cancel();
        final watchdogAttemptId = _connectionAttemptId;
        connectionWatchdog = Timer(connectionAttemptTimeout, () async {
          const failure = ConnectionFailure.timeout('Connection status did not advance from CONNECTING.');
          loggy.error('connection watchdog expired', failure);
          if (watchdogAttemptId == _connectionAttemptId && _userInitiatedAttempt && !_handoverInProgress) {
            await _connectionRepo.disconnect().run();
            state = AsyncData(recoverConnectionFailure(failure));
            _queueConnectionFailure(failure);
          }
        });
      } else {
        connectionWatchdog?.cancel();
      }
      if (event is Connected) {
        _cancelPendingFailure();
        _confirmedConnected = true;
        wifiPolicyWatchdog ??= Timer.periodic(const Duration(seconds: 3), (_) async {
          await _enforceWifiOutboundPolicy();
        });
        _unexpectedStopHandled = false;
        _expectedStopReason = null;
        networkWatchdog ??= Timer.periodic(const Duration(seconds: 8), (_) async {
          final online = await _hasInternetConnection();
          if (online) {
            _consecutiveNetworkFailures = 0;
            return;
          }
          _consecutiveNetworkFailures++;
          // Do not react to a transient radio handover. Three failed checks
          // prove the device has no usable internet transport.
          if (_consecutiveNetworkFailures >= 3) {
            networkWatchdog?.cancel();
            networkWatchdog = null;
            await _handleNetworkLost();
          }
        });
      } else {
        networkWatchdog?.cancel();
        networkWatchdog = null;
        wifiPolicyWatchdog?.cancel();
        wifiPolicyWatchdog = null;
        _consecutiveNetworkFailures = 0;
      }
      if (event case Disconnected(connectionFailure: final failure)) {
        _handleDisconnected(failure);
      }
      if (event case Disconnected(connectionFailure: final _?) when PlatformUtils.isDesktop) {
        Future.microtask(() => ref.read(Preferences.startedByUser.notifier).update(false));
      }
      loggy.info("connection status: ${event.runtimeType}");
    });
  }

  ConnectionRepository get _connectionRepo => ref.read(connectionRepositoryProvider);

  /// Lifecycle transitions are not connection transitions. Android can emit a
  /// short STOPPED/rebind event while the foreground VPN service remains up.
  void onAppPaused() {
    _lifecycleEpoch++;
    _appPaused = true;
    _resumeRebinding = false;
    _resumeGraceTimer?.cancel();
    _cancelPendingFailure();
  }

  Future<void> onAppResumed() async {
    if (!Platform.isAndroid) return;
    final resumeEpoch = _lifecycleEpoch;
    _appPaused = false;
    _resumeRebinding = true;
    _resumeGraceTimer?.cancel();

    // Let Android reattach the activity/service callback, then verify twice.
    // A single transient STOPPED notification is never enough to alert users.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_appPaused || resumeEpoch != _lifecycleEpoch) return;
    final first = await _isNativeVpnStarted();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (_appPaused || resumeEpoch != _lifecycleEpoch) return;
    final second = await _isNativeVpnStarted();
    if (first || second) {
      _confirmedConnected = true;
      _unexpectedStopHandled = false;
      _resumeDisconnectedFailure = null;
      state = const AsyncData(Connected());
      loggy.info('VPN service confirmed active after app resume');
    }
    _resumeGraceTimer = Timer(const Duration(seconds: 2), () {
      if (_appPaused || resumeEpoch != _lifecycleEpoch) return;
      _resumeRebinding = false;
      final pending = _resumeDisconnectedFailure;
      _resumeDisconnectedFailure = null;
      // Only a persistent disconnected state with an inactive native VPN is a
      // candidate for an unexpected-disconnect warning.
      if (pending != null && !first && !second) _handleDisconnected(pending);
    });
  }

  Future<bool> _isNativeVpnStarted() async {
    try {
      final status = await _platformChannel
          .invokeMethod<String>('get_service_status')
          .timeout(const Duration(seconds: 2));
      return status == 'Started';
    } on PlatformException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> mayConnect() async {
    if (state case AsyncData(:final value)) {
      if (value case Disconnected()) return _connect(userInitiated: false);
    }
  }

  Future<void> toggleConnection() async {
    final haptic = ref.read(hapticServiceProvider.notifier);
    if (state case AsyncError()) {
      await haptic.lightImpact();
      await _connect(userInitiated: true);
    } else if (state case AsyncData(:final value)) {
      switch (value) {
        case Disconnected():
          await haptic.lightImpact();
          await ref.read(Preferences.startedByUser.notifier).update(true);
          await _connect(userInitiated: true);
        case Connected():
          // default:
          await haptic.mediumImpact();
          await ref.read(Preferences.startedByUser.notifier).update(false);
          await _disconnect();
        default:
          loggy.warning("switching status, debounce");
      }
    }
  }

  Future<void> reconnect(ProfileEntity? profile) async {
    if (subscriptionBlocksConnection(profile)) {
      await _disconnect(reason: ConnectionStopReason.serverSwitch);
      return;
    }
    if (state case AsyncData(:final value) when value == const Connected()) {
      if (profile == null) {
        loggy.info("no active profile, disconnecting");
        return _disconnect(reason: ConnectionStopReason.serverSwitch);
      }
      loggy.info("active profile changed, reconnecting");
      _handoverInProgress = true;
      _cancelPendingFailure();
      _connectionAttemptId++;
      _expectedStopReason = ConnectionStopReason.serverSwitch;
      await ref.read(Preferences.startedByUser.notifier).update(true);
      try {
        await _connectionRepo.reconnect(profile, ref.read(Preferences.disableMemoryLimit)).mapLeft((err) async {
          loggy.warning("error reconnecting", err);
          await ref.read(Preferences.startedByUser.notifier).update(false);
          state = AsyncData(recoverConnectionFailure(err));
        }).run();
      } finally {
        _handoverInProgress = false;
      }
    }
  }

  Future<void> abortConnection() async {
    if (state case AsyncData(:final value)) {
      switch (value) {
        case Connected() || Connecting():
          loggy.debug("aborting connection");
          await _disconnect();
        default:
      }
    }
  }

  final _singleStart = SingleCall();

  Future<void> _connect({bool userInitiated = false}) async {
    _singleStart.run(
      () async {
        await _connectThrottled(userInitiated: userInitiated);
      },
      onIgnored: () {
        loggy.debug("connect called while another connect/disconnect is still running, ignoring");
      },
    );
  }

  Future<void> _connectThrottled({required bool userInitiated}) async {
    _connectionAttemptId++;
    _userInitiatedAttempt = userInitiated;
    _cancelPendingFailure();
    final attemptId = _connectionAttemptId;
    final activeProfile = await ref.read(activeProfileProvider.future);
    if (activeProfile == null) {
      loggy.info("no active profile, not connecting");
      return;
    }
    if (subscriptionBlocksConnection(activeProfile)) {
      loggy.info('subscription is expired; VPN start refused');
      await ref.read(Preferences.startedByUser.notifier).update(false);
      return;
    }
    // A saved selector can survive an app restart. Correct or reject it
    // before the native VPN service is asked to start.
    final policy = await ref.read(proxyRepositoryProvider).enforceBaseNetworkPolicy();
    if (policy == WifiSelectionPolicyResult.noAllowedCandidate) {
      loggy.info('Wi-Fi policy: no permitted outbound; leaving VPN disconnected');
      await ref.read(Preferences.startedByUser.notifier).update(false);
      return;
    }
    final result = await _connectionRepo
        .connect(activeProfile, ref.read(Preferences.disableMemoryLimit))
        .run()
        .timeout(
          connectionAttemptTimeout,
          onTimeout: () =>
              left(const ConnectionFailure.timeout('VPN core did not report a connected state within 30 seconds.')),
        );
    await result.match((ConnectionFailure err) async {
      loggy.warning("error connecting: ${err.runtimeType}");
      // Keep details in the technical log, but restore a retryable UI first.
      state = AsyncData(recoverConnectionFailure(err));
      if (err.toString().contains("panic")) {
        await Sentry.captureException(Exception(err.toString()));
      }
      await ref.read(Preferences.startedByUser.notifier).update(false);
      if (attemptId == _connectionAttemptId) _queueConnectionFailure(err, attemptId: attemptId);
    }, (_) {});
  }

  void _handleDisconnected(ConnectionFailure? failure) {
    if (_appPaused || _resumeRebinding) {
      _resumeDisconnectedFailure = failure;
      loggy.info('deferring disconnected event during app lifecycle rebind');
      return;
    }
    final expectedReason = _expectedStopReason;
    final wasConnected = _confirmedConnected;
    _confirmedConnected = false;

    if (expectedReason?.isExpected ?? false) {
      loggy.info('expected connection stop: ${expectedReason!.name}');
      _expectedStopReason = null;
      return;
    }
    if (!wasConnected || _unexpectedStopHandled || !_userInitiatedAttempt || _handoverInProgress) return;

    _unexpectedStopHandled = true;
    final reason = failure == null ? ConnectionStopReason.networkLost : ConnectionStopReason.coreFailure;
    loggy.warning('unexpected connection stop: ${reason.name}');
    Future.microtask(() async {
      await ref.read(Preferences.startedByUser.notifier).update(false);
      _queueConnectionFailure(
        failure ?? const ConnectionFailure.timeout('Connection ended without a core error.'),
        networkLost: reason == ConnectionStopReason.networkLost,
      );
    });
  }

  /// The profile file received from the subscription is immutable. A physical
  /// network handover rebuilds its separate runtime copy before sing-box can
  /// perform selector/URLTest work on the new transport. Wi-Fi removes only
  /// «обход» candidates; cellular restores the complete original candidate set.
  Future<void> _rebuildRuntimeForBaseTransportHandover(BaseNetworkTransport transport) async {
    if (!(state.valueOrNull?.isConnected ?? false)) return;
    final profile = await ref.read(activeProfileProvider.future);
    if (profile == null) return;
    loggy.info('base transport changed to ${transport.name}; rebuilding runtime profile');
    await reconnect(profile);
  }

  Future<void> _enforceWifiOutboundPolicy() async {
    if (await readBaseNetworkTransport() != BaseNetworkTransport.wifi) return;
    final result = await ref.read(proxyRepositoryProvider).enforceBaseNetworkPolicy();
    if (result != WifiSelectionPolicyResult.noAllowedCandidate) return;
    if (!(state.valueOrNull?.isConnected ?? false)) return;
    loggy.info('Wi-Fi policy: no permitted outbound after handover; disconnecting');
    await ref.read(Preferences.startedByUser.notifier).update(false);
    await _disconnect(reason: ConnectionStopReason.serverSwitch);
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final addresses = await InternetAddress.lookup(
        'connectivitycheck.gstatic.com',
      ).timeout(const Duration(seconds: 3));
      return addresses.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<void> _handleNetworkLost() async {
    if (!_confirmedConnected || _unexpectedStopHandled) return;
    _confirmedConnected = false;
    _unexpectedStopHandled = true;
    _expectedStopReason = ConnectionStopReason.networkLost;
    const failure = ConnectionFailure.timeout('No usable Internet connection.');
    loggy.warning('unexpected connection stop: ${ConnectionStopReason.networkLost.name}');
    await ref.read(Preferences.startedByUser.notifier).update(false);
    state = const AsyncData(Disconnected(failure));
    // Bring the platform VPN indicator and the retryable UI back in sync. The
    // following normal CoreStopped event is deduplicated by the flag above.
    await _connectionRepo.disconnect().run();
    _queueConnectionFailure(failure, networkLost: true);
  }

  void _cancelPendingFailure() {
    _failureDebounceTimer?.cancel();
    _failureDebounceTimer = null;
    _pendingFailure = null;
  }

  void _queueConnectionFailure(ConnectionFailure error, {bool networkLost = false, int? attemptId}) {
    final id = attemptId ?? _connectionAttemptId;
    if (!_userInitiatedAttempt || id != _connectionAttemptId || _handoverInProgress || _appPaused || _resumeRebinding) {
      loggy.info('connection failure suppressed before grace period');
      return;
    }
    _failureDebounceTimer?.cancel();
    _pendingFailure = error;
    _failureDebounceTimer = Timer(_failureGracePeriod, () async {
      if (id != _connectionAttemptId ||
          _pendingFailure == null ||
          _handoverInProgress ||
          _appPaused ||
          _resumeRebinding)
        return;
      if (state.valueOrNull is Connected || await _isNativeVpnStarted()) {
        _cancelPendingFailure();
        return;
      }
      if (networkLost && await _hasInternetConnection()) {
        _cancelPendingFailure();
        return;
      }
      final failure = _pendingFailure!;
      _cancelPendingFailure();
      await _presentConnectionFailure(failure, networkLost: networkLost);
    });
  }

  Future<void> _presentConnectionFailure(ConnectionFailure error, {bool networkLost = false}) async {
    if (_presentingFailure) return;
    _presentingFailure = true;
    try {
      // A transport stop does not prove the subscription is invalid. Import
      // failures present subscription actions in their own update flow.
      final action = await ref.read(dialogNotifierProvider.notifier).showConnectionFailure(networkLost: networkLost);
      switch (action) {
        case ConnectionFailureAction.retry:
          Future<void>.delayed(Duration.zero, () => _connect(userInitiated: true));
        case ConnectionFailureAction.server:
          final context = rootNavKey.currentContext;
          if (context == null || !context.mounted) return;
          GoRouter.of(context).goNamed('proxies');
        case ConnectionFailureAction.update:
          final profile = await ref.read(activeProfileProvider.future);
          if (profile is RemoteProfileEntity) {
            await ref.read(updateProfileNotifierProvider(profile.id).notifier).updateProfile(profile);
          }
        case null:
          break;
      }
    } finally {
      _presentingFailure = false;
    }
  }

  Future<void> _disconnect({ConnectionStopReason reason = ConnectionStopReason.userInitiated}) async {
    _connectionAttemptId++;
    _cancelPendingFailure();
    _userInitiatedAttempt = false;
    _expectedStopReason = reason;
    await _connectionRepo.disconnect().mapLeft((err) {
      loggy.warning("error disconnecting", err);
      state = AsyncData(recoverConnectionFailure(err));
    }).run();
  }
}

@Riverpod(keepAlive: true)
bool serviceRunning(Ref ref) {
  // ref.watch(coreRestartSignalProvider);
  return ref.watch(connectionNotifierProvider).valueOrNull?.isConnected ?? false;
}

class SingleCall {
  bool _running = false;

  Future<T> run<T>(Future<T> Function() task, {required T onIgnored}) async {
    if (_running) return onIgnored;

    _running = true;
    try {
      return await task();
    } finally {
      _running = false;
    }
  }
}
