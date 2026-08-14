import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/services/knowledge_map_service.dart';

void main() {
  test('groups learned unique words by category and topic', () {
    final data = KnowledgeMapData.group([
      {
        'id': 'inference-old',
        'word': 'Inference',
        'meaning': '추론',
        'category': 'technology',
        'topic': 'artificial_intelligence',
        'topic_label_ko': '인공지능',
        'is_learned': true,
      },
      {
        'id': 'inference-duplicate',
        'word': 'inference',
        'meaning': '추론',
        'category': 'technology',
        'topic': 'artificial_intelligence',
        'is_learned': true,
      },
      {
        'id': 'foundry',
        'word': 'foundry',
        'category': 'technology',
        'topic': 'semiconductor',
        'topic_label_ko': '반도체',
        'is_learned': true,
      },
      {
        'id': 'ignored',
        'word': 'ignored',
        'category': 'economy',
        'is_learned': false,
      },
    ]);

    expect(data.wordCount, 2);
    expect(data.topicCount, 2);
    expect(data.categoryCount, 1);
    expect(data.categories.single.key, 'technology');
  });

  test('keeps category-only legacy words in a safe fallback topic', () {
    final data = KnowledgeMapData.group([
      {
        'id': 'legacy',
        'word': 'legacy',
        'meaning': '기존 데이터',
        'category': 'economy',
        'is_learned': true,
      },
      {'id': 'missing-category', 'word': 'orphan', 'is_learned': true},
    ]);

    expect(data.wordCount, 2);
    expect(
      data.categories
          .expand((category) => category.topics)
          .map((topic) => topic.label),
      everyElement('기타 학습'),
    );
  });
}
