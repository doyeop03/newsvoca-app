import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/services/onboarding_service.dart';

void main() {
  test(
    'OnboardingService stores completion separately for each account',
    () async {
      SharedPreferences.setMockInitialValues({});

      expect(await OnboardingService.isCompleted('user-a'), isFalse);
      await OnboardingService.setCompleted('user-a');
      expect(await OnboardingService.isCompleted('user-a'), isTrue);
      expect(await OnboardingService.isCompleted('user-b'), isFalse);
    },
  );

  test('legacy completion migrates to only the current account', () async {
    SharedPreferences.setMockInitialValues({
      OnboardingService.legacyCompletionKey: true,
    });

    expect(await OnboardingService.isCompleted('user-a'), isTrue);
    expect(await OnboardingService.isCompleted('user-b'), isFalse);
  });

  testWidgets('onboarding next advances the PageView', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen(userId: 'test-user')),
    );
    await tester.pump();

    expect(find.textContaining('NEWSVOCA로'), findsOneWidget);
    expect(find.text('다음'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding_indicator_3')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('onboarding_indicator_4')), findsNothing);

    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.textContaining('매일 새로운 기사로'), findsOneWidget);
  });

  testWidgets('review preview automatically loops local save state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen(userId: 'test-user')),
    );

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.text('다음'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('저장한 단어와 틀린 단어를\n다시 복습해요'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    expect(find.text('복습에 다시 나와요'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('저장됨'), findsOneWidget);
    expect(find.text('복습 목록에 추가됐어요'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2900));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('저장'), findsOneWidget);
    expect(find.text('복습에 다시 나와요'), findsOneWidget);
    expect(await OnboardingService.isCompleted('test-user'), isFalse);
    expect(find.text('건너뛰기'), findsNothing);
  });

  testWidgets('V2 onboarding omits category and daily goal pages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          userId: 'test-user',
          onCompleted: () => completed = true,
          completionSaver: OnboardingService.setCompleted,
        ),
      ),
    );

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.text('다음'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '시작하기'),
    );
    expect(startButton.onPressed, isNotNull);
    expect(find.text('하루 학습 단어 수'), findsNothing);
    expect(find.text('관심 분야'), findsNothing);

    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(completed, isTrue);

    expect(await OnboardingService.isCompleted('test-user'), isTrue);
  });

  testWidgets('completion save failure does not trap the user', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var completionCalls = 0;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          userId: 'test-user',
          onCompleted: () => completed = true,
          completionSaver: (_) async {
            completionCalls++;
            throw Exception('local write failed');
          },
        ),
      ),
    );

    await _advanceToOnboardingFinish(tester);
    await tester.tap(find.text('시작하기'));
    await tester.pump();

    expect(completionCalls, 1);
    expect(completed, isTrue);
    expect(await OnboardingService.isCompleted('test-user'), isFalse);
    expect(find.textContaining('학습 설정을 저장하지 못했어요'), findsNothing);
  });

  testWidgets('a hanging completion flag save does not delay Home', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final hangingCompletion = Completer<void>();
    var completionCalls = 0;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          userId: 'test-user',
          onCompleted: () => completed = true,
          completionSaver: (_) {
            completionCalls++;
            return hangingCompletion.future;
          },
        ),
      ),
    );

    await _advanceToOnboardingFinish(tester);
    await tester.tap(find.text('시작하기'));
    await tester.pump();

    expect(completionCalls, 1);
    expect(completed, isTrue);
    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('저장 중...'), findsNothing);
    expect(find.textContaining('학습 설정을 저장하지 못했어요'), findsNothing);
    expect(find.textContaining('저장에 시간이 오래 걸리고 있어요'), findsNothing);
  });
}

Future<void> _advanceToOnboardingFinish(WidgetTester tester) async {
  for (var index = 0; index < 3; index++) {
    await tester.tap(find.text('다음'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}
