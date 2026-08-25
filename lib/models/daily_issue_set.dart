import 'dart:convert';

class DailyIssueSet {
  const DailyIssueSet({
    required this.date,
    required this.status,
    required this.issues,
  });

  final String date;
  final String status;
  final List<IssueLearningItem> issues;

  int get wordCount => issues.fold(0, (sum, issue) => sum + issue.words.length);
  bool get isReady =>
      status == 'ready' &&
      issues.length == 5 &&
      wordCount == 15 &&
      issues.every((issue) => issue.isReady);

  List<Map<String, dynamic>> get learningWords => [
    for (var index = 0; index < issues.length; index++)
      ...learningWordsForIssue(index),
  ];

  List<Map<String, dynamic>> learningWordsForIssue(int index) {
    final issue = issues[index];
    return [
      for (final word in issue.words)
        {
          ...word.toMap(learnedDate: date),
          'category': issue.category.isEmpty ? 'daily' : issue.category,
          'topic': issue.topic,
          'topic_label_ko': issue.topicLabelKo,
          'source_issue_id': issue.id,
          'source_article_url': issue.article.url,
          'related_articles': issue.articles
              .map((article) => article.toMap())
              .toList(),
        },
    ];
  }

  factory DailyIssueSet.fromMap(Map<String, dynamic> map) => DailyIssueSet(
    date: _text(map['date']),
    status: _text(map['status']),
    issues: _maps(map['issues']).map(IssueLearningItem.fromMap).toList(),
  );
}

class IssueLearningItem {
  const IssueLearningItem({
    required this.id,
    required this.rank,
    required this.titleKo,
    required this.titleEn,
    required this.category,
    required this.topic,
    required this.topicLabelKo,
    required this.articles,
    required this.whatHappened,
    required this.whyItMatters,
    required this.context,
    required this.flow,
    required this.keyTakeaway,
    required this.words,
    required this.extraExpressions,
  });

  final String id;
  final int rank;
  final String titleKo;
  final String titleEn;
  final String category;
  final String topic;
  final String topicLabelKo;
  final List<IssueArticle> articles;
  final String whatHappened;
  final String whyItMatters;
  final String context;
  final List<IssueFlowStep> flow;
  final String keyTakeaway;
  final List<IssueWord> words;
  final List<ExtraExpression> extraExpressions;

  IssueArticle get article =>
      articles.isEmpty ? IssueArticle.empty : articles.first;
  bool get isReady =>
      titleKo.isNotEmpty && articles.isNotEmpty && words.length == 3;

  factory IssueLearningItem.fromMap(Map<String, dynamic> map) {
    final articleMaps = _maps(map['articles']);
    final article = _map(map['article']);
    return IssueLearningItem(
      id: _text(map['id']),
      rank: _integer(map['rank']),
      titleKo: _text(map['issue_title_ko'] ?? map['issue_title']),
      titleEn: _text(map['issue_title_en']),
      category: _text(map['category']),
      topic: _text(map['topic']),
      topicLabelKo: _text(map['topic_label_ko']),
      articles: (article.isNotEmpty ? [article] : articleMaps)
          .map(IssueArticle.fromMap)
          .toList(),
      whatHappened: _text(map['what_happened'] ?? map['issue_summary']),
      whyItMatters: _text(map['why_it_matters'] ?? map['issue_background']),
      context: _text(map['context']),
      flow: _flowSteps(map['issue_flow']),
      keyTakeaway: _text(map['key_takeaway'] ?? map['issue_summary']),
      words: _maps(map['words']).map(IssueWord.fromMap).toList(),
      extraExpressions: _maps(
        map['extra_expressions'],
      ).map(ExtraExpression.fromMap).toList(),
    );
  }
}

class IssueFlowStep {
  const IssueFlowStep({required this.step, required this.description});

  final int step;
  final String description;

  factory IssueFlowStep.fromMap(
    Map<String, dynamic> map, {
    required int fallbackStep,
  }) => IssueFlowStep(
    step: _positiveInteger(map['step'] ?? map['step_number'], fallbackStep),
    description: _text(
      map['description'] ?? map['description_ko'] ?? map['text'],
    ),
  );
}

