import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

Map<String, dynamic> wordData(
  String word,
  String meaning, {
  String category = '',
  String topic = '',
  String partOfSpeech = '',
  String level = '',
  bool reviewExcluded = false,
}) => {
  'word': word,
  'meaning': meaning,
  if (category.isNotEmpty) 'category': category,
  if (topic.isNotEmpty) 'topic': topic,
  if (partOfSpeech.isNotEmpty) 'part_of_speech': partOfSpeech,
  if (level.isNotEmpty) 'level': level,
  if (reviewExcluded) 'review_excluded': true,
};

void main() {
  group('selectDistractorWordData', () {
    final answer = wordData(
      'inflation',
      '인플레이션',
      category: 'economy',
      topic: 'monetary_policy',
      partOfSpeech: 'noun',
      level: 'B2',
    );

    test('takes all three distractors from the same topic when available', () {
      final selected = selectDistractorWordData(
        answer: answer,
        candidates: [
          wordData(
            'liquidity',
            '유동성',
            category: 'economy',
            topic: 'monetary_policy',
          ),
          wordData(
            'deflation',
            '디플레이션',
            category: 'economy',
            topic: 'monetary_policy',
          ),
          wordData(
            'tightening',
            '긴축',
            category: 'economy',
            topic: 'monetary_policy',
          ),
          wordData(
            'robotics',
            '로봇 공학',
            category: 'technology',
            topic: 'robotics',
          ),
        ],
        count: 3,
        random: math.Random(1),
      );

      expect(selected, hasLength(3));
      expect(
        selected.every((item) => item['topic'] == 'monetary_policy'),
        isTrue,
      );
    });

    test('fills a short topic pool from the same category before fallback', () {
      final selected = selectDistractorWordData(
        answer: answer,
        candidates: [
          wordData(
            'liquidity',
            '유동성',
            category: 'economy',
            topic: 'monetary_policy',
          ),
          wordData(
            'deflation',
            '디플레이션',
            category: 'economy',
            topic: 'monetary_policy',
          ),
          wordData(
            'recession',
            '경기 침체',
            category: 'economy',
            topic: 'business_cycle',
          ),
          wordData(
            'robotics',
            '로봇 공학',
            category: 'technology',
            topic: 'robotics',
          ),
        ],
        count: 3,
        random: math.Random(2),
      );

      expect(
        selected.where((item) => item['topic'] == 'monetary_policy'),
        hasLength(2),
      );
      expect(selected.last['word'], 'recession');
    });

    test(
      'uses category then the whole pool when topic/category are sparse',
      () {
        final noTopicAnswer = wordData(
          'inflation',
          '인플레이션',
          category: 'economy',
        );
        final selected = selectDistractorWordData(
          answer: noTopicAnswer,
          candidates: [
            wordData('recession', '경기 침체', category: 'economy'),
            wordData('robotics', '로봇 공학', category: 'technology'),
            wordData('election', '선거', category: 'politics'),
          ],
          count: 3,
          random: math.Random(3),
        );

        expect(selected.first['word'], 'recession');
        expect(selected, hasLength(3));
      },
    );

    test('works safely when both topic and category metadata are missing', () {
      final selected = selectDistractorWordData(
        answer: wordData('legacy', '레거시'),
        candidates: [
          wordData('alpha', '알파'),
          wordData('beta', '베타'),
          wordData('gamma', '감마'),
        ],
        count: 3,
        random: math.Random(4),
      );

      expect(selected.map((item) => item['word']).toSet(), {
        'alpha',
        'beta',
        'gamma',
      });
    });

    test(
      'removes the answer, normalized duplicates, and duplicate meanings',
      () {
        final selected = selectDistractorWordData(
          answer: answer,
          candidates: [
            answer,
            wordData(' Inflation ', '다른 표기', category: 'economy'),
            wordData('price rise', ' 인플레이션 ', category: 'economy'),
            wordData('liquidity', '유동성', category: 'economy'),
            wordData('LIQUIDITY', '현금성', category: 'economy'),
            wordData('cash flow', '유동성', category: 'economy'),
            wordData('recession', '경기 침체', category: 'economy'),
            wordData('deflation', '디플레이션', category: 'economy'),
          ],
          count: 3,
          random: math.Random(5),
        );

        expect(
          selected
              .map((item) => normalizeDistractorValue(item['word']))
              .toSet(),
          hasLength(3),
        );
        expect(
          selected
              .map((item) => normalizeDistractorValue(item['meaning']))
              .toSet(),
          hasLength(3),
        );
        expect(
          selected.any(
            (item) => normalizeDistractorValue(item['word']) == 'inflation',
          ),
          isFalse,
        );
        expect(
          selected.any(
            (item) => normalizeDistractorValue(item['meaning']) == '인플레이션',
          ),
          isFalse,
        );
      },
    );

    test('review mode excludes review-excluded words from distractors', () {
      final selected = selectDistractorWordData(
        answer: answer,
        candidates: [
          wordData(
            'excluded',
            '제외됨',
            category: 'economy',
            reviewExcluded: true,
          ),
          wordData('liquidity', '유동성', category: 'economy'),
          wordData('recession', '경기 침체', category: 'economy'),
          wordData('deflation', '디플레이션', category: 'economy'),
        ],
        count: 3,
        random: math.Random(6),
        excludeReviewExcluded: true,
      );

      expect(selected.map((item) => item['word']), isNot(contains('excluded')));
      expect(selected, hasLength(3));
    });

    test('choice builder returns four unique options including one answer', () {
      final choices = buildPrioritizedDistractorChoices(
        answer: answer,
        candidates: [
          wordData('liquidity', '유동성', category: 'economy'),
          wordData('recession', '경기 침체', category: 'economy'),
          wordData('deflation', '디플레이션', category: 'economy'),
        ],
        optionField: 'word',
        random: math.Random(7),
      );

      expect(choices, hasLength(4));
      expect(choices.toSet(), hasLength(4));
      expect(choices.where((item) => item == 'inflation'), hasLength(1));
    });
  });
}
