import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_recovery.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';

void main() {
  test('connection attempt watchdog is 30 seconds', () {
    expect(connectionAttemptTimeout, const Duration(seconds: 30));
  });

  test('a timed-out connection returns the UI to disconnected', () {
    final status = recoverConnectionFailure(const ConnectionFailure.timeout());
    expect(status, isA<Disconnected>());
  });

  test('a rejected VPN permission returns the UI to disconnected', () {
    final status = recoverConnectionFailure(const ConnectionFailure.missingVpnPermission());
    expect(status, isA<Disconnected>());
  });
}
