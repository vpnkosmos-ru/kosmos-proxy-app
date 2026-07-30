import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/active/active_proxy_card.dart';
import 'package:hiddify/features/proxy/active/active_proxy_delay_indicator.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    final activeProfile = ref.watch(activeProfileProvider);
    final hasProfile = ref.watch(hasAnyProfileProvider).value ?? false;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            _BrandMark(size: 34),
            const Gap(10),
            Text(t.common.appTitle),
            const Gap(8),
            const AppVersionLabel(),
          ],
        ),
        actions: [
          Semantics(
            key: const ValueKey('profile_add_button'),
            label: t.pages.profiles.add,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
              ),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.scaffoldBackgroundColor, theme.colorScheme.primaryContainer.withValues(alpha: .20)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth > 760 ? 660 : 600),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    if (activeProfile case AsyncData(value: final profile?))
                      ProfileTile(
                        profile: profile,
                        isMain: true,
                        margin: const EdgeInsets.only(bottom: 18),
                        color: theme.colorScheme.surface,
                      ),
                    const _OrbitBackdrop(child: ConnectionButton()),
                    const Gap(8),
                    const ActiveProxyDelayIndicator(),
                    const Gap(20),
                    if (hasProfile) const ActiveProxyFooter(),
                    if (hasProfile) const Gap(12),
                    _HomeActions(
                      onServers: () => context.goNamed('proxies'),
                      onProfiles: () => ref.read(bottomSheetsNotifierProvider.notifier).showProfilesOverview(),
                    ),
                    const Gap(18),
                    _HelpCard(onTap: () => context.goNamed('about')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitBackdrop extends StatelessWidget {
  const _OrbitBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 244,
            height: 244,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [theme.colorScheme.primaryContainer.withValues(alpha: .76), Colors.transparent],
              ),
            ),
          ),
          Transform.rotate(
            angle: -.25,
            child: Container(
              width: 320,
              height: 116,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.colorScheme.secondary.withValues(alpha: .22), width: 2),
              ),
            ),
          ),
          Positioned(top: 24, right: 52, child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.tertiary, size: 26)),
          child,
        ],
      ),
    );
  }
}

class _HomeActions extends StatelessWidget {
  const _HomeActions({required this.onServers, required this.onProfiles});

  final VoidCallback onServers;
  final VoidCallback onProfiles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.language_rounded,
            title: 'Серверы',
            subtitle: 'Страны и скорость',
            color: theme.colorScheme.primary,
            onTap: onServers,
          ),
        ),
        const Gap(12),
        Expanded(
          child: _ActionCard(
            icon: Icons.manage_accounts_outlined,
            title: 'Подписка',
            subtitle: 'Профиль и срок',
            color: theme.colorScheme.tertiary,
            onTap: onProfiles,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const Gap(14),
              Text(title, style: theme.textTheme.titleMedium),
              const Gap(3),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(colors: [theme.colorScheme.primary, theme.colorScheme.secondary]),
                ),
                child: const Icon(Icons.headset_mic_outlined, color: Colors.white),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Нужна помощь?', style: theme.textTheme.titleMedium),
                    const Gap(3),
                    Text('Поддержка и полезная информация', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .30),
    child: Assets.images.logo.svg(width: size, height: size),
  );
}

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();
    return Semantics(
      label: t.common.version,
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(version, textDirection: TextDirection.ltr, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary)),
      ),
    );
  }
}
