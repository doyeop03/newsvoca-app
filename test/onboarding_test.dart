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

  testWidgets('settings require categories and a daily goal before start', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          userId: 'test-user',
          onCompleted: () => completed = true,
          preferenceSaver:
              ({required categories, required dailyWordGoal}) async {},
          completionSaver: OnboardingService.setCompleted,
        ),
      ),
    );

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.text('다음'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    FilledButton startButton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, '시작하기'));
    expect(startButton().onPressed, isNull);
    expect(find.text('하루 학습 단어 수'), findsOneWidget);

    final economyTapTarget = find.ancestor(
      of: find.text('경제'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(economyTapTarget).height, greaterThanOrEqualTo(54));
    final politicsPosition = tester.getTopLeft(find.text('정치'));
    final societyPosition = tester.getTopLeft(find.text('사회'));
    expect(societyPosition.dx, closeTo(politicsPosition.dx, 1));
    expect(societyPosition.dy, greaterThan(politicsPosition.dy));

    final threeWordTapTarget = find.ancestor(
      of: find.text('3개'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(threeWordTapTarget).height, greaterThanOrEqualTo(78));

    for (final category in ['경제', '기술', '국제']) {
      await tester.tap(find.text(category));
      await tester.pump(const Duration(milliseconds: 100));
    }

    final selectedEconomyText = tester.widget<Text>(find.text('경제'));
    expect(selectedEconomyText.style?.color, Colors.white);

    expect(find.text('하루 학습 단어 수'), findsOneWidget);
    expect(find.text('약 5분'), findsOneWidget);
    expect(find.text('약 15분'), findsOneWidget);
    expect(find.text('약 30분'), findsOneWidget);
    expect(startButton().onPressed, isNull);

    await tester.ensureVisible(find.text('9개'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -180),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('9개'));
    await tester.pump();
    expect(startButton().onPressed, isNotNull);

    await tester.tap(find.text('시작하기'));
    await tester.pump();
    expect(completed, isTrue);

    expect(await OnboardingService.isCompleted('test-user'), isTrue);
  });
}
