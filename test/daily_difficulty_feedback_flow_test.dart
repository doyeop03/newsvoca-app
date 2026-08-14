import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  const words = <Map<String, dynamic>>[
    {'word': 'regulation', 'meaning': '규제', 'level': 'B2'},
    {'word': 'subsidy', 'meaning': '보조금', 'level': 'B2'},
  ];

  Future<void> pumpCompletedFlow(
    WidgetTester tester, {
    required Future<bool> Function(String, String) status,
    required Future<void> Function(
      String,
      String,
      String,
      List<Map<String, dynamic>>,
    )
    save,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewQuizPage(
          reviewWords: const [],
          dailyLearningFlow: true,
          learningDate: '2026-08-06',
          feedbackCategory: 'daily',
          learnedWords: words,
          completeDailyFlowForTest: () async {},
          notifyCompletionForTest: () async {},
          feedbackStatusForTest: status,
          saveFeedbackForTest: save,
          completionHoldDuration: Duration.zero,
          completionFadeDuration: Duration.zero,
          leaveDailyFlowForTest: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('asks once at the final completion point and saves the set', (
    tester,
  ) async {
    final saves = <Map<String, dynamic>>[];
    await pumpCompletedFlow(
      tester,
      status: (_, _) async => false,
      save: (date, category, rating, learnedWords) async {
        saves.add({
          'date': date,
          'category': category,
          'rating': rating,
          'words': learnedWords,
        });
      },
    );

    expect(find.text('오늘 단어 난이도는 어땠나요?'), findsOneWidget);
    expect(find.text('다시 볼 단어'), findsNothing);
    expect(find.text('가까워진 단어'), findsNothing);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);

    await tester.tap(find.text('매우 어려웠어요'));
    await tester.pump();
    expect(saves, [
      {
        'date': '2026-08-06',
        'category': 'daily',
        'rating': 'too_hard',
        'words': words,
      },
    ]);
    expect(find.text('오늘 학습을 완료했어요'), findsOneWidget);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('skip does not save feedback in the current session', (
    tester,
  ) async {
    var saveCount = 0;
    await pumpCompletedFlow(
      tester,
      status: (_, _) async => false,
      save: (_, _, _, _) async => saveCount++,
    );

    await tester.tap(find.text('건너뛰기'));
    await tester.pump();
    expect(saveCount, 0);
    expect(find.text('오늘 학습을 완료했어요'), findsOneWidget);
    expect(find.text('오늘 단어 난이도는 어땠나요?'), findsNothing);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('already submitted feedback is not requested again', (
    tester,
  ) async {
    var saveCount = 0;
    await pumpCompletedFlow(
      tester,
      status: (_, _) async => true,
      save: (_, _, _, _) async => saveCount++,
    );

    expect(find.text('오늘 단어 난이도는 어땠나요?'), findsNothing);
    expect(find.text('오늘 학습을 완료했어요'), findsOneWidget);
    expect(saveCount, 0);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  });

  testWidgets('a feedback save failure still completes the daily flow', (
    tester,
  ) async {
    await pumpCompletedFlow(
      tester,
      status: (_, _) async => false,
      save: (_, _, _, _) async => throw StateError('save failed'),
    );

    await tester.tap(find.text('적당했어요'));
    await tester.pump();

    expect(find.text('오늘 학습을 완료했어요'), findsOneWidget);
    await tester.pump();
    await tester.pump();
  });
}
