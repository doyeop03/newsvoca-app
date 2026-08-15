import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

int getMaxAvailableWords(int selectedCategoryCount) {
  return selectedCategoryCount < 0 ? 0 : selectedCategoryCount * 3;
}

List<int> getAvailableDailyWordGoals(int selectedCategoryCount) {
  final max = getMaxAvailableWords(selectedCategoryCount);
  return UserPreferenceService.dailyWordGoalOptions
      .where((goal) => goal <= max)
      .toList(growable: false);
}

int normalizeDailyWordGoal({
  required int currentGoal,
  required int selectedCategoryCount,
}) {
  final available = getAvailableDailyWordGoals(selectedCategoryCount);
  if (available.isEmpty) {
    return UserPreferenceService.dailyWordGoalOptions.first;
  }
  if (available.contains(currentGoal)) {
    return currentGoal;
  }
  return available.last;
}

class UserLearningPreferences {
  const UserLearningPreferences({
    required this.interestCategories,
    required this.dailyWordGoal,
  });

  final List<String> interestCategories;
  final int dailyWordGoal;
}

class UserPreferenceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const List<String> defaultInterestCategories = [
    'economy',
    'technology',
    'politics',
    'world',
    'society',
  ];
  static const int defaultDailyWordGoal = 9;
  static const List<int> dailyWordGoalOptions = [3, 9, 15];

  static Future<UserLearningPreferences> getLearningPreferences() async {
    final uid = await AuthService.ensureAnonymousLogin();
    final ref = _firestore.collection('users').doc(uid);
    final snapshot = await ref.get();
    final data = snapshot.data();
    final categories = data?['interest_categories'] is List
        ? _sanitizeCategories(data!['interest_categories'] as List)
        : <String>[];
    final resolvedCategories = categories.isEmpty
        ? defaultInterestCategories
        : categories;
    final goal = normalizeDailyWordGoal(
      currentGoal: sanitizeDailyWordGoal(data?['daily_word_goal']),
      selectedCategoryCount: resolvedCategories.length,
    );

    if (categories.isEmpty || data?['daily_word_goal'] != goal) {
      await ref.set({
        'interest_categories': resolvedCategories,
        'daily_word_goal': goal,
        'updated_at': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return UserLearningPreferences(
      interestCategories: resolvedCategories,
      dailyWordGoal: goal,
    );
  }

  static int sanitizeDailyWordGoal(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return dailyWordGoalOptions.contains(parsed)
        ? parsed!
        : defaultDailyWordGoal;
  }

  static Future<List<String>> getInterestCategories() async {
    return (await getLearningPreferences()).interestCategories;
  }

  static Future<void> updateLearningPreferences({
    required List<String> categories,
    required int dailyWordGoal,
  }) async {
    final uid = await AuthService.ensureAnonymousLogin();
    await updateLearningPreferencesForUser(
      userId: uid,
      categories: categories,
      dailyWordGoal: dailyWordGoal,
    );
  }

  static Future<void> updateLearningPreferencesForUser({
    required String userId,
    required List<String> categories,
    required int dailyWordGoal,
  }) async {
    final sanitized = _sanitizeCategories(categories);
    if (sanitized.isEmpty) {
      throw StateError('At least one interest category is required.');
    }
    final normalizedGoal = normalizeDailyWordGoal(
      currentGoal: sanitizeDailyWordGoal(dailyWordGoal),
      selectedCategoryCount: sanitized.length,
    );
    await _firestore.collection('users').doc(userId).set({
      'interest_categories': sanitized,
      'daily_word_goal': normalizedGoal,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateInterestCategories(List<String> categories) async {
    final sanitized = _sanitizeCategories(categories);
    if (sanitized.isEmpty) {
      throw StateError('At least one interest category is required.');
    }

    final current = await getLearningPreferences();
    await updateLearningPreferences(
      categories: sanitized,
      dailyWordGoal: current.dailyWordGoal,
    );

    // ignore: avoid_print
    print('Interest categories saved: $sanitized');
  }

  static Future<List<String>> toggleInterestCategory(String categoryId) async {
    final categories = await getInterestCategories();
    final next = [...categories];

    if (next.contains(categoryId)) {
      if (next.length == 1) {
        throw StateError('At least one interest category is required.');
      }
      next.remove(categoryId);
    } else if (_validCategoryIds.contains(categoryId)) {
      next.add(categoryId);
    }

    await updateInterestCategories(next);
    // ignore: avoid_print
    print('Interest category toggled: $categoryId');
    return next;
  }

  static Set<String> get _validCategoryIds => defaultInterestCategories.toSet();

  static List<String> _sanitizeCategories(Iterable<dynamic> categories) {
    final validIds = _validCategoryIds;
    final result = <String>[];
    for (final category in categories) {
      final id = category.toString();
      if (validIds.contains(id) && !result.contains(id)) {
        result.add(id);
      }
    }
    return result;
  }
}
