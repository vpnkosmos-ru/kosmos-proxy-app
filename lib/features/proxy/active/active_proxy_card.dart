import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ActiveProxyFooter extends ConsumerWidget with InfraLogger {
  const ActiveProxyFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(
      connectionNotifierProvider.select((value) => value.valueOrNull ?? const Disconnected()),
    );
    final proxy = ref.watch(activeProxyNotifierProvider.select((value) => value.valueOrNull));
    final t = ref.watch(translationsProvider).requireValue;
    if (connection != const Connected() || proxy == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final delay = proxy.urlTestDelay;
    final delayColor = delay <= 0 || delay > 65000
        ? theme.colorScheme.onSurfaceVariant
        : delay < 150
        ? const Color(0xFF43B38A)
        : delay < 450
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    Future<void> test() async {
      try {
        await ref.read(activeProxyNotifierProvider.notifier).urlTest('');
      } catch (error, stackTrace) {
        loggy.error('Could not refresh active proxy delay', error, stackTrace);
      }
    }

    return Card(
      child: InkWell(
        onTap: () => context.goNamed('proxies'),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              InkResponse(
                onTap: () async {
                  await test();
                  if (context.mounted)
                    await ref.read(dialogNotifierProvider.notifier).showProxyInfo(outboundInfo: proxy);
                },
                radius: 32,
                child: IPCountryFlag(countryCode: proxy.ipinfo.countryCode, organization: proxy.ipinfo.org, size: 48),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выбранный сервер',
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      proxy.tagDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (proxy.ipinfo.ip.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      IPText(ip: proxy.ipinfo.ip, onLongPress: test, constrained: true),
                    ] else
                      Text(t.pages.proxies.unknownIp, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.signal_cellular_alt_rounded, color: delayColor),
                  const SizedBox(height: 3),
                  Text(
                    delay <= 0
                        ? '…'
                        : delay > 65000
                        ? t.common.timeout
                        : '$delay ms',
                    style: theme.textTheme.labelLarge?.copyWith(color: delayColor),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

String getRealOutboundTag(dynamic group) => group.tagDisplay as String;
