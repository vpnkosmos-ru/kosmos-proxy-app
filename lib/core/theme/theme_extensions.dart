import 'package:flutter/material.dart';

class ConnectionButtonTheme extends ThemeExtension<ConnectionButtonTheme> {
  const ConnectionButtonTheme({required this.idleColor, required this.connectedColor, required this.connectingColor});

  final Color idleColor;
  final Color connectedColor;
  final Color connectingColor;

  factory ConnectionButtonTheme.kosmos({required bool isDark}) => ConnectionButtonTheme(
    idleColor: isDark ? const Color(0xFFB8A8FF) : const Color(0xFF6C56F5),
    connectedColor: const Color(0xFF43B38A),
    connectingColor: const Color(0xFFFF934D),
  );

  @override
  ConnectionButtonTheme copyWith({Color? idleColor, Color? connectedColor, Color? connectingColor}) => ConnectionButtonTheme(
    idleColor: idleColor ?? this.idleColor,
    connectedColor: connectedColor ?? this.connectedColor,
    connectingColor: connectingColor ?? this.connectingColor,
  );

  @override
  ConnectionButtonTheme lerp(covariant ThemeExtension<ConnectionButtonTheme>? other, double t) {
    if (other is! ConnectionButtonTheme) return this;
    return ConnectionButtonTheme(
      idleColor: Color.lerp(idleColor, other.idleColor, t)!,
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t)!,
      connectingColor: Color.lerp(connectingColor, other.connectingColor, t)!,
    );
  }
}
