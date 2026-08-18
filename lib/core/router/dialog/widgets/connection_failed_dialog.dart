import 'package:flutter/material.dart';
import 'package:hiddify/core/widget/kosmos_surface.dart';

enum ConnectionFailureAction { retry, server, update }

class ConnectionFailedDialog extends StatelessWidget {
  const ConnectionFailedDialog({super.key, this.networkLost = false, this.canUpdateSubscription = false});

  final bool networkLost;
  final bool canUpdateSubscription;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: KosmosSurface(
      padding: const EdgeInsets.fromLTRB(24, 22, 20, 16),
      borderRadius: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded),
          const SizedBox(height: 14),
          Text('Не удалось подключиться', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            networkLost
                ? 'Подключение прервалось. Проверьте интернет-соединение и попробуйте подключиться снова.'
                : 'Проверьте интернет-соединение или выберите другой сервер.',
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              if (canUpdateSubscription)
                TextButton(
                  onPressed: () => Navigator.pop(context, ConnectionFailureAction.update),
                  child: const Text('Обновить подписку'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, ConnectionFailureAction.server),
                child: const Text('Выбрать сервер'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, ConnectionFailureAction.retry),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
