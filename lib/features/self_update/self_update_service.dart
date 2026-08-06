import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _productionManifestUrl = 'https://kosmosproxy.ru/app/update.json';
const _manifestOverride = String.fromEnvironment('KOSMOS_UPDATE_MANIFEST_URL');
// This is intentionally opt-in at compile time.  It exists solely for the
// signed `mockRelease` flavour used with adb reverse; normal release builds
// cannot fetch clear-text manifests even if a URL is supplied at runtime.
const _allowLocalMock = bool.fromEnvironment('KOSMOS_ALLOW_LOCAL_UPDATE_MOCK');

final selfUpdateServiceProvider = Provider<SelfUpdateService>(
  (ref) => SelfUpdateService(ref.watch(sharedPreferencesProvider).requireValue, ref),
);

enum UpdateStatus {
  notChecked,
  latest,
  available,
  noInternet,
  invalidManifest,
  downloading,
  ready,
  installPermissionRequired,
  verificationFailed,
  unavailable,
}

class UpdateManifest {
  const UpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.minimumVersionCode,
    required this.mandatory,
    required this.publishedAt,
    required this.apkUrl,
    required this.sha256,
    required this.size,
    required this.title,
    required this.message,
    required this.changelog,
  });
  final int versionCode, minimumVersionCode, size;
  final String versionName, apkUrl, sha256, title, message;
  final bool mandatory;
  final DateTime publishedAt;
  final List<String> changelog;
  bool isMandatoryFor(int current) => mandatory || current < minimumVersionCode;
  static UpdateManifest parse(Object? raw, {required bool allowLocal}) {
    if (raw is! Map) throw const FormatException('manifest_not_object');
    final map = raw.cast<String, dynamic>();
    final schema = map['schemaVersion'];
    final code = map['versionCode'];
    final min = map['minimumVersionCode'];
    final size = map['size'];
    final version = map['versionName'];
    final urlString = map['apkUrl'];
    final hash = map['sha256'];
    if (schema != 1 ||
        code is! int ||
        code <= 0 ||
        min is! int ||
        min <= 0 ||
        size is! int ||
        size <= 0 ||
        version is! String ||
        version.trim().isEmpty ||
        urlString is! String ||
        hash is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash))
      throw const FormatException('manifest_invalid_fields');
    final url = Uri.tryParse(urlString);
    if (url == null) throw const FormatException('manifest_url');
    final prodHost = url.host == 'kosmosproxy.ru' || url.host == 'www.kosmosproxy.ru';
    final local = allowLocal && url.scheme == 'http' && (url.host == '127.0.0.1' || url.host == 'localhost');
    if (!((url.scheme == 'https' && prodHost) || local)) throw const FormatException('manifest_untrusted_url');
    final published = DateTime.tryParse(map['publishedAt'] as String? ?? '');
    if (published == null) throw const FormatException('manifest_date');
    final changes = (map['changelog'] is List)
        ? (map['changelog'] as List).whereType<String>().toList(growable: false)
        : const <String>[];
    return UpdateManifest(
      versionCode: code,
      versionName: version,
      minimumVersionCode: min,
      mandatory: map['mandatory'] == true,
      publishedAt: published,
      apkUrl: url.toString(),
      sha256: hash.toLowerCase(),
      size: size,
      title: map['title'] as String? ?? 'Доступно обновление',
      message: map['message'] as String? ?? '',
      changelog: changes,
    );
  }
}

class UpdateSnapshot {
  const UpdateSnapshot(this.status, {this.manifest, this.progress = 0, this.filePath, this.message});
  final UpdateStatus status;
  final UpdateManifest? manifest;
  final double progress;
  final String? filePath, message;
}

