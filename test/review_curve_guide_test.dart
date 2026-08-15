import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/services/article_related_words_guide_service.dart';
import 'package:wordapp/services/review_curve_guide_service.dart';

void main() {
  const reviewWord = <String, dynamic>{
    'id': 'sanction',
    'word': 'sanction',
    'meaning': '제재',
    'description_ko': '규칙 위반에 대해 가하는 제재',
    'example': 'The country imposed a sanction.',
    'example_ko': '그 국가는 제재를 부과했습니다.',
    'category': 'world',
    'is_learned': true,
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ReviewQuizPage buildReviewPage({
    Key? key,
    ReviewGuideVisibilityChecker? reviewGuideShouldShow,
  }) {
    return ReviewQuizPage(
      key: key,
      reviewWords: const [reviewWord],
      reviewCompletionChecker: (_) async => false,
      updateReviewResultForWord: (_, _) async {},
      excludeWordFromReview: (_) async {},
      restoreWordToReview: (_) async {},
      reviewGuideShouldShow: reviewGuideShouldShow,
    );
  }

  Future<void> pumpReview(WidgetTester tester, {Key? key}) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: buildReviewPage(key: key)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  test(
    'review guide preference is independent from the article guide',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(
        ArticleRelatedWordsGuideService.hiddenPreferenceKey,
        true,
      );

      expect(await ReviewCurveGuideService.shouldShow(), isTrue);
      await ReviewCurveGuideService.hidePermanently();
      expect(await ReviewCurveGuideService.shouldShow(), isFalse);
      expect(
        preferences.getBool(
          ArticleRelatedWordsGuideService.hiddenPreferenceKey,
        ),
        isTrue,
      );
    },
  );

  testWidgets('closing shows the guide again on the next review visit', (
    tester,
  ) async {
    await pumpReview(tester);

    expect(find.text('자동 복습 안내'), findsOneWidget);
    expect(find.textContaining('학습 결과에 맞춰 필요한 단어를'), findsOneWidget);
    expect(find.text('다음 복습 시점도 자동으로 조정돼요.'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsNothing);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(ReviewCurveGuideService.hiddenPreferenceKey),
      isNull,
    );
    expect(find.text('1 / 15'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(home: buildReviewPage(key: UniqueKey())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('학습 결과에 맞춰 필요한 단어를\n자동으로 복습해요.'), findsOneWidget);
  });

  testWidgets('async guide lookup schedules a frame and shows only once', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final guideResult = Completer<bool>();
    var guideChecks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: buildReviewPage(
          reviewGuideShouldShow: () {
            guideChecks++;
            return guideResult.future;
          },
        ),
      ),
    );
    await tester.pump();
    expect(guideChecks, 1);

    guideResult.complete(true);
    await tester.idle();
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('자동 복습 안내'), findsOneWidget);
    expect(guideChecks, 1);

    await tester.pump();
    expect(find.text('자동 복습 안내'), findsOneWidget);
    expect(guideChecks, 1);
  });

  testWidgets('hide permanently survives a new review page instance', (
    tester,
  ) async {
    await pumpReview(tester);

    await tester.tap(find.text('다시 보지 않기'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getBool(ReviewCurveGuideService.hiddenPreferenceKey),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(home: buildReviewPage(key: UniqueKey())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('학습 결과에 맞춰 필요한 단어를\n자동으로 복습해요.'), findsNothing);
    expect(find.text('1 / 15'), findsOneWidget);
  });

  testWidgets('empty review sessions never check or show the guide', (
    tester,
  ) async {
    var guideChecks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewQuizPage(
          reviewWords: const [],
          reviewCompletionChecker: (_) async => false,
          reviewGuideShouldShow: () async {
            guideChecks++;
            return true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(guideChecks, 0);
    expect(find.text('학습 결과에 맞춰 필요한 단어를\n자동으로 복습해요.'), findsNothing);
    expect(find.text('오늘 복습할 단어가 없습니다.'), findsOneWidget);
  });
}
