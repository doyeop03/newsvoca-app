import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const legacyCompletionKey = 'hasCompletedIntroOnboarding';
  static const completionKeyPrefix = 'onboarding_completed_';

  static String completionKeyFor(String uid) => '$completionKeyPrefix$uid';

  static Future<bool> isCompleted(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    final completionKey = completionKeyFor(uid);
    final accountCompletion = preferences.getBool(completionKey);
    if (accountCompletion != null) return accountCompletion;

    // Migrate the old device-wide flag to only the account that is currently
    // signed in. Removing it prevents another account from inheriting it.
    if (preferences.getBool(legacyCompletionKey) == true) {
      final saved = await preferences.setBool(completionKey, true);
      if (!saved) return false;
      await preferences.remove(legacyCompletionKey);
      return true;
    }
    return false;
  }

  static Future<void> setCompleted(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setBool(completionKeyFor(uid), true);
    if (!saved) {
      throw StateError('Failed to save onboarding completion.');
    }
  }
}
