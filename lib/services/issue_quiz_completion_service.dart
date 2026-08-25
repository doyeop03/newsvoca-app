import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IssueQuizCompletionService {
  static const keyPrefix = 'issue_quiz_completed_';

  static String keyFor({
    required String learningDate,
    required String issueIdentity,
  }) => '$keyPrefix${learningDate}_$issueIdentity';

  static Future<bool> isCompleted({
    required String learningDate,
    required String issueIdentity,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getBool(
            keyFor(learningDate: learningDate, issueIdentity: issueIdentity),
          ) ??
          false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[IssueQuizCompletion] read failed: $error');
      }
      return false;
    }
  }

  static Future<void> markCompleted({
    required String learningDate,
    required String issueIdentity,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(
        keyFor(learningDate: learningDate, issueIdentity: issueIdentity),
        true,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[IssueQuizCompletion] write failed: $error');
      }
    }
  }
}
