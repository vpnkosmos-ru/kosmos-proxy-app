import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/self_update/self_update_service.dart';
import 'package:hiddify/features/subscription_expiry/subscription_expiration_info.dart';

void main() {
  test('expiry info uses local calendar day and persists without URL', () {
    final info = SubscriptionExpirationInfo(
      expiresAt: DateTime.now().add(const Duration(days: 3)),
      source: 'subscription-userinfo.expire',
      parsedAt: DateTime.now(),
      subscriptionFingerprint: 'profile-fingerprint',
    );
    expect(info.remainingCalendarDays, greaterThanOrEqualTo(2));
    expect(info.toJson(), isNot(contains('url')));
    expect(SubscriptionExpirationInfo.fromJsonString(jsonEncode(info.toJson())), isNotNull);
  });
  test('update manifest rejects untrusted and malformed URLs', () {
    expect(() => UpdateManifest.parse({'schemaVersion': 1}, allowLocal: false), throwsFormatException);
    final valid = UpdateManifest.parse({
      'schemaVersion': 1,
      'versionCode': 40201,
      'versionName': '4.2.1',
      'minimumVersionCode': 40200,
      'mandatory': false,
      'publishedAt': '2026-08-02T12:00:00Z',
      'apkUrl': 'https://kosmosproxy.ru/app/a.apk',
      'sha256': 'a' * 64,
      'size': 100,
      'changelog': [],
    }, allowLocal: false);
    expect(valid.versionCode, 40201);
    expect(() => UpdateManifest.parse({...validMap(), 'apkUrl': 'http://evil.example/a.apk'}, allowLocal: false), throwsFormatException);
  });
}
Map<String, dynamic> validMap() => {
  'schemaVersion': 1,
  'versionCode': 40201,
  'versionName': '4.2.1',
  'minimumVersionCode': 40200,
  'mandatory': false,
  'publishedAt': '2026-08-02T12:00:00Z',
  'apkUrl': 'https://kosmosproxy.ru/app/a.apk',
  'sha256': 'a' * 64,
  'size': 100,
};
