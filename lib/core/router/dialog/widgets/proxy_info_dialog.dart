import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/proxy/model/outbound_display_name.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// User-facing diagnostics intentionally exclude host, port, IP/SNI and raw
/// location coordinates. Those are implementation details, not server labels.
class ProxyInfoDialog extends HookConsumerWidget {
  const ProxyInfoDialog({super.key, required this.outboundInfo});
  final OutboundInfo outboundInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return AlertDialog(
      title: Text(displayOutboundName(outboundInfo.tagDisplay)),
      content: OutboundInfoWidget(outboundInfo: outboundInfo),
      actions: [TextButton(onPressed: context.pop, child: Text(t.common.close))],
    );
  }
}

class OutboundInfoWidget extends StatelessWidget {
  const OutboundInfoWidget({super.key, required this.outboundInfo});
  final OutboundInfo outboundInfo;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (outboundInfo.ipinfo.countryCode.isNotEmpty) _row('Страна', outboundInfo.ipinfo.countryCode),
      if (outboundInfo.ipinfo.city.isNotEmpty) _row('Город', outboundInfo.ipinfo.city),
      _row('Задержка', outboundInfo.urlTestDelay > 0 ? '${outboundInfo.urlTestDelay} мс' : 'Не измерена'),
      _row('Состояние', outboundInfo.isSelected ? 'Выбран' : 'Доступен'),
    ],
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
