import 'package:flutter/foundation.dart';

const Map<String, String> _partOfSpeechLabels = {
  'noun': '명사',
  'n': '명사',
  'verb': '동사',
  'v': '동사',
  'adjective': '형용사',
  'adj': '형용사',
  'adverb': '부사',
  'adv': '부사',
  'pronoun': '대명사',
  'preposition': '전치사',
  'conjunction': '접속사',
  'interjection': '감탄사',
  'determiner': '한정사',
  'article': '관사',
  'auxiliary verb': '조동사',
  'modal verb': '조동사',
  'phrasal verb': '구동사',
  'noun phrase': '명사구',
  'verb phrase': '동사구',
  'adjective phrase': '형용사구',
  'adverb phrase': '부사구',
  'phrase': '구',
  'expression': '표현',
  'idiom': '숙어',
};

const Map<String, String> _levelLabels = {
  'a1': '초급',
  'a2': '초급',
  'beginner': '초급',
  'elementary': '초급',
  'basic': '초급',
  'b1': '중급',
  'b2': '중급',
  'intermediate': '중급',
  'upper intermediate': '중급',
  'c1': '고급',
  'c2': '고급',
  'advanced': '고급',
};

final RegExp _hangulPattern = RegExp(r'[가-힣]');

String _normalizedMetadataKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[._]+$'), '')
    .replaceAll(RegExp(r'[-_]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

String formatPartOfSpeech(String? value) => _formatLearningMetadataValue(
  value,
  labels: _partOfSpeechLabels,
  fieldName: 'part_of_speech',
);

String formatLearningLevel(String? value) => _formatLearningMetadataValue(
  value,
  labels: _levelLabels,
  fieldName: 'level',
);

String formatLearningMetadata({String? partOfSpeech, String? level}) => [
  formatPartOfSpeech(partOfSpeech),
  formatLearningLevel(level),
].where((value) => value.isNotEmpty).join(' · ');

String _formatLearningMetadataValue(
  String? value, {
  required Map<String, String> labels,
  required String fieldName,
}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return '';
  if (_hangulPattern.hasMatch(raw)) return raw;

  final label = labels[_normalizedMetadataKey(raw)];
  if (label != null) return label;

  if (kDebugMode) {
    debugPrint('[LearningMetadata] unknown $fieldName="$raw"');
  }
  return '';
}
