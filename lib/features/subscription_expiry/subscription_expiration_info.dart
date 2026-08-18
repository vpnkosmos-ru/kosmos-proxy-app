import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';

/// Persisted, privacy-safe expiry metadata. The fingerprint is derived from the
/// profile id, never from the subscription URL or token.
class SubscriptionExpirationInfo {
  const SubscriptionExpirationInfo({
    required this.expiresAt,
    required this.source,
    required this.parsedAt,
    required this.subscriptionFingerprint,
  });

  final DateTime expiresAt;
  final String source;
  final DateTime parsedAt;
  final String subscriptionFingerprint;

  bool get isExpired => !expiresAt.isAfter(DateTime.now());
  Duration get remainingDuration => expiresAt.difference(DateTime.now());
  int get remainingCalendarDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    return end.difference(today).inDays;
  }

  Map<String, Object> toJson() => {
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'source': source,
    'parsedAt': parsedAt.toUtc().toIso8601String(),
    'subscriptionFingerprint': subscriptionFingerprint,
  };

  static SubscriptionExpirationInfo? fromJsonString(String? raw) {
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final expiresAt = DateTime.tryParse(map['expiresAt'] as String? ?? '')?.toLocal();
      final parsedAt = DateTime.tryParse(map['parsedAt'] as String? ?? '')?.toLocal();
      final fingerprint = map['subscriptionFingerprint'] as String?;
      if (expiresAt == null || parsedAt == null || fingerprint == null || fingerprint.isEmpty) return null;
      return SubscriptionExpirationInfo(
        expiresAt: expiresAt,
        source: map['source'] as String? ?? 'unknown',
        parsedAt: parsedAt,
        subscriptionFingerprint: fingerprint,
      );
    } catch (_) {
      return null;
    }
  }

  static SubscriptionExpirationInfo? fromProfile(ProfileEntity? profile) {
    if (profile is! RemoteProfileEntity) return null;
    // Profile migration historically created SubscriptionInfo only when every
    // traffic counter was present.  `expire` itself is still valid when a
    // server omits one of those counters, so fall back to the already stored
    // Subscription-Userinfo response header.  No URL or token is inspected.
    final fingerprint = sha256.convert(utf8.encode(profile.id)).toString();
    final expiresAt = profile.subInfo?.expire ?? _expiryFromHeaders(profile.populatedHeaders);
    if (expiresAt != null && expiresAt.year >= 2020 && expiresAt.year <= 2100) {
      return SubscriptionExpirationInfo(
        expiresAt: expiresAt.toLocal(),
        source: 'subscription-userinfo.expire',
        parsedAt: DateTime.now(),
        subscriptionFingerprint: fingerprint,
      );
    }

    // Several subscription providers publish the remaining calendar days in
    // profile-title. This is an explicit fallback, not a server-name guess.
    final titleDays = _remainingDaysFromTitle(profile.name);
    if (titleDays == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Keep the local date equal to the provider's advertised calendar count.
    // Exact time is unknown, so use the end of that date and mark the source.
    final estimated = DateTime(today.year, today.month, today.day + titleDays, 23, 59);
    return SubscriptionExpirationInfo(
      expiresAt: estimated,
      source: 'titleDays',
      parsedAt: now,
      subscriptionFingerprint: fingerprint,
    );
  }

  /// Parses the human-facing Russian subscription title without coupling it to
  /// a particular server, URL or traffic format. Returns calendar days.
  static int? remainingDaysFromTitle(String title) => _remainingDaysFromTitle(title);

  static int? _remainingDaysFromTitle(String title) {
    final normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (RegExp(r'(подписка\s+истекла|срок\s+подписки\s+ист[её]к)').hasMatch(normalized)) return 0;
    if (RegExp(r'истекает\s+сегодня').hasMatch(normalized)) return 0;
    final match = RegExp(
      r'(?:истекает\s+через|остал(?:ся|ось|ось\s+ли))\s+(\d+)\s+(?:день|дня|дней)',
      caseSensitive: false,
    ).firstMatch(normalized);
    final days = int.tryParse(match?.group(1) ?? '');
    return days == null || days < 0 || days > 3650 ? null : days;
  }

  static DateTime? _expiryFromHeaders(Map<String, dynamic>? headers) {
    if (headers == null) return null;
    String? value;
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'subscription-userinfo' || entry.key.toLowerCase() == 'x-subscription-userinfo') {
        value = entry.value?.toString();
        break;
      }
    }
    if (value == null) return null;
    final match = RegExp(r'(?:^|[;,\s])expire\s*=\s*(\d{10,13})(?:$|[;,\s])', caseSensitive: false).firstMatch(value);
    final raw = int.tryParse(match?.group(1) ?? '');
    if (raw == null || raw <= 0) return null;
    // Accept seconds primarily; tolerate a standard millisecond timestamp.
    final millis = raw > 99999999999 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
  }
}
