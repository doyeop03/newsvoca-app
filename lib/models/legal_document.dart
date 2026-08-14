import 'package:cloud_firestore/cloud_firestore.dart';

class LegalDocument {
  const LegalDocument({
    required this.id,
    required this.title,
    required this.content,
    required this.version,
    required this.effectiveDate,
    required this.updatedAt,
    required this.isActive,
  });

  final String id;
  final String title;
  final String content;
  final String version;
  final String effectiveDate;
  final DateTime? updatedAt;
  final bool isActive;

  factory LegalDocument.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    return LegalDocument.fromMap(document.id, document.data() ?? const {});
  }

  factory LegalDocument.fromMap(String id, Map<String, dynamic> data) {
    final timestamp = data['updated_at'];
    return LegalDocument(
      id: id,
      title: (data['title'] ?? '').toString().trim(),
      content: (data['content'] ?? '').toString(),
      version: (data['version'] ?? '').toString().trim(),
      effectiveDate: (data['effective_date'] ?? '').toString().trim(),
      updatedAt: timestamp is Timestamp ? timestamp.toDate() : null,
      isActive: data['is_active'] == true,
    );
  }
}
