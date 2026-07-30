import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';
import 'package:hiddify/core/widget/animated_text.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final delay = ref.watch(activeProxyNotifierProvider).valueOrNull?.urlTestDelay ?? 0;
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;
    final buttonTheme = Theme.of(context).extension<ConnectionButtonTheme>()!;

    final state = switch (connectionStatus) {
      AsyncData(value: Connected()) when requiresReconnect == true => _ConnectionVisualState.reconnect,
      AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => _ConnectionVisualState.connecting,
      AsyncData(value: Connected()) => _ConnectionVisualState.connected,
      AsyncData(value: Disconnected()) => _ConnectionVisualState.disconnected,
      AsyncError() => _ConnectionVisualState.error,
      _ => _ConnectionVisualState.connecting,
    };

    final label = switch (state) {
      _ConnectionVisualState.reconnect => t.connection.reconnect,
      _ConnectionVisualState.connecting => t.connection.connecting,
      _ConnectionVisualState.connected => t.connection.connected,
      _ConnectionVisualState.disconnected => t.connection.tapToConnect,
      _ConnectionVisualState.error => t.connection.tapToConnect,
    };
    final color = switch (state) {
      _ConnectionVisualState.connected => buttonTheme.connectedColor,
      _ConnectionVisualState.connecting || _ConnectionVisualState.reconnect => buttonTheme.connectingColor,
      _ConnectionVisualState.error => Theme.of(context).colorScheme.error,
      _ConnectionVisualState.disconnected => buttonTheme.idleColor,
    };
    final enabled = switch (connectionStatus) {
      AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
      _ => false,
    };

    return _ConnectionButton(
      label: label,
      color: color,
      enabled: enabled,
      animated: state == _ConnectionVisualState.connected || state == _ConnectionVisualState.connecting,
      connected: state == _ConnectionVisualState.connected,
      onTap: switch (connectionStatus) {
        AsyncData(value: Connected()) when requiresReconnect == true => () async {
          await ref.read(connectionNotifierProvider.notifier).reconnect(await ref.read(activeProfileProvider.future));
        },
        AsyncData(value: Disconnected()) || AsyncError() => () async {
          if (ref.read(activeProfileProvider).valueOrNull == null) {
            await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
            ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
            return;
          }
          if (await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
            await ref.read(connectionNotifierProvider.notifier).toggleConnection();
          }
        },
        AsyncData(value: Connected()) => () async {
          await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        },
        _ => () {},
      },
    );
  }
}

enum _ConnectionVisualState { disconnected, connecting, connected, reconnect, error }

class _ConnectionButton extends StatelessWidget {
  const _ConnectionButton({
    required this.label,
    required this.color,
    required this.enabled,
    required this.animated,
    required this.connected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool enabled;
  final bool animated;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: Container(
            width: 188,
            height: 188,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: .96), theme.colorScheme.secondary.withValues(alpha: .96)],
              ),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .28), blurRadius: 34, spreadRadius: 4, offset: const Offset(0, 14)),
              ],
            ),
            child: Material(
              key: const ValueKey('home_connection_button'),
              type: MaterialType.transparency,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onTap : null,
                child: Center(
                  child: Container(
                    width: 142,
                    height: 142,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .17),
                      border: Border.all(color: Colors.white.withValues(alpha: .56), width: 1.5),
                    ),
                    padding: const EdgeInsets.all(38),
                    child: Assets.images.logo.svg(
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          )
              .animate(target: animated ? 1 : 0, onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.045, duration: 1800.ms, curve: Curves.easeInOut),
        ),
        const Gap(18),
        AnimatedText(label, style: theme.textTheme.titleLarge?.copyWith(color: color)),
        const Gap(4),
        Text(
          connected ? 'Защита активна' : 'Нажмите, чтобы изменить состояние',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
