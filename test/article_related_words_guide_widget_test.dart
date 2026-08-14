import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordapp/main.dart';

void main() {
  testWidgets('guide uses compact copy and interactive save preview', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: ArticleLearningPage(
          article: {
            'title': 'Test article',
            'expressions': [
              {'text': 'take effect', 'meaning': '효력이 생기다'},
            ],
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('관련 단어를 저장할 수 있어요'), findsOneWidget);
    expect(find.text('저장된 단어는 이후 복습 문제에서 다시 학습할 수 있어요.'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_add_rounded), findsNothing);
    expect(find.text('저장됨'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2250));

    expect(find.text('저장됨'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });
}
