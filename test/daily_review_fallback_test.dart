import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/models/daily_issue_set.dart';
import 'package:wordapp/services/issue_quiz_completion_service.dart';
import 'package:wordapp/services/review_service.dart';

const vocabulary = {
  'tariff': '관세',
  'inflation': '물가 상승',
  'ceasefire': '휴전',
  'lawsuit': '소송',
  'semiconductor': '반도체',
  'emissions': '배출량',
  'vaccination': '예방접종',
  'coalition': '연합',
  'regulation': '규제',
  'retention': '유지율',
  'leverage': '활용 효과',
  'funding': '자금 지원',
  'deficit': '적자',
  'breach': '정보 유출',
  'subsidy': '보조금',
};

DailyIssueSet dailyFixture() => DailyIssueSet.fromMap({
  'date': '2026-10-13',
  'status': 'ready',
  'issues': List.generate(
    5,
    (issue) => {
      'id': 'issue_$issue',
      'category': 'economy',
      'topic': 'monetary_policy',
      'issue_title_ko': '세계 주요 뉴스 $issue',
      'what_happened': '기사에 보도된 주요 변화입니다.',
      'why_it_matters': '경제와 사회에 영향을 줍니다.',
      'articles': [
        {
          'title': 'News report $issue',
          'source': 'Reuters',
          'url': 'https://example.com/$issue',
          'published_at': '2026-10-12T10:00:00Z',
        },
      ],
      'words': vocabulary.entries
          .skip(issue * 3)
          .take(3)
          .map(
            (entry) => {
              'word': entry.key,
              'meaning': entry.value,
              'part_of_speech': 'noun',
              'level': 'intermediate',
              'description_ko': '${entry.value}에 관한 기사 문맥을 설명합니다.',
              'example': 'The report discusses ${entry.key}.',
              'example_ko': '보도는 ${entry.value}에 대해 설명합니다.',
            },
          )
          .toList(),
      'extra_expressions': [
        {'expression': 'not a core word', 'meaning': '추가 표현'},
      ],
    },
  ),
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final set = dailyFixture();
  final today = set.learningWords;

  for (final completed in [0, 1, 3, 5]) {
    test(
      '$completed Issue Quizzes: 10 unique questions with old words first',
      () {
        final stored = today
            .take(completed * 3)
            .map((word) => {...word, 'is_learned': true, 'wrong_count': 3})
            .toList();
        final pool = ReviewService.buildDailyReviewPool(
          storedWords: stored,
          todayWords: today,
        );
        expect(pool, hasLength(15));
        expect(
          pool
              .take(stored.length)
              .every((w) => !ReviewService.isTemporaryWord(w)),
          isTrue,
        );
        expect(
          pool.where(ReviewService.isTemporaryWord),
          hasLength(15 - stored.length),
        );
        final questions = previewUniqueReviewQuestions(pool);
        expect(questions, hasLength(10));
        expect(
          questions.map((q) => (q['wordData'] as Map)['word']).toSet(),
          hasLength(10),
        );
        expect(pool.any((w) => w['word'] == 'not a core word'), isFalse);
        for (final q in questions) {
          final choices = q['choices'] as List;
          expect(choices.toSet(), hasLength(choices.length));
          expect(
            choices.where((option) => option == q['correctAnswer']),
            hasLength(1),
          );
        }
      },
    );
  }

  test(
    'excluded/mastered today duplicates cannot bypass historical filters',
    () {
      final stored = [
        {...today[0], 'is_learned': true, 'review_excluded': true},
        {...today[1], 'is_learned': true, 'is_mastered': true},
        {...today[2], 'is_saved': true, 'wrong_count': 8},
      ];
      final pool = ReviewService.buildDailyReviewPool(
        storedWords: stored,
        todayWords: today,
      );
      expect(pool.map((w) => w['word']), isNot(contains('tariff')));
      expect(pool.map((w) => w['word']), isNot(contains('inflation')));
      expect(pool.first['word'], 'ceasefire');
      expect(previewUniqueReviewQuestions(pool), hasLength(10));
    },
  );

  test('canonical word ID removes case/space duplicates', () {
    final pool = ReviewService.buildDailyReviewPool(
      storedWords: [
        {...today[0], 'word': ' TARIFF ', 'id': 'tariff', 'is_learned': true},
      ],
      todayWords: [
        ...today,
        {...today[0], 'word': 'tariff'},
      ],
    );
    expect(pool, hasLength(15));
    expect(pool.where((w) => w['id'] == 'tariff'), hasLength(1));
  });

  test('existing history is prioritized even with zero quizzes today', () {
    final history = [
      {...today[0], 'is_saved': true, 'review_wrong_count': 4},
      {...today[1], 'is_learned': true, 'review_level': 2},
    ];
    final pool = ReviewService.buildDailyReviewPool(
      storedWords: history,
      todayWords: today,
    );
    expect(pool.first['word'], 'tariff');
    expect(
      pool.take(2).every((w) => !ReviewService.isTemporaryWord(w)),
      isTrue,
    );
    final questions = previewUniqueReviewQuestions(pool);
    expect(questions, hasLength(10));
    expect(questions.where((q) => q['type'] == 'spelling'), hasLength(1));
    expect(history[1]['review_level'], 2);
  });

  testWidgets('slow user_words lookup times out to local daily pool', (
    tester,
  ) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    final result = ReviewService.getDailyReviewPool(
      todayWords: today,
      loadStoredWords: () => pending.future,
    );
    await tester.pump(const Duration(seconds: 9));
    expect(previewUniqueReviewQuestions(await result), hasLength(10));
    pending.complete([]);
  });

  test('read error falls back to already loaded data without writes', () async {
    final pool = await ReviewService.getDailyReviewPool(
      todayWords: today,
      loadStoredWords: () async => throw StateError('offline'),
    );
    expect(pool, hasLength(15));
    expect(previewUniqueReviewQuestions(pool), hasLength(10));
    for (final word in pool) {
      await ReviewService.updateReviewResultForWord(word, true);
      await ReviewService.updateReviewResultForWord(word, false);
      await ReviewService.excludeWordFromReview(word);
      await ReviewService.restoreWordToReview(word);
    }
    // No Firebase app is initialized: any authentication/write would fail.
  });

  test('ambiguous synonym cannot be an alternative correct answer', () {
    final pool = ReviewService.buildDailyReviewPool(
      storedWords: [],
      todayWords: today,
    );
    final questions = previewUniqueReviewQuestions(
      pool,
      distractorWords: [
        {'word': 'duty', 'meaning': '관세, 세금', 'part_of_speech': 'noun'},
      ],
    );
    final question = questions.firstWhere(
      (q) => (q['wordData'] as Map)['word'] == 'tariff',
    );
    expect(question['choices'], isNot(contains('관세, 세금')));
    expect(question['choices'], isNot(contains('duty')));
  });

  test('insufficient words do not cycle answers to force ten', () {
    expect(previewUniqueReviewQuestions(today.take(3).toList()), hasLength(3));
  });

  for (final completed in [0, 1, 3, 5]) {
    testWidgets(
      'last issue navigation works with $completed quizzes complete',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: IssueLearningPage(
              issueSet: set,
              issueIndex: 4,
              completedIssueIndexes: {for (var i = 0; i < completed; i++) i},
              loadReviewWordsForTest: (_) async => today
                  .take(completed * 3)
                  .map((w) => {...w, 'is_learned': true})
                  .toList(),
              reviewPageBuilderForTest: (words) => ReviewQuizPage(
                reviewWords: words,
                learnedWords: today,
                questionLimit: 10,
                uniqueWordQuestions: true,
                reviewCompletionChecker: (_) async => false,
                reviewGuideShouldShow: () async => false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '복습 퀴즈 풀기'));
        await tester.pumpAndSettle();
        expect(find.byType(ReviewQuizPage), findsOneWidget);
        expect(find.text('1 / 10'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'answer/exclude/exit never persists temporary words or issue completion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var writes = 0;
      final pool = ReviewService.buildDailyReviewPool(
        storedWords: [],
        todayWords: today,
      );
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewQuizPage(
            reviewWords: pool,
            questionLimit: 10,
            uniqueWordQuestions: true,
            reviewCompletionChecker: (_) async => false,
            reviewGuideShouldShow: () async => false,
            updateReviewResultForWord: (_, _) async {
              writes++;
            },
            excludeWordFromReview: (_) async {
              writes++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final choice = find.ancestor(
        of: find.text('A.'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await tester.tap(find.text('그만 볼래요'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where(
          (k) => k.startsWith(IssueQuizCompletionService.keyPrefix),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'finishing ten temporary questions does not complete any Issue Quiz',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      var saves = 0;
      var writes = 0;
      final pool = ReviewService.buildDailyReviewPool(
        storedWords: [],
        todayWords: today,
      );
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: ReviewQuizPage(
            reviewWords: pool,
            questionLimit: 10,
            uniqueWordQuestions: true,
            reviewCompletionChecker: (_) async => false,
            reviewGuideShouldShow: () async => false,
            updateReviewResultForWord: (_, _) async {
              writes++;
            },
            saveReviewResultForTest: (_, total, _, _) async {
              saves++;
              expect(total, 10);
            },
            notifyCompletionForTest: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var index = 0; index < 10; index++) {
        final choice = find.ancestor(
          of: find.text('A.'),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        final next = find.text(index == 9 ? '결과 보기' : '다음 문제');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(saves, 1);
      expect(writes, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where(
          (k) => k.startsWith(IssueQuizCompletionService.keyPrefix),
        ),
        isEmpty,
      );
    },
  );
}
