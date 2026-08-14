import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  test('뜻 보고 고르기 설명의 문장형 접미 표현만 제거한다', () {
    expect(
      normalizeWordChoiceDescription('코딩 중심 업데이트를 의미하는 단어입니다.'),
      '코딩 중심 업데이트',
    );
    expect(
      normalizeWordChoiceDescription('예상 밖의 충격적인 발표라는 뜻입니다.'),
      '예상 밖의 충격적인 발표',
    );
    expect(
      normalizeWordChoiceDescription('인재 채용이라는 뜻입니다'),
      '인재 채용',
    );
    expect(
      normalizeWordChoiceDescription('정책 방향인 단어입니다.'),
      '정책 방향',
    );
  });

  test('설명 중간에 있는 표현과 일반 설명문은 유지한다', () {
    expect(
      normalizeWordChoiceDescription('변화를 의미하는 단어입니다. 기사에서 자주 쓰입니다.'),
      '변화를 의미하는 단어입니다. 기사에서 자주 쓰입니다.',
    );
    expect(
      normalizeWordChoiceDescription('코딩 작업을 중심으로 한 업데이트'),
      '코딩 작업을 중심으로 한 업데이트',
    );
  });

  test('따옴표로 감싼 bombshell과 조사까지 제거한다', () {
    final result = sanitizeQuestionText(
      text: "뉴스에서 'bombshell'은 예상치 못하고 큰 파장을 일으키는 충격적인 소식이나 발표를 의미합니다.",
      answerWord: 'bombshell',
    );

    expect(result.toLowerCase(), isNot(contains('bombshell')));
    expect(result, contains('예상치 못하고 큰 파장'));
  });

  test('대소문자와 다양한 따옴표의 recruitment를 제거한다', () {
    for (final text in [
      '뉴스에서 “Recruitment”는 기업이 인재를 모집하는 상황을 설명합니다.',
      "'recruitment'는 기업이 인재를 모집하는 상황을 설명합니다.",
      'RECRUITMENT은 기업이 인재를 모집하는 상황을 설명합니다.',
    ]) {
      final result = sanitizeQuestionText(
        text: text,
        answerWord: 'recruitment',
      );
      expect(result.toLowerCase(), isNot(contains('recruitment')));
      expect(result, contains('기업이 인재를 모집'));
    }
  });
}
