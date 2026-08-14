import '../utils/learning_date.dart';
import 'daily_word_service.dart';
import 'user_preference_service.dart';

class IntegratedDailyLearningSet {
  const IntegratedDailyLearningSet({
    required this.date,
    required this.words,
    required this.categories,
    required this.requestedGoal,
    required this.actualWordCount,
  });

  final String date;
  final List<Map<String, dynamic>> words;
  final List<String> categories;
  final int requestedGoal;
  final int actualWordCount;
}

int getReviewCountForDailyGoal(int dailyWordGoal) {
  if (dailyWordGoal == 3) return 7;
  if (dailyWordGoal == 15) return 12;
  return 9;
}

Map<String, int> distributeDailyWords({
  required List<String> categories,
  required int dailyWordGoal,
}) {
  if (categories.isEmpty) return const {};
  final target = dailyWordGoal.clamp(0, categories.length * 3).toInt();
  final base = target ~/ categories.length;
  var remainder = target % categories.length;
  return {
    for (final category in categories)
      category: (base + (remainder-- > 0 ? 1 : 0)).clamp(0, 3).toInt(),
  };
}

class IntegratedDailyLearningService {
  IntegratedDailyLearningService({DailyWordService? dailyWordService})
    : _dailyWordService = dailyWordService ?? DailyWordService();

  final DailyWordService _dailyWordService;

  Future<IntegratedDailyLearningSet> load() async {
    final preferences = await UserPreferenceService.getLearningPreferences();
    final date = getCurrentLearningDateKst();
    final allocation = distributeDailyWords(
      categories: preferences.interestCategories,
      dailyWordGoal: preferences.dailyWordGoal,
    );
    final availableWords = <String, List<Map<String, dynamic>>>{};
    final merged = <Map<String, dynamic>>[];
    final loadedCategories = <String>[];

    for (final category in preferences.interestCategories) {
      final set = await _dailyWordService.getDailyWordSet(
        date: date,
        category: category,
      );
      final rawWords = set?['words'];
      availableWords[category] = rawWords is List
          ? rawWords
                .whereType<Map>()
                .take(3)
                .map((word) => Map<String, dynamic>.from(word))
                .toList()
          : const [];
    }

    final target = preferences.dailyWordGoal
        .clamp(0, preferences.interestCategories.length * 3)
        .toInt();
    // A category can be missing or contain fewer than its share. Give the
    // unused places to the next selected categories, never exceeding 3 each.
    final resolvedAllocation = <String, int>{
      for (final category in preferences.interestCategories)
        category: (allocation[category] ?? 0)
            .clamp(0, availableWords[category]?.length ?? 0)
            .toInt(),
    };
    var selectedCount = resolvedAllocation.values.fold(0, (a, b) => a + b);
    while (selectedCount < target) {
      var added = false;
      for (final category in preferences.interestCategories) {
        final current = resolvedAllocation[category] ?? 0;
        final available = availableWords[category]?.length ?? 0;
        if (current >= available || current >= 3) continue;
        resolvedAllocation[category] = current + 1;
        selectedCount++;
        added = true;
        if (selectedCount == target) break;
      }
      if (!added) break;
    }

    for (final category in preferences.interestCategories) {
      final requested = resolvedAllocation[category] ?? 0;
      final selected = (availableWords[category] ?? const [])
          .take(requested)
          .map(
            (word) => {
              ...Map<String, dynamic>.from(word),
              'category': category,
            },
          );
      if (selected.isNotEmpty) loadedCategories.add(category);
      merged.addAll(selected);
    }

    return IntegratedDailyLearningSet(
      date: date,
      words: merged,
      categories: loadedCategories,
      requestedGoal: preferences.dailyWordGoal,
      actualWordCount: merged.length,
    );
  }
}
