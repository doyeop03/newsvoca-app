import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/main.dart';
import 'package:wordapp/models/legal_document.dart';
import 'package:wordapp/services/legal_document_service.dart';

void main() {
  LegalDocument document({
    String content = '제1조 목적\n\nNEWSVOCA 이용 조건입니다.',
    bool isActive = true,
  }) {
    return LegalDocument.fromMap('terms', {
      'title': '이용약관',
      'content': content,
      'version': '1.0',
      'effective_date': '2026-08-03',
      'updated_at': Timestamp.fromDate(DateTime(2026, 8, 3)),
      'is_active': isActive,
    });
  }

  test('parses snake_case legal document fields', () {
    final parsed = document();
    expect(parsed.id, 'terms');
    expect(parsed.title, '이용약관');
    expect(parsed.version, '1.0');
    expect(parsed.effectiveDate, '2026-08-03');
    expect(parsed.updatedAt, DateTime(2026, 8, 3));
    expect(parsed.isActive, isTrue);
  });

  test('rejects inactive and empty documents', () {
    expect(
      () => validateLegalDocument(document(isActive: false)),
      throwsA(
        isA<LegalDocumentUnavailableException>().having(
          (error) => error.reason,
          'reason',
          LegalDocumentUnavailableReason.inactive,
        ),
      ),
    );
    expect(
      () => validateLegalDocument(document(content: '  ')),
      throwsA(isA<LegalDocumentUnavailableException>()),
    );
  });

  testWidgets('shows multiline content and metadata', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LegalDocumentPage(
          documentId: 'terms',
          fallbackTitle: '이용약관',
          loader: () async => document(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('제1조 목적\n\nNEWSVOCA 이용 조건입니다.'), findsOneWidget);
    expect(find.text('버전 1.0  ·  시행일 2026-08-03'), findsOneWidget);
  });

  testWidgets('shows an error and retries without rebuilding requests', (
    tester,
  ) async {
    var requests = 0;
    Future<LegalDocument> loader() async {
      requests++;
      if (requests == 1) throw StateError('offline');
      return document();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: LegalDocumentPage(
          documentId: 'terms',
          fallbackTitle: '이용약관',
          loader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.textContaining('NEWSVOCA 이용 조건'), findsOneWidget);
  });

  testWidgets('login page only exposes account support links', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.text('회원가입'), findsOneWidget);
    expect(find.text('비밀번호 찾기'), findsOneWidget);
    expect(find.text('이용약관'), findsNothing);
    expect(find.text('개인정보처리방침'), findsNothing);
  });
}
