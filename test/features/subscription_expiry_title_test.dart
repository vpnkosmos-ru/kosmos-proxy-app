import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/network/base_network_transport.dart';
import 'package:hiddify/features/proxy/model/outbound_display_name.dart';
import 'package:hiddify/features/subscription_expiry/subscription_expiration_info.dart';

void main() {
  test('parses Russian subscription title variants', () {
    expect(SubscriptionExpirationInfo.remainingDaysFromTitle('Истекает через 10 дней'), 10);
    expect(SubscriptionExpirationInfo.remainingDaysFromTitle('Осталось 2 дня'), 2);
    expect(SubscriptionExpirationInfo.remainingDaysFromTitle('Остался 1 день'), 1);
    expect(SubscriptionExpirationInfo.remainingDaysFromTitle('Истекает сегодня'), 0);
    expect(SubscriptionExpirationInfo.remainingDaysFromTitle('Срок подписки истёк'), 0);
  });

  test('Wi-Fi restriction matches only bypass-named servers', () {
    expect(isServerAllowedForTransport('Авто-выбор (Hysteria)', BaseNetworkTransport.wifi), isTrue);
    expect(isServerAllowedForTransport('📶Обход глушилок №2', BaseNetworkTransport.wifi), isFalse);
    expect(isServerAllowedForTransport('ОБХОД', BaseNetworkTransport.wifi), isFalse);
    expect(isServerAllowedForTransport('Обход глушилок', BaseNetworkTransport.cellular), isTrue);
  });

  test('technical selector suffixes are hidden in display names', () {
    expect(displayOutboundName('Авто-выбор (Hysteria)'), 'Авто-выбор');
    expect(displayOutboundName('Авто-выбор · BALANCE'), 'Авто-выбор');
  });
}