class IssueArticle {
  const IssueArticle({
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.url,
  });
  static const empty = IssueArticle(
    title: '',
    source: '',
    publishedAt: '',
    url: '',
  );
  final String title;
  final String source;
  final String publishedAt;
  final String url;

  factory IssueArticle.fromMap(Map<String, dynamic> map) => IssueArticle(
    title: _text(map['title']),
    source: _text(map['source']),
    publishedAt: _text(map['publishedAt'] ?? map['published_at']),
    url: _text(map['url']),
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'source': source,
    'publishedAt': publishedAt,
    'url': url,
  };
}

class IssueWord {
  const IssueWord({
    required this.word,
    required this.meaning,
    required this.descriptionKo,
    required this.partOfSpeech,
    required this.level,
    required this.example,
    required this.exampleKo,
  });
  final String word;
  final String meaning;
  final String descriptionKo;
  final String partOfSpeech;
  final String level;
  final String example;
  final String exampleKo;

  factory IssueWord.fromMap(Map<String, dynamic> map) => IssueWord(
    word: _text(map['word']),
    meaning: _text(map['meaning']),
    descriptionKo: _text(map['description_ko']),
    partOfSpeech: _text(map['part_of_speech']),
    level: _text(map['level']),
    example: _text(map['example']),
    exampleKo: _text(map['example_ko']),
  );

  Map<String, dynamic> toMap({String learnedDate = ''}) => {
    'word': word,
    'meaning': meaning,
    'description_ko': descriptionKo,
    'part_of_speech': partOfSpeech,
    'level': level,
    'example': example,
    'example_ko': exampleKo,
    'category': 'daily',
    if (learnedDate.isNotEmpty) 'learned_date': learnedDate,
  };
}

class ExtraExpression {
  const ExtraExpression({required this.expression, required this.meaning});
  final String expression;
  final String meaning;

  factory ExtraExpression.fromMap(Map<String, dynamic> map) => ExtraExpression(
    expression: _text(map['expression']),
    meaning: _text(map['meaning']),
  );
}

String _text(dynamic value) => value?.toString().trim() ?? '';
int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? 0;
int _positiveInteger(dynamic value, int fallback) {
  final parsed = _integer(value);
  return parsed > 0 ? parsed : fallback;
}
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map((v) => Map<String, dynamic>.from(v)).toList()
    : <Map<String, dynamic>>[];
List<IssueFlowStep> _flowSteps(dynamic value) {
  if (value is! List) return const <IssueFlowStep>[];
  final steps = <IssueFlowStep>[];
  for (final item in value) {
    final fallbackStep = steps.length + 1;
    final parsed = _flowStep(item, fallbackStep);
    if (parsed != null && parsed.description.isNotEmpty) steps.add(parsed);
  }
  return steps;
}

IssueFlowStep? _flowStep(dynamic value, int fallbackStep) {
  if (value is Map) {
    return IssueFlowStep.fromMap(
      Map<String, dynamic>.from(value),
      fallbackStep: fallbackStep,
    );
  }
  final text = _text(value);
  if (text.isEmpty) return null;

  // Some production documents contain a JSON object serialized as a string.
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return IssueFlowStep.fromMap(
        Map<String, dynamic>.from(decoded),
        fallbackStep: fallbackStep,
      );
    }
  } on FormatException {
    // Continue with the known legacy Python dict representation below.
  }

  final legacy = _pythonFlowMapPattern.firstMatch(text);
  if (legacy != null) {
    final quote = legacy.group(2)!;
    final description = legacy
        .group(3)!
        .replaceAll('\\$quote', quote)
        .replaceAll('\\\\', '\\');
    return IssueFlowStep(
      step: int.tryParse(legacy.group(1)!) ?? fallbackStep,
      description: description.trim(),
    );
  }

  // Do not expose an unparsed raw object literal in the learning UI.
  if (text.startsWith('{') && text.endsWith('}')) return null;
  return IssueFlowStep(step: fallbackStep, description: text);
}

final _pythonFlowMapPattern = RegExp(
  r'''^\{\s*['"](?:step|step_number)['"]\s*:\s*(\d+)\s*,\s*['"](?:description|description_ko)['"]\s*:\s*(['"])([\s\S]*)\2\s*\}\s*$''',
);
