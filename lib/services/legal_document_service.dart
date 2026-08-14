import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/legal_document.dart';

enum LegalDocumentUnavailableReason { missing, inactive, empty }

class LegalDocumentUnavailableException implements Exception {
  const LegalDocumentUnavailableException(this.reason);

  final LegalDocumentUnavailableReason reason;

  @override
  String toString() => switch (reason) {
    LegalDocumentUnavailableReason.missing => '법적 문서를 찾을 수 없습니다.',
    LegalDocumentUnavailableReason.inactive => '현재 문서를 확인할 수 없습니다.',
    LegalDocumentUnavailableReason.empty => '법적 문서의 내용이 비어 있습니다.',
  };
}

class LegalDocumentService {
  LegalDocumentService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<LegalDocument> getDocument(String documentId) async {
    final snapshot = await _firestore
        .collection('legal_documents')
        .doc(documentId)
        .get();

    if (!snapshot.exists) {
      throw const LegalDocumentUnavailableException(
        LegalDocumentUnavailableReason.missing,
      );
    }

    return validateLegalDocument(LegalDocument.fromFirestore(snapshot));
  }

  Future<LegalDocument> getTerms() => getDocument('terms');

  Future<LegalDocument> getPrivacyPolicy() => getDocument('privacy');
}

LegalDocument validateLegalDocument(LegalDocument document) {
  if (!document.isActive) {
    throw const LegalDocumentUnavailableException(
      LegalDocumentUnavailableReason.inactive,
    );
  }
  if (document.content.trim().isEmpty) {
    throw const LegalDocumentUnavailableException(
      LegalDocumentUnavailableReason.empty,
    );
  }
  return document;
}
