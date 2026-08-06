/// Presentation-only names for implementation outbounds supplied by sing-box.
///
/// Do not use this value for selection, routing, or configuration: those paths
/// must always keep the original outbound tag.
String displayOutboundName(String value) {
  var displayed = value;
  const replacements = <String, String>{
    'round-robin': 'Равномерное распределение',
    'leastPing': 'Самый низкий пинг',
    'balancer': 'Авто-выбор',
    'balance': 'Авто-выбор',
    'lowest': 'Самый низкий пинг',
    'DIRECT': 'Прямое подключение',
    'direct': 'Прямое подключение',
  };

  // Tags are ASCII protocol identifiers commonly embedded in a friendly name
  // ("… · BALANCE"). Use ASCII boundaries, rather than Dart's Unicode \b,
  // so Cyrillic/emoji user names are never touched.
  for (final replacement in replacements.entries) {
    displayed = displayed.replaceAllMapped(
      RegExp('(?<![A-Za-z0-9_])${RegExp.escape(replacement.key)}(?![A-Za-z0-9_])', caseSensitive: false),
      (_) => replacement.value,
    );
  }

  // Protocol and selector implementation labels are not useful to people.
  // Selection always continues to use the untouched outbound tag.
  displayed = displayed.replaceAll(
    RegExp(
      r'\s*[\(\[]\s*(?:hysteria(?:2)?|vless|vmess|reality|grpc|websocket|urltest|selector|balance)\s*[\)\]]',
      caseSensitive: false,
    ),
    '',
  );
  displayed = displayed.replaceAll(
    RegExp(
      r'\s*(?:[·•|:/-]\s*)?(?:hysteria(?:2)?|vless|vmess|reality|grpc|websocket|urltest|selector|balance)\b',
      caseSensitive: false,
    ),
    '',
  );
  // Generated balancer suffixes (for example "· BALANCER_01") are
  // implementation details, not part of a server's display name.
  displayed = displayed.replaceAll(RegExp(r'\s*[·•|:/-]\s*balancer(?:[_ -]?\d+)?', caseSensitive: false), '');
  displayed = displayed.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  // If a technical suffix normalizes to the same friendly selector name,
  // collapse the duplicate presentation without touching its internal tag.
  final duplicate = RegExp(r'^(Авто-выбор)\s*[·•|:/-]\s*\1$', caseSensitive: false).firstMatch(displayed);
  if (duplicate != null) displayed = duplicate.group(1)!;
  return displayed;
}
