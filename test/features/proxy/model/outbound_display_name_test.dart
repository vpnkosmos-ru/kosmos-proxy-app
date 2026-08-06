import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/proxy/model/outbound_display_name.dart';

void main() {
  test('translates only technical display fragments', () {
    expect(displayOutboundName('balance'), 'Авто-выбор');
    expect(displayOutboundName('BALANCE'), 'Авто-выбор');
    expect(displayOutboundName('balancer'), 'Авто-выбор');
    expect(displayOutboundName('lowest / leastPing'), 'Самый низкий пинг / Самый низкий пинг');
    expect(displayOutboundName('DIRECT · direct'), 'Прямое подключение · Прямое подключение');
    expect(displayOutboundName('round-robin'), 'Равномерное распределение');
  });

  test('keeps a mixed user server name and emoji intact', () {
    expect(displayOutboundName('🪐 Обход глушилок №2 · BALANCE'), '🪐 Обход глушилок №2 · Авто-выбор');
  });
}
