import 'package:hiddify/features/profile/add/subscription_link.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical, device-local copy of the Kosmos subscription URL.
///
/// SharedPreferences belongs to the application package, so Android preserves it
/// across a signed `adb install -r` update. The database remains the source for
/// profile metadata; this value makes the subscription recoverable after
/// migrations and is never written to logs.
class SubscriptionUrlStore {
  SubscriptionUrlStore(this._preferences);

  static const key = 'kosmos.subscription_url.v1';
  static const _legacyKeys = <String>[
    'kosmos_subscription_url',
    'subscription_url',
    'remote_profile_url',
    'profile_url',
  ];

  final SharedPreferences _preferences;

  String? get value {
    final candidate = _preferences.getString(key);
    return isKosmosSubscriptionUrl(candidate) ? candidate!.trim() : null;
  }

  Future<void> migrateLegacyValue() async {
    if (value != null) return;
    for (final legacyKey in _legacyKeys) {
      final candidate = _preferences.getString(legacyKey);
      if (!isKosmosSubscriptionUrl(candidate)) continue;
      await _preferences.setString(key, candidate!.trim());
      return;
    }
  }

  Future<void> save(String url) async {
    if (!isKosmosSubscriptionUrl(url)) {
      throw ArgumentError.value(url, 'url', 'Expected a valid Kosmos HTTPS subscription URL');
    }
    await _preferences.setString(key, url.trim());
  }

  Future<void> removeIfMatches(String url) async {
    if (value == url.trim()) await _preferences.remove(key);
  }
}
