import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/learning_date.dart';
import 'auth_service.dart';
import 'local_notification_service.dart';

class LearningNotificationSettings {
  const LearningNotificationSettings({
    this.dailyEnabled = true,
    this.dailyHour = 8,
    this.dailyMinute = 0,
    this.noStudyEnabled = true,
    this.noStudyHour = 21,
    this.noStudyMinute = 0,
  });

  final bool dailyEnabled;
  final int dailyHour;
  final int dailyMinute;
  final bool noStudyEnabled;
  final int noStudyHour;
  final int noStudyMinute;

  LearningNotificationSettings copyWith({
    bool? dailyEnabled,
    bool? noStudyEnabled,
  }) => LearningNotificationSettings(
    dailyEnabled: dailyEnabled ?? this.dailyEnabled,
    dailyHour: dailyHour,
    dailyMinute: dailyMinute,
    noStudyEnabled: noStudyEnabled ?? this.noStudyEnabled,
    noStudyHour: noStudyHour,
    noStudyMinute: noStudyMinute,
  );

  Map<String, dynamic> toMap() => {
    'daily_enabled': dailyEnabled,
    'daily_hour': dailyHour,
    'daily_minute': dailyMinute,
    'no_study_enabled': noStudyEnabled,
    'no_study_hour': noStudyHour,
    'no_study_minute': noStudyMinute,
  };

  factory LearningNotificationSettings.fromMap(Map<String, dynamic>? map) {
    int number(String key, int fallback) =>
        (map?[key] as num?)?.toInt() ?? fallback;
    return LearningNotificationSettings(
      dailyEnabled: map?['daily_enabled'] as bool? ?? true,
      dailyHour: number('daily_hour', 8),
      dailyMinute: number('daily_minute', 0),
      noStudyEnabled: map?['no_study_enabled'] as bool? ?? true,
      noStudyHour: number('no_study_hour', 21),
      noStudyMinute: number('no_study_minute', 0),
    );
  }
}

class LearningNotificationService {
  static final _firestore = FirebaseFirestore.instance;
  static const _cacheKey = 'learning_notification_settings';

  static Future<LearningNotificationSettings> loadSettings() async {
    final user = AuthService.currentUser;
    if (user == null || user.isAnonymous) {
      return const LearningNotificationSettings();
    }
    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      final rawSettings = snapshot.data()?['notification_settings'];
      final settings = LearningNotificationSettings.fromMap(
        rawSettings is Map ? Map<String, dynamic>.from(rawSettings) : null,
      );
      await _cache(settings);
      return settings;
    } catch (error) {
      // ignore: avoid_print
      print('[notification] settings load failed: $error');
      return _loadCache();
    }
  }

  static Future<void> updateSettings(
    LearningNotificationSettings settings,
  ) async {
    final user = AuthService.currentUser;
    await _cache(settings);
    if (user != null && !user.isAnonymous) {
      await _firestore.collection('users').doc(user.uid).set({
        'notification_settings': {
          ...settings.toMap(),
          'updated_at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    }
    await rescheduleAll(settings: settings);
    // ignore: avoid_print
    print(
      '[notification] settings updated daily=${settings.dailyEnabled} '
      'noStudy=${settings.noStudyEnabled}',
    );
  }

  static Future<void> rescheduleAll({
    LearningNotificationSettings? settings,
  }) async {
    final current = settings ?? await loadSettings();
    final notifications = LocalNotificationService.instance;
    await notifications.initialize();
    if (current.dailyEnabled) {
      await notifications.scheduleDailyLearningNotification(
        hour: current.dailyHour,
        minute: current.dailyMinute,
      );
    } else {
      await notifications.cancelDailyLearningNotification();
    }
    if (!current.noStudyEnabled || await hasAnyLearningToday()) {
      await notifications.cancelNoStudyReminderForToday();
    } else {
      await notifications.scheduleNoStudyReminder(
        hour: current.noStudyHour,
        minute: current.noStudyMinute,
      );
    }
  }

  static Future<void> onLearningCompletedToday() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'last_learning_completed_date',
      getCurrentLearningDateKst(),
    );
    await LocalNotificationService.instance.cancelNoStudyReminderForToday();
  }

  static Future<bool> hasAnyLearningToday() async {
    final user = AuthService.currentUser;
    if (user == null || user.isAnonymous) return false;
    final date = getCurrentLearningDateKst();
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getString('last_learning_completed_date') == date) {
      return _logLearning(true);
    }
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final quiz = await userRef
          .collection('quiz_results')
          .where('date', isEqualTo: date)
          .limit(10)
          .get();
      if (quiz.docs.any((doc) => doc.data()['completed'] == true)) {
        return _logLearning(true);
      }
      final review = await userRef.collection('review_results').doc(date).get();
      if (review.data()?['completed'] == true) return _logLearning(true);

      final dateValue = DateTime.parse(date);
      final startUtc = DateTime.utc(
        dateValue.year,
        dateValue.month,
        dateValue.day - 1,
        21,
      );
      final endUtc = startUtc.add(const Duration(days: 1));
      final articles = await userRef
          .collection('article_learning_results')
          .where(
            'completed_at',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startUtc),
          )
          .where('completed_at', isLessThan: Timestamp.fromDate(endUtc))
          .limit(1)
          .get();
      return _logLearning(
        articles.docs.any((doc) => doc.data()['completed'] == true),
      );
    } catch (error) {
      // A composite index may be requested for the article query. Follow the
      // Firebase Console link in the error; do not cancel reminders on failure.
      // ignore: avoid_print
      print('[learning] check failed: $error');
      return false;
    }
  }

  static bool _logLearning(bool value) {
    // ignore: avoid_print
    print('[learning] hasAnyLearningToday=$value');
    return value;
  }

  static Future<void> _cache(LearningNotificationSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_cacheKey, [
      settings.dailyEnabled.toString(),
      settings.dailyHour.toString(),
      settings.dailyMinute.toString(),
      settings.noStudyEnabled.toString(),
      settings.noStudyHour.toString(),
      settings.noStudyMinute.toString(),
    ]);
  }

  static Future<LearningNotificationSettings> _loadCache() async {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_cacheKey);
    if (values == null || values.length != 6) {
      return const LearningNotificationSettings();
    }
    return LearningNotificationSettings(
      dailyEnabled: values[0] == 'true',
      dailyHour: int.tryParse(values[1]) ?? 8,
      dailyMinute: int.tryParse(values[2]) ?? 0,
      noStudyEnabled: values[3] == 'true',
      noStudyHour: int.tryParse(values[4]) ?? 21,
      noStudyMinute: int.tryParse(values[5]) ?? 0,
    );
  }
}
