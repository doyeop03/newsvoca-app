import 'package:shared_preferences/shared_preferences.dart';

class DailyLearningGuideService {
  static const hiddenPreferenceKey = 'daily_learning_guide_hidden';

  static Future<bool> shouldShow() async {
    final preferences = await SharedPreferences.getInstance();
    return !(preferences.getBool(hiddenPreferenceKey) ?? false);
  }

  static Future<void> hidePermanently() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(hiddenPreferenceKey, true);
  }
}
