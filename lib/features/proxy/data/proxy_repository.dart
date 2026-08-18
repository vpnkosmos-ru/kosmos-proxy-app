import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/utils/exception_handler.dart';
import 'package:hiddify/features/proxy/model/ip_info_entity.dart' as oldipinfo;

import 'package:hiddify/features/network/base_network_transport.dart';
import 'package:hiddify/features/proxy/model/proxy_failure.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/hiddify_core_service.dart';
import 'package:hiddify/utils/custom_loggers.dart';

abstract interface class ProxyRepository {
  // Stream<Either<ProxyFailure, List<OutboundGroup>>> watchProxies();
  Stream<Either<ProxyFailure, OutboundGroup?>> watchProxies();
  Stream<Either<ProxyFailure, List<OutboundGroup>>> watchActiveProxies();
  TaskEither<ProxyFailure, oldipinfo.IpInfo> getCurrentIpInfo(CancelToken cancelToken);
  TaskEither<ProxyFailure, Unit> selectProxy(String groupTag, String outboundTag);
  TaskEither<ProxyFailure, Unit> urlTest(String groupTag);
  Future<WifiSelectionPolicyResult> enforceBaseNetworkPolicy();
}

class ProxyRepositoryImpl with ExceptionHandler, InfraLogger implements ProxyRepository {
  ProxyRepositoryImpl({required this.singbox, required this.client});

  final HiddifyCoreService singbox;
  final DioHttpClient client;

  // @override
  // Stream<Either<ProxyFailure, List<OutboundGroup>>> watchProxies() {
  //   return singbox.watchGroups().map((event) {
  //     // final groupWithSelected = {
  //     //   for (final group in event) group.tag: group.selected,
  //     // };

  //     return event;
  //     // .map(
  //     //   (e) => ProxyGroupEntity(
  //     //     tag: e.tag,
  //     //     type: e.type,
  //     //     selected: e.selected,
  //     //     items: e.items
  //     //         .map(
  //     //           (e) => ProxyItemEntity(
  //     //             tag: e.tag,
  //     //             type: e.type,
  //     //             urlTestDelay: e.urlTestDelay,
  //     //             selectedTag: groupWithSelected[e.tag],
  //     //           ),
  //     //         )
  //     //         .filter((t) => t.isVisible)
  //     //         .toList(),
  //     //   ),
  //     // )
  //     // .toList();
  //   }).handleExceptions(
  //     (error, stackTrace) {
  //       loggy.error("error watching proxies", error, stackTrace);
  //       return ProxyUnexpectedFailure(error, stackTrace);
  //     },
  //   );
  // }

  @override
  Stream<Either<ProxyFailure, OutboundGroup?>> watchProxies() {
    return singbox.watchGroup().handleExceptions((error, stackTrace) {
      loggy.error("error watching proxies", error, stackTrace);
      return ProxyUnexpectedFailure(error, stackTrace);
    });
  }

  @override
  Stream<Either<ProxyFailure, List<OutboundGroup>>> watchActiveProxies() {
    return singbox.watchActiveGroups().handleExceptions((error, stackTrace) {
      loggy.error("error watching active proxies", error, stackTrace);
      return ProxyUnexpectedFailure(error, stackTrace);
    });
  }

  @override
  TaskEither<ProxyFailure, Unit> selectProxy(String groupTag, String outboundTag) {
    return exceptionHandler(() async {
      // This lower-layer guard is intentionally independent of the UI: a
      // stale tap, saved selector or reconnect cannot send a restricted item
      // to the core while the validated physical transport is Wi-Fi.
      final transport = await readBaseNetworkTransport();
      if (!isServerAllowedForTransport(outboundTag, transport, tag: outboundTag)) return right(unit);
      final selected = await singbox.selectOutbound(groupTag, outboundTag).run();
      return selected.mapLeft(ProxyUnexpectedFailure.new);
    }, ProxyUnexpectedFailure.new);
  }

