import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/services/article_related_words_guide_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('shows for a first visit with a saveable sentence word', () async {
    final article = <String, dynamic>{
      'learning_sentences': [
        {
          'highlight_words': [
            {'text': 'main word', 'is_focus_word': true},
            {'text': 'related word', 'is_focus_word': false},
          ],
        },
      ],
    };

    expect(
      ArticleRelatedWordsGuideService.hasSaveableRelatedWords(article),
      isTrue,
    );
    expect(await ArticleRelatedWordsGuideService.shouldShow(article), isTrue);
  });

  test('shows when a saveable expression exists', () async {
    final article = <String, dynamic>{
      'expressions': [
        {'text': 'take effect', 'meaning': '효력이 생기다'},
      ],
    };

    expect(await ArticleRelatedWordsGuideService.shouldShow(article), isTrue);
  });

  test('does not show without a saveable related word', () async {
    final article = <String, dynamic>{
      'learning_sentences': [
        {
          'highlight_words': [
            {'text': 'main word', 'is_focus_word': true},
          ],
        },
      ],
      'expressions': <Map<String, dynamic>>[],
    };

    expect(
      ArticleRelatedWordsGuideService.hasSaveableRelatedWords(article),
      isFalse,
    );
    expect(await ArticleRelatedWordsGuideService.shouldShow(article), isFalse);
  });

  test(
    'hide permanently stores preference and prevents future guides',
    () async {
      final article = <String, dynamic>{
        'expressions': [
          {'text': 'take effect'},
        ],
      };

      await ArticleRelatedWordsGuideService.hidePermanently();

      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getBool(
          ArticleRelatedWordsGuideService.hiddenPreferenceKey,
        ),
        isTrue,
      );
      expect(
        await ArticleRelatedWordsGuideService.shouldShow(article),
        isFalse,
      );
    },
  );

  test('closing without hiding leaves the next visit eligible', () async {
    final article = <String, dynamic>{
      'expressions': [
        {'text': 'take effect'},
      ],
    };

    expect(await ArticleRelatedWordsGuideService.shouldShow(article), isTrue);
    expect(await ArticleRelatedWordsGuideService.shouldShow(article), isTrue);
  });
}
