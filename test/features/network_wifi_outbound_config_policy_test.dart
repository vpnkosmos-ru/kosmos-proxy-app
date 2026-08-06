import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/network/base_network_transport.dart';
import 'package:hiddify/features/network/wifi_outbound_config_policy.dart';

void main() {
  const source = '''
{
    "outbounds": [
      {"type":"selector","tag":"Космос","default":"Автовыбор","outbounds":["Автовыбор","Обычный","📶Обход глушилок №2","DIRECT"]},
      {"type":"urltest","tag":"Автовыбор","outbounds":["Обычный","📶Обход глушилок №2","DIRECT"]},
      {"type":"vless","tag":"Обычный"},
      {"type":"vless","tag":"📶Обход глушилок №2"},
      {"type":"direct","tag":"DIRECT"}
    ]
  }''';

  Map<String, dynamic> groupsFor(BaseNetworkTransport transport) {
    final runtime = jsonDecode(prepareRuntimeProfileConfig(source, transport)) as Map<String, dynamic>;
    return {
      for (final value in runtime['outbounds'] as List)
        if (value is Map<String, dynamic>) value['tag'] as String: value,
    };
  }

  test('Wi-Fi removes bypass and service children from every runtime selector', () {
    final groups = groupsFor(BaseNetworkTransport.wifi);
    expect(groups['Космос']!['outbounds'], ['Автовыбор', 'Обычный']);
    expect(groups['Автовыбор']!['outbounds'], ['Обычный']);
    expect(groups.keys.any(isBypassNamedServer), isFalse);
  });

  test('cellular retains bypass but removes DIRECT from selectable graph', () {
    final groups = groupsFor(BaseNetworkTransport.cellular);
    expect(groups['Космос']!['outbounds'], ['Автовыбор', 'Обычный', '📶Обход глушилок №2']);
    expect(groups['Автовыбор']!['outbounds'], ['Обычный', '📶Обход глушилок №2']);
    expect(groups['DIRECT']!['type'], 'direct');
  });
}
