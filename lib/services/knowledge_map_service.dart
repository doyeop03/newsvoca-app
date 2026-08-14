import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

class KnowledgeMapWord {
  const KnowledgeMapWord({
    required this.id,
    required this.word,
    required this.meaning,
    required this.category,
    required this.topic,
    required this.topicLabel,
    required this.level,
    required this.reviewCount,
    required this.correctCount,
    required this.wrongCount,
    required this.lastSeenAt,
  });

  final String id;
  final String word;
  final String meaning;
  final String category;
  final String topic;
  final String topicLabel;
  final String level;
  final int reviewCount;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastSeenAt;

  static KnowledgeMapWord? fromData(String id, Map<String, dynamic> data) {
    String text(String key) => data[key]?.toString().trim() ?? '';
    int count(String key) => data[key] is num
        ? (data[key] as num).toInt()
        : int.tryParse(text(key)) ?? 0;
    final word = text('word');
    if (word.isEmpty || data['is_learned'] != true) return null;
    final category = text('category').isEmpty
        ? 'uncategorized'
        : text('category');
    final topic = text('topic');
    final timestamp = data['last_seen_at'] ?? data['last_learned_at'];
    return KnowledgeMapWord(
      id: id,
      word: word,
      meaning: text('meaning'),
      category: category,
      topic: topic.isEmpty ? '__legacy__' : topic,
      topicLabel: topic.isEmpty
          ? '기타 학습'
          : (text('topic_label_ko').isEmpty
                ? _humanize(topic)
                : text('topic_label_ko')),
      level: text('level'),
      reviewCount: count('review_correct_count') + count('review_wrong_count'),
      correctCount: count('correct_count') + count('review_correct_count'),
      wrongCount: count('wrong_count') + count('review_wrong_count'),
      lastSeenAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }
}

class KnowledgeMapTopic {
  const KnowledgeMapTopic({
    required this.key,
    required this.label,
    required this.words,
  });
  final String key;
  final String label;
  final List<KnowledgeMapWord> words;
}

class KnowledgeMapCategory {
  const KnowledgeMapCategory({required this.key, required this.topics});
  final String key;
  final List<KnowledgeMapTopic> topics;
  int get wordCount =>
      topics.fold(0, (totalSoFar, topic) => totalSoFar + topic.words.length);
}

class KnowledgeMapData {
  const KnowledgeMapData({required this.categories});
  final List<KnowledgeMapCategory> categories;
  int get wordCount => categories.fold(
    0,
    (totalSoFar, category) => totalSoFar + category.wordCount,
  );
  int get topicCount => categories.fold(
    0,
    (totalSoFar, category) => totalSoFar + category.topics.length,
  );
  int get categoryCount => categories.length;

  static KnowledgeMapData group(Iterable<Map<String, dynamic>> documents) {
    final unique = <String, KnowledgeMapWord>{};
    for (final document in documents) {
      final id = document['id']?.toString() ?? '';
      final parsed = KnowledgeMapWord.fromData(id, document);
      if (parsed == null) continue;
      final key = parsed.word.trim().toLowerCase();
      final existing = unique[key];
      if (existing == null ||
          _isNewer(parsed.lastSeenAt, existing.lastSeenAt)) {
        unique[key] = parsed;
      }
    }
    final grouped = <String, Map<String, List<KnowledgeMapWord>>>{};
    for (final word in unique.values) {
      grouped
          .putIfAbsent(word.category, () => {})
          .putIfAbsent(word.topic, () => [])
          .add(word);
    }
    final categories = grouped.entries.map((category) {
      final topics = category.value.entries.map((topic) {
        topic.value.sort((a, b) => a.word.compareTo(b.word));
        return KnowledgeMapTopic(
          key: topic.key,
          label: topic.value.first.topicLabel,
          words: List.unmodifiable(topic.value),
        );
      }).toList()..sort((a, b) => b.words.length.compareTo(a.words.length));
      return KnowledgeMapCategory(
        key: category.key,
        topics: List.unmodifiable(topics),
      );
    }).toList()..sort((a, b) => b.wordCount.compareTo(a.wordCount));
    return KnowledgeMapData(categories: List.unmodifiable(categories));
  }
}

class KnowledgeMapService {
  static Future<KnowledgeMapData> load() async {
    final uid = await AuthService.ensureAnonymousLogin();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('user_words')
        .get();
    return KnowledgeMapData.group(
      snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}),
    );
  }
}

bool _isNewer(DateTime? left, DateTime? right) {
  if (left == null) return false;
  return right == null || left.isAfter(right);
}

String _humanize(String value) => value
    .split(RegExp(r'[_\-\s]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
