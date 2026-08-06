import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/features/profile/add/subscription_link.dart';
import 'package:hiddify/features/profile/add/widgets/loading.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Imports only subscriptions issued by Kosmos Proxy. Keeping validation at the
/// UI boundary prevents accidental imports from look-alike domains.
class AddProfileModal extends HookConsumerWidget {
  const AddProfileModal({super.key, this.url});

  final String? url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(addProfileNotifierProvider).isLoading;
    ref.listen(addProfileNotifierProvider, (_, next) {
      if (next case AsyncData(value: final _?)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && context.canPop()) context.pop();
        });
      }
    });

    return SafeArea(child: isLoading ? const ProfileLoading() : _KosmosSubscriptionForm(initialUrl: url));
  }
}

class _KosmosSubscriptionForm extends HookConsumerWidget {
  const _KosmosSubscriptionForm({this.initialUrl});

  final String? initialUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final controller = useTextEditingController(text: initialUrl ?? '');
    final theme = Theme.of(context);

    Future<void> addSubscription() async {
      if (!(formKey.currentState?.validate() ?? false)) return;
      await ref
          .read(addProfileNotifierProvider.notifier)
          .addManual(url: controller.text.trim(), userOverride: const UserOverride());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close_rounded)),
              ),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.public_rounded, color: Colors.white, size: 34),
                    Gap(18),
                    Text(
                      'Подключите Kosmos Proxy',
                      style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800),
                    ),
                    Gap(8),
                    Text(
                      'Вставьте ссылку подписки, которую получили после оплаты. Новые пользователи могут бесплатно проверить сервис в течение 24 часов.',
                      style: TextStyle(color: Colors.white, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Gap(20),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onFieldSubmitted: (_) => addSubscription(),
                validator: validateKosmosSubscriptionUrl,
                decoration: InputDecoration(
                  labelText: 'Ссылка подписки',
                  hintText: 'https://vpnspacekpot.ru/sub/ТОКЕН',
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const Gap(12),
              Text(
                'Одна подписка - несколько доступных серверов. После добавления профиль будет обновляться автоматически.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
              ),
              const Gap(22),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: addSubscription,
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Добавить подписку'),
                ),
              ),
              const Gap(10),
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () async => await _openCabinet(context),
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Попробовать 24 часа бесплатно'),
                ),
              ),
              const Gap(8),
              Text(
                'Пробный доступ оформляется в личном кабинете',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCabinet(BuildContext context) async => context.go('/cabinet');
}
