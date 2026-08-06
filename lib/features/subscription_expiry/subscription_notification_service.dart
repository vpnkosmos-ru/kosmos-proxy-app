import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/subscription_expiry/subscription_expiration_info.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final subscriptionNotificationServiceProvider = Provider<SubscriptionNotificationService>(
  (ref) => SubscriptionNotificationService(ref.watch(sharedPreferencesProvider).requireValue),
);

/// Decouples notification callbacks from Flutter's startup order.
class SubscriptionNotificationNavigation {
  static final StreamController<String> _routes = StreamController.broadcast();
  static Stream<String> get routes => _routes.stream;
  static void openCabinet() => _routes.add('/cabinet');
}

class SubscriptionNotificationService {
  SubscriptionNotificationService(this._prefs);
  final SharedPreferences _prefs;
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _enabledKey = 'kosmos_subscription_notifications_enabled';
  static const _expiryKey = 'kosmos_subscription_expiration_info_v1';
  static const _nextKey = 'kosmos_subscription_notification_next_v1';
  static const _realIds = [8130, 8131, 8120, 8121, 8110, 8111, 8100];
  static const _testIds = [8203, 8202, 8201, 8200];
  static const _channelId = 'kosmos_subscription_expiry';

  bool get enabled => _prefs.getBool(_enabledKey) ?? false;
  SubscriptionExpirationInfo? get expiration => SubscriptionExpirationInfo.fromJsonString(_prefs.getString(_expiryKey));
  DateTime? get nextScheduledAt => DateTime.tryParse(_prefs.getString(_nextKey) ?? '')?.toLocal();

  Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    tz.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // The timezone package's local default still provides safe scheduling.
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'cabinet') SubscriptionNotificationNavigation.openCabinet();
      },
    );
    _initialized = true;
    // If Android launched a cold Flutter activity from a notification, the
    // response callback is not delivered until after initialization.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true && launch!.notificationResponse?.payload == 'cabinet') {
      SubscriptionNotificationNavigation.openCabinet();
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!Platform.isAndroid) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<bool?> permissionGranted() async {
    await initialize();
    if (!Platform.isAndroid) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return android?.areNotificationsEnabled();
  }

  Future<void> setEnabled(bool value, {ProfileEntity? profile}) async {
    await initialize();
    await _prefs.setBool(_enabledKey, value);
    if (!value) {
      await cancelAll();
      return;
    }
    await requestPermission();
    await refreshFromProfile(profile);
  }

  Future<void> refreshFromProfile(ProfileEntity? profile) async {
    final info = SubscriptionExpirationInfo.fromProfile(profile);
    if (info != null) await _prefs.setString(_expiryKey, jsonEncode(info.toJson()));
    if (enabled) await scheduleCurrent();
  }

  Future<void> reschedulePersisted() async {
    await initialize();
    if (enabled && expiration != null) await scheduleCurrent();
  }

  Future<void> scheduleCurrent() async {
    await initialize();
    await _cancelIds(_realIds);
    final info = expiration;
    if (info == null || !enabled) {
      await _prefs.remove(_nextKey);
      return;
    }
    final now = tz.TZDateTime.now(tz.local);
    final expiry = tz.TZDateTime.from(info.expiresAt, tz.local);
    final entries = <({int id, tz.TZDateTime at, String title, String body})>[];
    if (expiry.isAfter(now)) {
      final endDate = tz.TZDateTime(tz.local, expiry.year, expiry.month, expiry.day);
      final reminders = [
        (
          3,
          8130,
          8131,
          'Подписка закончится через 3 дня',
          'Продлите доступ заранее, чтобы Kosmos Proxy продолжил работать без перерыва.',
        ),
        (
          2,
          8120,
          8121,
          'До окончания подписки осталось 2 дня',
          'Продлить доступ можно в личном кабинете Kosmos Proxy.',
        ),
        (
          1,
          8110,
          8111,
          'Подписка закончится завтра',
          'Продлите доступ сейчас, чтобы сохранить подключение к серверам.',
        ),
      ];
      for (final item in reminders) {
        final day = endDate.subtract(Duration(days: item.$1));
        final morning = tz.TZDateTime(tz.local, day.year, day.month, day.day, 10);
        final evening = tz.TZDateTime(tz.local, day.year, day.month, day.day, 20);
        if (morning.isAfter(now)) entries.add((id: item.$2, at: morning, title: item.$4, body: item.$5));
        if (evening.isAfter(now)) entries.add((id: item.$3, at: evening, title: item.$4, body: item.$5));
      }
      entries.add((
        id: 8100,
        at: expiry,
        title: 'Срок подписки закончился',
        body: 'Откройте кабинет, чтобы восстановить доступ.',
      ));
    }
    // Missed alarms are never replayed. IDs are deterministic and are first
    // cancelled, so profile refresh, reboot and timezone changes cannot create duplicates.
    for (final entry in entries) {
      await _schedule(entry.id, entry.at, entry.title, entry.body);
    }
    final next = entries.map((e) => e.at).fold<tz.TZDateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    if (next == null) {
      await _prefs.remove(_nextKey);
    } else {
      await _prefs.setString(_nextKey, next.toUtc().toIso8601String());
    }
  }

  Future<void> showTestNow() async {
    await initialize();
    await _plugin.show(
      id: 8299,
      title: 'Проверка уведомлений Kosmos Proxy',
      body: _testNotificationBody(),
      notificationDetails: NotificationDetails(android: _details()),
      payload: 'cabinet',
    );
  }

  String _testNotificationBody() {
    final info = expiration;
    if (info?.source == 'titleDays') {
      return 'Тест: подписка истекает через ${info!.remainingCalendarDays} дней';
    }
    return 'Тестовое уведомление отображается корректно.';
  }

  Future<void> scheduleTests() async {
    await initialize();
    await _cancelIds(_testIds);
    final now = tz.TZDateTime.now(tz.local);
    final tests = [
      (
        8203,
        1,
        'Подписка закончится через 3 дня',
        'Продлите доступ заранее, чтобы Kosmos Proxy продолжил работать без перерыва.',
      ),
      (8202, 2, 'До окончания подписки осталось 2 дня', 'Продлить доступ можно в личном кабинете Kosmos Proxy.'),
      (8201, 3, 'Подписка закончится завтра', 'Продлите доступ сейчас, чтобы сохранить подключение к серверам.'),
      (8200, 4, 'Срок подписки закончился', 'Откройте личный кабинет, чтобы восстановить доступ.'),
    ];
    for (final e in tests) {
      await _schedule(e.$1, now.add(Duration(minutes: e.$2)), e.$3, e.$4);
    }
  }

  Future<List<PendingNotificationRequest>> pendingTests() async =>
      (await _plugin.pendingNotificationRequests()).where((e) => _testIds.contains(e.id)).toList();

  Future<void> cancelAll() async {
    await _cancelIds([..._realIds, ..._testIds, 8299]);
    await _prefs.remove(_nextKey);
  }

  Future<void> cancelTests() => _cancelIds([..._testIds, 8299]);
  Future<void> _cancelIds(List<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id: id);
    }
  }

  AndroidNotificationDetails _details() => const AndroidNotificationDetails(
    _channelId,
    'Kosmos Proxy — подписка',
    channelDescription: 'Напоминания об окончании подписки',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    enableVibration: true,
    playSound: true,
    actions: [
      AndroidNotificationAction('open_cabinet', 'Открыть кабинет'),
      AndroidNotificationAction('later', 'Позже', cancelNotification: true),
    ],
  );
  Future<void> _schedule(int id, tz.TZDateTime at, String title, String body) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: at,
    notificationDetails: NotificationDetails(android: _details()),
    payload: 'cabinet',
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );
}
