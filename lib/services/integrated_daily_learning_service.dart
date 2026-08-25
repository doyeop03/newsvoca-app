import '../utils/learning_date.dart';
import '../models/daily_issue_set.dart';
import 'daily_issue_service.dart';

class IntegratedDailyLearningSet {
  const IntegratedDailyLearningSet({
    required this.date,
    required this.words,
    required this.categories,
    required this.requestedGoal,
    required this.actualWordCount,
    this.dailyIssueSet,
  });

  final String date;
  final List<Map<String, dynamic>> words;
  final List<String> categories;
  final int requestedGoal;
  final int actualWordCount;
  final DailyIssueSet? dailyIssueSet;

  factory IntegratedDailyLearningSet.fromDailyIssue(DailyIssueSet issueSet) {
    final words = issueSet.learningWords;
    return IntegratedDailyLearningSet(
      date: issueSet.date,
      words: words,
      categories: const [],
      requestedGoal: words.length,
      actualWordCount: words.length,
      dailyIssueSet: issueSet,
    );
  }
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
  IntegratedDailyLearningService({DailyIssueService? dailyIssueService})
    : _dailyIssueService = dailyIssueService ?? DailyIssueService();

  final DailyIssueService _dailyIssueService;

  Future<IntegratedDailyLearningSet> load() async {
    final date = getCurrentLearningDateKst();
    final issueSet = await _dailyIssueService.load(date: date);
    if (issueSet != null) {
      return IntegratedDailyLearningSet.fromDailyIssue(issueSet);
    }

    return IntegratedDailyLearningSet(
      date: date,
      words: const [],
      categories: const [],
      requestedGoal: 0,
      actualWordCount: 0,
    );
  }
}
