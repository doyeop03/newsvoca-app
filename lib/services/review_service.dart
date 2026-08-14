import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'user_word_service.dart';
import '../utils/learning_date.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<List<Map<String, dynamic>>> getTodayReviewWords({
    int limit = 10,
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('user_words')
        .limit(100)
        .get();

    final now = DateTime.now();
    final candidates =
        snapshot.docs
            .map(
              (doc) => _withComputedScore({...doc.data(), 'id': doc.id}, now),
            )
            .where(isReviewCandidate)
            .toList()
          ..sort(
            (a, b) => _numValue(
              b['review_score'],
            ).compareTo(_numValue(a['review_score'])),
          );

    // ignore: avoid_print
    print('Today review candidate count=${candidates.length}');
    // ignore: avoid_print
    print(
      'Top review words=${candidates.take(limit).map((word) => word['word']).toList()}',
    );

    return candidates.take(limit).toList();
  }

  static Future<void> updateReviewResultForWord(
    Map<String, dynamic> wordData,
    bool isCorrect,
  ) async {
    final word = _stringValue(wordData['word']);
    if (word.isEmpty) {
      return;
    }

    final uid = await AuthService.ensureAnonymousLogin();
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('user_words')
        .doc(UserWordService.wordIdFor(word));
    final snapshot = await ref.get();
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = FieldValue.serverTimestamp();
    final currentLevel = _intValue(data['review_level']);
    final currentConsecutive = _intValue(data['consecutive_correct_count']);

    final Map<String, dynamic> updates;
    if (isCorrect) {
      final nextLevel = currentLevel + 1;
      final nextConsecutive = currentConsecutive + 1;
      final mastered = nextConsecutive >= 5 || nextLevel >= 5;
      updates = {
        'review_correct_count': FieldValue.increment(1),
        'correct_count': FieldValue.increment(1),
        'consecutive_correct_count': FieldValue.increment(1),
        'review_level': FieldValue.increment(1),
        'last_reviewed_at': now,
        'last_seen_at': now,
        'updated_at': now,
        if (mastered) ...{
          'is_mastered': true,
          'mastered_at': now,
          'next_review_at': null,
        } else
          'next_review_at': Timestamp.fromDate(
            DateTime.now().add(Duration(days: _daysForLevel(nextLevel))),
          ),
      };
      // ignore: avoid_print
      print(
        'updateReviewResultForWord correct word=$word nextLevel=$nextLevel mastered=$mastered',
      );
    } else {
      final nextLevel = currentLevel > 0 ? currentLevel - 1 : 0;
      updates = {
        'review_wrong_count': FieldValue.increment(1),
        'wrong_count': FieldValue.increment(1),
        'consecutive_correct_count': 0,
        'review_level': nextLevel,
        'is_mastered': false,
        'last_reviewed_at': now,
        'last_seen_at': now,
        'next_review_at': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 1)),
        ),
        'updated_at': now,
      };
      // ignore: avoid_print
      print('updateReviewResultForWord wrong word=$word nextLevel=$nextLevel');
    }

    await ref.set({
      ..._baseWordFields(wordData),
      ...updates,
      if (!snapshot.exists) 'created_at': now,
    }, SetOptions(merge: true));
  }

  static Future<void> excludeWordFromReview(
    Map<String, dynamic> wordData,
  ) async {
    final word = _stringValue(wordData['word']);
    final documentId = _stringValue(wordData['id']).isNotEmpty
        ? _stringValue(wordData['id'])
        : UserWordService.wordIdFor(word);
    if (documentId.isEmpty) {
      throw ArgumentError('복습 단어 정보를 확인할 수 없습니다.');
    }

    final uid = await AuthService.ensureAnonymousLogin();
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('user_words')
        .doc(documentId);
    await ref.set(
      buildReviewExclusionData(excludedAt: FieldValue.serverTimestamp()),
      SetOptions(merge: true),
    );
  }

  static Map<String, dynamic> buildReviewExclusionData({
    required Object excludedAt,
  }) {
    return {
      'review_excluded': true,
      'review_excluded_at': excludedAt,
      'review_excluded_reason': 'user_stop',
    };
  }

  static Future<void> restoreWordToReview(Map<String, dynamic> wordData) async {
    final word = _stringValue(wordData['word']);
    final documentId = _stringValue(wordData['id']).isNotEmpty
        ? _stringValue(wordData['id'])
        : UserWordService.wordIdFor(word);
    if (documentId.isEmpty) {
      throw ArgumentError('복습 단어 정보를 확인할 수 없습니다.');
    }

    final uid = await AuthService.ensureAnonymousLogin();
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('user_words')
        .doc(documentId);
    await ref.set(
      buildReviewRestoreData(deletedValue: FieldValue.delete()),
      SetOptions(merge: true),
    );
  }

  static Map<String, dynamic> buildReviewRestoreData({
    required Object deletedValue,
  }) {
    return {
      'review_excluded': false,
      'review_excluded_at': deletedValue,
      'review_excluded_reason': deletedValue,
    };
  }

  static Future<void> saveReviewResult({
    required int score,
    required int total,
    required List<String> wrongWords,
    required List<String> correctWords,
    String? date,
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final resultDate = date ?? getCurrentLearningDateKst();
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('review_results')
        .doc(resultDate);
    final snapshot = await ref.get();
    if (snapshot.data()?['completed'] == true) {
      // ignore: avoid_print
      print('Today review already completed: date=$resultDate');
      return;
    }

    await ref.set({
      'date': resultDate,
      'completed': true,
      'score': score,
      'total': total,
      'wrong_words': wrongWords,
      'correct_words': correctWords,
      'completed_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // ignore: avoid_print
    print(
      'Today review completion saved: date=$resultDate score=$score/$total',
    );
  }

  static Future<Map<String, bool>> getWeeklyReviewCompletion() async {
    final uid = await AuthService.ensureAnonymousLogin();
    final now = nowInKst();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekEndExclusive = weekStart.add(const Duration(days: 7));
    final weekStartString = _dateString(weekStart);
    final weekEndString = _dateString(weekEnd);
    final weekDates = List.generate(
      7,
      (index) => _dateString(weekStart.add(Duration(days: index))),
    );
    final completedDates = <String>{};

    // ignore: avoid_print
    print('Weekly review week start: $weekStartString');
    // ignore: avoid_print
    print('Weekly review week end: $weekEndString');

    try {
      final collection = _firestore
          .collection('users')
          .doc(uid)
          .collection('review_results');

      void collectCompletedDates(QuerySnapshot<Map<String, dynamic>> snapshot) {
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final date = _reviewResultDate(doc.id, data);
          if (date == null || !weekDates.contains(date)) {
            continue;
          }
          if (_isCompletedReviewResult(data)) {
            completedDates.add(date);
          }
        }
      }

      final dateSnapshot = await collection
          .where('date', isGreaterThanOrEqualTo: weekStartString)
          .where('date', isLessThanOrEqualTo: weekEndString)
          .get();
      collectCompletedDates(dateSnapshot);

      final startTimestamp = Timestamp.fromDate(weekStart);
      final endTimestamp = Timestamp.fromDate(weekEndExclusive);
      final completedAtSnapshot = await collection
          .where('completed_at', isGreaterThanOrEqualTo: startTimestamp)
          .where('completed_at', isLessThan: endTimestamp)
          .get();
      collectCompletedDates(completedAtSnapshot);

      final createdAtSnapshot = await collection
          .where('created_at', isGreaterThanOrEqualTo: startTimestamp)
          .where('created_at', isLessThan: endTimestamp)
          .get();
      collectCompletedDates(createdAtSnapshot);

      final result = <String, bool>{
        'mon': completedDates.contains(weekDates[0]),
        'tue': completedDates.contains(weekDates[1]),
        'wed': completedDates.contains(weekDates[2]),
        'thu': completedDates.contains(weekDates[3]),
        'fri': completedDates.contains(weekDates[4]),
        'sat': completedDates.contains(weekDates[5]),
        'sun': completedDates.contains(weekDates[6]),
      };

      // ignore: avoid_print
      print('Review completed dates: ${completedDates.toList()..sort()}');
      // ignore: avoid_print
      print(
        'Weekly review completion: '
        'mon=${result['mon']}, tue=${result['tue']}, '
        'wed=${result['wed']}, thu=${result['thu']}, '
        'fri=${result['fri']}, sat=${result['sat']}, sun=${result['sun']}',
      );

      return result;
    } catch (error) {
      // ignore: avoid_print
      print('getWeeklyReviewCompletion failed: $error');
      return _emptyWeeklyReviewCompletion();
    }
  }

  static Future<bool> hasReviewResultForDate(String date) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('review_results')
        .doc(date)
        .get();
    return snapshot.data()?['completed'] == true;
  }

  static Future<bool> isTodayReviewCompleted({String? date}) {
    return hasReviewResultForDate(date ?? getCurrentLearningDateKst());
  }

  static Future<bool> trySaveReviewResult({
    required int score,
    required int total,
    required List<String> wrongWords,
    required List<String> correctWords,
    String? date,
  }) async {
    final resultDate = date ?? getCurrentLearningDateKst();
    if (await hasReviewResultForDate(resultDate)) {
      return false;
    }
    await saveReviewResult(
      score: score,
      total: total,
      wrongWords: wrongWords,
      correctWords: correctWords,
      date: resultDate,
    );
    return true;
  }

  static Map<String, dynamic> _withComputedScore(
    Map<String, dynamic> data,
    DateTime now,
  ) {
    final score = _reviewScore(data, now);
    return {...data, 'review_score': score};
  }

  static bool isReviewCandidate(Map<String, dynamic> data) {
    final word = _stringValue(data['word']);
    final meaning = _stringValue(data['meaning']);
    final learnedOrSaved =
        data['is_learned'] == true || data['is_saved'] == true;

    return data['review_excluded'] != true &&
        data['is_mastered'] != true &&
        learnedOrSaved &&
        word.isNotEmpty &&
        meaning.isNotEmpty;
  }

  static int _reviewScore(Map<String, dynamic> data, DateTime now) {
    var score =
        _intValue(data['wrong_count']) * 3 +
        _intValue(data['review_wrong_count']) * 4 +
        _intValue(data['saved_count']) * 2 +
        _intValue(data['learned_count']) -
        _intValue(data['correct_count']) -
        _intValue(data['review_correct_count']) -
        _intValue(data['review_level']);

    final nextReviewAt = data['next_review_at'];
    if (nextReviewAt is Timestamp && !nextReviewAt.toDate().isAfter(now)) {
      score += 10;
    }
    if (data['is_saved'] == true) {
      score += 3;
    }

    final lastReviewedAt = data['last_reviewed_at'];
    if (lastReviewedAt is! Timestamp) {
      score += 5;
    } else if (now.difference(lastReviewedAt.toDate()).inDays >= 7) {
      score += 4;
    }

    return score;
  }

  static int _daysForLevel(int level) {
    return switch (level) {
      <= 0 => 1,
      1 => 3,
      2 => 7,
      3 => 14,
      4 => 30,
      _ => 30,
    };
  }

  static Map<String, dynamic> _baseWordFields(Map<String, dynamic> data) {
    return {
      'word': _stringValue(data['word']),
      'meaning': _stringValue(data['meaning']),
      'description_ko': _stringValue(
        data['description_ko'] ?? data['description'],
      ),
      'example': _stringValue(data['example']),
      'example_ko': _stringValue(data['example_ko']),
      'category': _stringValue(data['category']),
      if (_stringValue(data['topic']).isNotEmpty)
        'topic': _stringValue(data['topic']),
      if (_stringValue(data['topic_label_ko']).isNotEmpty)
        'topic_label_ko': _stringValue(data['topic_label_ko']),
      if (_stringValue(data['level']).isNotEmpty)
        'level': _stringValue(data['level']),
    };
  }

  static String _dateString(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  static Map<String, bool> _emptyWeeklyReviewCompletion() {
    return const {
      'mon': false,
      'tue': false,
      'wed': false,
      'thu': false,
      'fri': false,
      'sat': false,
      'sun': false,
    };
  }

  static bool _isCompletedReviewResult(Map<String, dynamic> data) {
    if (data['completed'] == false) {
      return false;
    }
    return data['completed'] == true ||
        data['completed_at'] != null ||
        data['created_at'] != null;
  }

  static String? _reviewResultDate(String docId, Map<String, dynamic> data) {
    final date = _stringValue(data['date']);
    if (_isDateString(date)) {
      return date;
    }

    final completedAt = data['completed_at'];
    if (completedAt is Timestamp) {
      return getCurrentLearningDateKst(completedAt.toDate());
    }

    final createdAt = data['created_at'];
    if (createdAt is Timestamp) {
      return getCurrentLearningDateKst(createdAt.toDate());
    }

    final docDate = docId.length >= 10 ? docId.substring(0, 10) : '';
    if (_isDateString(docDate)) {
      return docDate;
    }

    return null;
  }

  static bool _isDateString(String value) {
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
  }

  static num _numValue(dynamic value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _intValue(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _stringValue(dynamic value) => value?.toString().trim() ?? '';
}
