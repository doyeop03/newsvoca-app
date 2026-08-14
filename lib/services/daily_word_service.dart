import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/learning_date.dart';

class DailyWordService {
  DailyWordService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _collectionName = 'daily_word_sets';
  final FirebaseFirestore _firestore;
  String? lastError;

  Future<Map<String, dynamic>?> getDailyWordSet({
    String? date,
    required String category,
  }) async {
    final targetDate = date ?? getCurrentLearningDateKst();
    final documentId = '${targetDate}_$category';
    final now = DateTime.now().toUtc();
    lastError = null;

    try {
      // ignore: avoid_print
      print('[wordset] trying target doc $documentId');
      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(documentId)
          .get();
      final data = snapshot.data();

      if (snapshot.exists && !_isPublished(data, now)) {
        // ignore: avoid_print
        print('[wordset] target publish_at not reached, fallback');
      }

      if (snapshot.exists && _isTargetWordSetReady(data, now)) {
        // ignore: avoid_print
        print('[wordset] loaded ready doc $documentId');
        return _withLoadMetadata(data!, targetDate, isFallback: false);
      }

      final fallback = await loadLatestReadyWordSetForCategory(
        category,
        targetDate: targetDate,
        now: now,
      );
      if (fallback != null) {
        final fallbackDate = _documentDate(fallback) ?? 'latest';
        // ignore: avoid_print
        print(
          '[wordset] target not ready, fallback to '
          '${fallbackDate}_$category',
        );
        // ignore: avoid_print
        print('[wordset] loaded ${fallbackDate}_$category');
        return _withLoadMetadata(fallback, fallbackDate, isFallback: true);
      }

      // ignore: avoid_print
      print('[wordset] no ready data for category=$category');
      return null;
    } catch (error) {
      lastError = error.toString();
      // ignore: avoid_print
      print('[wordset] load failed category=$category error=$error');
      return null;
    }
  }

  Future<Map<String, dynamic>?> loadLatestReadyWordSetForCategory(
    String category, {
    String? targetDate,
    DateTime? now,
  }) async {
    final effectiveTargetDate = targetDate ?? getCurrentLearningDateKst();
    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final collection = _firestore.collection(_collectionName);

    try {
      final strictSnapshot = await collection
          .where('category', isEqualTo: category)
          .where('is_ready', isEqualTo: true)
          .where('generation_status', isEqualTo: 'ready')
          .where(
            'publish_at',
            isLessThanOrEqualTo: Timestamp.fromDate(effectiveNow),
          )
          .limit(20)
          .get();
      final strict = _latestValidCandidate(
        strictSnapshot.docs,
        category: category,
        targetDate: effectiveTargetDate,
        now: effectiveNow,
        allowLegacy: false,
      );
      if (strict != null) return strict;
    } catch (error) {
      // This query can require a Firestore composite index. In development,
      // follow the Firebase Console index-creation link included in the error.
      // ignore: avoid_print
      print('[wordset] strict fallback query failed: $error');
    }

    try {
      final compatibilitySnapshot = await collection
          .where('category', isEqualTo: category)
          .where('date', isLessThanOrEqualTo: effectiveTargetDate)
          .orderBy('date', descending: true)
          .limit(20)
          .get();
      final compatible = _latestValidCandidate(
        compatibilitySnapshot.docs,
        category: category,
        targetDate: effectiveTargetDate,
        now: effectiveNow,
        allowLegacy: true,
      );
      if (compatible != null) return compatible;
    } catch (error) {
      // This query can also require a Firestore composite index. Follow the
      // Firebase Console link in the error, then deploy the generated index.
      // ignore: avoid_print
      print('[wordset] compatibility fallback query failed: $error');
    }

    // Last-resort compatibility path keeps the app usable while an index is
    // being built. Every returned document is still validated client-side.
    final snapshot = await collection.limit(100).get();
    return _latestValidCandidate(
      snapshot.docs,
      category: category,
      targetDate: effectiveTargetDate,
      now: effectiveNow,
      allowLegacy: true,
    );
  }

  Map<String, dynamic>? _latestValidCandidate(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> documents, {
    required String category,
    required String targetDate,
    required DateTime now,
    required bool allowLegacy,
  }) {
    final candidates =
        documents.where((document) {
          final data = document.data();
          final documentCategory = data['category']?.toString().trim();
          final matchesCategory =
              documentCategory == category ||
              ((documentCategory == null || documentCategory.isEmpty) &&
                  document.id.endsWith('_$category'));
          final date = _documentDate(data, document.id);
          return matchesCategory &&
              date != null &&
              date.compareTo(targetDate) <= 0 &&
              _isFallbackWordSetReady(data, now, allowLegacy: allowLegacy);
        }).toList()..sort((a, b) {
          final aDate = _documentDate(a.data(), a.id) ?? '';
          final bDate = _documentDate(b.data(), b.id) ?? '';
          return bDate.compareTo(aDate);
        });

    if (candidates.isEmpty) return null;
    final selected = candidates.first;
    return {...selected.data(), '_document_id': selected.id};
  }

  bool _isTargetWordSetReady(Map<String, dynamic>? data, DateTime now) {
    if (!_hasEnoughWords(data) || !_isPublished(data, now)) return false;
    return data?['is_ready'] == true &&
        data?['generation_status']?.toString() == 'ready';
  }

  bool _isFallbackWordSetReady(
    Map<String, dynamic> data,
    DateTime now, {
    required bool allowLegacy,
  }) {
    if (!_hasEnoughWords(data) || !_isPublished(data, now)) return false;
    if (data['is_ready'] == false ||
        data['generation_status']?.toString() == 'failed') {
      return false;
    }
    if (data['is_ready'] == true ||
        data['generation_status']?.toString() == 'ready') {
      return true;
    }
    final hasReadinessFields =
        data.containsKey('is_ready') || data.containsKey('generation_status');
    return allowLegacy && !hasReadinessFields;
  }

  bool _hasEnoughWords(Map<String, dynamic>? data) {
    final words = data?['words'];
    return words is List && words.isNotEmpty;
  }

  bool _isPublished(Map<String, dynamic>? data, DateTime now) {
    final publishAt = data?['publish_at'];
    if (publishAt == null) return true;
    if (publishAt is Timestamp) {
      return !publishAt.toDate().toUtc().isAfter(now);
    }
    if (publishAt is DateTime) return !publishAt.toUtc().isAfter(now);
    final parsed = DateTime.tryParse(publishAt.toString());
    return parsed != null && !parsed.toUtc().isAfter(now);
  }

  String? _documentDate(Map<String, dynamic> data, [String? documentId]) {
    final date = data['date']?.toString().trim() ?? '';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) return date;
    final id = documentId ?? data['_document_id']?.toString() ?? '';
    if (id.length >= 10) {
      final idDate = id.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(idDate)) return idDate;
    }
    return null;
  }

  Map<String, dynamic> _withLoadMetadata(
    Map<String, dynamic> data,
    String resolvedDate, {
    required bool isFallback,
  }) {
    return {
      ...data,
      '_resolved_date': resolvedDate,
      '_is_fallback': isFallback,
    };
  }
}
