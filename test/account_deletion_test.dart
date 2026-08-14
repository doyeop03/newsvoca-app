import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/services/app_local_data_service.dart';
import 'package:wordapp/services/auth_service.dart';

void main() {
  group('account deletion provider selection', () {
    test('uses password reauthentication when password is linked', () {
      expect(
        AuthService.resolveAccountLoginProvider(['password']),
        AccountLoginProvider.password,
      );
    });

    test('uses Google reauthentication for a Google-only account', () {
      expect(
        AuthService.resolveAccountLoginProvider(['google.com']),
        AccountLoginProvider.google,
      );
    });

    test('prefers password when both supported providers are linked', () {
      expect(
        AuthService.resolveAccountLoginProvider(['google.com', 'password']),
        AccountLoginProvider.password,
      );
    });

    test('rejects unsupported providers before deletion', () {
      expect(
        () => AuthService.resolveAccountLoginProvider(['apple.com']),
        throwsA(isA<AccountDeletionException>()),
      );
    });
  });

  test('clears only NEWSVOCA SharedPreferences data', () async {
    SharedPreferences.setMockInitialValues({
      'hasCompletedIntroOnboarding': true,
      'pendingOnboardingInterestCategories': ['business'],
      'pendingOnboardingDailyWordGoal': 10,
      'article_related_words_guide_hidden': true,
      'review_curve_guide_hidden': true,
      'daily_learning_guide_hidden': true,
      'learning_notification_settings': ['true', '8', '0'],
      'last_learning_completed_date': '2026-08-03',
      'daily_quiz_completed_2026-08-03_business': true,
      'onboarding_completed_user-a': true,
      'onboarding_completed_user-b': true,
      'unrelated_preference': 'keep',
    });

    await AppLocalDataService.clearAppPreferences(uid: 'user-a');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getKeys(), {
      'onboarding_completed_user-b',
      'unrelated_preference',
    });
    expect(preferences.getString('unrelated_preference'), 'keep');
  });
}
