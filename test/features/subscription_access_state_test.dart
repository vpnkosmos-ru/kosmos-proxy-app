import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/subscription_expiry/subscription_access_state.dart';

void main() {
  RemoteProfileEntity profile({required String title, required int expiry}) => RemoteProfileEntity(
    id: 'test',
    active: true,
    name: title,
    url: 'https://vpnspacekpot.ru/sub/token',
    lastUpdate: DateTime.now(),
    populatedHeaders: {'subscription-userinfo': 'upload=0; download=0; total=0; expire=$expiry'},
  );

  test('expired server expiry blocks connection regardless of cached local profile', () {
    final expired = profile(
      title: 'Оплатите доступ',
      expiry: DateTime.now().subtract(const Duration(days: 3)).millisecondsSinceEpoch ~/ 1000,
    );
    expect(subscriptionAccessState(expired), SubscriptionAccessState.expired);
    expect(subscriptionBlocksConnection(expired), isTrue);
  });

  test('future server expiry is active and accepts both epoch seconds and metadata', () {
    final active = profile(
      title: 'Kosmos',
      expiry: DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch ~/ 1000,
    );
    expect(subscriptionAccessState(active), SubscriptionAccessState.active);
    expect(subscriptionBlocksConnection(active), isFalse);
  });
}
