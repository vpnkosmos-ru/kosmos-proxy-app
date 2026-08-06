import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/subscription_expiry/subscription_expiration_info.dart';
import 'package:hiddify/features/subscription_expiry/subscription_notification_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Keeps a subscription value safe in UI and diagnostics: only the stable
/// ends are visible, never the bearer/token body.
String maskSubscriptionToken(String value) {
  if (value.length < 12) return '••••••••';
  return '${value.substring(0, 4)}••••••••${value.substring(value.length - 4)}';
}

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    if (profile is! RemoteProfileEntity) {
      return const Scaffold(body: Center(child: Text('Добавьте подписку, чтобы увидеть информацию о ней.')));
    }

    final persistedExpiry = ref.watch(subscriptionNotificationServiceProvider).expiration;
    final subscription = profile.subInfo;
    // The provider title is a reliable user-facing fallback when metadata
    // headers are unavailable. It must be considered before stale storage.
    final expiresAt =
        SubscriptionExpirationInfo.fromProfile(profile)?.expiresAt ??
        subscription?.expire ??
        persistedExpiry?.expiresAt;
    final devices = _deviceLimit(profile.populatedHeaders);
    final expired = expiresAt != null && !expiresAt.isAfter(DateTime.now());
    final updateState = ref.watch(updateProfileNotifierProvider(profile.id));
    final String? status = expiresAt == null ? null : (expired ? 'Срок подписки закончился' : 'Подписка активна');
    final statusColor = status == 'Подписка активна' ? Colors.green.shade700 : Theme.of(context).colorScheme.onSurface;
    final updateStatus = updateState.isLoading
        ? 'Обновление выполняется'
        : updateState.hasError
        ? 'Не удалось обновить данные. Сохранённые настройки продолжают работать.'
        : 'Последнее обновление выполнено';

    return Scaffold(
      appBar: AppBar(title: const Text('Подписка')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _HeroCard(name: profile.name, status: status, statusColor: statusColor, expiresAt: expiresAt),
          const Gap(14),
          _InfoCard(
            children: [
              if (expiresAt != null) _InfoRow('Дата окончания', _formatRussianDate(expiresAt)),
              if (expiresAt != null) _InfoRow('Осталось', _remaining(expiresAt)),
              if (devices != null) _InfoRow('Разрешено устройств', devices),
              _InfoRow('Последнее обновление', _formatRussianDate(profile.lastUpdate)),
              _InfoRow('Состояние обновления', updateStatus),
            ],
          ),
          const Gap(14),
          const _InfoCard(
            children: [
              Text('Подписка безопасно сохранена на устройстве.', style: TextStyle(fontWeight: FontWeight.w700)),
              Gap(8),
              Text(
                'Kosmos Proxy автоматически обновляет настройки подключения. Не удаляйте подписку, пока она активна.',
              ),
            ],
          ),
          const Gap(18),
          FilledButton.icon(
            onPressed: () => ref.read(updateProfileNotifierProvider(profile.id).notifier).updateProfile(profile),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Обновить подписку'),
          ),
          const Gap(10),
          OutlinedButton.icon(
            onPressed: () => _openCabinet(context),
            icon: const Icon(Icons.account_circle_outlined),
            label: const Text('Личный кабинет'),
          ),
          const Gap(10),
          TextButton.icon(
            onPressed: () => context.go('/help'),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Поддержка'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCabinet(BuildContext context) async => context.go('/cabinet');

  String _remaining(DateTime expiresAt) {
    if (!expiresAt.isAfter(DateTime.now())) return 'Срок действия закончился';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expirationDate = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    final days = expirationDate.difference(today).inDays;
    if (days <= 0) return 'Истекает сегодня';
    return '$days ${_daysWord(days)}';
  }

  String _formatRussianDate(DateTime value) {
    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}, ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _daysWord(int days) {
    final mod10 = days % 10;
    final mod100 = days % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) return 'дня';
    return 'дней';
  }

  String? _deviceLimit(Map<String, dynamic>? headers) {
    if (headers == null) return null;
    for (final key in ['subscription-device-limit', 'profile-device-limit', 'device-limit']) {
      final value = headers[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.name, required this.status, required this.statusColor, required this.expiresAt});

  final String name;
  final String? status;
  final Color statusColor;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.verified_user_outlined, color: Colors.white, size: 34),
        const Gap(16),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24),
        ),
        const Gap(8),
        if (expiresAt != null && expiresAt!.isAfter(DateTime.now()))
          Text(
            _expiryText(expiresAt!),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        if (expiresAt != null && expiresAt!.isAfter(DateTime.now())) const Gap(8),
        if (status != null)
          Chip(
            label: Text(status!),
            labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w700),
            backgroundColor: Colors.white,
          ),
      ],
    ),
  );

  static String _expiryText(DateTime expiresAt) {
    final now = DateTime.now();
    final days = DateTime(
      expiresAt.year,
      expiresAt.month,
      expiresAt.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    return days <= 0 ? 'Истекает сегодня' : 'Истекает через $days ${_daysWord(days)}';
  }

  static String _daysWord(int days) {
    final mod10 = days % 10;
    final mod100 = days % 100;
    if (mod10 == 1 && mod100 != 11) return 'день';
    if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) return 'дня';
    return 'дней';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const Gap(2),
              SelectableText(value),
            ],
          ),
        ),
      ],
    ),
  );
}
