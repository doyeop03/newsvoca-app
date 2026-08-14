import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/main.dart';

void main() {
  testWidgets('AI summary preserves newlines without truncation on a small screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const summary =
        '정부는 물가 안정을 위한 새로운 지원 대책을 발표했습니다.\n'
        '관계 부처와 지방자치단체가 대상과 집행 시기를 조율하고 있습니다.\n'
        '이번 대책은 최근 생활비 부담이 커진 상황을 배경으로 마련됐습니다.\n'
        '세부 기준은 추가 협의를 거쳐 확정되며 실제 효과도 이후 점검할 예정입니다.';

    await tester.pumpWidget(
      const MaterialApp(
        home: ArticleLearningPage(
          article: {
            'title': '생활비 지원 대책 발표',
            'ai_summary_ko': summary,
          },
        ),
      ),
    );
    await tester.pump();

    final summaryFinder = find.text(summary);
    expect(summaryFinder, findsOneWidget);

    final summaryText = tester.widget<Text>(summaryFinder);
    expect(summaryText.softWrap, isTrue);
    expect(summaryText.maxLines, isNull);
    expect(summaryText.overflow, TextOverflow.visible);
    expect(summaryText.style?.height, 1.65);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy short AI summary is still displayed unchanged', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const summary = '기존에 저장된 짧은 요약입니다.';

    await tester.pumpWidget(
      const MaterialApp(
        home: ArticleLearningPage(
          article: {
            'title': '기존 기사',
            'ai_summary_ko': summary,
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text(summary), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
