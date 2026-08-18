import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/network/base_network_transport.dart';

void main() {
  test('service and direct outbounds are never user-connectable', () {
    expect(isUserConnectableOutbound(tag: 'DIRECT', type: 'direct'), isFalse);
    expect(isUserConnectableOutbound(tag: 'direct'), isFalse);
    expect(isUserConnectableOutbound(tag: 'any', displayName: 'Прямое подключение'), isFalse);
    expect(isUserConnectableOutbound(tag: 'freedom', type: 'freedom'), isFalse);
    expect(isUserConnectableOutbound(tag: 'BLOCK', type: 'block'), isFalse);
    expect(isUserConnectableOutbound(tag: 'dns-out', type: 'dns'), isFalse);
    expect(isUserConnectableOutbound(tag: 'Germany', type: 'vless'), isTrue);
  });

  test('bypass is Wi-Fi-only restriction while direct is always rejected', () {
    expect(
      isServerAllowedForTransport('📶Обход глушилок №2', BaseNetworkTransport.wifi, tag: 'bypass', type: 'vless'),
      isFalse,
    );
    expect(
      isServerAllowedForTransport('📶Обход глушилок №2', BaseNetworkTransport.cellular, tag: 'bypass', type: 'vless'),
      isTrue,
    );
    expect(
      isServerAllowedForTransport('Прямое подключение', BaseNetworkTransport.cellular, tag: 'DIRECT', type: 'direct'),
      isFalse,
    );
  });
}
