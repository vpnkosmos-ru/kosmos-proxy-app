import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Process-local on purpose: closing the app discards access to advanced settings.
final settingsUnlockedProvider = StateProvider<bool>((ref) => false);

bool isSettingsPinValid(String value) {
  const fingerprint = [130, 182, 221, 156];
  if (value.length != fingerprint.length) return false;
  for (var index = 0; index < value.length; index++) {
    if (((value.codeUnitAt(index) * 13 + 7) % 257) != fingerprint[index]) return false;
  }
  return true;
}

Future<bool> requestSettingsPin(BuildContext context) async {
  var value = '';
  var invalid = false;
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Расширенные настройки'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Введите PIN-код для доступа к техническим параметрам.'),
                const SizedBox(height: 18),
                Text('•' * value.length, style: const TextStyle(fontSize: 30, letterSpacing: 9)),
                if (invalid)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Неверный PIN-код', style: TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final digit in const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
                      SizedBox(
                        width: 64,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () {
                            if (value.length == 4) return;
                            final next = '$value$digit';
                            if (next.length == 4) {
                              if (isSettingsPinValid(next)) {
                                Navigator.of(dialogContext).pop(true);
                              } else {
                                setDialogState(() {
                                  value = '';
                                  invalid = true;
                                });
                              }
                            } else {
                              setDialogState(() {
                                value = next;
                                invalid = false;
                              });
                            }
                          },
                          child: Text(digit),
                        ),
                      ),
                    SizedBox(
                      width: 138,
                      height: 48,
                      child: TextButton.icon(
                        onPressed: value.isEmpty
                            ? null
                            : () => setDialogState(() => value = value.substring(0, value.length - 1)),
                        icon: const Icon(Icons.backspace_outlined),
                        label: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Отмена'))],
          ),
        ),
      ) ??
      false;
}
