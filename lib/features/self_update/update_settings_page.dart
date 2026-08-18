import 'package:flutter/material.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/features/self_update/self_update_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class UpdateSettingsPage extends ConsumerStatefulWidget {
  const UpdateSettingsPage({super.key});
  @override
  ConsumerState<UpdateSettingsPage> createState() => _UpdateSettingsPageState();
}

class _UpdateSettingsPageState extends ConsumerState<UpdateSettingsPage> with WidgetsBindingObserver {
  UpdateSnapshot? _snapshot;
  bool _checking = false;
  String? _pendingInstallPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed || _pendingInstallPath == null) return;
    final updater = ref.read(selfUpdateServiceProvider);
    if (await updater.canInstall()) {
      final path = _pendingInstallPath!;
      _pendingInstallPath = null;
      if (mounted) setState(() => _snapshot = UpdateSnapshot(UpdateStatus.ready, filePath: path));
      await updater.install(path);
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final r = await ref.read(selfUpdateServiceProvider).check();
    if (mounted)
      setState(() {
        _snapshot = r;
        _checking = false;
      });
    if (r.status == UpdateStatus.available && mounted) _show(r.manifest!);
  }

  Future<void> _show(UpdateManifest m) async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Доступно обновление Kosmos Proxy'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Версия ${m.versionName}'),
              if (m.message.isNotEmpty) ...[const SizedBox(height: 8), Text(m.message)],
              if (m.changelog.isNotEmpty) ...[const SizedBox(height: 8), ...m.changelog.map((e) => Text('• $e'))],
              const SizedBox(height: 8),
              Text('Размер: ${(m.size / 1024 / 1024).toStringAsFixed(1)} МБ'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Позже')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(c);
              await _download(m);
            },
            child: const Text('Обновить сейчас'),
          ),
        ],
      ),
    );
  }

  Future<void> _download(UpdateManifest m) async {
    setState(() => _snapshot = UpdateSnapshot(UpdateStatus.downloading, manifest: m));
    final r = await ref
        .read(selfUpdateServiceProvider)
        .download(
          m,
          onProgress: (p) {
            if (mounted) setState(() => _snapshot = UpdateSnapshot(UpdateStatus.downloading, manifest: m, progress: p));
          },
        );
    if (mounted) setState(() => _snapshot = r);
    if (r.status == UpdateStatus.ready && mounted) await ref.read(selfUpdateServiceProvider).install(r.filePath!);
    if (r.status == UpdateStatus.installPermissionRequired && mounted) await _permission(r);
  }

  Future<void> _permission(UpdateSnapshot r) async {
    _pendingInstallPath = r.filePath;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Разрешение на установку'),
        content: const Text(
          'Чтобы обновить Kosmos Proxy, разрешите установку обновлений из этого приложения. Это потребуется только один раз.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Позже')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(c);
              await ref.read(selfUpdateServiceProvider).requestInstallPermission();
            },
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final info = ref.watch(appInfoProvider).requireValue;
    final s = _snapshot;
    String status = switch (s?.status) {
      UpdateStatus.latest => 'Установлена последняя версия',
      UpdateStatus.available => 'Доступна новая версия',
      UpdateStatus.noInternet => 'Нет интернета',
      UpdateStatus.invalidManifest => 'Ошибка файла обновления',
      UpdateStatus.downloading => 'Обновление скачивается',
      UpdateStatus.ready => 'Файл готов к установке',
      UpdateStatus.installPermissionRequired => 'Требуется разрешение на установку',
      UpdateStatus.verificationFailed => 'Проверка файла не пройдена',
      UpdateStatus.unavailable => 'Проверка обновлений временно недоступна',
      _ => 'Проверка не выполнена',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Обновление приложения')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(title: Text('Текущая версия ${info.version}'), subtitle: Text('versionCode ${info.buildNumber}')),
          ListTile(title: const Text('Статус'), subtitle: Text(status)),
          if (s?.status == UpdateStatus.downloading) LinearProgressIndicator(value: s!.progress),
          if (s?.status == UpdateStatus.downloading)
            TextButton.icon(
              onPressed: () => ref.read(selfUpdateServiceProvider).cancelDownload(),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Отменить скачивание'),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _checking ? null : _check,
            icon: _checking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.system_update_rounded),
            label: const Text('Проверить обновления'),
          ),
          if (s?.message case final message?) Padding(padding: const EdgeInsets.only(top: 12), child: Text(message)),
        ],
      ),
    );
  }
}
