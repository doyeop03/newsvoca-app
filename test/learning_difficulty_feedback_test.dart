import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/services/learning_difficulty_feedback_service.dart';

void main() {
  test('uses a deterministic date and category document id', () {
    expect(
      LearningDifficultyFeedbackService.documentId(
        uid: 'user/1',
        learningDate: '2026-08-07',
        category: 'daily',
      ),
      'user_1_2026-08-07_daily',
    );
  });

  test('stores snapshots using only fields present in learned words', () {
    final snapshots = LearningDifficultyFeedbackService.buildWordSnapshots([
      {
        'id': 'regulation-id',
        'word': 'regulation',
        'meaning': '규제',
        'level': 'B2',
        'email': 'not-saved@example.com',
      },
      {'word': 'subsidy', 'meaning': '보조금'},
      {'word': '   ', 'meaning': '제외'},
    ]);

    expect(snapshots, [
      {
        'word': 'regulation',
        'id': 'regulation-id',
        'meaning': '규제',
        'level': 'B2',
      },
      {'word': 'subsidy', 'meaning': '보조금'},
    ]);
  });

  test('builds the complete rating payload from the actual set', () {
    final createdAt = Object();
    final updatedAt = Object();
    final words = [
      {'word': 'regulation', 'meaning': '규제', 'level': 'B2'},
      {'word': 'subsidy', 'meaning': '보조금', 'level': 'B2'},
    ];

    final data = LearningDifficultyFeedbackService.buildData(
      uid: 'uid-1',
      learningDate: '2026-08-07',
      category: 'daily',
      rating: 'too_hard',
      words: words,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(data['uid'], 'uid-1');
    expect(data['learning_date'], '2026-08-07');
    expect(data['category'], 'daily');
    expect(data['rating'], 'too_hard');
    expect(data['rating_label'], '매우 어려웠어요');
    expect(data['word_count'], words.length);
    expect(data['words'], words);
    expect(data['created_at'], same(createdAt));
    expect(data['updated_at'], same(updatedAt));
  });

  test('supports every difficulty rating and its Korean label', () {
    expect(LearningDifficultyFeedbackService.ratingLabels, {
      'too_hard': '매우 어려웠어요',
      'just_right': '적당했어요',
      'too_easy': '너무 쉬웠어요',
    });
  });
}
