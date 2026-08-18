import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hiddify/core/widget/kosmos_surface.dart';

/// Native launchers replace the former embedded browser. Authentication now
/// lives in the chosen browser/VK/Telegram app instead of this VPN app.
enum CabinetNativeSection { cabinet, help }

class CabinetNativePage extends StatelessWidget {
  const CabinetNativePage({super.key, required this.section});

  final CabinetNativeSection section;

  bool get _isCabinet => section == CabinetNativeSection.cabinet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actions = _isCabinet
        ? const <_ContactAction>[
            _ContactAction(
              'Войти в личный кабинет на сайте',
              'https://vpnspacekpot.ru/cabinet',
              Icons.language_rounded,
            ),
            _ContactAction('Войти через ВК', 'https://vk.me/club239207567', FluentIcons.chat_24_filled),
            _ContactAction('Войти через Telegram', 'https://t.me/kocmoc_vpnbot', Icons.send_rounded),
          ]
        : const <_ContactAction>[
            _ContactAction('Написать в ВК', 'https://vk.me/spacekpothelper', FluentIcons.chat_24_filled),
            _ContactAction('Написать в Telegram', 'https://telegram.dog/kosmos_help', Icons.send_rounded),
            _ContactAction('Подписаться на Telegram-канал', 'https://telegram.dog/kosmos_vpn', Icons.campaign_rounded),
          ];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 116),
          children: [
            KosmosSurface(
              padding: const EdgeInsets.all(24),
              borderRadius: 30,
              gradientTint: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6456D9), Color(0xFF3976E6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isCabinet ? Icons.account_circle_rounded : Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isCabinet ? 'Личный кабинет' : 'Помощь',
                    style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCabinet
                        ? 'Управляйте подпиской и выбирайте удобный способ входа'
                        : 'Выберите удобный способ связи с поддержкой',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: .92),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            for (final action in actions) ...[_ContactCard(action: action), const SizedBox(height: 12)],
          ],
        ),
      ),
    );
  }
}

class _ContactAction {
  const _ContactAction(this.title, this.url, this.icon);
  final String title;
  final String url;
  final IconData icon;
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.action});
  final _ContactAction action;

  Future<void> _open(BuildContext context) async {
    final launched = await UriUtils.tryLaunch(Uri.parse(action.url));
    if (!context.mounted || launched) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KosmosSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            constraints: const BoxConstraints(minHeight: 82),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E0FA)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Color(0xFF7359D8), Color(0xFF4B7BEA)]),
                  ),
                  child: Icon(action.icon, color: Colors.white),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(action.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.open_in_new_rounded, color: Color(0xFF6E65A6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
