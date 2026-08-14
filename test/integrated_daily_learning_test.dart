import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/services/integrated_daily_learning_service.dart';
import 'package:wordapp/services/user_preference_service.dart';

void main() {
  group('distributeDailyWords', () {
    test('preserves category order and spreads a 9 word goal', () {
      final result = distributeDailyWords(
        categories: const ['economy', 'world', 'technology'],
        dailyWordGoal: 9,
      );

      expect(result.keys, ['economy', 'world', 'technology']);
      expect(result.values, [3, 3, 3]);
    });

    test('caps each category at three words', () {
      final result = distributeDailyWords(
        categories: const ['economy', 'world'],
        dailyWordGoal: 15,
      );

      expect(result, {'economy': 3, 'world': 3});
    });

    test('assigns remainder to earlier selected categories', () {
      final result = distributeDailyWords(
        categories: const ['economy', 'world', 'society'],
        dailyWordGoal: 3,
      );

      expect(result, {'economy': 1, 'world': 1, 'society': 1});
    });
  });

  test('daily goal determines review question limit', () {
    expect(getReviewCountForDailyGoal(3), 7);
    expect(getReviewCountForDailyGoal(9), 9);
    expect(getReviewCountForDailyGoal(15), 12);
    expect(getReviewCountForDailyGoal(999), 9);
  });

  group('daily word goal availability', () {
    test('enables goals from selected category capacity', () {
      expect(getAvailableDailyWordGoals(0), isEmpty);
      expect(getAvailableDailyWordGoals(1), [3]);
      expect(getAvailableDailyWordGoals(2), [3]);
      expect(getAvailableDailyWordGoals(3), [3, 9]);
      expect(getAvailableDailyWordGoals(4), [3, 9]);
      expect(getAvailableDailyWordGoals(5), [3, 9, 15]);
    });

    test('lowers an unavailable goal to the largest possible option', () {
      expect(
        normalizeDailyWordGoal(currentGoal: 15, selectedCategoryCount: 3),
        9,
      );
      expect(
        normalizeDailyWordGoal(currentGoal: 9, selectedCategoryCount: 1),
        3,
      );
      expect(
        normalizeDailyWordGoal(currentGoal: 15, selectedCategoryCount: 0),
        3,
      );
    });
  });
}
