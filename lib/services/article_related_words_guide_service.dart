import 'package:shared_preferences/shared_preferences.dart';

class ArticleRelatedWordsGuideService {
  static const hiddenPreferenceKey = 'article_related_words_guide_hidden';

  static bool hasSaveableRelatedWords(Map<String, dynamic> article) {
    final expressions = article['expressions'];
    if (expressions is List &&
        expressions.whereType<Map>().any(
          (item) => (item['text']?.toString().trim() ?? '').isNotEmpty,
        )) {
      return true;
    }

    final sentences = article['learning_sentences'];
    if (sentences is! List) return false;
    for (final sentence in sentences.whereType<Map>()) {
      final words = sentence['highlight_words'];
      if (words is! List) continue;
      final hasSaveableWord = words.whereType<Map>().any((item) {
        final text = item['text']?.toString().trim() ?? '';
        return text.isNotEmpty && item['is_focus_word'] != true;
      });
      if (hasSaveableWord) return true;
    }
    return false;
  }

  static Future<bool> shouldShow(Map<String, dynamic> article) async {
    if (!hasSaveableRelatedWords(article)) return false;
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool(hiddenPreferenceKey) ?? false);
  }

  static Future<void> hidePermanently() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(hiddenPreferenceKey, true);
  }
}
