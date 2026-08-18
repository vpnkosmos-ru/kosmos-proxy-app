import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/add/subscription_link.dart';

void main() {
  group('Kosmos subscription URL validation', () {
    test('accepts the primary subscription domain', () {
      expect(validateKosmosSubscriptionUrl('https://vpnspacekpot.ru/sub/example-token'), isNull);
    });

    test('accepts the mirror subscription domain', () {
      expect(validateKosmosSubscriptionUrl(' https://vpnspacekpot.online/sub/example-token '), isNull);
    });

    test('accepts the Kosmos Proxy mirror key route', () {
      expect(validateKosmosSubscriptionUrl('https://kosmosproxy.ru/key/example-token'), isNull);
    });

    test('rejects a valid host with a non-subscription route', () {
      expect(
        validateKosmosSubscriptionUrl('https://kosmosproxy.ru/sub/token/extra'),
        'Используйте ссылку, полученную в личном кабинете Kosmos Proxy',
      );
    });

    test('rejects an empty URL', () {
      expect(validateKosmosSubscriptionUrl(''), 'Введите ссылку подписки');
    });

    test('rejects HTTP URLs', () {
      expect(validateKosmosSubscriptionUrl('http://vpnspacekpot.ru/sub/token'), 'Ссылка должна начинаться с https://');
    });

    test('rejects an untrusted domain', () {
      expect(
        validateKosmosSubscriptionUrl('https://example.com/sub/token'),
        'Используйте ссылку, полученную в личном кабинете Kosmos Proxy',
      );
    });

    test('rejects an empty token', () {
      expect(
        validateKosmosSubscriptionUrl('https://vpnspacekpot.ru/sub/'),
        'Используйте ссылку, полученную в личном кабинете Kosmos Proxy',
      );
    });

    test('uses the official cabinet URL for the trial and cabinet actions', () {
      expect(kosmosCabinetUri.toString(), kosmosCabinetUrl);
      expect(kosmosCabinetUrl, 'https://vpnspacekpot.ru/cabinet');
    });
  });
}
