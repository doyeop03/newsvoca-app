import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/services/user_word_service.dart';

void main() {
  test('flow_completed true is the primary completion signal', () {
    expect(
      isDailyLearningFlowCompletedData({
        'completed': true,
        'flow_completed': true,
        'review_completed': true,
      }, null),
      isTrue,
    );
  });

  test('daily quiz alone does not complete the learning flow', () {
    expect(
      isDailyLearningFlowCompletedData(
        {'completed': true, 'flow_completed': false},
        {'completed': true},
      ),
      isFalse,
    );
  });

  test('review alone does not complete the learning flow', () {
    expect(
      isDailyLearningFlowCompletedData(null, {'completed': true}),
      isFalse,
    );
  });

  test('legacy results require both daily quiz and review completion', () {
    expect(
      isDailyLearningFlowCompletedData(
        {'completed': true},
        {'completed': true},
      ),
      isTrue,
    );
    expect(
      isDailyLearningFlowCompletedData(
        {'completed': true},
        {'completed': false},
      ),
      isFalse,
    );
  });

  test('a valid no-review flow is completed only by flow_completed', () {
    expect(
      isDailyLearningFlowCompletedData({
        'completed': true,
        'review_skipped': true,
        'flow_completed': true,
      }, null),
      isTrue,
    );
  });
}
