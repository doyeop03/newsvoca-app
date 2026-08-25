import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import '../utils/learning_date.dart';

bool isDailyLearningFlowCompletedData(
  Map<String, dynamic>? dailyResult,
  Map<String, dynamic>? reviewResult,
) {
  if (dailyResult == null) return false;
  if (dailyResult.containsKey('flow_completed')) {
    return dailyResult['flow_completed'] == true;
  }
  return dailyResult['completed'] == true && reviewResult?['completed'] == true;
}

class UserWordService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> markWordLearned(
    Map<String, dynamic> wordData,
    String category,
  ) async {
    final word = _stringValue(wordData['word']);
    if (word.isEmpty) {
      return;
    }

    final ref = await _wordRef(word);
    final snapshot = await ref.get();
    final data = snapshot.data();
    final now = FieldValue.serverTimestamp();
    final nextReviewAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 3)),
    );

    await ref.set({
      ..._baseWordFields(wordData, category),
      ..._missingDefaultWordFields(data),
      'is_learned': true,
      'learned_count': FieldValue.increment(1),
      if (data?['first_learned_at'] == null) 'first_learned_at': now,
      'last_learned_at': now,
      'last_seen_at': now,
      if (data?['next_review_at'] == null) 'next_review_at': nextReviewAt,
      'updated_at': now,
      if (!snapshot.exists) 'created_at': now,
    }, SetOptions(merge: true));

    // ignore: avoid_print
    print('markWordLearned: $word');
  }

  static Future<void> completeDailyWordsAfterQuiz({
    required String date,
    required Iterable<Map<String, dynamic>> words,
  }) async {
    for (final wordData in words) {
      final word = _stringValue(wordData['word']);
      if (word.isEmpty) continue;
      final category = _stringValue(wordData['category']);
      final ref = await _wordRef(word);
      final snapshot = await ref.get();
      final data = snapshot.data();
      if (data?['last_completed_learning_date'] == date) {
        continue;
      }
      final now = FieldValue.serverTimestamp();
      await ref.set({
        ..._baseWordFields(wordData, category),
        ..._missingDefaultWordFields(data),
        'is_learned': true,
        'learned_count': FieldValue.increment(1),
        'last_completed_learning_date': date,
        if (data?['first_learned_at'] == null) 'first_learned_at': now,
        'last_learned_at': now,
        'last_seen_at': now,
        if (data?['next_review_at'] == null)
          'next_review_at': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 3)),
          ),
        'updated_at': now,
        if (!snapshot.exists) 'created_at': now,
      }, SetOptions(merge: true));
    }
    // ignore: avoid_print
    print('[learning] completed words after quiz date=$date');
  }

  static Future<void> saveWord(
    Map<String, dynamic> wordData,
    String category,
  ) async {
    final word = _stringValue(wordData['word']);
    if (word.isEmpty) {
      return;
    }

    final ref = await _wordRef(word);
    final snapshot = await ref.get();
    final data = snapshot.data();
    final alreadySaved = data?['is_saved'] == true;
    final now = FieldValue.serverTimestamp();
    final nextReviewAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 1)),
    );

    await ref.set({
      ..._baseWordFields(wordData, category),
      ..._missingDefaultWordFields(data),
      'is_saved': true,
      if (!alreadySaved) 'saved_count': FieldValue.increment(1),
      'last_saved_at': now,
      'last_seen_at': now,
      if (!alreadySaved) 'next_review_at': nextReviewAt,
      'updated_at': now,
      if (!snapshot.exists) 'created_at': now,
    }, SetOptions(merge: true));

    // ignore: avoid_print
    print('saveWord: $word');
  }

  static Future<void> updateQuizResultForWord(
    Map<String, dynamic> wordData,
    String category,
    bool isCorrect,
  ) async {
    final word = _stringValue(wordData['word']);
    if (word.isEmpty) {
      return;
    }

    final ref = await _wordRef(word);
    final snapshot = await ref.get();
    final data = snapshot.data();
    final now = FieldValue.serverTimestamp();
    final nextReviewAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 1)),
    );

    await ref.set({
      ..._baseWordFields(wordData, category),
      ..._missingDefaultWordFields(data),
      if (isCorrect)
        'correct_count': FieldValue.increment(1)
      else
        'wrong_count': FieldValue.increment(1),
      'last_quizzed_at': now,
      'last_seen_at': now,
      if (!isCorrect) 'next_review_at': nextReviewAt,
      'updated_at': now,
      if (!snapshot.exists) 'created_at': now,
    }, SetOptions(merge: true));

    // ignore: avoid_print
    print('updateQuizResultForWord: $word isCorrect=$isCorrect');
  }

  static Future<void> updateDailyQuizResultForWord(
    Map<String, dynamic> wordData,
    String category,
    bool isCorrect,
  ) {
    return updateQuizResultForWord(wordData, category, isCorrect);
  }

  static Future<List<Map<String, dynamic>>> getReviewWords() async {
    final uid = await AuthService.ensureAnonymousLogin();
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('user_words')
        .get();

    final words =
        snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .where(
              (data) => data['is_learned'] == true || data['is_saved'] == true,
            )
            .toList()
          ..sort(_compareReviewPriority);

    // ignore: avoid_print
    print('getReviewWords count=${words.length}');
    return words;
  }

  static Future<void> saveQuizResult({
    required String date,
    required String category,
    required int score,
    required int total,
    required List<String> wrongWords,
    List<String> categories = const [],
    int? wordCount,
    int? dailyWordGoal,
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final now = FieldValue.serverTimestamp();
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results')
        .doc('${date}_$category');
    final snapshot = await ref.get();

    await ref.set({
      'date': date,
      'category': category,
      if (category == 'daily') 'type': 'daily',
      if (category == 'daily') 'categories': categories,
      if (category == 'daily') 'word_count': wordCount ?? 0,
      if (category == 'daily')
        'daily_word_goal': dailyWordGoal ?? wordCount ?? 0,
      if (category == 'daily') ...{
        'flow_completed': false,
        'review_required': null,
        'review_completed': false,
        'review_skipped': false,
      },
      'completed': true,
      'score': score,
      'total': total,
      'accuracy': total <= 0 ? 0 : ((score / total) * 100).round(),
      'wrong_words': wrongWords,
      'completed_at': now,
      'updated_at': now,
      if (!snapshot.exists) 'created_at': now,
    }, SetOptions(merge: true));

    // ignore: avoid_print
    print('saveQuizResult: ${date}_$category score=$score/$total');
  }

  static Future<bool> hasDailyQuizResult(String date) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results')
        .doc('${date}_daily')
        .get();
    final data = snapshot.data();
    if (data == null) return false;
    if (data.containsKey('flow_completed')) {
      return data['flow_completed'] == true;
    }
    return data['completed'] == true;
  }

  static Future<Map<String, bool>> getWeeklyLearningCompletion() async {
    final uid = await AuthService.ensureAnonymousLogin();
    final now = nowInKst();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final weekDates = List.generate(
      7,
      (index) => formatDate(weekStart.add(Duration(days: index))),
    );
    final userRef = _firestore.collection('users').doc(uid);
    final dailySnapshots = await Future.wait(
      weekDates.map(
        (date) => userRef.collection('quiz_results').doc('${date}_daily').get(),
      ),
    );

    final legacyReviewData = <String, Map<String, dynamic>?>{};
    final legacyDates = <String>[];
    for (var index = 0; index < dailySnapshots.length; index++) {
      final data = dailySnapshots[index].data();
      if (data != null && !data.containsKey('flow_completed')) {
        legacyDates.add(weekDates[index]);
      }
    }
    final reviewSnapshots = await Future.wait(
      legacyDates.map(
        (date) => userRef.collection('review_results').doc(date).get(),
      ),
    );
    for (var index = 0; index < legacyDates.length; index++) {
      legacyReviewData[legacyDates[index]] = reviewSnapshots[index].data();
    }

    const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return {
      for (var index = 0; index < weekDates.length; index++)
        dayKeys[index]: isDailyLearningFlowCompletedData(
          dailySnapshots[index].data(),
          legacyReviewData[weekDates[index]],
        ),
    };
  }

  static Future<void> completeDailyLearningFlow({
    required String date,
    required bool reviewRequired,
    required bool reviewCompleted,
    required bool reviewSkipped,
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results')
        .doc('${date}_daily')
        .set({
          'flow_completed': true,
          'review_required': reviewRequired,
          'review_completed': reviewCompleted,
          'review_skipped': reviewSkipped,
          'flow_completed_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  static Future<Set<String>> getCompletedQuizCategories({
    required String date,
    required Iterable<String> categories,
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final collection = _firestore
        .collection('users')
        .doc(uid)
        .collection('quiz_results');
    final categoryList = categories.toSet().toList(growable: false);
    final snapshots = await Future.wait(
      categoryList.map((category) => collection.doc('${date}_$category').get()),
    );

    return {
      for (var index = 0; index < snapshots.length; index++)
        if (snapshots[index].data()?['completed'] == true) categoryList[index],
    };
  }

  static Future<Set<String>> getCompletedArticleIds() async {
    final uid = await AuthService.ensureAnonymousLogin();
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('article_learning_results')
        .where('completed', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  static Future<bool> isArticleCompleted(Map<String, dynamic> article) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('article_learning_results')
        .doc(articleIdForArticle(article))
        .get();
    return snapshot.data()?['completed'] == true;
  }

  static Future<void> saveArticleLearningResult({
    required Map<String, dynamic> article,
    required int score,
    required int total,
    List<Map<String, dynamic>> learnedItems = const [],
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    final title = _stringValue(article['title']);
    final url = _stringValue(article['url']);
    final source = _stringValue(article['source']);
    final focusWord = _stringValue(article['focus_word']);
    final learningWord = _stringValue(article['_learning_word']);
    final now = FieldValue.serverTimestamp();
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('article_learning_results')
        .doc(articleIdForArticle(article));
    final snapshot = await ref.get();

    await ref.set({
      'completed': true,
      'date': getCurrentLearningDateKst(),
      'title': title,
      'url': url,
      'source': source,
      'focus_word': focusWord,
      'learning_word': learningWord,
      'score': score,
      'total': total,
      if (learnedItems.isNotEmpty) 'learned_items': learnedItems,
      'completed_at': now,
      'updated_at': now,
      if (!snapshot.exists) 'created_at': now,
    }, SetOptions(merge: true));

    // ignore: avoid_print
    print('saveArticleLearningResult: $title score=$score/$total');
  }

  static Future<DocumentReference<Map<String, dynamic>>> _wordRef(
    String word,
  ) async {
    final uid = await AuthService.ensureAnonymousLogin();
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('user_words')
        .doc(wordIdFor(word));
  }

  static String wordIdFor(String word) {
    final normalized = word
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s_-]'), '')
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'unknown_word' : normalized;
  }

  static String articleIdFor(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s_-]'), ' ')
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final source = value.trim();
    var hash = 0;
    for (final unit in source.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final base = normalized.isEmpty ? 'article' : normalized;
    final clipped = base.length > 90 ? base.substring(0, 90) : base;
    return '${clipped}_$hash';
  }

  static String articleIdForArticle(Map<String, dynamic> article) {
    final url = _stringValue(article['url']);
    final title = _stringValue(article['title']);
    final focusWord = _stringValue(article['focus_word']);
    final learningWord = _stringValue(article['_learning_word']);
    final articleIdentity = url.isNotEmpty ? url : title;
    return articleIdFor(
      '$articleIdentity|learning:$learningWord|focus:$focusWord',
    );
  }

  static Map<String, dynamic> _baseWordFields(
    Map<String, dynamic> wordData,
    String category,
  ) {
    return {
      'word': _stringValue(wordData['word']),
      'meaning': _stringValue(wordData['meaning']),
      'description_ko': _stringValue(
        wordData['description_ko'] ?? wordData['description'],
      ),
      'example': _stringValue(wordData['example']),
      'example_ko': _stringValue(wordData['example_ko']),
      'category': _stringValue(wordData['category']).isNotEmpty
          ? _stringValue(wordData['category'])
          : category,
      if (_stringValue(wordData['topic']).isNotEmpty)
        'topic': _stringValue(wordData['topic']),
      if (_stringValue(wordData['topic_label_ko']).isNotEmpty)
        'topic_label_ko': _stringValue(wordData['topic_label_ko']),
      if (_stringValue(wordData['level']).isNotEmpty)
        'level': _stringValue(wordData['level']),
      if (_stringValue(wordData['part_of_speech']).isNotEmpty)
        'part_of_speech': _stringValue(wordData['part_of_speech']),
      if (_stringValue(wordData['source_issue_id']).isNotEmpty)
        'source_issue_id': _stringValue(wordData['source_issue_id']),
      if (_stringValue(wordData['source_article_url']).isNotEmpty)
        'source_article_url': _stringValue(wordData['source_article_url']),
      if (_stringValue(wordData['learned_date']).isNotEmpty)
        'learned_date': _stringValue(wordData['learned_date']),
    };
  }

  static Map<String, dynamic> _missingDefaultWordFields(
    Map<String, dynamic>? data,
  ) {
    final defaults = {
      'is_learned': false,
      'is_saved': false,
      'is_mastered': false,
      'learned_count': 0,
      'saved_count': 0,
      'wrong_count': 0,
      'correct_count': 0,
      'review_wrong_count': 0,
      'review_correct_count': 0,
      'consecutive_correct_count': 0,
      'review_level': 0,
      'review_score': 0,
      'next_review_at': null,
      'first_learned_at': null,
      'last_learned_at': null,
      'last_saved_at': null,
      'last_quizzed_at': null,
      'last_reviewed_at': null,
      'last_seen_at': null,
      'mastered_at': null,
    };
    if (data == null) {
      return defaults;
    }

    return {
      for (final entry in defaults.entries)
        if (!data.containsKey(entry.key)) entry.key: entry.value,
    };
  }

  static int _compareReviewPriority(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final scoreComparison = _reviewScore(right).compareTo(_reviewScore(left));
    if (scoreComparison != 0) {
      return scoreComparison;
    }

    final leftTime = left['last_quizzed_at'];
    final rightTime = right['last_quizzed_at'];
    if (leftTime is Timestamp && rightTime is Timestamp) {
      return leftTime.compareTo(rightTime);
    }
    if (leftTime is Timestamp) {
      return 1;
    }
    if (rightTime is Timestamp) {
      return -1;
    }
    return 0;
  }

  static int _reviewScore(Map<String, dynamic> data) {
    return _intValue(data['wrong_count']) * 3 +
        _intValue(data['saved_count']) * 2 +
        _intValue(data['learned_count']) -
        _intValue(data['correct_count']);
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
