import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/models/daily_issue_set.dart';
import 'package:wordapp/services/issue_quiz_completion_service.dart';

DailyIssueSet fixture() => DailyIssueSet.fromMap({
  'date': '2026-08-18',
  'status': 'ready',
  'issues': List.generate(5, issueFixture),
});

Map<String, dynamic> issueFixture(int issue) => {
  'rank': issue + 1,
  'category': 'technology',
  'topic': 'robotics',
  'topic_label_ko': '로보틱스',
  'issue_title': '물가 흐름 변화와 금리 전망 ${issue + 1}',
  'issue_summary': '이슈 ${issue + 1}의 새 지표가 발표됐습니다.\n\n시장은 금리 경로를 다시 평가했습니다.',
  'issue_background': '가계 부담과 금융시장에 영향을 줄 수 있습니다.',
  'articles': [
    {
      'title': 'Inflation report',
      'source': 'Reuters',
      'publishedAt': '2026-08-18',
      'url': '',
    },
  ],
  'words': List.generate(
    3,
    (word) => {
      'word': 'outlook_${issue}_$word',
      'meaning': '전망_${issue}_$word',
      'description_ko': '앞으로의 상황을 내다보는 판단 ${issue}_$word',
      'part_of_speech': 'noun',
      'level': '중급',
      'example': 'The outlook_${issue}_$word changed.',
      'example_ko': '전망 ${issue}_$word이 바뀌었습니다.',
    },
  ),
};

List<Map<String, dynamic>> quizCandidates() => List.generate(
  6,
  (index) => {
    'word': 'candidate_$index',
    'meaning': '후보 뜻 $index',
    'description_ko': '후보 설명 $index',
    'example': 'A candidate_$index appeared.',
    'example_ko': '후보 예문 $index',
    'category': 'economy',
    'topic': 'monetary_policy',
    'part_of_speech': 'noun',
  },
);

