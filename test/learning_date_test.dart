import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/utils/learning_date.dart';

void main() {
  test('06:00 이후에는 다음 날 06:00까지 남은 시간을 계산한다', () {
    final nowUtc = DateTime.utc(2026, 7, 16, 13, 20, 35);

    expect(
      durationUntilNextPublishKst(nowUtc),
      const Duration(hours: 7, minutes: 39, seconds: 25),
    );
  });

  test('06:00 이전에는 같은 날 06:00까지 남은 시간을 계산한다', () {
    final nowUtc = DateTime.utc(2026, 7, 15, 20, 59);

    expect(durationUntilNextPublishKst(nowUtc), const Duration(minutes: 1));
  });

  test('KST 06:00을 기준으로 학습 날짜가 전환된다', () {
    expect(
      getCurrentLearningDateKst(DateTime.utc(2026, 7, 15, 20, 59)),
      '2026-07-15',
    );
    expect(
      getCurrentLearningDateKst(DateTime.utc(2026, 7, 15, 21)),
      '2026-07-16',
    );
  });
}
