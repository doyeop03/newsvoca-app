import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/models/daily_issue_set.dart';
import 'package:wordapp/services/calendar_learning_service.dart';
import 'package:wordapp/services/knowledge_map_service.dart';
import 'package:wordapp/services/learning_notification_service.dart';
import 'package:wordapp/services/review_service.dart';
import 'daily_review_fallback_test.dart' as fixture;
import 'issue_learning_page_test.dart' as issue_fixture;

void main() {
  final set = fixture.dailyFixture();
  final knowledge = KnowledgeMapData.group([
    for (final word in set.learningWords) {...word, 'is_learned': true},
  ]);
  final reviewWords = ReviewService.buildDailyReviewPool(
    storedWords: [],
    todayWords: set.learningWords,
  );
  final summary = DailyLearningSummary(
    date: set.date,
    completedCategories: const [],
    learnedWordCount: 15,
    reviewScore: 8,
    reviewTotal: 10,
    hasReview: true,
    hasDailyQuiz: false,
    dailyQuizScore: 0,
    dailyQuizTotal: 0,
    hasArticleLearning: false,
    reviewAccuracyValue: null,
    dailyQuizAccuracyValue: null,
  );

  Future<void> render(
    WidgetTester tester,
    Widget page, {
    required Size size,
    required double scale,
    double nav = 48,
    double keyboard = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, platform: TargetPlatform.android),
        builder: (context, child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
            padding: EdgeInsets.only(top: 24, bottom: keyboard > 0 ? 0 : nav),
            viewPadding: EdgeInsets.only(top: 24, bottom: nav),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: child!,
        ),
        home: page,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));
  final sizes = [
    const Size(320, 640),
    const Size(360, 800),
    const Size(393, 852),
    const Size(430, 932),
    const Size(600, 1024),
    const Size(800, 1280),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 1.3, 1.5]) {
      for (final nav in [0.0, 24.0, 48.0]) {
        testWidgets('layout ${size.width}dp scale=$scale nav=$nav', (
          tester,
        ) async {
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final pages = <String, Widget>{
            'Home': HomeScreen(initialIssueSet: set),
            'Issue': IssueLearningPage(
              issueSet: set,
              issueIndex: 4,
              issueQuizCompleted: true,
            ),
            'Review': ReviewQuizPage(
              reviewWords: reviewWords,
              questionLimit: 10,
              uniqueWordQuestions: true,
              reviewCompletionChecker: (_) async => false,
              reviewGuideShouldShow: () async => false,
            ),
            'IssueQuiz': IssueQuizPage(
              issueSet: set,
              issueIndex: 0,
              loadQuizCandidateWordsForTest: () async => set.learningWords,
            ),
            'Knowledge': KnowledgeMapPage(loadForTest: () async => knowledge),
            'Calendar': LearningCalendarScreen(summaryForTest: summary),
            'Profile': const MyPageScreen(
              emailForTest: 'a.very.long.news.vocabulary.learner@example.com',
            ),
            'Login': const LoginPage(),
            'PasswordReset': const PasswordResetPage(),
            'ArticleList': const ArticleListScreen(),
            'Settings': const LearningNotificationSettingsPage(
              settingsForTest: LearningNotificationSettings(),
            ),
            'Onboarding': const OnboardingScreen(userId: 'layout-test'),
            'Article': const ArticleLearningPage(
              article: {
                'title':
                    'Long English article title about international cooperation and technology',
                'ai_summary_ko':
                    '이 문장은 기사 설명을 줄이지 않고 표시하는지 확인합니다.\n\n문단을 포함한 긴 내용을 모두 읽을 수 있어야 합니다.',
              },
            ),
          };
          for (final entry in pages.entries) {
            await tester.pumpWidget(const SizedBox.shrink());
            await render(
              tester,
              entry.value,
              size: size,
              scale: scale,
              nav: nav,
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${entry.key} ${size.width}dp / $scale / $nav',
            );
            if (entry.key == 'Home') {
              final banner = find.byWidgetPredicate(
                (widget) => widget.runtimeType.toString() == '_StreakBanner',
              );
              final caption = find.textContaining('캘린더 보기');
              expect(
                tester.getRect(banner).contains(tester.getBottomRight(caption)),
                isTrue,
              );
            }
            if (entry.key == 'Issue') {
              final button = find.widgetWithText(FilledButton, '복습 퀴즈 풀기');
              expect(
                tester.getBottomRight(button).dy,
                lessThanOrEqualTo(size.height - nav),
              );
              await tester.scrollUntilVisible(
                find.text('퀴즈 완료'),
                300,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.pump();
              expect(
                tester.getBottomRight(find.text('퀴즈 완료')).dy,
                lessThanOrEqualTo(tester.getTopLeft(button).dy),
              );
            }
            // Exercise lazily built lower cards, not just the initial viewport.
            final vertical = find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            );
            if (vertical.evaluate().isNotEmpty) {
              for (var step = 0; step < 12; step++) {
                final state = tester.state<ScrollableState>(vertical.first);
                if (state.position.pixels >= state.position.maxScrollExtent) {
                  break;
                }
                await tester.drag(
                  vertical.first,
                  Offset(0, -size.height * 0.7),
                );
                await tester.pump(const Duration(milliseconds: 500));
                expect(
                  tester.takeException(),
                  isNull,
                  reason:
                      '${entry.key} scrolled / ${size.width}dp / $scale / $nav',
                );
              }
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('footer owns one inset and lifts above IME', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final keyboard in [0.0, 300.0]) {
      await render(
        tester,
        Scaffold(
          body: const SingleChildScrollView(child: Text('Scrollable content')),
          bottomNavigationBar: BottomActionSafeArea(
            child: AdaptiveButtonBox(
              height: 58,
              width: double.infinity,
              child: FilledButton(onPressed: () {}, child: const Text('정답 확인')),
            ),
          ),
        ),
        size: const Size(360, 800),
        scale: 1.5,
        nav: 48,
        keyboard: keyboard,
      );
      final bottom = tester.getBottomRight(find.byType(FilledButton)).dy;
      expect(bottom, closeTo(800 - (keyboard == 0 ? 48 : keyboard), 0.1));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Review spelling field and footer remain above keyboard', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      ReviewQuizPage(
        reviewWords: [
          for (final word in reviewWords) {...word, 'review_level': 2},
        ],
        questionLimit: 10,
        uniqueWordQuestions: true,
        reviewCompletionChecker: (_) async => false,
        reviewGuideShouldShow: () async => false,
      ),
      size: const Size(360, 800),
      scale: 1.5,
      keyboard: 300,
    );
    final input = find.byType(TextField);
    expect(input, findsOneWidget);
    await tester.ensureVisible(input);
    await tester.pump();
    final next = find.ancestor(
      of: find.text('다음 문제'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    );
    expect(tester.getBottomRight(next).dy, lessThanOrEqualTo(800 - 300));
    expect(
      tester.getBottomRight(input).dy,
      lessThanOrEqualTo(tester.getTopLeft(next).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('long topic and word content wrap without truncation', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final issue = issue_fixture.issueFixture(0);
    issue['topic_label_ko'] = '인공지능과 국제 협력 정책의 변화';
    final words = issue['words'] as List;
    words.first['word'] = 'internationalization';
    words.first['meaning'] = '국제화, 국제 협력 범위의 확대';
    final data = DailyIssueSet.fromMap({
      'date': '2026-10-13',
      'status': 'ready',
      'issues': [issue],
    });
    await render(
      tester,
      IssueLearningPage(issueSet: data),
      size: const Size(320, 640),
      scale: 1.5,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('internationalization'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.text('internationalization')).maxLines,
      isNull,
    );
  });

  testWidgets('expanded knowledge words and bottom sheet fit scaled screen', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = KnowledgeMapData.group([
      for (var i = 0; i < 8; i++)
        {
          'id': 'long-$i',
          'word': 'internationalization_$i',
          'meaning': '국제 협력 정책을 통한 국제화 범위 확대',
          'category': 'technology',
          'topic': 'artificial_intelligence',
          'topic_label_ko': '인공지능',
          'is_learned': true,
        },
    ]);
    await render(
      tester,
      KnowledgeMapPage(loadForTest: () async => data),
      size: const Size(320, 640),
      scale: 1.5,
    );
    await tester.tap(find.text('기술'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('인공지능'));
    await tester.tap(find.text('인공지능'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('단어 8개 모두 보기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('단어 8개 모두 보기')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('단어 8개 모두 보기'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    final word = find.descendant(
      of: sheet,
      matching: find.text('internationalization_0'),
    );
    expect(tester.widget<Text>(word).maxLines, isNull);
    expect(tester.getBottomRight(word).dy, lessThanOrEqualTo(640 - 48));
  });

  testWidgets('scaled Review answers and result retain ten questions', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      ReviewQuizPage(
        reviewWords: reviewWords,
        questionLimit: 10,
        uniqueWordQuestions: true,
        reviewCompletionChecker: (_) async => false,
        reviewGuideShouldShow: () async => false,
        saveReviewResultForTest: (_, total, _, _) async => expect(total, 10),
        notifyCompletionForTest: () async {},
      ),
      size: const Size(320, 640),
      scale: 1.5,
    );
    for (var index = 0; index < 10; index++) {
      final choice = find.text('A.');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'answer $index');
      final next = find.text(index == 9 ? '결과 보기' : '다음 문제');
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'next/result $index');
    }
    expect(find.textContaining('/ 10'), findsWidgets);
  });

  testWidgets('scaled Issue answers and completion overlay fit', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      IssueQuizPage(
        issueSet: issue_fixture.fixture(),
        issueIndex: 0,
        loadQuizCandidateWordsForTest: () async =>
            issue_fixture.quizCandidates(),
        saveLearnedWordsForTest: (_) async {},
      ),
      size: const Size(320, 640),
      scale: 1.5,
    );
    await issue_fixture.completeIssueQuiz(tester);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(IssueLearningPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels and floating snackbar respect footer inset', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text('긴 안내 문구도 시스템 영역이나 고정 버튼과 겹치지 않아야 합니다.'),
              ),
            ),
            child: const Text('show'),
          ),
        ),
        bottomNavigationBar: BottomActionSafeArea(
          child: AdaptiveButtonBox(
            height: 58,
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              child: const Text('복습 퀴즈 풀기'),
            ),
          ),
        ),
      ),
      size: const Size(320, 640),
      scale: 1.5,
    );
    await tester.tap(find.text('show'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getBottomRight(find.byType(SnackBar)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(FilledButton)).dy),
    );
  });

  testWidgets('scaled learning exit dialog scrolls within safe screen', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      IssueLearningPage(issueSet: set, issueIndex: 4, issueQuizCompleted: true),
      size: const Size(320, 568),
      scale: 1.5,
    );
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all onboarding pages and signup fit at 150 percent', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await render(
      tester,
      const OnboardingScreen(userId: 'layout-test'),
      size: const Size(320, 640),
      scale: 1.5,
    );
    for (var page = 0; page < 3; page++) {
      await tester.tap(find.widgetWithText(FilledButton, '다음'));
      await tester.pump(const Duration(milliseconds: 650));
      expect(
        tester.takeException(),
        isNull,
        reason: 'Onboarding page ${page + 2}',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await render(
      tester,
      const LoginPage(),
      size: const Size(360, 640),
      scale: 1.5,
      keyboard: 250,
    );
    await tester.ensureVisible(find.text('회원가입'));
    await tester.tap(find.text('회원가입'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
