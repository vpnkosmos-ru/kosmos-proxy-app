import 'dart:convert';

import 'package:hiddify/features/network/base_network_transport.dart';

/// Produces a runtime-only sing-box profile with a safe user-selection graph.
/// The downloaded subscription itself stays intact. Service routing outbounds
/// (DIRECT, block, DNS, etc.) remain available to routing rules but are removed
/// from every selector/urltest/balancer candidate list on every transport. On
/// Wi-Fi, «обход» candidates are removed in addition.
String prepareRuntimeProfileConfig(String source, BaseNetworkTransport transport) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) return source;
  final outbounds = decoded['outbounds'];
  if (outbounds is! List) return source;

  final byTag = <String, Map<dynamic, dynamic>>{
    for (final value in outbounds)
      if (value is Map && value['tag'] is String) value['tag'] as String: value,
  };
  final groupTags = <String>{
    for (final entry in byTag.entries)
      if (entry.value['outbounds'] is List) entry.key,
  };

  bool usableCandidate(String candidate) {
    final outbound = byTag[candidate];
    if (outbound == null) return false;
    if (!isUserConnectableOutbound(tag: candidate, type: outbound['type'] as String?, displayName: candidate)) {
      return false;
    }
    return transport != BaseNetworkTransport.wifi || !isBypassNamedServer(candidate);
  }

  // Repeatedly prune empty nested groups. This makes a visible selector
  // unavailable only when every child is service/restricted, while retaining
  // an auto selector with at least one normal VPN child.
  var changed = true;
  while (changed) {
    changed = false;
    for (final entry in byTag.entries) {
      final outbound = entry.value;
      final candidates = outbound['outbounds'];
      if (candidates is! List) continue;
      final filtered = <dynamic>[];
      for (final candidate in candidates) {
        if (candidate is! String || !usableCandidate(candidate)) continue;
        if (groupTags.contains(candidate)) {
          final nested = byTag[candidate]!['outbounds'];
          if (nested is List && nested.isEmpty) continue;
        }
        filtered.add(candidate);
      }
      if (filtered.length != candidates.length) {
        outbound['outbounds'] = filtered;
        changed = true;
      }
      final remaining = outbound['outbounds'] as List;
      if (outbound['default'] is String && !remaining.contains(outbound['default'])) {
        outbound['default'] = remaining.isEmpty ? null : remaining.first;
        changed = true;
      }
    }
  }

  // A bypass protocol outbound itself must not be reachable on Wi-Fi even if a
  // malformed future config references it outside a group. Service outbounds
  // are intentionally retained for route rules, but have no selection path.
  if (transport == BaseNetworkTransport.wifi) {
    outbounds.removeWhere(
      (value) => value is Map && value['tag'] is String && isBypassNamedServer(value['tag'] as String),
    );
  }
  return jsonEncode(decoded);
}
