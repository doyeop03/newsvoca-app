import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import '../utils/learning_date.dart';

class DailyLearningSummary {
  const DailyLearningSummary({
    required this.date,
    required this.completedCategories,
    required this.learnedWordCount,
    required this.reviewScore,
    required this.reviewTotal,
    required this.reviewAccuracyValue,
    required this.hasReview,
    required this.hasDailyQuiz,
    required this.dailyQuizScore,
    required this.dailyQuizTotal,
    required this.dailyQuizAccuracyValue,
    required this.hasArticleLearning,
  });

  final String date;
  final List<String> completedCategories;
  final int learnedWordCount;
  final int reviewScore;
  final int reviewTotal;
  final int? reviewAccuracyValue;
  final bool hasReview;
  final bool hasDailyQuiz;
  final int dailyQuizScore;
  final int dailyQuizTotal;
  final int? dailyQuizAccuracyValue;
  final bool hasArticleLearning;

  int? get reviewAccuracy {
    if (!hasReview) {
      return null;
    }
    if (reviewAccuracyValue != null) return reviewAccuracyValue;
    if (reviewTotal <= 0) return null;
    return ((reviewScore / reviewTotal) * 100).round();
  }

  int? get dailyQuizAccuracy {
    if (!hasDailyQuiz) return null;
    if (dailyQuizAccuracyValue != null) return dailyQuizAccuracyValue;
    if (dailyQuizTotal <= 0) return null;
    return ((dailyQuizScore / dailyQuizTotal) * 100).round();
  }

  bool get hasAnyLearning => hasDailyQuiz || hasReview || hasArticleLearning;

  bool get hasCompletedLearning => hasAnyLearning;
}

