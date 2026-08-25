import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/utils/learning_metadata_formatter.dart';

void main() {
  group('learning metadata formatter', () {
    test('formats common part of speech and level combinations in Korean', () {
      expect(
        formatLearningMetadata(partOfSpeech: 'noun', level: 'B2'),
        '명사 · 중급',
      );
      expect(
        formatLearningMetadata(partOfSpeech: 'noun', level: 'intermediate'),
        '명사 · 중급',
      );
      expect(
        formatLearningMetadata(partOfSpeech: 'noun', level: 'advanced'),
        '명사 · 고급',
      );
      expect(
        formatLearningMetadata(partOfSpeech: 'verb', level: 'A2'),
        '동사 · 초급',
      );
      expect(
        formatLearningMetadata(partOfSpeech: 'adjective', level: 'C1'),
        '형용사 · 고급',
      );
      expect(
        formatLearningMetadata(partOfSpeech: 'noun phrase', level: 'B1'),
        '명사구 · 중급',
      );
    });

    test('normalizes case, whitespace, abbreviations, and hyphens', () {
      expect(formatPartOfSpeech(' NOUN '), '명사');
      expect(formatPartOfSpeech('n.'), '명사');
      expect(formatPartOfSpeech('v.'), '동사');
      expect(formatPartOfSpeech('ADJ'), '형용사');
      expect(formatLearningLevel(' b2 '), '중급');
      expect(formatLearningLevel('upper-intermediate'), '중급');
    });

    test('preserves Korean values and hides unknown English values', () {
      expect(
        formatLearningMetadata(partOfSpeech: '명사', level: '중급'),
        '명사 · 중급',
      );
      expect(formatPartOfSpeech('unexpected-type'), isEmpty);
      expect(formatLearningLevel('expert'), isEmpty);
    });
  });
}
