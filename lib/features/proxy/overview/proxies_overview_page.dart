import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/features/proxy/widget/proxy_tile.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxiesOverviewPage extends HookConsumerWidget with PresLogger {
  const ProxiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final sortBy = ref.watch(proxiesSortNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.proxies.title),
        actions: [
          PopupMenuButton<ProxiesSort>(
            initialValue: sortBy,
            onSelected: ref.read(proxiesSortNotifierProvider.notifier).update,
            icon: const Icon(FluentIcons.arrow_sort_24_regular),
            tooltip: t.pages.proxies.sort,
            itemBuilder: (context) => [
              for (final item in ProxiesSort.values) PopupMenuItem(value: item, child: Text(item.present(t))),
            ],
          ),
          const Gap(8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async => await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest('select'),
        tooltip: t.pages.proxies.testDelay,
        icon: const Icon(FluentIcons.flash_24_filled),
        label: Text(t.pages.proxies.testDelay),
      ),
      body: proxies.when(
        data: (group) => group == null
            ? Center(child: Text(t.pages.proxies.empty))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final columns = PlatformUtils.isMobile && constraints.maxWidth < 600
                      ? 1
                      : max(1, (constraints.maxWidth / 330).floor());
                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _FastServerBanner(
                          onTap: () => ref.read(proxiesOverviewNotifierProvider.notifier).urlTest('select'),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate((context, index) {
                            final proxy = group.items[index];
                            return ProxyTile(
                              proxy,
                              selected: group.selected == proxy.tag,
                              onTap: () async => await ref
                                  .read(proxiesOverviewNotifierProvider.notifier)
                                  .changeProxy(group.tag, proxy.tag),
                            );
                          }, childCount: group.items.length),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisExtent: 98,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
        error: (error, stackTrace) => Center(child: Text(t.presentShortError(error))),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _FastServerBanner extends StatelessWidget {
  const _FastServerBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: [theme.colorScheme.primaryContainer, theme.colorScheme.secondaryContainer]),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Самый быстрый сервер', style: theme.textTheme.titleLarge),
                const Gap(5),
                Text('Проверим задержку и поможем выбрать лучший вариант.', style: theme.textTheme.bodyMedium),
                const Gap(14),
                FilledButton.tonalIcon(
                  onPressed: onTap,
                  icon: const Icon(Icons.bolt_rounded),
                  label: const Text('Проверить скорость'),
                ),
              ],
            ),
          ),
          const Gap(12),
          Icon(Icons.public_rounded, size: 70, color: theme.colorScheme.primary.withValues(alpha: .72)),
        ],
      ),
    );
  }
}
