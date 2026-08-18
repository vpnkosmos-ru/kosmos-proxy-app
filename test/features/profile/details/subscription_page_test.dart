import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/profile/details/subscription_page.dart';

void main() {
  test('masks a subscription token by default', () {
    expect(maskSubscriptionToken('abcd12345678wxyz'), 'abcd••••••••wxyz');
  });

  test('does not expose short subscription tokens', () {
    expect(maskSubscriptionToken('short'), '••••••••');
  });
}
