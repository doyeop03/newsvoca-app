import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  const eligibleWord = <String, dynamic>{
    'id': 'protect',
    'word': 'protect',
    'meaning': '보호하다',
    'description_ko': '위험이나 피해를 입지 않도록 지키다',
    'review_level': 2,
    'is_learned': true,
  };

  Future<void> pumpReview(WidgetTester tester, List<bool> updates) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewQuizPage(
          reviewWords: const [eligibleWord],
          reviewCompletionChecker: (_) async => false,
          reviewGuideShouldShow: () async => false,
          updateReviewResultForWord: (_, isCorrect) async {
            updates.add(isCorrect);
          },
          excludeWordFromReview: (_) async {},
          restoreWordToReview: (_) async {},
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> reachSpellingQuestion(WidgetTester tester) async {
    for (var attempt = 0; attempt < 15; attempt++) {
      if (find.byType(TextField).evaluate().isNotEmpty) return;
      final firstChoice = find.ancestor(
        of: find.text('A.'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(firstChoice);
      await tester.tap(firstChoice);
      await tester.pump();
      final next = find.text(attempt == 14 ? '결과 보기' : '다음 문제');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
    }
    fail('spelling question was not generated');
  }

  group('review spelling comparison', () {
    test('ignores case, surrounding whitespace, and repeated spaces', () {
      expect(reviewSpellingMatches('protect', 'protect'), isTrue);
      expect(reviewSpellingMatches('Protect', 'protect'), isTrue);
      expect(reviewSpellingMatches(' PROTECT ', 'protect'), isTrue);
      expect(reviewSpellingMatches('interest   rate', 'interest rate'), isTrue);
    });

    test('requires exact spelling and meaningful punctuation', () {
      expect(reviewSpellingMatches('protekt', 'protect'), isFalse);
      expect(reviewSpellingMatches('protects', 'protect'), isFalse);
      expect(
        reviewSpellingMatches('M&A activity', 'M and A activity'),
        isFalse,
      );
    });
  });

  group('review spelling eligibility', () {
    const eligible = eligibleWord;

    test('requires review level two or higher', () {
      expect(
        isReviewSpellingCandidate({...eligible, 'review_level': 0}),
        isFalse,
      );
      expect(
        isReviewSpellingCandidate({...eligible, 'review_level': 1}),
        isFalse,
      );
      expect(isReviewSpellingCandidate(eligible), isTrue);
    });

    test('rejects excluded, invalid, and overly long candidates', () {
      expect(
        isReviewSpellingCandidate({...eligible, 'review_excluded': true}),
        isFalse,
      );
      expect(
        isReviewSpellingCandidate({...eligible, 'meaning': '뜻 정보 없음'}),
        isFalse,
      );
      expect(
        isReviewSpellingCandidate({...eligible, 'word': 'one two three four'}),
        isFalse,
      );
      expect(isReviewSpellingCandidate({...eligible, 'word': '-'}), isFalse);
    });
  });

  test('spelling questions never exceed thirty percent ceiling', () {
    expect(maxReviewSpellingQuestions(0), 0);
    expect(maxReviewSpellingQuestions(1), 0);
    expect(maxReviewSpellingQuestions(10), 3);
    expect(maxReviewSpellingQuestions(15), 4);
  });

  testWidgets('hint and normalized correct answer work', (tester) async {
    final updates = <bool>[];
    await pumpReview(tester, updates);
    await reachSpellingQuestion(tester);
    expect(find.text('모르겠어요'), findsNothing);
    expect(find.byIcon(Icons.spellcheck_rounded), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.tap(find.text('힌트 보기'));
    await tester.pump();
    expect(find.text('첫 글자는 “p”예요.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' PROTECT ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(updates.last, isTrue);
    expect(find.text('정답입니다!'), findsOneWidget);
    expect(find.text('그만 볼래요'), findsOneWidget);
  });

  testWidgets('empty submission records a wrong answer without advancing', (
    tester,
  ) async {
    final updates = <bool>[];
    await pumpReview(tester, updates);
    await reachSpellingQuestion(tester);
    final questionCounter = find.textContaining(RegExp(r'^\d+ / 15$'));
    final before = tester.widget<Text>(questionCounter.first).data;

    await tester.tap(find.text('정답 확인'));
    await tester.pump();

    expect(updates.last, isFalse);
    expect(find.text('오답입니다. 정답은 protect입니다.'), findsOneWidget);
    expect(find.text('그만 볼래요'), findsOneWidget);
    expect(tester.widget<Text>(questionCounter.first).data, before);
    expect(find.text('다음 문제'), findsOneWidget);
  });
}
