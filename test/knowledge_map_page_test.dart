import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/services/knowledge_map_service.dart';

void main() {
  final data = KnowledgeMapData.group([
    for (final item in const [
      ('inference', '추론', 'artificial_intelligence', '인공지능'),
      ('reasoning', '추론 과정', 'artificial_intelligence', '인공지능'),
      ('foundry', '반도체 위탁 생산', 'semiconductor', '반도체'),
    ])
      {
        'id': item.$1,
        'word': item.$1,
        'meaning': item.$2,
        'category': 'technology',
        'topic': item.$3,
        'topic_label_ko': item.$4,
        'is_learned': true,
      },
    {
      'id': 'inflation',
      'word': 'inflation',
      'meaning': '물가 상승',
      'category': 'economy',
      'topic': 'monetary_policy',
      'topic_label_ko': '통화 정책',
      'is_learned': true,
    },
    {
      'id': 'legacy-tech',
      'word': 'legacy tech',
      'meaning': '기존 기술',
      'category': 'technology',
      'is_learned': true,
    },
  ]);

  Future<void> render(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: KnowledgeMapPage(loadForTest: () async => data)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('drills down from category to words on a small viewport', (
    tester,
  ) async {
    await render(tester, const Size(320, 640));

    expect(find.text('나의 학습 현황'), findsOneWidget);
    expect(find.text('분야별 학습 현황'), findsOneWidget);
    expect(find.text('경제'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.text('인공지능'), findsNothing);
    expect(tester.takeException(), isNull);

    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.text('4개'), findsOneWidget);

    await tester.tap(find.text('기술'));
    await tester.pumpAndSettle();
    expect(find.text('세부 주제'), findsOneWidget);
    expect(find.text('인공지능'), findsOneWidget);
    expect(find.text('반도체'), findsOneWidget);
    expect(find.text('기타'), findsOneWidget);
    expect(find.text('1개'), findsNWidgets(2));

    await tester.ensureVisible(find.text('인공지능'));
    await tester.tap(find.text('인공지능'));
    await tester.pumpAndSettle();
    expect(find.text('inference'), findsOneWidget);
    expect(find.text('reasoning'), findsOneWidget);
    final inferenceRow = find.byKey(
      const ValueKey('knowledge-word-row-inference'),
    );
    expect(inferenceRow, findsOneWidget);
    expect(
      find.descendant(of: inferenceRow, matching: find.text('•')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: inferenceRow, matching: find.byType(Card)),
      findsNothing,
    );
    expect(
      find.descendant(of: inferenceRow, matching: find.byType(Container)),
      findsNothing,
    );
    expect(
      find.descendant(of: inferenceRow, matching: find.byType(Ink)),
      findsNothing,
    );
    expect(find.text('추론'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('기술'));
    await tester.tap(find.text('기술'));
    await tester.pumpAndSettle();
    expect(find.text('세부 주제'), findsNothing);
  });

  testWidgets('uses a constrained dashboard on a tablet viewport', (
    tester,
  ) async {
    await render(tester, const Size(800, 1280));
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(find.byType(ConstrainedBox), findsWidgets);
    expect(find.text('기술'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
