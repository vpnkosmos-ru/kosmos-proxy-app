import 'dart:async';

import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Physical network underneath the VPN. The Android implementation returns a
/// transport only for a validated default network, before the VPN overlay.
enum BaseNetworkTransport { wifi, cellular, other, none }

enum WifiSelectionPolicyResult { allowed, reselected, noAllowedCandidate }

const _platform = MethodChannel('ru.kosmosproxy.app/platform');

Future<BaseNetworkTransport> readBaseNetworkTransport() async {
  try {
    final raw = await _platform.invokeMethod<String>('get_base_network_transport');
    return switch (raw) {
      'wifi' => BaseNetworkTransport.wifi,
      'cellular' => BaseNetworkTransport.cellular,
      'other' => BaseNetworkTransport.other,
      _ => BaseNetworkTransport.none,
    };
  } on PlatformException {
    return BaseNetworkTransport.none;
  }
}

final baseNetworkTransportProvider = StreamProvider<BaseNetworkTransport>((ref) async* {
  yield await readBaseNetworkTransport();
  yield* Stream<BaseNetworkTransport>.periodic(
    const Duration(seconds: 2),
  ).asyncMap((_) => readBaseNetworkTransport()).distinct();
});

/// The only Wi-Fi business restriction. `toLowerCase` is Unicode-aware; trim
/// keeps accidental surrounding whitespace from affecting comparisons.
bool isBypassNamedServer(String displayName) => displayName.trim().toLowerCase().contains('обход');

/// True for an outbound that is only infrastructure, never a user VPN server.
///
/// This deliberately operates on untouched tags/types, not formatted UI labels.
/// Real protocol outbounds may use any friendly Russian name. Selector/urltest
/// groups are handled by their filtered children, so they are not classified as
/// service outbounds here.
bool isServiceOutbound({required String tag, String? type, String? displayName}) {
  final normalizedTag = tag.trim().toLowerCase();
  final normalizedDisplay = (displayName ?? '').trim().toLowerCase();
  final normalizedType = (type ?? '').trim().toLowerCase();

  const serviceTypes = {'direct', 'freedom', 'block', 'blackhole', 'dns'};
  if (serviceTypes.contains(normalizedType)) return true;

  const exactServiceTags = {
    'direct',
    'freedom',
    'block',
    'blackhole',
    'dns',
    'local',
    'local-dns',
    'dns-out',
    'dns_out',
    'route',
    'routing',
  };
  if (exactServiceTags.contains(normalizedTag) || exactServiceTags.contains(normalizedDisplay)) return true;
  if (normalizedDisplay == 'прямое подключение') return true;

  // Generated configuration tags normally use separators for technical routes.
  final servicePrefix = RegExp(r'^(?:direct|freedom|block|blackhole|dns|local)[_\-:]');
  return servicePrefix.hasMatch(normalizedTag);
}

/// Single eligibility rule for any user-selectable outbound.
bool isUserConnectableOutbound({required String tag, String? type, String? displayName}) =>
    !isServiceOutbound(tag: tag, type: type, displayName: displayName);

bool isServerAllowedForTransport(String displayName, BaseNetworkTransport transport, {String? tag, String? type}) {
  if (!isUserConnectableOutbound(tag: tag ?? displayName, type: type, displayName: displayName)) return false;
  return transport != BaseNetworkTransport.wifi || !isBypassNamedServer(displayName);
}

// Compatibility aliases for callers added before the shared policy API.
bool isWifiRestrictedOutbound(String displayName) => isBypassNamedServer(displayName);
bool isOutboundAllowedOn(BaseNetworkTransport transport, String displayName) =>
    isServerAllowedForTransport(displayName, transport, tag: displayName);
