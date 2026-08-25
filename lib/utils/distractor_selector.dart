part of '../main.dart';

String normalizeDistractorValue(Object? value) => (value?.toString() ?? '')
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[-_\s]+'), ' ')
    .replaceAll(RegExp(r'''[.,;:!?"'`()\[\]{}]'''), '')
    .trim();

String normalizeDistractorLemma(Object? value, {Object? partOfSpeech}) {
  final normalized = normalizeDistractorValue(value);
  if (normalized.isEmpty) return '';
  final tokens = normalized.split(' ');
  final part = normalizeDistractorValue(partOfSpeech);
  final index = part.contains('verb') ? 0 : tokens.length - 1;
  var token = tokens[index];
  const irregular = {
    'was': 'be',
    'were': 'be',
    'been': 'be',
    'went': 'go',
    'gone': 'go',
    'made': 'make',
    'took': 'take',
    'taken': 'take',
    'ran': 'run',
    'written': 'write',
    'wrote': 'write',
    'woos': 'woo',
    'wooed': 'woo',
    'studies': 'study',
    'studied': 'study',
    'companies': 'company',
    'investors': 'investor',
  };
  token = irregular[token] ?? token;
  const invariant = {
    'analysis',
    'business',
    'gas',
    'news',
    'series',
    'species',
  };
  if (invariant.contains(token)) {
    // Keep dictionary forms whose trailing s is not a plural/verb suffix.
  } else if (token.endsWith('ies') && token.length > 4) {
    token = '${token.substring(0, token.length - 3)}y';
  } else if (token.endsWith('ing') && token.length > 5) {
    token = token.substring(0, token.length - 3);
    if (token.length >= 3 &&
        token[token.length - 1] == token[token.length - 2] &&
        !'aeiou'.contains(token[token.length - 1])) {
      token = token.substring(0, token.length - 1);
    }
  } else if (token.endsWith('ed') && token.length > 4) {
    token = token.substring(0, token.length - 2);
  } else if (token.endsWith('s') &&
      !token.endsWith('ss') &&
      !token.endsWith('us') &&
      !token.endsWith('is')) {
    token = token.substring(0, token.length - 1);
  }
  tokens[index] = token;
  return tokens.join(' ');
}

bool areDistractorMeaningsAmbiguous(Object? first, Object? second) {
  final firstRaw = first?.toString().trim().toLowerCase() ?? '';
  final secondRaw = second?.toString().trim().toLowerCase() ?? '';
  final a = normalizeDistractorValue(firstRaw);
  final b = normalizeDistractorValue(secondRaw);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b ||
      (a.length >= 2 && b.length >= 2 && (a.contains(b) || b.contains(a)))) {
    return true;
  }
  Set<String> equivalents(String value) => value
      .split(RegExp(r'[,/·]|\s+(?:또는|혹은)\s+'))
      .map(normalizeDistractorValue)
      .where((item) => item.length >= 2)
      .toSet();
  return equivalents(firstRaw).intersection(equivalents(secondRaw)).isNotEmpty;
}

String _distractorText(Map<String, dynamic> data, String key) =>
    data[key]?.toString().trim() ?? '';

String _distractorCategory(Map<String, dynamic> data) {
  final category = normalizeDistractorValue(data['category']);
  return category == 'international' ? 'world' : category;
}

String _distractorTopic(Map<String, dynamic> data) {
  final topic = normalizeDistractorValue(data['topic']);
  if (topic.isNotEmpty) return topic;
  return normalizeDistractorValue(data['topic_label_ko']);
}

String _distractorPartOfSpeech(Map<String, dynamic> data) {
  final raw = normalizeDistractorValue(
    data['part_of_speech'] ?? data['partOfSpeech'],
  );
  if (raw.contains('noun') || raw == 'phrase') return 'noun';
  if (raw.contains('verb')) return 'verb';
  if (raw.contains('adjective') || raw == 'adj') return 'adjective';
  if (raw.contains('adverb') || raw == 'adv') return 'adverb';
  return raw;
}

int? _distractorLevelIndex(Map<String, dynamic> data) {
  final level = normalizeDistractorValue(
    data['level'] ?? data['difficulty'],
  ).toUpperCase();
  const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  final index = levels.indexOf(level);
  return index < 0 ? null : index;
}

List<Map<String, dynamic>> _shuffleByLevelPreference(
  Map<String, dynamic> answer,
  Iterable<Map<String, dynamic>> candidates,
  math.Random random,
) {
  final answerLevel = _distractorLevelIndex(answer);
  final exact = <Map<String, dynamic>>[];
  final adjacent = <Map<String, dynamic>>[];
  final remaining = <Map<String, dynamic>>[];
  for (final candidate in candidates) {
    final level = _distractorLevelIndex(candidate);
    if (answerLevel != null && level == answerLevel) {
      exact.add(candidate);
    } else if (answerLevel != null &&
        level != null &&
        (answerLevel - level).abs() == 1) {
      adjacent.add(candidate);
    } else {
      remaining.add(candidate);
    }
  }
  exact.shuffle(random);
  adjacent.shuffle(random);
  remaining.shuffle(random);
  return [...exact, ...adjacent, ...remaining];
}