  @override
  Future<WifiSelectionPolicyResult> enforceBaseNetworkPolicy() async {
    if (await readBaseNetworkTransport() != BaseNetworkTransport.wifi) {
      return WifiSelectionPolicyResult.allowed;
    }
    try {
      final group = await singbox.watchGroup().first.timeout(const Duration(seconds: 2));
      if (group == null) return WifiSelectionPolicyResult.allowed;
      OutboundInfo? selected;
      for (final item in group.items) {
        if (item.tag == group.selected) {
          selected = item;
          break;
        }
      }
      final selectedName = selected?.tagDisplay.isNotEmpty == true ? selected!.tagDisplay : group.selected;
      if (isServerAllowedForTransport(
        selectedName,
        BaseNetworkTransport.wifi,
        tag: group.selected,
        type: selected?.type,
      )) {
        return WifiSelectionPolicyResult.allowed;
      }
      final candidates =
          group.items
              .where(
                (item) =>
                    !item.isGroup &&
                    isServerAllowedForTransport(
                      item.tagDisplay.isEmpty ? item.tag : item.tagDisplay,
                      BaseNetworkTransport.wifi,
                      tag: item.tag,
                      type: item.type,
                    ),
              )
              .toList()
            ..sort((a, b) {
              final aDelay = a.urlTestDelay <= 0 ? 1 << 30 : a.urlTestDelay;
              final bDelay = b.urlTestDelay <= 0 ? 1 << 30 : b.urlTestDelay;
              final compared = aDelay.compareTo(bDelay);
              return compared != 0 ? compared : a.tag.compareTo(b.tag);
            });
      if (candidates.isEmpty) return WifiSelectionPolicyResult.noAllowedCandidate;
      final selectResult = await singbox.selectOutbound(group.tag, candidates.first.tag).run();
      return selectResult.isRight()
          ? WifiSelectionPolicyResult.reselected
          : WifiSelectionPolicyResult.noAllowedCandidate;
    } catch (_) {
      // No initialized core / no selector snapshot is not evidence that every
      // server is forbidden. Let the normal connection bootstrap continue;
      // once groups arrive the same policy validates the effective selection.
      return WifiSelectionPolicyResult.allowed;
    }
  }

  @override
  TaskEither<ProxyFailure, Unit> urlTest(String groupTag) {
    return exceptionHandler(
      () => singbox.urlTest(groupTag).mapLeft(ProxyUnexpectedFailure.new).run(),
      ProxyUnexpectedFailure.new,
    );
  }

  static final Map<String, oldipinfo.IpInfo Function(Map<String, dynamic> response)> _ipInfoSources = {
    // "https://geolocation-db.com/json/": IpInfo.fromGeolocationDbComJson, //bug response is not json
    "https://ipwho.is/": oldipinfo.IpInfo.fromIpwhoIsJson,
    "https://api.ip.sb/geoip/": oldipinfo.IpInfo.fromIpSbJson,
    "https://ipapi.co/json/": oldipinfo.IpInfo.fromIpApiCoJson,
    "https://ipinfo.io/json/": oldipinfo.IpInfo.fromIpInfoIoJson,
  };

  @override
  TaskEither<ProxyFailure, oldipinfo.IpInfo> getCurrentIpInfo(CancelToken cancelToken) {
    return TaskEither.tryCatch(() async {
      Object? error;
      for (final source in _ipInfoSources.entries) {
        try {
          loggy.debug("getting current ip info using [${source.key}]");
          final response = await client.get<Map<String, dynamic>>(
            source.key,
            cancelToken: cancelToken,
            proxyOnly: true,
          );
          if (response.statusCode == 200 && response.data != null) {
            return source.value(response.data!);
          }
        } catch (e, s) {
          loggy.debug("failed getting ip info using [${source.key}]", e, s);
          error = e;
          continue;
        }
      }
      throw UnableToRetrieveIp(error, StackTrace.current);
    }, ProxyUnexpectedFailure.new);
  }
}
