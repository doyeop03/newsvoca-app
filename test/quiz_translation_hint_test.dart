import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  group('buildMaskedKoreanHint', () {
    test('masks a conjugated hada meaning', () {
      expect(
        buildMaskedKoreanHint(
          koreanSentence: '새 행정부는 투명성과 책임감을 가지고 통치하겠다고 약속했습니다.',
          answerMeaning: '통치하다, 운영하다',
        ),
        '새 행정부는 투명성과 책임감을 가지고 _____하겠다고 약속했습니다.',
      );
    });

    test('masks a noun while preserving its particle', () {
      expect(
        buildMaskedKoreanHint(
          koreanSentence: '정부는 투명성을 높이겠다고 밝혔다.',
          answerMeaning: '투명성',
        ),
        '정부는 _____을 높이겠다고 밝혔다.',
      );
    });

    test('uses a matching candidate from multiple meanings', () {
      expect(
        buildMaskedKoreanHint(
          koreanSentence: '정부는 더 큰 책임감을 약속했다.',
          answerMeaning: '책임감, 설명 책임',
        ),
        '정부는 더 큰 _____을 약속했다.',
      );
    });

    test('returns empty when no meaning can be masked', () {
      expect(
        buildMaskedKoreanHint(
          koreanSentence: '정부는 변화를 약속했다.',
          answerMeaning: '투명성',
        ),
        isEmpty,
      );
    });
  });

  testWidgets('reveals only the masked translation after tapping', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuizTranslationHint(
            koreanSentence: '정부는 투명성을 높였다.',
            answerMeaning: '투명성',
            answerText: 'transparency',
          ),
        ),
      ),
    );

    expect(find.text('힌트 보기'), findsOneWidget);
    expect(find.text('정부는 _____을 높였다.'), findsNothing);

    await tester.tap(find.text('힌트 보기'));
    await tester.pump();

    expect(find.text('해석 힌트'), findsOneWidget);
    expect(find.text('정부는 _____을 높였다.'), findsOneWidget);
    expect(find.textContaining('transparency'), findsNothing);
  });

  testWidgets('does not show a hint button without a Korean sentence', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuizTranslationHint(
            koreanSentence: '',
            answerMeaning: '투명성',
            answerText: 'transparency',
          ),
        ),
      ),
    );

    expect(find.text('힌트 보기'), findsNothing);
  });
}
