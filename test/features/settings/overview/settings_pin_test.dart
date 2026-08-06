import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/settings/overview/settings_pin.dart';

void main() {
  test('accepts the Kosmos advanced-settings PIN', () {
    expect(isSettingsPinValid('1583'), isTrue);
  });

  test('rejects an invalid advanced-settings PIN', () {
    expect(isSettingsPinValid('0000'), isFalse);
  });
}