class CalendarLearningService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const List<String> categories = [
    'economy',
    'technology',
    'politics',
    'world',
    'society',
  ];

  static const Map<String, String> categoryLabels = {
    'economy': '경제',
    'technology': '기술',
    'politics': '정치',
    'world': '국제',
    'society': '사회',
  };

  static Future<Set<String>> getMonthlyLearningDates(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return _getLearningDatesBetween(start, end);
  }

  static Future<int> getMonthlyStudyDayCount(int year, int month) async {
    final dates = await getMonthlyLearningDates(year, month);
    return dates.length;
  }

  static Future<int> getDailyLearnedWordCount(String uid, String date) async {
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results');
    final daily = await collection.doc('${date}_daily').get();
    if (daily.data()?['completed'] == true) {
      return (daily.data()?['word_count'] as num?)?.toInt() ?? 0;
    }
    var completedCategoryCount = 0;
    for (final category in categories) {
      final snapshot = await collection.doc('${date}_$category').get();
      if (snapshot.data()?['completed'] == true) {
        completedCategoryCount++;
      }
    }
    return completedCategoryCount * 5;
  }

  static Future<int> getCurrentStreak({required String today}) async {
    final streakDates = await getCurrentStreakLearningDates(today: today);
    return streakDates.length;
  }

  static Future<List<String>> getCurrentStreakLearningDates({
    required String today,
  }) async {
    final todayDate = _dateFromString(today);
    final start = todayDate.subtract(const Duration(days: 370));
    final end = todayDate.add(const Duration(days: 1));
    final dates = await _getLearningDatesBetween(start, end);

    var cursor = dates.contains(_dateString(todayDate))
        ? todayDate
        : todayDate.subtract(const Duration(days: 1));
    final streakDates = <String>[];

    while (dates.contains(_dateString(cursor))) {
      streakDates.add(_dateString(cursor));
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streakDates;
  }

  static Future<DailyLearningSummary> getDailyLearningSummary(
    String date,
  ) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final completedQuizCategories = <String>{};

    final quizCollection = _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results');
    final dailyQuiz = await quizCollection.doc('${date}_daily').get();
    final dailyData = dailyQuiz.data();
    final hasDailyQuiz = _isCompletedQuiz(dailyData);
    var integratedWordCount = 0;
    var dailyQuizScore = 0;
    var dailyQuizTotal = 0;
    int? dailyQuizAccuracy;
    if (hasDailyQuiz) {
      integratedWordCount = (dailyData?['word_count'] as num?)?.toInt() ?? 0;
      dailyQuizScore = _intValue(dailyData?['score']);
      dailyQuizTotal = _intValue(dailyData?['total']);
      if (dailyData?['accuracy'] != null) {
        dailyQuizAccuracy = _intValue(dailyData?['accuracy']);
      }
      final values = dailyData?['categories'];
      if (values is List) {
        completedQuizCategories.addAll(
          values.map((value) => value.toString()).where(categories.contains),
        );
      }
    } else {
      for (final category in categories) {
        final snapshot = await quizCollection.doc('${date}_$category').get();
        final legacyData = snapshot.data();
        if (_isCompletedQuiz(legacyData)) {
          completedQuizCategories.add(category);
          dailyQuizScore += _intValue(legacyData?['score']);
          dailyQuizTotal += _intValue(legacyData?['total']);
        }
      }
    }

    final review = await _reviewSummary(uid, date);
    final learnedWordCount = hasDailyQuiz
        ? integratedWordCount
        : completedQuizCategories.length * 5;
    final articleCompletedCount = await _articleCompletedCount(uid, date);
    final hasArticleLearning = articleCompletedCount > 0;

    final summary = DailyLearningSummary(
      date: date,
      completedCategories: categories
          .where(completedQuizCategories.contains)
          .toList(growable: false),
      learnedWordCount: learnedWordCount,
      reviewScore: review.score,
      reviewTotal: review.total,
      reviewAccuracyValue: review.accuracy,
      hasReview: review.hasReview,
      hasDailyQuiz: hasDailyQuiz || completedQuizCategories.isNotEmpty,
      dailyQuizScore: dailyQuizScore,
      dailyQuizTotal: dailyQuizTotal,
      dailyQuizAccuracyValue: dailyQuizAccuracy,
      hasArticleLearning: hasArticleLearning,
    );
    // ignore: avoid_print
    print('[calendar] checking date=$date');
    // ignore: avoid_print
    print('[calendar] quiz completed count=${completedQuizCategories.length}');
    // ignore: avoid_print
    print('[calendar] review completed=${review.hasReview}');
    // ignore: avoid_print
    print('[calendar] article completed count=$articleCompletedCount');
    // ignore: avoid_print
    print('[calendar] hasAnyCompletedLearning=${summary.hasCompletedLearning}');
    return summary;
  }

  static Future<Set<String>> _getLearningDatesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final dates = <String>{};
    final startString = _dateString(start);
    final endInclusiveString = _dateString(
      end.subtract(const Duration(days: 1)),
    );
    final startTimestamp = Timestamp.fromDate(_learningDayStartUtc(start));
    final endTimestamp = Timestamp.fromDate(_learningDayStartUtc(end));

    await _collectQuizDates(uid, startString, endInclusiveString, dates);
    await _collectReviewDates(uid, startString, endInclusiveString, dates);
    await _collectArticleDates(uid, startTimestamp, endTimestamp, dates);

    return dates;
  }

  static Future<void> _collectQuizDates(
    String uid,
    String start,
    String end,
    Set<String> dates,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results')
        .where('completed', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final date = _resultDate(doc.id, data);
      if (date != null &&
          date.compareTo(start) >= 0 &&
          date.compareTo(end) <= 0) {
        dates.add(date);
      }
    }
  }

  static Future<void> _collectReviewDates(
    String uid,
    String start,
    String end,
    Set<String> dates,
  ) async {
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection('review_results');
    final snapshot = await collection.where('completed', isEqualTo: true).get();
    for (final doc in snapshot.docs) {
      final docDate = doc.id.length >= 10 ? doc.id.substring(0, 10) : '';
      if (_isDateString(docDate) &&
          docDate.compareTo(start) >= 0 &&
          docDate.compareTo(end) <= 0) {
        dates.add(docDate);
      }
    }
  }

  static Future<void> _collectArticleDates(
    String uid,
    Timestamp start,
    Timestamp end,
    Set<String> dates,
  ) async {
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection('article_learning_results');

    final snapshot = await collection
        .where('completed_at', isGreaterThanOrEqualTo: start)
        .where('completed_at', isLessThan: end)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final completedAt = data['completed_at'];
      if (data['completed'] == true && completedAt is Timestamp) {
        dates.add(getCurrentLearningDateKst(completedAt.toDate()));
      }
    }
  }

  static Future<_ReviewSummary> _reviewSummary(String uid, String date) async {
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection('review_results');
    final doc = await collection.doc(date).get();
    if (doc.exists && doc.data()?['completed'] == true) {
      final data = doc.data() ?? const <String, dynamic>{};
      return _ReviewSummary(
        hasReview: true,
        score: _intValue(data['score']),
        total: _intValue(data['total']),
        accuracy: data['accuracy'] == null ? null : _intValue(data['accuracy']),
      );
    }

    return const _ReviewSummary(
      hasReview: false,
      score: 0,
      total: 0,
      accuracy: null,
    );
  }

  static Future<int> _articleCompletedCount(String uid, String date) async {
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection('article_learning_results');

    final selected = _dateFromString(date);
    final start = Timestamp.fromDate(_learningDayStartUtc(selected));
    final end = Timestamp.fromDate(
      _learningDayStartUtc(selected.add(const Duration(days: 1))),
    );
    final snapshot = await collection
        .where('completed_at', isGreaterThanOrEqualTo: start)
        .where('completed_at', isLessThan: end)
        .get();
    return snapshot.docs.where((doc) => doc.data()['completed'] == true).length;
  }

  static bool _isCompletedQuiz(Map<String, dynamic>? data) {
    return data?['completed'] == true;
  }

  static String? _resultDate(String docId, Map<String, dynamic> data) {
    final docDate = docId.length >= 10 ? docId.substring(0, 10) : '';
    if (_isDateString(docDate)) {
      return docDate;
    }
    final date = _stringValue(data['date']);
    if (_isDateString(date)) {
      return date;
    }
    final completedAt = data['completed_at'];
    if (completedAt is Timestamp) {
      return getCurrentLearningDateKst(completedAt.toDate());
    }
    return null;
  }

  static DateTime _dateFromString(String date) {
    final parts = date.split('-').map(int.tryParse).toList(growable: false);
    if (parts.length != 3 ||
        parts[0] == null ||
        parts[1] == null ||
        parts[2] == null) {
      return DateTime.now();
    }
    return DateTime(parts[0]!, parts[1]!, parts[2]!);
  }

  static DateTime _learningDayStartUtc(DateTime kstDate) {
    return DateTime.utc(kstDate.year, kstDate.month, kstDate.day - 1, 21);
  }

  static String _dateString(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  static bool _isDateString(String value) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);

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

class _ReviewSummary {
  const _ReviewSummary({
    required this.hasReview,
    required this.score,
    required this.total,
    required this.accuracy,
  });

  final bool hasReview;
  final int score;
  final int total;
  final int? accuracy;
}
