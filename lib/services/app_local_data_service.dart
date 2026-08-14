import 'package:shared_preferences/shared_preferences.dart';

class AppLocalDataService {
  static const _exactKeys = <String>{
    'hasCompletedIntroOnboarding',
    'pendingOnboardingInterestCategories',
    'pendingOnboardingDailyWordGoal',
    'article_related_words_guide_hidden',
    'review_curve_guide_hidden',
    'daily_learning_guide_hidden',
    'learning_notification_settings',
    'last_learning_completed_date',
  };

  static const _dailyQuizCompletedPrefix = 'daily_quiz_completed_';

  static Future<void> clearAppPreferences({String? uid}) async {
    final preferences = await SharedPreferences.getInstance();
    final appKeys = preferences.getKeys().where(
      (key) =>
          _exactKeys.contains(key) || key.startsWith(_dailyQuizCompletedPrefix),
    );

    for (final key in appKeys.toList(growable: false)) {
      await preferences.remove(key);
    }
    if (uid != null) {
      await preferences.remove('onboarding_completed_$uid');
    }
  }
}
