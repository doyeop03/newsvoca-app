import 'package:flutter/foundation.dart';

const Duration _kstOffset = Duration(hours: 9);
const int _learningDayStartHour = 6;

DateTime nowInKst([DateTime? now]) {
  final instant = now ?? DateTime.now();
  return instant.toUtc().add(_kstOffset);
}

String getCurrentLearningDateKst([DateTime? now]) {
  final nowKst = nowInKst(now);
  final learningDate = nowKst.hour < _learningDayStartHour
      ? nowKst.subtract(const Duration(days: 1))
      : nowKst;
  final targetDate = formatDate(learningDate);
  if (now == null && kDebugMode) {
    debugPrint(
      '[learning-date] nowKst=${formatDateTime(nowKst)} '
      'cutoff=06:00 targetDate=$targetDate',
    );
  }
  return targetDate;
}

DateTime nextPublishAtKst([DateTime? now]) {
  final nowKst = nowInKst(now);
  var next = DateTime.utc(
    nowKst.year,
    nowKst.month,
    nowKst.day,
    _learningDayStartHour,
  );
  if (!next.isAfter(nowKst)) next = next.add(const Duration(days: 1));
  return next;
}

Duration durationUntilNextPublishKst([DateTime? now]) {
  final nowKst = nowInKst(now);
  final delay = nextPublishAtKst(now).difference(nowKst);
  return delay > Duration.zero ? delay : const Duration(days: 1);
}

String formatDate(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
}

String formatDateTime(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  String threeDigits(int value) => value.toString().padLeft(3, '0');
  return '${formatDate(date)} '
      '${twoDigits(date.hour)}:${twoDigits(date.minute)}:'
      '${twoDigits(date.second)}.${threeDigits(date.millisecond)} KST';
}
