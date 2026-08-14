import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  group('hasValidArticleQuizMeaning', () {
    test('rejects missing and placeholder meanings', () {
      for (final meaning in <String?>[
        null,
        '',
        '   ',
        '뜻 정보 없음',
        '정보 없음',
        '의미 정보 없음',
        '-',
        'N/A',
        'null',
        'None',
      ]) {
        expect(
          hasValidArticleQuizMeaning(meaning),
          isFalse,
          reason: 'meaning=$meaning',
        );
      }
    });

    test('accepts a real meaning', () {
      expect(hasValidArticleQuizMeaning('보호하다'), isTrue);
      expect(hasValidArticleQuizMeaning('인수합병 활동'), isTrue);
    });
  });
}
