import 'package:flutter/material.dart';
import 'package:hiddify/core/widget/kosmos_surface.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/features/common/general_pref_tiles.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/notifier/profile_notifier.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/features/settings/overview/settings_pin.dart';
import 'package:hiddify/features/subscription_expiry/notification_settings_page.dart';
import 'package:hiddify/features/self_update/update_settings_page.dart';
import 'package:hiddify/utils/external_link.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends ConsumerStatefulWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(settingsUnlockedProvider);
    // The normal settings screen is always visible. Technical options are
    // intentionally gated by the explicit developer-mode action below.
    if (!unlocked) return _SafeSettingsPage(ref: ref);

    final t = ref.watch(translationsProvider).requireValue;
    // final scrollController = useScrollController();

    // useMemoized(
    //   () {
    //     if (section != null) {
    //       WidgetsBinding.instance.addPostFrameCallback(
    //         (_) {
    //           final box = section!.key.currentContext?.findRenderObject() as RenderBox?;

    //           final offset = box?.localToGlobal(Offset.zero);
    //           if (offset == null) return;
    //           final height = scrollController.offset + offset.dy - MediaQueryData.fromView(View.of(context)).padding.top - kToolbarHeight;
    //           scrollController.animateTo(
    //             height,
    //             duration: const Duration(milliseconds: 500),
    //             curve: Curves.decelerate,
    //           );
    //         },
    //       );
    //     }
    //   },
    // );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.settings.title),
        actions: [
          MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async =>
                        await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // TipCard(message: t.settings.experimentalMsg),
          SettingsSection(
            title: t.pages.settings.general.title,
            icon: Icons.layers_rounded,
            namedLocation: context.namedLocation('general'),
          ),
          if (ref.watch(hasAnyProfileProvider).value ?? false)
            SettingsSection(
              title: t.pages.settings.chain.title,
              icon: Icons.webhook_rounded,
              subtitle: Text(t.pages.settings.chain.subtitle),
              namedLocation: context.namedLocation('chainOptions'),
            ),
          SettingsSection(
            title: t.pages.settings.routing.title,
            icon: Icons.route_rounded,
            namedLocation: context.namedLocation('routingOptions'),
          ),
          SettingsSection(
            title: t.pages.settings.dns.title,
            icon: Icons.dns_rounded,
            namedLocation: context.namedLocation('dnsOptions'),
          ),
          SettingsSection(
            title: t.pages.settings.inbound.title,
            icon: Icons.input_rounded,
            namedLocation: context.namedLocation('inboundOptions'),
          ),
          SettingsSection(
            title: t.pages.settings.tlsTricks.title,
            icon: Icons.content_cut_rounded,
            namedLocation: context.namedLocation('tlsTricks'),
          ),
          if (PlatformUtils.isIOS)
            _SettingsCard(
              child: ListTile(
                title: Text(t.pages.settings.resetTunnel),
                leading: const Icon(Icons.autorenew_rounded),
                onTap: () async => await ref.read(resetTunnelNotifierProvider.notifier).run(),
              ),
            ),
          if (Breakpoint(context).isMobile()) ...[
            SettingsSection(
              title: t.pages.logs.title,
              icon: Icons.description_rounded,
              namedLocation: context.namedLocation('logs'),
            ),
            SettingsSection(
              title: t.pages.about.title,
              icon: Icons.info_rounded,
              namedLocation: context.namedLocation('about'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SafeSettingsPage extends StatelessWidget {
  const _SafeSettingsPage({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Настройки')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Text('Без PIN доступны только безопасные действия.', style: TextStyle(color: Colors.black54)),
        ),
        _SafeSettingsCard(
          icon: Icons.language_rounded,
          title: 'Язык и тема',
          subtitle: 'Безопасные параметры интерфейса',
          onTap: () =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _AppearanceSettingsPage())),
        ),
        _SafeSettingsCard(
          icon: Icons.refresh_rounded,
          title: 'Обновить подписку',
          onTap: () async {
            final profile = await ref.read(activeProfileProvider.future);
            if (profile is RemoteProfileEntity) {
              await ref.read(updateProfileNotifierProvider(profile.id).notifier).updateProfile(profile);
            }
          },
        ),
        _SafeSettingsCard(
          icon: Icons.notifications_active_outlined,
          title: 'Уведомления о подписке',
          subtitle: 'Срок и напоминания',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionNotificationSettingsPage())),
        ),
        _SafeSettingsCard(
          icon: Icons.system_update_rounded,
          title: 'Обновление приложения',
          subtitle: 'Проверка новой версии Kosmos Proxy',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UpdateSettingsPage())),
        ),
        _SafeSettingsCard(icon: Icons.support_agent_rounded, title: 'Поддержка', onTap: () => context.go('/help')),
        _SafeSettingsCard(
          icon: Icons.info_outline_rounded,
          title: 'Сведения о приложении',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const _KosmosAboutPage())),
        ),
        _SafeSettingsCard(
          icon: Icons.developer_mode_rounded,
          title: 'Режим разработчика',
          subtitle: 'Технические параметры текущей сессии',
          onTap: () async {
            final accepted = await requestSettingsPin(context);
            if (accepted) ref.read(settingsUnlockedProvider.notifier).state = true;
          },
        ),
      ],
    ),
  );
}

class _AppearanceSettingsPage extends StatelessWidget {
  const _AppearanceSettingsPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Язык и тема')),
    body: ListView(children: const [LocalePrefTile(), ThemeModePrefTile()]),
  );
}

class _KosmosAboutPage extends HookConsumerWidget {
  const _KosmosAboutPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appInfo = ref.watch(appInfoProvider).requireValue;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Сведения о приложении')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset('assets/branding-approved/kosmos_proxy_logo_1024.png', fit: BoxFit.contain),
                    ),
                  ),
                  const Gap(18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kosmos Proxy', style: theme.textTheme.headlineSmall),
                        const Gap(5),
                        Text('Версия ${appInfo.version} (${appInfo.buildNumber})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),
          const Text(
            'Kosmos Proxy — приложение для подключения к подписке Kosmos VPN. Настройки серверов обновляются автоматически после обновления подписки.',
          ),
          const Gap(18),
          _SafeSettingsCard(icon: Icons.support_agent_rounded, title: 'Поддержка', onTap: () => context.go('/help')),
          _SafeSettingsCard(
            icon: Icons.account_circle_outlined,
            title: 'Личный кабинет',
            onTap: () => openExternalKosmosLink(context, Uri.parse(Constants.cabinetUrl)),
          ),
        ],
      ),
    );
  }
}

class _SafeSettingsCard extends StatelessWidget {
  const _SafeSettingsCard({required this.icon, required this.title, required this.onTap, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: KosmosSurface(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    ),
  );
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    this.subtitle,
    required this.namedLocation,
  });

  final String title;
  final Widget? subtitle;
  final IconData icon;
  final String namedLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsCard(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: subtitle,
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go(namedLocation),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: KosmosSurface(padding: EdgeInsets.zero, child: child),
  );
}
