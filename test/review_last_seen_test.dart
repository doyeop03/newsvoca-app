import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  group('getLastSeenTimestampFromUserWord', () {
    test('uses the newest timestamp across all fallback fields', () {
      final firstLearned = DateTime.utc(2026, 7, 1, 3);
      final lastSaved = DateTime.utc(2026, 7, 10, 3);
      final lastReviewed = DateTime.utc(2026, 7, 20, 3);

      expect(
        getLastSeenTimestampFromUserWord({
          'first_learned_at': firstLearned,
          'last_saved_at': lastSaved,
          'last_reviewed_at': lastReviewed,
        }),
        lastReviewed,
      );
    });

    test('returns null without a usable timestamp', () {
      expect(getLastSeenTimestampFromUserWord(const {}), isNull);
    });
  });

  group('buildLastSeenLabel', () {
    final now = DateTime.utc(2026, 7, 22, 3);

    test('formats today and yesterday using KST calendar dates', () {
      expect(
        buildLastSeenLabel(DateTime.utc(2026, 7, 21, 16), now: now),
        '오늘 학습',
      );
      expect(
        buildLastSeenLabel(DateTime.utc(2026, 7, 20, 16), now: now),
        '어제 학습',
      );
    });

    test('formats day, month, year, and missing-history labels', () {
      expect(
        buildLastSeenLabel(DateTime.utc(2026, 7, 7, 3), now: now),
        '15일 전 학습',
      );
      expect(
        buildLastSeenLabel(DateTime.utc(2026, 5, 22, 3), now: now),
        '2개월 전 학습',
      );
      expect(
        buildLastSeenLabel(DateTime.utc(2025, 7, 22, 3), now: now),
        '1년 전 학습',
      );
      expect(buildLastSeenLabel(null, now: now), '학습 기록 없음');
    });
  });
}
