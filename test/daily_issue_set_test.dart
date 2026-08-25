import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/models/daily_issue_set.dart';
import 'package:wordapp/models/debug_issue_fixture.dart';

Map<String, dynamic> dailyIssueMap({String status = 'ready'}) => {
  'date': '2026-08-18',
  'status': status,
  'issues': List.generate(5, issueMap),
};

Map<String, dynamic> issueMap(int rank) => {
  'id': 'issue_${rank + 1}',
  'rank': rank + 1,
  'issue_title_ko': '세계 주요 이슈 ${rank + 1}',
  'issue_title_en': 'Global issue ${rank + 1}',
  'category': 'economy',
  'topic': 'monetary_policy',
  'topic_label_ko': '통화 정책',
  'what_happened': '새 지표가 발표됐습니다.',
  'why_it_matters': '시민 생활과 시장에 영향을 줄 수 있습니다.',
  'context': '정책 변화의 배경입니다.',
  'issue_flow': ['발표', '시장 반응', '정책 변화'],
  'key_takeaway': '새 지표가 정책 전망을 바꿨습니다.',
  'article': {
    'title': 'Global report ${rank + 1}',
    'source': 'Wire',
    'url': 'https://news.test/${rank + 1}',
    'published_at': '2026-08-18T00:00:00Z',
  },
  'words': List.generate(
    3,
    (index) => {
      'word': 'word_${rank}_$index',
      'meaning': '의미 $index',
      'description_ko': '설명',
      'part_of_speech': 'noun',
      'level': '중급',
      'example': 'An example sentence.',
      'example_ko': '예문입니다.',
    },
  ),
};

void main() {
  test('parses a ready date-keyed daily issue document', () {
    final set = DailyIssueSet.fromMap(dailyIssueMap());
    expect(set.isReady, isTrue);
    expect(set.issues, hasLength(5));
    expect(set.wordCount, 15);
    expect(set.issues.first.category, 'economy');
    expect(set.issues.first.flow, hasLength(3));
    expect(set.issues.first.flow.first.step, 1);
    expect(set.issues.first.flow.first.description, '발표');
  });

  test('normalizes map, legacy map, JSON, Python dict, and plain flow values', () {
    final map = dailyIssueMap();
    final issues = map['issues'] as List<Map<String, dynamic>>;
    issues[0]['issue_flow'] = [
      {'step': 4, 'description': '정상 Map 설명'},
    ];
    issues[1]['issue_flow'] = [
      {'step_number': 2, 'description_ko': 'legacy Map 설명'},
    ];
    issues[2]['issue_flow'] = ['일반 문자열 설명'];
    issues[3]['issue_flow'] = [
      '{"step": 7, "description": "JSON 문자열 설명"}',
    ];
    issues[4]['issue_flow'] = [
      "{'step': 1, 'description': '뉴질랜드 정부, 법안 도입 발표.'}",
    ];

    final set = DailyIssueSet.fromMap(map);
    expect(set.issues[0].flow.single.step, 4);
    expect(set.issues[0].flow.single.description, '정상 Map 설명');
    expect(set.issues[1].flow.single.step, 2);
    expect(set.issues[1].flow.single.description, 'legacy Map 설명');
    expect(set.issues[2].flow.single.step, 1);
    expect(set.issues[2].flow.single.description, '일반 문자열 설명');
    expect(set.issues[3].flow.single.step, 7);
    expect(set.issues[3].flow.single.description, 'JSON 문자열 설명');
    expect(set.issues[4].flow.single.step, 1);
    expect(set.issues[4].flow.single.description, '뉴질랜드 정부, 법안 도입 발표.');
  });

  test('learning words inherit every article from the same document', () {
    final set = DailyIssueSet.fromMap(dailyIssueMap());
    expect(set.learningWords, hasLength(15));
    expect(set.learningWords.first['category'], 'economy');
    expect(set.learningWords.first['topic'], 'monetary_policy');
    expect(set.learningWords.first['related_articles'], hasLength(1));
  });

  test('exposes only one issue core words for learning completion', () {
    final set = DailyIssueSet.fromMap(dailyIssueMap());
    final learnedWords = set.learningWordsForIssue(2);

    expect(learnedWords, hasLength(3));
    expect(
      learnedWords.every((word) => word['source_issue_id'] == 'issue_3'),
      isTrue,
    );
    expect(
      learnedWords.every((word) => word['learned_date'] == set.date),
      isTrue,
    );
  });

  test('rejects a failed document as learning-ready', () {
    final set = DailyIssueSet.fromMap(dailyIssueMap(status: 'failed'));
    expect(set.isReady, isFalse);
  });

  test('ignores legacy Firestore quiz fields', () {
    final map = dailyIssueMap();
    final issues = map['issues'] as List<Map<String, dynamic>>;
    issues.first['issue_quiz'] = {
      'question': 'AI가 저장했던 이전 문제',
      'choices': ['A'],
    };
    final set = DailyIssueSet.fromMap(map);
    expect(set.isReady, isTrue);
    expect(set.issues.first.words, hasLength(3));
  });

  test('debug fixture contains five articles in one date document', () {
    final set = buildDebugIssueFixture();
    expect(set.isReady, isTrue);
    expect(set.issues, hasLength(5));
    expect(set.wordCount, 15);
  });
}