Future<void> completeIssueQuiz(WidgetTester tester, {int issue = 0}) async {
  await tester.pumpAndSettle();
  final answers = [
    '전망_${issue}_0',
    'outlook_${issue}_1',
    'outlook_${issue}_2',
    'outlook_${issue}_0',
    '전망_${issue}_1',
  ];
  for (var index = 0; index < 5; index++) {
    final answer = find.text(answers[index]).first;
    await tester.ensureVisible(answer);
    await tester.pump();
    await tester.tap(answer);
    await tester.pump();
    await tester.tap(find.text(index == 4 ? '완료' : '다음 문제'));
    await tester.pump();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Home learning card opens the date-keyed daily issue', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(initialIssueSet: fixture())),
    );
    expect(find.text('오늘의 주요 이슈 5개'), findsOneWidget);
    expect(find.text('핵심 단어 15개를 함께 학습해요'), findsOneWidget);
    await tester.tap(find.text('오늘의 주요 이슈 5개'));
    await tester.pumpAndSettle();
    expect(find.byType(IssueLearningPage), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.textContaining('오늘의 이슈'), findsNothing);
    expect(find.text('기사로 익히기'), findsNothing);
    expect(find.text('오늘의 핵심 이슈와 단어를 차근차근 익혀보세요.'), findsNothing);
    expect(find.text('로보틱스'), findsOneWidget);
    expect(find.text('Reuters  •  2026-08-18'), findsOneWidget);
  });

  testWidgets('renders issue content and words on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: IssueLearningPage(issueSet: fixture())),
    );
    expect(find.text('무슨 일이 있었나요?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('핵심 단어 3개'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('핵심 단어 3개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders normalized flow descriptions without raw map text', (
    tester,
  ) async {
    final issues = List.generate(5, issueFixture);
    issues[0]['issue_flow'] = ["{'step': 1, 'description': '첫 번째 이슈의 흐름 설명'}"];
    issues[1]['issue_flow'] = [
      {'step': 3, 'description': '두 번째 이슈의 흐름 설명'},
    ];
    final set = DailyIssueSet.fromMap({
      'date': '2026-08-25',
      'status': 'ready',
      'issues': issues,
    });

    await tester.pumpWidget(
      MaterialApp(home: IssueLearningPage(issueSet: set)),
    );
    await tester.scrollUntilVisible(
      find.text('첫 번째 이슈의 흐름 설명'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('첫 번째 이슈의 흐름 설명'), findsOneWidget);
    expect(find.textContaining("{'step'"), findsNothing);
    expect(find.textContaining("'description'"), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, '다음 기사'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('두 번째 이슈의 흐름 설명'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('두 번째 이슈의 흐름 설명'), findsOneWidget);
    expect(find.textContaining('{step:'), findsNothing);
    expect(find.textContaining('description:'), findsNothing);
  });

  testWidgets('renders every article paragraph without truncation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: IssueLearningPage(issueSet: fixture())),
    );

    for (final paragraph in [
      '이슈 1의 새 지표가 발표됐습니다.',
      '시장은 금리 경로를 다시 평가했습니다.',
      '가계 부담과 금융시장에 영향을 줄 수 있습니다.',
    ]) {
      final finder = find.text(paragraph);
      expect(finder, findsOneWidget);
      final text = tester.widget<Text>(finder);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
    }
  });

  testWidgets('long word-card copy and phrase highlighting do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final issues = List.generate(5, issueFixture);
    final words = <Map<String, dynamic>>[
      for (final word in issues.first['words'] as List)
        Map<String, dynamic>.from(word as Map),
    ];
    issues.first['words'] = words;
    const example =
        'The court may STRIKE DOWN, the unusually long regulation after reviewing the evidence.';
    words[0] = {
      ...words[0],
      'word': 'strike down',
      'meaning': '무효로 하다, 긴 법률적 검토 후 기존 규정의 효력을 인정하지 않다',
      'description_ko': '법원이 법률이나 규정을 세밀하게 검토한 뒤 법적 효력이 없다고 판단하는 행위를 의미합니다.',
      'example': example,
      'example_ko': '법원은 근거를 검토한 후 그 긴 규정을 무효로 할 수 있습니다.',
    };
    final set = DailyIssueSet.fromMap({
      'date': '2026-08-18',
      'status': 'ready',
      'issues': issues,
    });

    await tester.pumpWidget(
      MaterialApp(home: IssueLearningPage(issueSet: set)),
    );
    await tester.scrollUntilVisible(
      find.text('strike down'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText() == example,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks all three core words in the issue scroll content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: IssueLearningPage(issueSet: fixture())),
    );

    expect(find.text('핵심 단어 3개'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '이전 기사'), findsNothing);
    expect(find.widgetWithText(FilledButton, '다음 기사'), findsOneWidget);

    expect(find.text('outlook_0_0'), findsOneWidget);
    expect(find.text('outlook_0_1'), findsOneWidget);
    expect(find.text('outlook_0_2'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '다음 기사'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('물가 흐름 변화와 금리 전망 2'), findsOneWidget);
    expect(find.text('outlook_1_0'), findsOneWidget);
    final enabledPreviousArticle = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '이전 기사'),
    );
    expect(enabledPreviousArticle.onPressed, isNotNull);
  });

  testWidgets('article navigation is free, bounded, and resets scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final set = fixture();
    await tester.pumpWidget(
      MaterialApp(home: IssueLearningPage(issueSet: set, issueIndex: 3)),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      greaterThan(0),
    );

    await tester.tap(find.widgetWithText(FilledButton, '다음 기사'));
    await tester.pumpAndSettle();
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('물가 흐름 변화와 금리 전망 5'), findsOneWidget);
    expect(
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
      0,
    );
    expect(find.widgetWithText(FilledButton, '다음 기사'), findsNothing);
    expect(find.widgetWithText(FilledButton, '복습 퀴즈 풀기'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '이전 기사'));
    await tester.pumpAndSettle();
    expect(find.text('4 / 5'), findsOneWidget);
  });

  testWidgets('per-issue quiz completion survives article navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IssueLearningPage(
          issueSet: fixture(),
          completedIssueIndexes: const {0},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('퀴즈 완료'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('퀴즈 완료'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '퀴즈 완료'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, '다음 기사'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('퀴즈 시작하기'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('퀴즈 시작하기'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '이전 기사'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('퀴즈 완료'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('퀴즈 완료'), findsOneWidget);
  });

  testWidgets('persisted completion is scoped by date and issue identity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      IssueQuizCompletionService.keyFor(
        learningDate: '2026-08-18',
        issueIdentity: 'index_0',
      ): true,
    });

    await tester.pumpWidget(
      MaterialApp(home: IssueLearningPage(issueSet: fixture())),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('퀴즈 완료'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('퀴즈 완료'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '퀴즈 완료'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('leaving an issue quiz early does not complete it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IssueLearningPage(
          issueSet: fixture(),
          loadQuizCandidateWordsForTest: () async => quizCandidates(),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('퀴즈 시작하기'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('퀴즈 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('퀴즈 시작하기'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byType(IssueLearningPage), findsOneWidget);
    expect(find.text('퀴즈 시작하기'), findsOneWidget);
    expect(find.text('퀴즈 완료'), findsNothing);
  });

  testWidgets('issue back reuses the unsaved-learning confirmation dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: IssueLearningPage(issueSet: fixture())),
    );
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
    expect(find.byType(IssueLearningPage), findsOneWidget);
  });

  test('builds five runtime questions covering all three issue words', () {
    final issue = fixture().issues.first;
    final summaries = buildIssueQuizQuestionSummariesForTest(
      issue,
      quizCandidates(),
    );
    expect(summaries, hasLength(5));
    expect(summaries.map((item) => item['word']).toSet(), hasLength(3));
    expect(summaries.every((item) => item['choice_count'] == '4'), isTrue);
  });

  test(
    'Issue Quiz prioritizes same-topic/POS distractors and guards cloze grammar',
    () {
      final map = issueFixture(0);
      final words = [
        for (final word in map['words'] as List)
          Map<String, dynamic>.from(word as Map),
      ];
      map['words'] = words;
      words[0] = {
        ...words[0],
        'word': 'disclosure',
        'meaning': '공개, 밝힘',
        'part_of_speech': 'noun',
        'example': 'The disclosure changed the outlook.',
      };
      words[2] = {
        ...words[2],
        'word': 'statement',
        'meaning': '성명',
        'part_of_speech': 'noun',
        'example': 'The statement clarified the policy.',
      };
      final issue = DailyIssueSet.fromMap({
        'date': '2026-08-25',
        'status': 'ready',
        'issues': [
          map,
          ...List.generate(4, (index) => issueFixture(index + 1)),
        ],
      }).issues.first;
      final candidates = [
        {
          'word': 'announcement',
          'meaning': '발표',
          'category': 'technology',
          'topic': 'robotics',
          'part_of_speech': 'noun',
        },
        {
          'word': 'reporting',
          'meaning': '보고',
          'category': 'technology',
          'topic': 'robotics',
          'part_of_speech': 'noun',
        },
        {
          'word': 'notice',
          'meaning': '통지',
          'category': 'technology',
          'topic': 'robotics',
          'part_of_speech': 'noun',
        },
        {
          'word': 'reveal',
          'meaning': '드러내다',
          'category': 'technology',
          'topic': 'robotics',
          'part_of_speech': 'verb',
        },
        {
          'word': 'creative AI',
          'meaning': '창작 인공지능',
          'category': 'technology',
          'topic': 'artificial_intelligence',
          'part_of_speech': 'noun',
        },
        {
          'word': 'workflow',
          'meaning': '업무 흐름',
          'category': 'business',
          'topic': 'corporate',
          'part_of_speech': 'noun',
        },
      ];

      final summaries = buildIssueQuizQuestionSummariesForTest(
        issue,
        candidates,
      );
      final meaningChoices = summaries.first.entries
          .where((entry) => entry.key.startsWith('choice_'))
          .map((entry) => entry.value)
          .toSet();
      expect(meaningChoices, containsAll({'공개, 밝힘', '발표', '보고', '통지'}));
      expect(meaningChoices, isNot(contains('창작 인공지능')));
      expect(meaningChoices, isNot(contains('업무 흐름')));

      final cloze = summaries.firstWhere(
        (item) => item['type'] == 'blankExample',
      );
      final clozeChoices = cloze.entries
          .where((entry) => entry.key.startsWith('choice_'))
          .map((entry) => entry.value)
          .toSet();
      expect(clozeChoices, isNot(contains('reveal')));
    },
  );

  testWidgets('builds runtime quiz from words with V1 hint and feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IssueLearningPage(
          issueSet: fixture(),
          loadQuizCandidateWordsForTest: () async => quizCandidates(),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('퀴즈 시작하기'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('퀴즈 시작하기'),
      ),
      findsOneWidget,
    );
    final quizStartButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '퀴즈 시작하기'),
    );
    expect(quizStartButton.onPressed, isNotNull);
    expect(
      find.descendant(
        of: find.widgetWithText(FilledButton, '퀴즈 시작하기'),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    await tester.tap(find.text('퀴즈 시작하기'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('이슈 퀴즈 · 1 / 5'), findsNothing);
    expect(find.text('"outlook_0_0"의 뜻은 무엇일까요?'), findsOneWidget);
    await tester.tap(find.text('전망_0_0').first);
    await tester.pump();
    expect(find.text('정답입니다!'), findsOneWidget);
    expect(find.text('앞으로의 상황을 내다보는 판단 0_0'), findsOneWidget);

    await tester.tap(find.text('다음 문제'));
    await tester.pump();
    await tester.tap(find.text('outlook_0_1').first);
    await tester.pump();
    await tester.tap(find.text('다음 문제'));
    await tester.pump();
    expect(find.text('힌트 보기'), findsOneWidget);
    await tester.tap(find.text('힌트 보기'));
    await tester.pumpAndSettle();
    expect(find.text('해석 힌트'), findsOneWidget);
  });

  testWidgets('issue completion returns to the issue with a disabled CTA', (
    tester,
  ) async {
    final set = fixture();
    var savedWords = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: IssueQuizPage(
          issueSet: set,
          issueIndex: 0,
          saveLearnedWordsForTest: (words) async {
            savedWords = words;
          },
          loadQuizCandidateWordsForTest: () async => quizCandidates(),
        ),
      ),
    );
    await completeIssueQuiz(tester);
    expect(find.text('퀴즈가 완료되었어요'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    expect(find.byType(IssueLearningPage), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('퀴즈 완료'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('퀴즈 완료'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '퀴즈 완료'))
          .onPressed,
      isNull,
    );
    expect(savedWords, hasLength(3));
    expect(
      savedWords.every(
        (word) => word['word'].toString().startsWith('outlook_0_'),
      ),
      isTrue,
    );
  });

  testWidgets('review CTA depends only on being on the fifth issue', (
    tester,
  ) async {
    final set = fixture();

    for (final issueIndex in [0, 3]) {
      await tester.pumpWidget(
        MaterialApp(
          home: IssueLearningPage(issueSet: set, issueIndex: issueIndex),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('복습 퀴즈 풀기'), findsNothing);
    }

    var requestedLimit = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: IssueLearningPage(
          issueSet: set,
          issueIndex: 4,
          loadReviewWordsForTest: (limit) async {
            requestedLimit = limit;
            return set.learningWords;
          },
          reviewPageBuilderForTest: (words) => ReviewQuizPage(
            reviewWords: words,
            questionLimit: 10,
            reviewCompletionChecker: (_) async => false,
            reviewGuideShouldShow: () async => false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('퀴즈 시작하기'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('퀴즈 시작하기'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '복습 퀴즈 풀기'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '복습 퀴즈 풀기'));
    await tester.pumpAndSettle();
    expect(requestedLimit, 10);
    expect(find.byType(ReviewQuizPage), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
  });

  testWidgets('fifth issue returns to learning and starts review only on tap', (
    tester,
  ) async {
    final set = fixture();
    var savedWordCount = 0;
    var requestedLimit = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: IssueQuizPage(
          issueSet: set,
          issueIndex: 4,
          loadQuizCandidateWordsForTest: () async => quizCandidates(),
          saveLearnedWordsForTest: (words) async {
            savedWordCount = words.length;
          },
          loadReviewWordsForTest: (limit) async {
            requestedLimit = limit;
            return set.learningWords;
          },
          reviewPageBuilderForTest: (words) => ReviewQuizPage(
            reviewWords: words,
            questionLimit: 10,
            reviewCompletionChecker: (_) async => false,
            reviewGuideShouldShow: () async => false,
          ),
        ),
      ),
    );
    await completeIssueQuiz(tester, issue: 4);
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    expect(find.byType(DailyQuizPage), findsNothing);
    expect(savedWordCount, 3);
    expect(find.byType(ReviewQuizPage), findsNothing);
    expect(find.byType(IssueLearningPage), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '복습 퀴즈 풀기'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, '복습 퀴즈 풀기'));
    await tester.pumpAndSettle();
    expect(requestedLimit, 10);
    expect(find.byType(ReviewQuizPage), findsOneWidget);
    expect(find.text('1 / 10'), findsOneWidget);
  });
}
