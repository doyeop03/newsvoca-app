import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

class LearningDifficultyFeedbackService {
  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static const ratingLabels = <String, String>{
    'too_hard': '매우 어려웠어요',
    'just_right': '적당했어요',
    'too_easy': '너무 쉬웠어요',
  };

  static String documentId({
    required String uid,
    required String learningDate,
    required String category,
  }) {
    String safe(String value) => value.trim().replaceAll('/', '_');
    return '${safe(uid)}_${safe(learningDate)}_${safe(category)}';
  }

  static List<Map<String, String>> buildWordSnapshots(
    Iterable<Map<String, dynamic>> words,
  ) {
    final snapshots = <Map<String, String>>[];
    for (final data in words) {
      final word = data['word']?.toString().trim() ?? '';
      if (word.isEmpty) continue;
      final snapshot = <String, String>{'word': word};
      for (final key in const ['id', 'meaning', 'level']) {
        final value = data[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) snapshot[key] = value;
      }
      snapshots.add(snapshot);
    }
    return snapshots;
  }

  static Map<String, dynamic> buildData({
    required String uid,
    required String learningDate,
    required String category,
    required String rating,
    required List<Map<String, String>> words,
    required Object createdAt,
    required Object updatedAt,
  }) {
    final label = ratingLabels[rating];
    if (label == null) throw ArgumentError.value(rating, 'rating');
    return {
      'uid': uid,
      'learning_date': learningDate,
      'category': category,
      'rating': rating,
      'rating_label': label,
      'word_count': words.length,
      'words': words,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  static Future<bool> hasFeedback({
    required String learningDate,
    required String category,
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final id = documentId(
      uid: uid,
      learningDate: learningDate,
      category: category,
    );
    return (await _firestore
            .collection('learning_difficulty_feedback')
            .doc(id)
            .get())
        .exists;
  }

  static Future<void> save({
    required String learningDate,
    required String category,
    required String rating,
    required Iterable<Map<String, dynamic>> learnedWords,
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final snapshots = buildWordSnapshots(learnedWords);
    final id = documentId(
      uid: uid,
      learningDate: learningDate,
      category: category,
    );
    final timestamp = FieldValue.serverTimestamp();
    await _firestore
        .collection('learning_difficulty_feedback')
        .doc(id)
        .set(
          buildData(
            uid: uid,
            learningDate: learningDate,
            category: category,
            rating: rating,
            words: snapshots,
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
          SetOptions(merge: true),
        );
  }
}
