import 'package:flutter/material.dart';
import 'package:hiddify/utils/uri_utils.dart';

bool _isLaunchingExternalLink = false;

/// Launches approved Kosmos web links outside the app and keeps failure copy
/// consistent across cards and settings rows.
Future<void> openExternalKosmosLink(BuildContext context, Uri uri) async {
  if (_isLaunchingExternalLink) return;
  _isLaunchingExternalLink = true;
  final launched = await UriUtils.tryLaunch(uri);
  _isLaunchingExternalLink = false;
  if (launched || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Не удалось открыть браузер'),
      content: const Text('Установите или включите браузер и повторите попытку.'),
      actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Закрыть'))],
    ),
  );
}
