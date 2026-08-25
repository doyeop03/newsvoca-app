import 'daily_issue_set.dart';

/// Development-only content used when neither today's ready document nor a
/// recent ready fallback exists. Release builds never use this fixture.
DailyIssueSet buildDebugIssueFixture() => DailyIssueSet.fromMap({
  'date': '2026-08-18',
  'status': 'ready',
  'issues': List.generate(5, (index) => _debugIssue(index)),
});

Map<String, dynamic> _debugIssue(int index) {
  final number = index + 1;
  final words = [
    _word('outlook $number', '전망'),
    _word('capacity $number', '수용 능력'),
    _word('response $number', '대응'),
  ];
  return {
    'rank': number,
    'issue_title': '글로벌 주요 이슈 $number',
    'issue_summary': '여러 지역의 주요 변화를 영어권 보도가 공통으로 다뤘습니다.',
    'issue_background': '정책과 산업, 시민 생활에 미치는 영향을 함께 이해할 필요가 있습니다.',
    'articles': [
      {
        'title': 'Global major issue $number',
        'source': 'Global News fixture',
        'publishedAt': '2026-08-18',
        'url': 'https://example.com/debug-daily-issue-$number',
      },
    ],
    'words': words,
  };
}

Map<String, dynamic> _word(String word, String meaning) => {
  'word': word,
  'meaning': meaning,
  'description_ko': '뉴스에서 원인과 영향을 설명할 때 재사용하기 좋은 표현입니다.',
  'part_of_speech': 'noun',
  'level': '중급',
  'example': 'The report highlighted $word.',
  'example_ko': '보고서는 $meaning을 강조했습니다.',
};
