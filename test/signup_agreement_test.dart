import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/models/legal_document.dart';
import 'package:wordapp/services/auth_service.dart';

void main() {
  Future<void> useTallTestViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> openSignUp(WidgetTester tester) async {
    await tapVisible(tester, find.text('회원가입'));
    await tester.pumpAndSettle();
  }

  testWidgets('email sign-up requires every mandatory agreement', (
    tester,
  ) async {
    await useTallTestViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await openSignUp(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'learner@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.enterText(fields.at(2), 'password123');

    await tapVisible(tester, find.widgetWithText(FilledButton, '회원가입'));
    expect(find.text('필수 약관에 모두 동의해 주세요.'), findsOneWidget);

    final checkboxes = find.byType(Checkbox);
    await tapVisible(tester, checkboxes.at(1));
    await tapVisible(tester, checkboxes.at(2));
    await tapVisible(tester, find.widgetWithText(FilledButton, '회원가입'));
    expect(find.text('필수 약관에 모두 동의해 주세요.'), findsOneWidget);
  });

  testWidgets('all agreement toggles every item and reflects an opt-out', (
    tester,
  ) async {
    await useTallTestViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await openSignUp(tester);

    await tapVisible(tester, find.byType(Checkbox).first);
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((item) => item.value),
      everyElement(isTrue),
    );

    await tapVisible(tester, find.byType(Checkbox).last);
    final values = tester
        .widgetList<Checkbox>(find.byType(Checkbox))
        .map((item) => item.value)
        .toList();
    expect(values.first, isFalse);
    expect(values.last, isFalse);
  });

  testWidgets('legal views use distinct documents and preserve form state', (
    tester,
  ) async {
    await useTallTestViewport(tester);
    final requestedIds = <String>[];
    Future<LegalDocument> loadDocument(String id) async {
      requestedIds.add(id);
      return LegalDocument(
        id: id,
        title: id == 'terms' ? '이용약관' : '개인정보 수집·이용 동의',
        content: '$id document content',
        version: '1.0',
        effectiveDate: '2026-08-03',
        updatedAt: null,
        isActive: true,
      );
    }

    await tester.pumpWidget(
      MaterialApp(home: LoginPage(legalDocumentLoader: loadDocument)),
    );
    await openSignUp(tester);
    await tester.enterText(find.byType(TextField).first, 'keep@example.com');
    await tapVisible(tester, find.byType(Checkbox).at(1));

    await tapVisible(tester, find.text('보기').first);
    await tester.pumpAndSettle();
    expect(find.text('terms document content'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('keep@example.com'), findsOneWidget);
    expect(
      tester.widgetList<Checkbox>(find.byType(Checkbox)).elementAt(1).value,
      isTrue,
    );

    await tapVisible(tester, find.text('보기').last);
    await tester.pumpAndSettle();
    expect(find.text('privacy_consent document content'), findsOneWidget);
    expect(requestedIds, ['terms', 'privacy_consent']);
  });

  testWidgets('sign-up agreements remain scrollable on a small screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    await openSignUp(tester);
    final signUpButton = find.widgetWithText(FilledButton, '회원가입');
    await tester.scrollUntilVisible(
      signUpButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(signUpButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('auth service rejects incomplete consent before account creation', () {
    expectLater(
      AuthService.signUpWithEmail(
        'learner@example.com',
        'password123',
        termsAgreed: true,
        privacyAgreed: true,
        ageConfirmed: false,
      ),
      throwsA(isA<AccountRegistrationException>()),
    );
  });

  test('agreement history uses centralized versions and required fields', () {
    final timestamp = Object();
    final agreements = AuthService.buildRequiredAgreementData(
      timestamp: timestamp,
    );

    expect(agreements['terms'], {
      'agreed': true,
      'version': '1.0',
      'agreed_at': timestamp,
    });
    expect(agreements['privacy_collection'], {
      'agreed': true,
      'version': '1.0',
      'agreed_at': timestamp,
    });
    expect(agreements['age_over_14'], {
      'confirmed': true,
      'confirmed_at': timestamp,
    });
  });
}
