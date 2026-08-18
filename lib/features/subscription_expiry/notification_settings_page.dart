import 'package:flutter/material.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/subscription_expiry/subscription_notification_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SubscriptionNotificationSettingsPage extends ConsumerStatefulWidget {
  const SubscriptionNotificationSettingsPage({super.key});
  @override
  ConsumerState<SubscriptionNotificationSettingsPage> createState() => _SubscriptionNotificationSettingsPageState();
}

class _SubscriptionNotificationSettingsPageState extends ConsumerState<SubscriptionNotificationSettingsPage> {
  bool _busy = false;
  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final profile = await ref.read(activeProfileProvider.future);
    await ref.read(subscriptionNotificationServiceProvider).setEnabled(value, profile: profile);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(subscriptionNotificationServiceProvider);
    final expiry = service.expiration;
    final next = service.nextScheduledAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления о подписке')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile.adaptive(
            value: service.enabled,
            onChanged: _busy ? null : _toggle,
            title: const Text('Включить уведомления'),
            subtitle: const Text('Напомним заранее об окончании подписки'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Статус разрешения Android'),
            subtitle: FutureBuilder<bool?>(
              future: service.permissionGranted(),
              builder: (_, s) => Text(s.data == true ? 'Разрешено' : 'Не разрешено'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Дата окончания подписки'),
            subtitle: Text(
              expiry == null
                  ? 'Метаданные срока отсутствуют'
                  : '${expiry.expiresAt.day.toString().padLeft(2, '0')}.${expiry.expiresAt.month.toString().padLeft(2, '0')}.${expiry.expiresAt.year} ${expiry.expiresAt.hour.toString().padLeft(2, '0')}:${expiry.expiresAt.minute.toString().padLeft(2, '0')}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Следующее уведомление'),
            subtitle: Text(
              next == null
                  ? 'Не назначено'
                  : '${next.day.toString().padLeft(2, '0')}.${next.month.toString().padLeft(2, '0')}.${next.year} ${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    await service.showTestNow();
                  },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Проверить уведомление'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    await service.refreshFromProfile(await ref.read(activeProfileProvider.future));
                    if (mounted) setState(() => _busy = false);
                  },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Обновить данные подписки'),
          ),
        ],
      ),
    );
  }
}

class NotificationTestPage extends ConsumerStatefulWidget {
  const NotificationTestPage({super.key});
  @override
  ConsumerState<NotificationTestPage> createState() => _NotificationTestPageState();
}

class _NotificationTestPageState extends ConsumerState<NotificationTestPage> {
  Future<void> _refresh() async {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext c) {
    final s = ref.watch(subscriptionNotificationServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Тест уведомлений')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Только для режима разработчика. Тестовые задания не влияют на срок подписки.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () async {
              await s.showTestNow();
            },
            child: const Text('Отправить уведомление сейчас'),
          ),
          OutlinedButton(
            onPressed: () async {
              await s.scheduleTests();
              await _refresh();
            },
            child: const Text('Запланировать 1 / 2 / 3 / 4 минуты'),
          ),
          OutlinedButton(
            onPressed: () async {
              await s.cancelTests();
              await _refresh();
            },
            child: const Text('Отменить тестовые уведомления'),
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: s.pendingTests(),
            builder: (_, snapshot) {
              final p = snapshot.data ?? [];
              return Text(p.isEmpty ? 'Тестовых уведомлений нет' : 'Запланировано: ${p.map((e) => e.id).join(', ')}');
            },
          ),
        ],
      ),
    );
  }
}
