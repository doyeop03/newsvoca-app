import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/learning_date.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();
  static const dailyLearningNotificationId = 1001;
  static const noStudyReminderNotificationId = 2001;
  static const _channelId = 'newsvoca_learning';
  static const _channelName = 'NEWSVOCA 학습 알림';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _supportsScheduling =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (_initialized || !_supportsScheduling) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
    // ignore: avoid_print
    print('[notification] initialized');
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_supportsScheduling) return false;
    bool granted = false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      granted = await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      granted = await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    // ignore: avoid_print
    print('[notification] permission granted=$granted');
    return granted;
  }

  Future<void> scheduleDailyLearningNotification({
    int hour = 8,
    int minute = 0,
  }) async {
    await initialize();
    if (!_supportsScheduling) return;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: dailyLearningNotificationId,
      title: '오늘의 뉴스 단어가 준비됐어요',
      body: '5분만 투자해서 오늘의 이슈를 영어로 만나보세요',
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    // ignore: avoid_print
    print('[notification] daily scheduled ${_timeLabel(hour, minute)}');
  }

  Future<void> scheduleNoStudyReminder({
    int hour = 21,
    int minute = 0,
  }) async {
    await initialize();
    if (!_supportsScheduling) return;
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    await _plugin.cancel(id: noStudyReminderNotificationId);
    if (!scheduled.isAfter(now)) return;
    await _plugin.zonedSchedule(
      id: noStudyReminderNotificationId,
      title: '오늘 학습을 아직 시작하지 않았어요',
      body: '지금이라도 오늘의 뉴스 단어를 확인해볼까요?',
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    // ignore: avoid_print
    print(
      '[notification] no-study reminder scheduled '
      '${_timeLabel(hour, minute)} for date=${getCurrentLearningDateKst()}',
    );
  }

  Future<void> cancelDailyLearningNotification() async {
    await initialize();
    if (_supportsScheduling) {
      await _plugin.cancel(id: dailyLearningNotificationId);
    }
  }

  Future<void> cancelNoStudyReminderForToday() async {
    await initialize();
    if (_supportsScheduling) {
      await _plugin.cancel(id: noStudyReminderNotificationId);
    }
    // ignore: avoid_print
    print(
      '[notification] no-study reminder canceled '
      'for date=${getCurrentLearningDateKst()}',
    );
  }

  Future<void> openSystemNotificationSettings() async {
    await openAppSettings();
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: '데일리 학습과 미학습 리마인더 알림',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  String _timeLabel(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}
