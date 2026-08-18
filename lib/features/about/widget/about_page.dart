import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/directories/directories_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/app_update/notifier/app_update_notifier.dart';
import 'package:hiddify/features/app_update/notifier/app_update_state.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AboutPage extends HookConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final appInfo = ref.watch(appInfoProvider).requireValue;
    final appUpdate = ref.watch(appUpdateNotifierProvider);
    final theme = Theme.of(context);

    ref.listen(appUpdateNotifierProvider, (_, next) async {
      if (!context.mounted) return;
      switch (next) {
        case AppUpdateStateAvailable(:final versionInfo) || AppUpdateStateIgnored(:final versionInfo):
          await ref
              .read(dialogNotifierProvider.notifier)
              .showNewVersion(currentVersion: appInfo.presentVersion, newVersion: versionInfo, canIgnore: false);
        case AppUpdateStateError(:final error):
          CustomToast.error(t.presentShortError(error)).show(context);
        case AppUpdateStateNotAvailable():
          CustomToast.success(t.pages.about.notAvailableMsg).show(context);
        default:
          break;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.about.title),
        actions: [
          IconButton(
            tooltip: t.common.addToClipboard,
            icon: const Icon(Icons.content_copy_rounded),
            onPressed: () => Clipboard.setData(ClipboardData(text: appInfo.format())),
          ),
          const Gap(8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.public_rounded, color: theme.colorScheme.primary, size: 42),
                  ),
                  const Gap(18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.common.appTitle, style: theme.textTheme.headlineSmall),
                        const Gap(5),
                        Text('${t.common.version} ${appInfo.presentVersion}', style: theme.textTheme.bodyMedium),
                        const Gap(10),
                        Text(
                          'Быстро. Безопасно. Без границ.',
                          style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(18),
          _SectionTitle('Космос Proxy'),
          _AboutLink(icon: Icons.language_rounded, title: 'Официальный сайт', url: Constants.websiteUrl),
          _AboutLink(
            icon: Icons.support_agent_rounded,
            title: 'Поддержка',
            url: Constants.supportUrl,
            accent: theme.colorScheme.tertiary,
          ),
          _AboutLink(icon: Icons.send_rounded, title: t.pages.about.telegramChannel, url: Constants.telegramChannelUrl),
          _AboutLink(
            icon: Icons.description_outlined,
            title: t.pages.about.termsAndConditions,
            url: Constants.termsAndConditionsUrl,
          ),
          const Gap(18),
          _SectionTitle('Приложение'),
          if (appInfo.release.allowCustomUpdateChecker)
            _AboutAction(
              icon: Icons.system_update_alt_rounded,
              title: t.pages.about.checkForUpdate,
              trailing: switch (appUpdate) {
                AppUpdateStateChecking() => const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                _ => const Icon(FluentIcons.arrow_sync_24_regular),
              },
              onTap: () async => await ref.read(appUpdateNotifierProvider.notifier).check(),
            ),
          if (PlatformUtils.isDesktop)
            _AboutAction(
              icon: Icons.folder_outlined,
              title: t.pages.about.openWorkingDir,
              trailing: const Icon(FluentIcons.open_24_regular),
              onTap: () async => await UriUtils.tryLaunch(ref.read(appDirectoriesProvider).requireValue.workingDir.uri),
            ),
          _AboutLink(
            icon: Icons.privacy_tip_outlined,
            title: t.pages.about.privacyPolicy,
            url: Constants.privacyPolicyUrl,
          ),
          const Gap(18),
          _SectionTitle('Юридическая информация'),
          _AboutLink(icon: Icons.code_rounded, title: 'Лицензии открытого ПО', url: Constants.licenseUrl),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 0, 9),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _AboutLink extends StatelessWidget {
  const _AboutLink({required this.icon, required this.title, required this.url, this.accent});
  final IconData icon;
  final String title;
  final String url;
  final Color? accent;
  @override
  Widget build(BuildContext context) => _AboutAction(
    icon: icon,
    title: title,
    accent: accent,
    trailing: const Icon(FluentIcons.open_24_regular),
    onTap: () async => await UriUtils.tryLaunch(Uri.parse(url)),
  );
}

class _AboutAction extends StatelessWidget {
  const _AboutAction({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.onTap,
    this.accent,
  });
  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback onTap;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          title: Text(title),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}
