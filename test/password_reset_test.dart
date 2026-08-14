import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';

void main() {
  Future<void> useTallViewport(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> tapSend(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, '재설정 메일 보내기');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('login page opens the password reset page', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    await tester.tap(find.text('비밀번호 찾기'));
    await tester.pumpAndSettle();

    expect(find.text('비밀번호 재설정'), findsOneWidget);
    expect(find.text('비밀번호를 잊으셨나요?'), findsOneWidget);
    expect(find.textContaining('Google로 가입한 경우'), findsOneWidget);
  });

  testWidgets('empty and invalid emails are blocked before sending', (
    tester,
  ) async {
    await useTallViewport(tester);
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetPage(sendPasswordResetEmail: (_) async => calls++),
      ),
    );

    await tapSend(tester);
    expect(find.text('이메일 주소를 입력해 주세요.'), findsOneWidget);
    expect(calls, 0);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tapSend(tester);
    expect(find.text('올바른 이메일 주소를 입력해 주세요.'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('valid email is trimmed and success returns to login', (
    tester,
  ) async {
    await useTallViewport(tester);
    String? sentEmail;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PasswordResetPage(
                      sendPasswordResetEmail: (email) async {
                        sentEmail = email;
                      },
                    ),
                  ),
                ),
                child: const Text('비밀번호 찾기 열기'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('비밀번호 찾기 열기'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      '  learner@example.com  ',
    );
    await tapSend(tester);
    await tester.pump(const Duration(milliseconds: 400));

    expect(sentEmail, 'learner@example.com');
    expect(find.text('메일을 확인해 주세요'), findsOneWidget);
    expect(find.textContaining('스팸함'), findsOneWidget);

    await tester.tap(find.text('로그인으로 돌아가기'));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호 찾기 열기'), findsOneWidget);
  });

  testWidgets('sending state prevents duplicate reset requests', (
    tester,
  ) async {
    await useTallViewport(tester);
    final completer = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetPage(
          initialEmail: 'learner@example.com',
          sendPasswordResetEmail: (_) {
            calls++;
            return completer.future;
          },
        ),
      ),
    );

    await tapSend(tester);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(calls, 1);

    completer.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
  });

  testWidgets('Firebase reset errors use localized safe messages', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetPage(
          initialEmail: 'learner@example.com',
          sendPasswordResetEmail: (_) => Future<void>.error(
            FirebaseAuthException(code: 'too-many-requests'),
          ),
        ),
      ),
    );

    await tapSend(tester);
    await tester.pumpAndSettle();
    expect(find.text('요청이 너무 많아요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(find.textContaining('FirebaseAuthException'), findsNothing);
  });

  testWidgets('network errors show a connection message', (tester) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetPage(
          initialEmail: 'learner@example.com',
          sendPasswordResetEmail: (_) => Future<void>.error(
            FirebaseAuthException(code: 'network-request-failed'),
          ),
        ),
      ),
    );

    await tapSend(tester);
    await tester.pumpAndSettle();
    expect(find.text('인터넷 연결을 확인해 주세요.'), findsOneWidget);
  });

  testWidgets('unknown accounts do not reveal account existence', (
    tester,
  ) async {
    await useTallViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetPage(
          initialEmail: 'unknown@example.com',
          sendPasswordResetEmail: (_) =>
              Future<void>.error(FirebaseAuthException(code: 'user-not-found')),
        ),
      ),
    );

    await tapSend(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('메일을 확인해 주세요'), findsOneWidget);
    expect(find.textContaining('가입되지 않은'), findsNothing);
  });

  testWidgets('password reset page scrolls without overflow on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PasswordResetPage(sendPasswordResetEmail: (_) async {}),
      ),
    );

    final button = find.widgetWithText(FilledButton, '재설정 메일 보내기');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(button, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
