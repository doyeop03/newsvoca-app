import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  test('cloze rejects a sentence that contains only part of the answer', () {
    const sentence =
        'Opportunities center on biometric, touchless and mobile access.';

    expect(
      containsExactReviewAnswerPhrase(sentence, 'access control'),
      isFalse,
    );
    expect(buildReviewCloze(sentence, 'access control'), isNull);
  });

  test('cloze replaces the complete answer phrase exactly once', () {
    const sentence = 'Strict access control is required in secure facilities.';

    expect(containsExactReviewAnswerPhrase(sentence, 'access control'), isTrue);
    expect(
      buildReviewCloze(sentence, 'access control'),
      'Strict _____ is required in secure facilities.',
    );
  });

  test('cloze accepts natural hyphen and whitespace variants', () {
    expect(
      buildReviewCloze('On-device AI is expanding.', 'on device AI'),
      '_____ is expanding.',
    );
  });

  test('distractors prioritize matching category and part of speech', () {
    final answer = <String, dynamic>{
      'word': 'air dominance',
      'meaning': '제공권',
      'category': 'world',
      'part_of_speech': 'noun phrase',
      'level': 'advanced',
    };
    final candidates = <Map<String, dynamic>>[
      {
        'word': 'AI server',
        'meaning': 'AI 서버',
        'category': 'technology',
        'part_of_speech': 'noun phrase',
      },
      {
        'word': 'cash flow',
        'meaning': '현금 흐름',
        'category': 'economy',
        'part_of_speech': 'noun phrase',
      },
      {
        'word': 'discrimination',
        'meaning': '차별',
        'category': 'society',
        'part_of_speech': 'noun',
      },
      {
        'word': 'missile defense',
        'meaning': '미사일 방어 체계',
        'category': 'world',
        'part_of_speech': 'noun phrase',
        'level': 'advanced',
      },
      {
        'word': 'military deterrence',
        'meaning': '군사적 억지력',
        'category': 'world',
        'part_of_speech': 'noun phrase',
        'level': 'advanced',
      },
      {
        'word': 'ground operation',
        'meaning': '지상 작전',
        'category': 'world',
        'part_of_speech': 'noun phrase',
        'level': 'advanced',
      },
    ];

    final ranked = rankReviewDistractorCandidates(answer, candidates);

    expect(
      ranked.take(3).map((item) => item['word']),
      containsAll([
        'missile defense',
        'military deterrence',
        'ground operation',
      ]),
    );
    expect(
      ranked.take(3).map((item) => item['word']),
      isNot(contains('AI server')),
    );
  });

  test('candidate with the same normalized meaning is excluded', () {
    final answer = <String, dynamic>{
      'word': 'air dominance',
      'meaning': '제공권',
      'category': 'world',
    };
    final ranked = rankReviewDistractorCandidates(answer, [
      {'word': 'air superiority', 'meaning': '제공권', 'category': 'world'},
      {'word': 'missile defense', 'meaning': '미사일 방어 체계', 'category': 'world'},
    ]);

    expect(
      ranked.map((item) => item['word']),
      isNot(contains('air superiority')),
    );
    expect(ranked.map((item) => item['word']), contains('missile defense'));
  });

  test(
    'candidate sharing an answer phrase concept is excluded as ambiguous',
    () {
      final answer = <String, dynamic>{
        'word': 'air dominance',
        'meaning': '제공권',
        'category': 'technology',
      };
      final ranked = rankReviewDistractorCandidates(answer, [
        {'word': 'air superiority', 'meaning': '공중 우세', 'category': 'world'},
        {
          'word': 'missile defense',
          'meaning': '미사일 방어 체계',
          'category': 'world',
        },
      ]);

      expect(
        ranked.map((item) => item['word']),
        isNot(contains('air superiority')),
      );
      expect(ranked.map((item) => item['word']), contains('missile defense'));
    },
  );

  test('choice builder returns one answer and three unique distractors', () {
    final answer = <String, dynamic>{
      'word': 'air dominance',
      'meaning': '제공권',
      'category': 'world',
      'part_of_speech': 'noun phrase',
    };

    final choices = buildReviewChoiceOptions(
      correctAnswer: 'air dominance',
      answerWordData: answer,
      words: [
        answer,
        {
          'word': 'missile defense',
          'meaning': '미사일 방어 체계',
          'category': 'world',
          'part_of_speech': 'noun phrase',
        },
        {
          'word': 'military deterrence',
          'meaning': '군사적 억지력',
          'category': 'world',
          'part_of_speech': 'noun phrase',
        },
        {
          'word': 'ground operation',
          'meaning': '지상 작전',
          'category': 'world',
          'part_of_speech': 'noun phrase',
        },
      ],
      useMeaning: false,
      random: math.Random(7),
    );

    expect(choices, hasLength(4));
    expect(choices.toSet(), hasLength(4));
    expect(choices.where((choice) => choice == 'air dominance'), hasLength(1));
  });

  test(
    'review cloze choices exclude candidates with a different part of speech',
    () {
      final answer = <String, dynamic>{
        'word': 'disclosure',
        'meaning': '공개, 밝힘',
        'category': 'economy',
        'topic': 'corporate',
        'part_of_speech': 'noun',
      };
      final choices = buildReviewChoiceOptions(
        correctAnswer: 'disclosure',
        answerWordData: answer,
        words: [
          answer,
          {
            'word': 'statement',
            'meaning': '성명',
            'category': 'economy',
            'topic': 'corporate',
            'part_of_speech': 'noun',
          },
          {
            'word': 'reporting',
            'meaning': '보고',
            'category': 'economy',
            'topic': 'corporate',
            'part_of_speech': 'noun',
          },
          {
            'word': 'announcement',
            'meaning': '발표',
            'category': 'economy',
            'topic': 'corporate',
            'part_of_speech': 'noun',
          },
          {
            'word': 'reveal',
            'meaning': '드러내다',
            'category': 'economy',
            'topic': 'corporate',
            'part_of_speech': 'verb',
          },
        ],
        useMeaning: false,
        random: math.Random(11),
        requireMatchingPartOfSpeech: true,
      );

      expect(choices, hasLength(4));
      expect(choices, isNot(contains('reveal')));
      expect(choices.toSet(), {
        'disclosure',
        'statement',
        'reporting',
        'announcement',
      });
    },
  );
}
