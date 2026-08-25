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

  test('V2 inflected English examples keep their Korean hint data', () {
    final cases = [
      ('disclosure', '정보 공개', '회사는 정보 공개를 확대했습니다.'),
      ('woo', '구애하다, 유치하려 노력하다', '그 회사는 고객을 유치하려 노력한다.'),
      ('study', '연구하다', '연구진은 시장을 자세히 조사합니다.'),
      ('company', '회사', '여러 기업이 새로운 정책을 발표했습니다.'),
    ];

    for (final item in cases) {
      final hint = resolveQuizTranslationHint(
        answerText: item.$1,
        answerMeaning: item.$2,
        koreanSentence: item.$3,
      );
      expect(hint, isNot(quizHintUnavailableMessage), reason: item.$1);
      expect(hint, isNotEmpty, reason: item.$1);
    }
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

  testWidgets('uses the existing Korean example when meaning wording differs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuizTranslationHint(
            koreanSentence: '이 회사는 홍보 프로그램을 통해 지역 사회와 소통하는 것을 목표로 한다.',
            answerMeaning: '대외 활동, 지역 활동, 홍보 활동',
            answerText: 'outreach',
          ),
        ),
      ),
    );

    await tester.tap(find.text('힌트 보기'));
    await tester.pump();

    expect(find.text(quizHintUnavailableMessage), findsNothing);
    expect(
      find.text('이 회사는 홍보 프로그램을 통해 지역 사회와 소통하는 것을 목표로 한다.'),
      findsOneWidget,
    );
  });
}
