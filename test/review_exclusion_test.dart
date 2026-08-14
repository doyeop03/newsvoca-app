import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/services/review_service.dart';

void main() {
  const firstWord = <String, dynamic>{
    'id': 'first-word',
    'word': 'sanction',
    'meaning': '제재',
    'description_ko': '규칙을 어긴 대상에게 가하는 제재',
    'example': 'The country imposed a sanction.',
    'example_ko': '그 국가는 제재를 부과했습니다.',
    'category': 'world',
    'is_learned': true,
  };
  const secondWord = <String, dynamic>{
    'id': 'second-word',
    'word': 'policy',
    'meaning': '정책',
    'description_ko': '조직이나 정부가 따르는 방침',
    'example': 'The government announced a new policy.',
    'example_ko': '정부는 새 정책을 발표했습니다.',
    'category': 'politics',
    'is_saved': true,
  };

  Future<void> useTallViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> answerFirstChoice(WidgetTester tester) async {
    final firstChoice = find.ancestor(
      of: find.text('A.'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(firstChoice);
    await tester.tap(firstChoice);
    await tester.pump();
  }

  Future<void> excludeCurrentWord(WidgetTester tester) async {
    await tester.tap(find.text('그만 볼래요'));
    await tester.pumpAndSettle();
    expect(find.text('이 단어는 다음 복습부터 나오지 않아요.'), findsWidgets);
    await tester.tap(find.text('제외하기'));
    await tester.pumpAndSettle();
  }

  ReviewQuizPage buildPage({
    required List<Map<String, dynamic>> words,
    required ReviewWordExcluder excluder,
    ReviewWordRestorer? restorer,
    ReviewWordResultUpdater? updater,
  }) {
    return ReviewQuizPage(
      reviewWords: words,
      reviewCompletionChecker: (_) async => false,
      updateReviewResultForWord: updater ?? (_, _) async {},
      excludeWordFromReview: excluder,
      restoreWordToReview: restorer ?? (_) async {},
      reviewGuideShouldShow: () async => false,
    );
  }

  test('review candidates exclude only explicitly excluded words', () {
    expect(ReviewService.isReviewCandidate(firstWord), isTrue);
    expect(
      ReviewService.isReviewCandidate({...firstWord, 'review_excluded': false}),
      isTrue,
    );
    expect(
      ReviewService.isReviewCandidate({...firstWord, 'review_excluded': true}),
      isFalse,
    );
  });

  test('review exclusion update contains only recoverable status fields', () {
    final timestamp = Object();
    expect(ReviewService.buildReviewExclusionData(excludedAt: timestamp), {
      'review_excluded': true,
      'review_excluded_at': timestamp,
      'review_excluded_reason': 'user_stop',
    });
    final deletedValue = Object();
    expect(ReviewService.buildReviewRestoreData(deletedValue: deletedValue), {
      'review_excluded': false,
      'review_excluded_at': deletedValue,
      'review_excluded_reason': deletedValue,
    });
  });

  testWidgets('stop-review action toggles immediately after answering', (
    tester,
  ) async {
    await useTallViewport(tester);
    var answerUpdates = 0;
    var exclusionCalls = 0;
    var restorationCalls = 0;
    Map<String, dynamic>? excludedWord;
    await tester.pumpWidget(
      MaterialApp(
        home: buildPage(
          words: [firstWord],
          updater: (_, _) async => answerUpdates++,
          excluder: (wordData) async {
            exclusionCalls++;
            excludedWord = wordData;
          },
          restorer: (_) async => restorationCalls++,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('그만 볼래요'), findsNothing);
    await answerFirstChoice(tester);
    expect(find.text('그만 볼래요'), findsOneWidget);
    expect(answerUpdates, 1);

    await excludeCurrentWord(tester);

    expect(exclusionCalls, 1);
    expect(excludedWord?['id'], firstWord['id']);
    expect(find.text('복습에서 제외했어요'), findsOneWidget);
    expect(find.text('1 / 15'), findsOneWidget);
    expect(answerUpdates, 1);

    await tester.tap(find.text('복습에서 제외했어요'));
    await tester.pumpAndSettle();
    expect(restorationCalls, 1);
    expect(find.text('그만 볼래요'), findsOneWidget);
    expect(find.text('복습에서 제외했어요'), findsNothing);
    expect(answerUpdates, 1);
  });

  testWidgets('moving to the next word resets the exclusion UI state', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: buildPage(words: [firstWord, secondWord], excluder: (_) async {}),
      ),
    );
    await tester.pump();

    await answerFirstChoice(tester);
    await excludeCurrentWord(tester);
    expect(find.text('복습에서 제외했어요'), findsOneWidget);

    await tester.tap(find.text('다음 문제'));
    await tester.pump();
    expect(find.text('복습에서 제외했어요'), findsNothing);
    expect(find.text('그만 볼래요'), findsNothing);
  });

  testWidgets('failed exclusion keeps the answered question retryable', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: buildPage(
          words: [firstWord],
          excluder: (_) => Future<void>.error(Exception('write failed')),
        ),
      ),
    );
    await tester.pump();

    await answerFirstChoice(tester);
    await tester.tap(find.text('그만 볼래요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('제외하기'));
    await tester.pumpAndSettle();

    expect(find.text('그만 볼래요'), findsOneWidget);
    expect(find.text('복습에서 제외했어요'), findsNothing);
    expect(find.text('복습 제외 처리를 완료하지 못했어요.\n잠시 후 다시 시도해 주세요.'), findsOneWidget);
  });

  testWidgets('exclusion keeps duplicate questions and prevents duplicate writes', (
    tester,
  ) async {
    await useTallViewport(tester);
    var exclusionCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: buildPage(
          words: [firstWord],
          excluder: (_) async => exclusionCalls++,
        ),
      ),
    );
    await tester.pump();

    await answerFirstChoice(tester);
    await excludeCurrentWord(tester);
    expect(exclusionCalls, 1);
    expect(find.text('1 / 15'), findsOneWidget);

    await tester.tap(find.text('다음 문제'));
    await tester.pump();
    expect(find.text('2 / 15'), findsOneWidget);
    await answerFirstChoice(tester);
    expect(find.text('다음 복습부터 제외돼요'), findsOneWidget);
    expect(find.text('이번 복습의 남은 문제는 그대로 진행해요.'), findsOneWidget);
    expect(find.text('그만 볼래요'), findsNothing);
    expect(exclusionCalls, 1);
  });
}
