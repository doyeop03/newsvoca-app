import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  testWidgets('startup error screen renders without Firebase initialization', (
    tester,
  ) async {
    await tester.pumpWidget(
      const VocaBriefApp(startupError: 'Firebase initialization failed'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Firebase initialization failed'), findsOneWidget);
  });
}
