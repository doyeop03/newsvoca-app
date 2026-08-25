import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notice.dart';

class AppNoticeService {
  AppNoticeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const collectionPath = 'app_notices';
  static const currentDocumentId = 'current';
  static const currentDocumentPath = '$collectionPath/$currentDocumentId';

  Stream<AppNotice?> watchCurrentNotice() => _firestore
      .collection(collectionPath)
      .doc(currentDocumentId)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        final notice = data == null ? null : AppNotice.fromMap(data);
        if (kDebugMode) {
          debugPrint(
            '[app-notice] snapshot path=$currentDocumentPath '
            'exists=${snapshot.exists} enabled=${notice?.enabled} '
            'renderable=${notice?.isRenderable}',
          );
        }
        return notice;
      });

  Stream<DailyIssueAvailability> watchDailyIssue(String learningDate) =>
      _firestore.collection('daily_issues').doc(learningDate).snapshots().map((
        snapshot,
      ) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          return DailyIssueAvailability.missing;
        }
        return switch (data['status']) {
          'ready' => DailyIssueAvailability.ready,
          'failed' => DailyIssueAvailability.failed,
          _ => DailyIssueAvailability.notReady,
        };
      });
}
