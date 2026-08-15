import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  const article = <String, dynamic>{
    'focus_word': 'protect',
    'focus_word_meaning': '보호하다',
    'focus_word_description_ko': '위험이나 피해를 입지 않도록 지키다',
    'learning_sentences': [
      {
        'sentence': 'The policy aims to protect public safety.',
        'sentence_ko': '그 정책은 공공 안전을 보호하는 것을 목표로 합니다.',
        'highlight_words': [
          {'text': 'public safety', 'meaning': '공공 안전'},
        ],
      },
    ],
    'expressions': [
      {'text': 'policy reform', 'meaning': '정책 개혁'},
      {'text': 'public safety', 'meaning': '공공 안전'},
      {'text': 'economic growth', 'meaning': '경제 성장'},
      {'text': 'climate action', 'meaning': '기후 대응'},
    ],
  };

  testWidgets('last answer shows a light overlay and returns two routes', (
    tester,
  ) async {
    var saveCount = 0;
    var savedTotal = 0;
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/quiz',
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('단어 학습 화면')),
        ),
        onGenerateInitialRoutes: (_) => [
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/word'),
            builder: (_) => const Scaffold(body: Text('단어 학습 화면')),
          ),
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/article'),
            builder: (_) => const Scaffold(body: Text('기사 화면')),
          ),
          MaterialPageRoute<bool>(
            settings: const RouteSettings(name: '/quiz'),
            builder: (_) => ArticleMiniQuizPage(
              article: article,
              completionHoldDuration: const Duration(milliseconds: 100),
              completionFadeDuration: const Duration(milliseconds: 50),
              saveResultForTest: (score, total) async {
                saveCount++;
                savedTotal = total;
              },
              notifyCompletionForTest: () async {},
            ),
          ),
        ],
      ),
    );

    for (var index = 0; index < 5; index++) {
      expect(find.text('${index + 1} / 5'), findsOneWidget);
      final firstChoice = find.ancestor(
        of: find.text('A.'),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(firstChoice);
      await tester.tap(firstChoice);
      await tester.pump();
      expect(find.textContaining(RegExp(r'^(정답|오답)입니다')), findsOneWidget);

      final action = find.text(index == 4 ? '완료' : '다음 문제');
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();
    }

    expect(find.text('기사 학습이 완료되었어요'), findsOneWidget);
    final popupSurface = tester.widget<Container>(
      find.byKey(const ValueKey('article-completion-popup-surface')),
    );
    final popupDecoration = popupSurface.decoration! as BoxDecoration;
    expect(popupDecoration.color, Colors.white);
    expect(popupDecoration.gradient, isNull);
    expect(popupDecoration.image, isNull);
    expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);
    expect(find.text('단어 학습으로 돌아가기'), findsNothing);
    expect(find.text('기사로 돌아가기'), findsNothing);
    expect(saveCount, 1);
    expect(savedTotal, 5);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('단어 학습 화면'), findsOneWidget);
    expect(saveCount, 1);
  });
}