/// Selects real learned/dataset words in semantic-priority order.
///
/// Priority: same topic + POS, same topic, same category + POS,
/// same category, then the remaining available pool. Level is only a soft
/// preference inside each tier. No network or AI call is made here.
List<Map<String, dynamic>> selectDistractorWordData({
  required Map<String, dynamic> answer,
  required Iterable<Map<String, dynamic>> candidates,
  required int count,
  required math.Random random,
  bool excludeReviewExcluded = false,
  bool requireMatchingPartOfSpeech = false,
}) {
  if (count <= 0) return const [];
  final answerWord = normalizeDistractorLemma(
    answer['word'],
    partOfSpeech: answer['part_of_speech'] ?? answer['partOfSpeech'],
  );
  final answerMeaningRaw = answer['meaning'];
  final answerTopic = _distractorTopic(answer);
  final answerCategory = _distractorCategory(answer);
  final answerPart = _distractorPartOfSpeech(answer);

  final uniqueWords = <String>{};
  final uniqueMeanings = <String>{};
  final usable = <Map<String, dynamic>>[];
  for (final source in candidates) {
    final candidate = Map<String, dynamic>.from(source);
    if (excludeReviewExcluded && candidate['review_excluded'] == true) {
      continue;
    }
    final word = normalizeDistractorLemma(
      candidate['word'],
      partOfSpeech: candidate['part_of_speech'] ?? candidate['partOfSpeech'],
    );
    final candidateMeaningRaw = candidate['meaning'];
    final meaning = normalizeDistractorValue(candidateMeaningRaw);
    final candidatePart = _distractorPartOfSpeech(candidate);
    if (word.isEmpty ||
        meaning.isEmpty ||
        word == answerWord ||
        areDistractorMeaningsAmbiguous(candidateMeaningRaw, answerMeaningRaw) ||
        (requireMatchingPartOfSpeech &&
            answerPart.isNotEmpty &&
            candidatePart != answerPart) ||
        !uniqueWords.add(word) ||
        !uniqueMeanings.add(meaning)) {
      continue;
    }
    usable.add(candidate);
  }

  bool sameTopic(Map<String, dynamic> item) =>
      answerTopic.isNotEmpty && _distractorTopic(item) == answerTopic;
  bool sameCategory(Map<String, dynamic> item) =>
      answerCategory.isNotEmpty && _distractorCategory(item) == answerCategory;
  bool samePart(Map<String, dynamic> item) =>
      answerPart.isNotEmpty && _distractorPartOfSpeech(item) == answerPart;

  final tiers = <List<Map<String, dynamic>>>[
    usable.where((item) => sameTopic(item) && samePart(item)).toList(),
    usable.where((item) => sameTopic(item) && !samePart(item)).toList(),
    usable
        .where(
          (item) => !sameTopic(item) && sameCategory(item) && samePart(item),
        )
        .toList(),
    usable
        .where(
          (item) => !sameTopic(item) && sameCategory(item) && !samePart(item),
        )
        .toList(),
    usable
        .where(
          (item) => !sameTopic(item) && !sameCategory(item) && samePart(item),
        )
        .toList(),
    usable
        .where(
          (item) => !sameTopic(item) && !sameCategory(item) && !samePart(item),
        )
        .toList(),
  ];

  final selected = <Map<String, dynamic>>[];
  for (final tier in tiers) {
    for (final candidate in _shuffleByLevelPreference(answer, tier, random)) {
      selected.add(candidate);
      if (selected.length == count) return selected;
    }
  }
  return selected;
}

List<String> buildPrioritizedDistractorChoices({
  required Map<String, dynamic> answer,
  required Iterable<Map<String, dynamic>> candidates,
  required String optionField,
  required math.Random random,
  int choiceCount = 4,
  bool excludeReviewExcluded = false,
  bool requireMatchingPartOfSpeech = false,
}) {
  final correct = _distractorText(answer, optionField);
  if (correct.isEmpty || choiceCount <= 0) return const [];
  final distractors =
      selectDistractorWordData(
            answer: answer,
            candidates: candidates,
            count: choiceCount - 1,
            random: random,
            excludeReviewExcluded: excludeReviewExcluded,
            requireMatchingPartOfSpeech: requireMatchingPartOfSpeech,
          )
          .map((item) => _distractorText(item, optionField))
          .where((item) => item.isNotEmpty);
  return <String>[correct, ...distractors]..shuffle(random);
}
