import 'package:flutter/material.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/features/proxy/model/outbound_display_name.dart';
import 'package:hiddify/gen/fonts.gen.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxyTile extends HookConsumerWidget with PresLogger {
  const ProxyTile(this.proxy, {super.key, required this.selected, required this.enabled, required this.onTap});

  final OutboundInfo proxy;
  final bool selected;
  final bool enabled;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final delay = proxy.urlTestDelay;
    final delayColor = switch (delay) {
      <= 0 => theme.colorScheme.onSurfaceVariant,
      < 150 => const Color(0xFF43B38A),
      < 450 => theme.colorScheme.tertiary,
      _ => theme.colorScheme.error,
    };
    return Opacity(
      opacity: enabled ? 1 : .46,
      child: Card(
        color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: .70) : null,
        child: InkWell(
          onTap: enabled ? onTap : null,
          onLongPress: () async => await ref.read(dialogNotifierProvider.notifier).showProxyInfo(outboundInfo: proxy),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                IPCountryFlag(countryCode: proxy.ipinfo.countryCode, organization: proxy.ipinfo.org, size: 42),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayOutboundName(proxy.tagDisplay),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: PlatformUtils.isWindows ? FontFamily.emoji : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        !enabled
                            ? 'Только для мобильной сети'
                            : proxy.isGroup
                            ? displayOutboundName(proxy.groupSelectedTagDisplay.trim())
                            : 'Доступен для подключения',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.signal_cellular_alt_rounded, size: 20, color: delayColor),
                    const SizedBox(height: 2),
                    Text(
                      delay <= 0
                          ? '…'
                          : delay > 65000
                          ? '×'
                          : '$delay ms',
                      style: theme.textTheme.labelLarge?.copyWith(color: delayColor),
                    ),
                  ],
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
