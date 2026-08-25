import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_issue_set.dart';
import '../models/debug_issue_fixture.dart';
import '../utils/learning_date.dart';

class DailyIssueService {
  DailyIssueService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<DailyIssueSet?> load({String? date}) async {
    final wanted = date ?? getCurrentLearningDateKst();
    try {
      final exact = await _firestore
          .collection('daily_issues')
          .doc(wanted)
          .get();
      final exactSet = _ready(exact.data());
      if (exactSet != null) return exactSet;

      // Page by date so failed documents never hide an older ready fallback,
      // without requiring a compound status/date index.
      Query<Map<String, dynamic>> query = _firestore
          .collection('daily_issues')
          .orderBy('date', descending: true)
          .limit(20);
      while (true) {
        final recent = await query.get();
        for (final document in recent.docs) {
          if (document.id.compareTo(wanted) > 0) continue;
          final set = _ready(document.data());
          if (set != null) return set;
        }
        if (recent.docs.length < 20) break;
        query = _firestore
            .collection('daily_issues')
            .orderBy('date', descending: true)
            .startAfterDocument(recent.docs.last)
            .limit(20);
      }
    } catch (error) {
      debugPrint('[daily-issues] remote load failed: $error');
    }
    if (kDebugMode) return buildDebugIssueFixture();
    return null;
  }

  DailyIssueSet? _ready(Map<String, dynamic>? data) {
    if (data == null || data['status'] != 'ready') return null;
    final set = DailyIssueSet.fromMap(data);
    return set.isReady ? set : null;
  }
}