class SelfUpdateService {
  SelfUpdateService(this._prefs, this._ref);
  final SharedPreferences _prefs;
  final Ref _ref;
  final _channel = const MethodChannel('kosmos_proxy/update');
  final _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 12), receiveTimeout: const Duration(seconds: 30)),
  );
  int? _downloadId;
  static const _lastCheck = 'kosmos_update_last_check_v1';
  static String get manifestUrl => _manifestOverride.isNotEmpty ? _manifestOverride : _productionManifestUrl;
  bool get _allowLocal => (kDebugMode || _allowLocalMock) && _manifestOverride.isNotEmpty;
  DateTime? get lastChecked => DateTime.tryParse(_prefs.getString(_lastCheck) ?? '')?.toLocal();

  Future<UpdateSnapshot> check({bool manual = true}) async {
    final last = lastChecked;
    if (!manual && last != null && DateTime.now().difference(last) < const Duration(hours: 24))
      return const UpdateSnapshot(UpdateStatus.notChecked);
    try {
      final response = await _dio.get<String>(manifestUrl, options: Options(responseType: ResponseType.plain));
      await _prefs.setString(_lastCheck, DateTime.now().toUtc().toIso8601String());
      final manifest = UpdateManifest.parse(jsonDecode(response.data ?? ''), allowLocal: _allowLocal);
      final current = int.tryParse((await _ref.read(appInfoProvider.future)).buildNumber) ?? 0;
      return UpdateSnapshot(
        manifest.versionCode > current ? UpdateStatus.available : UpdateStatus.latest,
        manifest: manifest,
      );
    } on DioException catch (e) {
      final noNetwork =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      return UpdateSnapshot(
        noNetwork ? UpdateStatus.noInternet : UpdateStatus.unavailable,
        message: noNetwork ? 'Нет подключения к интернету' : 'Проверка обновлений временно недоступна',
      );
    } on FormatException {
      return const UpdateSnapshot(UpdateStatus.invalidManifest, message: 'Ошибка файла обновления');
    } catch (_) {
      return const UpdateSnapshot(UpdateStatus.unavailable, message: 'Проверка обновлений временно недоступна');
    }
  }

  Future<UpdateSnapshot> download(UpdateManifest manifest, {void Function(double)? onProgress}) async {
    File? file;
    try {
      final job = await _channel.invokeMapMethod<String, dynamic>('enqueueDownload', {
        'url': manifest.apkUrl,
        'versionCode': manifest.versionCode,
      });
      final id = job?['id'];
      final path = job?['path'];
      if (id is! int || path is! String) throw PlatformException(code: 'download', message: 'invalid job');
      _downloadId = id;
      file = File(path);
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final state = await _channel.invokeMapMethod<String, dynamic>('queryDownload', {'id': id});
        final status = state?['status'];
        final got = state?['downloaded'];
        final total = state?['total'];
        if (got is int && total is int && total > 0) onProgress?.call((got / total).clamp(0, 1));
        if (status == 'success') break;
        if (status != 'running') throw PlatformException(code: 'download', message: 'download failed');
      }
      if ((await file.length()) != manifest.size || !await _matchesHash(file, manifest.sha256)) {
        await file.delete();
        return const UpdateSnapshot(UpdateStatus.verificationFailed, message: 'Проверка файла не пройдена');
      }
      final verify = await _channel.invokeMapMethod<String, dynamic>('verifyArchive', {'path': file.path});
      if (verify?['valid'] != true) {
        await file.delete();
        return const UpdateSnapshot(
          UpdateStatus.verificationFailed,
          message: 'Проверка пакета или подписи не пройдена',
        );
      }
      final permission = await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
      return UpdateSnapshot(
        permission ? UpdateStatus.ready : UpdateStatus.installPermissionRequired,
        manifest: manifest,
        filePath: file.path,
      );
    } on Exception {
      if (file != null && await file.exists()) await file.delete();
      return const UpdateSnapshot(UpdateStatus.unavailable, message: 'Не удалось скачать обновление');
    } finally {
      _downloadId = null;
    }
  }

  Future<void> cancelDownload() async {
    final id = _downloadId;
    if (id != null) await _channel.invokeMethod<void>('cancelDownload', {'id': id});
  }

  Future<void> requestInstallPermission() => _channel.invokeMethod('requestInstallPermission');
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
  Future<void> install(String path) => _channel.invokeMethod('installArchive', {'path': path});
  Future<bool> _matchesHash(File file, String expected) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == expected;
  }
}
