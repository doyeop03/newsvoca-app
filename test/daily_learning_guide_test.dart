import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/services/article_related_words_guide_service.dart';
import 'package:wordapp/services/daily_learning_guide_service.dart';
import 'package:wordapp/services/integrated_daily_learning_service.dart';
import 'package:wordapp/services/review_curve_guide_service.dart';

void main() {
  const learningSet = IntegratedDailyLearningSet(
    date: '2026-08-06',
    words: [
      {
        'word': 'sanction',
        'meaning': '제재',
        'description_ko': '규칙 위반에 대해 가하는 제재',
        'part_of_speech': 'noun',
        'example': 'The country imposed a sanction.',
        'example_ko': '그 국가는 제재를 부과했습니다.',
        'category': 'world',
        'related_articles': [
          {
            'title': 'Countries discuss new sanctions',
            'source': 'NEWS',
            'publishedAt': '2026-08-06',
            'url': 'https://example.com/article',
          },
        ],
      },
    ],
    categories: ['world'],
    requestedGoal: 3,
    actualWordCount: 1,
  );

  const emptyLearningSet = IntegratedDailyLearningSet(
    date: '2026-08-06',
    words: [],
    categories: [],
    requestedGoal: 3,
    actualWordCount: 0,
  );

  const navigationLearningSet = IntegratedDailyLearningSet(
    date: '2026-08-06',
    words: [
      {'word': 'first', 'meaning': '첫 번째', 'category': 'world'},
      {'word': 'second', 'meaning': '두 번째', 'category': 'world'},
      {'word': 'third', 'meaning': '세 번째', 'category': 'world'},
    ],
    categories: ['world'],
    requestedGoal: 3,
    actualWordCount: 3,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLearning(
    WidgetTester tester, {
    Key? key,
    IntegratedDailyLearningSet set = learningSet,
    DailyLearningGuideVisibilityChecker? shouldShow,
    DailyLearningGuideHideHandler? hidePermanently,
    Size size = const Size(390, 844),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: WordDetailScreen(
          key: key,
          integratedSet: set,
          dailyLearningGuideShouldShow: shouldShow ?? () async => true,
          hideDailyLearningGuidePermanently:
              hidePermanently ?? DailyLearningGuideService.hidePermanently,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
  }

  test('daily guide preference stays independent from other guides', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      ArticleRelatedWordsGuideService.hiddenPreferenceKey,
      true,
    );
    await preferences.setBool(
      ReviewCurveGuideService.hiddenPreferenceKey,
      true,
    );

    expect(await DailyLearningGuideService.shouldShow(), isTrue);
    await DailyLearningGuideService.hidePermanently();
    expect(await DailyLearningGuideService.shouldShow(), isFalse);
    expect(
      preferences.getBool(ArticleRelatedWordsGuideService.hiddenPreferenceKey),
      isTrue,
    );
    expect(
      preferences.getBool(ReviewCurveGuideService.hiddenPreferenceKey),
      isTrue,
    );
  });

  testWidgets('shows after the first word is ready and close preserves it', (
    tester,
  ) async {
    await pumpLearning(tester);

    expect(find.text('오늘의 단어, 이렇게 학습해요'), findsOneWidget);
    expect(find.text('오늘의 단어를 확인해 보세요'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(DailyLearningGuideService.hiddenPreferenceKey),
      isNull,
    );
    expect(find.text('sanction'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('데일리 퀴즈 풀기'), findsOneWidget);
  });

  testWidgets('word navigation lives after the content and respects bounds', (
    tester,
  ) async {
    await pumpLearning(
      tester,
      set: navigationLearningSet,
      shouldShow: () async => false,
    );

    expect(find.text('first'), findsOneWidget);
    expect(find.text('이전 단어'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('다음 단어'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('다음 단어'));
    await tester.pumpAndSettle();

    expect(find.text('second'), findsOneWidget);
    expect(find.text('이전 단어'), findsOneWidget);
    expect(find.text('다음 단어'), findsOneWidget);
    await tester.tap(find.text('다음 단어'));
    await tester.pumpAndSettle();

    expect(find.text('third'), findsOneWidget);
    expect(find.text('이전 단어'), findsOneWidget);
    expect(find.text('다음 단어'), findsNothing);
    expect(find.text('데일리 퀴즈 풀기'), findsOneWidget);
  });

  testWidgets('app bar back asks for confirmation before leaving learning', (
    tester,
  ) async {
    await pumpLearning(tester, shouldShow: () async => false);

    final appBarBack = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.arrow_back_rounded),
    );
    await tester.tap(appBarBack);
    await tester.pumpAndSettle();

    expect(find.text('학습을 종료할까요?'), findsOneWidget);
    expect(find.text('나가면 현재 학습 중인 내용이 저장되지 않습니다.'), findsOneWidget);
    await tester.tap(find.text('계속 학습하기'));
    await tester.pumpAndSettle();
    expect(find.byType(WordDetailScreen), findsOneWidget);

    await tester.tap(appBarBack);
    await tester.pumpAndSettle();
    await tester.tap(find.text('나가기'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(WordDetailScreen), findsNothing);
  });

  testWidgets('close allows the guide on a later learning visit', (
    tester,
  ) async {
    await pumpLearning(tester);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: WordDetailScreen(
          key: UniqueKey(),
          integratedSet: learningSet,
          dailyLearningGuideShouldShow: () async => true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('오늘의 단어, 이렇게 학습해요'), findsOneWidget);
  });

  testWidgets('hide permanently prevents the guide after app recreation', (
    tester,
  ) async {
    await pumpLearning(
      tester,
      shouldShow: DailyLearningGuideService.shouldShow,
    );

    await tester.tap(find.text('다시 보지 않기'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(DailyLearningGuideService.hiddenPreferenceKey),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WordDetailScreen(key: UniqueKey(), integratedSet: learningSet),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('오늘의 단어, 이렇게 학습해요'), findsNothing);
    expect(find.text('sanction'), findsOneWidget);
  });

  testWidgets('auto advance and direct indicator navigation stay in sync', (
    tester,
  ) async {
    await pumpLearning(tester);

    double currentDotWidth(int index) => tester
        .getSize(find.byKey(ValueKey('daily-learning-guide-dot-$index')))
        .width;

    expect(currentDotWidth(0), 24);
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(currentDotWidth(1), 24);

    await tester.tap(find.bySemanticsLabel('3단계 안내'));
    await tester.pumpAndSettle();
    expect(currentDotWidth(2), 24);
    expect(find.text('확인했다면 다음 단어로 넘어가세요'), findsOneWidget);
  });

  testWidgets('swipe changes steps and rebuild never stacks dialogs', (
    tester,
  ) async {
    await pumpLearning(tester);

    await tester.drag(find.byType(PageView), const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSize(find.byKey(const ValueKey('daily-learning-guide-dot-1')))
          .width,
      24,
    );

    await tester.pump();
    await tester.pump();
    expect(find.byType(Dialog), findsOneWidget);
  });

  testWidgets('empty daily words never check or show the guide', (
    tester,
  ) async {
    var guideChecks = 0;
    await pumpLearning(
      tester,
      set: emptyLearningSet,
      shouldShow: () async {
        guideChecks++;
        return true;
      },
    );

    expect(guideChecks, 0);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('단어 데이터가 없습니다.'), findsOneWidget);
  });

  testWidgets('guide fits a small phone without overflow', (tester) async {
    await pumpLearning(tester, size: const Size(320, 568));

    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back acts like close without saving preference', (
    tester,
  ) async {
    await pumpLearning(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(find.byType(Dialog), findsNothing);
    expect(
      preferences.getBool(DailyLearningGuideService.hiddenPreferenceKey),
      isNull,
    );
    expect(find.text('sanction'), findsOneWidget);
  });
}
