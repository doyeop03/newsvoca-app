import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  const highlightColor = Color(0xFF5B8EF3);

  String combinedText(List<TextSpan> spans) =>
      spans.map((span) => span.text ?? '').join();

  List<TextSpan> highlighted(List<TextSpan> spans) => spans
      .where((span) => span.style?.color == highlightColor)
      .toList(growable: false);

  test('highlights a keyword without changing punctuation', () {
    const sentence = 'The success of diplomacy, could ease tensions.';
    final spans = buildHighlightedTextSpans(sentence, 'diplomacy');

    expect(combinedText(spans), sentence);
    expect(highlighted(spans).map((span) => span.text), ['diplomacy']);
  });

  test('matches case-insensitively while preserving original case', () {
    const sentence = 'Inflation can rise while INFLATION expectations fall.';
    final spans = buildHighlightedTextSpans(sentence, 'inflation');

    expect(combinedText(spans), sentence);
    expect(highlighted(spans).map((span) => span.text), [
      'Inflation',
      'INFLATION',
    ]);
  });

  test('highlights every occurrence of a multi-word phrase', () {
    const sentence = 'The interest rate affects another interest rate.';
    final spans = buildHighlightedTextSpans(sentence, 'interest rate');

    expect(combinedText(spans), sentence);
    expect(highlighted(spans).map((span) => span.text), [
      'interest rate',
      'interest rate',
    ]);
  });

  test('supports requested words and a phrase next to punctuation', () {
    final cases = {
      'Companies continue to reinvest profits.': 'reinvest',
      'Demand became a TAILWIND for growth.': 'tailwind',
      'The court may strike down, the rule.': 'strike down',
    };

    for (final entry in cases.entries) {
      final spans = buildHighlightedTextSpans(entry.key, entry.value);
      expect(combinedText(spans), entry.key);
      expect(highlighted(spans), hasLength(1));
    }
  });

  test('highlights natural inflections of a dictionary-form keyword', () {
    final cases = {
      'The company woos customers with innovative products.': 'woo',
      'She studies the market before investing.': 'study',
      'The policy was launched yesterday.': 'launch',
      'The executive stepped down.': 'step down',
      'Several rate hikes changed expectations.': 'rate hike',
    };

    for (final entry in cases.entries) {
      final spans = buildHighlightedTextSpans(entry.key, entry.value);
      expect(combinedText(spans), entry.key);
      expect(highlighted(spans), hasLength(1), reason: entry.key);
    }
  });

  test('returns unstyled text when keyword is empty or absent', () {
    for (final keyword in ['', 'diplomacy']) {
      final spans = buildHighlightedTextSpans('No matching term.', keyword);

      expect(combinedText(spans), 'No matching term.');
      expect(highlighted(spans), isEmpty);
    }
  });
}
