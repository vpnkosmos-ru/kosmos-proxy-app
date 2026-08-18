/// Public cabinet URL and validation shared by the subscription UI and tests.
const kosmosCabinetUrl = 'https://vpnspacekpot.ru/cabinet';

const _kosmosSubscriptionHosts = {'vpnspacekpot.ru', 'vpnspacekpot.online', 'kosmosproxy.ru'};

bool isKosmosSubscriptionUrl(String? raw) => validateKosmosSubscriptionUrl(raw) == null;

String? validateKosmosSubscriptionUrl(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Введите ссылку подписки';

  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme.toLowerCase() != 'https') {
    return 'Ссылка должна начинаться с https://';
  }
  if (!_kosmosSubscriptionHosts.contains(uri.host.toLowerCase())) {
    return 'Используйте ссылку, полученную в личном кабинете Kosmos Proxy';
  }

  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.length != 2 || !{'sub', 'key'}.contains(segments.first) || segments.last.trim().isEmpty) {
    return 'Используйте ссылку, полученную в личном кабинете Kosmos Proxy';
  }
  return null;
}

Uri get kosmosCabinetUri => Uri.parse(kosmosCabinetUrl);
