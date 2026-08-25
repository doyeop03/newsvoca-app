import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNoticeType { info, warning, error }

enum DailyIssueAvailability { unknown, ready, missing, failed, notReady }

class AppNotice {
  const AppNotice({
    required this.enabled,
    required this.title,
    required this.message,
    required this.type,
    this.startAt,
    this.endAt,
    this.updatedAt,
    this.isAutomatic = false,
  });

  final bool enabled;
  final String title;
  final String message;
  final AppNoticeType type;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? updatedAt;
  final bool isAutomatic;

  bool get isRenderable => title.trim().isNotEmpty && message.trim().isNotEmpty;

  bool isActiveAt(DateTime now) {
    if (!enabled || !isRenderable) return false;
    final instant = now.toUtc();
    if (startAt != null && instant.isBefore(startAt!.toUtc())) return false;
    if (endAt != null && instant.isAfter(endAt!.toUtc())) return false;
    return true;
  }

  factory AppNotice.fromMap(Map<String, dynamic> map) {
    return AppNotice(
      enabled: map['enabled'] == true,
      title: _noticeText(map['title']),
      message: _noticeText(map['message']),
      type: _noticeType(map['type']),
      startAt: _noticeDate(map['start_at']),
      endAt: _noticeDate(map['end_at']),
      updatedAt: _noticeDate(map['updated_at']),
    );
  }

  factory AppNotice.dailyIssueDelay() => const AppNotice(
    enabled: true,
    title: '\uC624\uB298\uC758 \uCF58\uD150\uCE20\uB97C \uC900\uBE44 \uC911\uC785\uB2C8\uB2E4',
    message: '\uC624\uB298\uC758 \uB274\uC2A4 \uD559\uC2B5 \uCF58\uD150\uCE20 \uC81C\uACF5\uC774 \uC9C0\uC5F0\uB418\uACE0 \uC788\uC2B5\uB2C8\uB2E4. \uC7A0\uC2DC \uD6C4 \uB2E4\uC2DC \uD655\uC778\uD574 \uC8FC\uC138\uC694.',
    type: AppNoticeType.warning,
    isAutomatic: true,
  );
}

AppNotice? resolveHomeNotice({
  required AppNotice? manualNotice,
  required DailyIssueAvailability dailyIssueAvailability,
  required DateTime now,
}) {
  if (manualNotice?.isActiveAt(now) == true) return manualNotice;
  final kst = now.toUtc().add(const Duration(hours: 9));
  final afterPublishTime = kst.hour >= 6;
  final issueUnavailable = switch (dailyIssueAvailability) {
    DailyIssueAvailability.missing ||
    DailyIssueAvailability.failed ||
    DailyIssueAvailability.notReady => true,
    DailyIssueAvailability.unknown || DailyIssueAvailability.ready => false,
  };
  return afterPublishTime && issueUnavailable
      ? AppNotice.dailyIssueDelay()
      : null;
}

String _noticeText(dynamic value) => value is String ? value.trim() : '';

AppNoticeType _noticeType(dynamic value) => switch (value) {
  'warning' => AppNoticeType.warning,
  'error' => AppNoticeType.error,
  _ => AppNoticeType.info,
};

DateTime? _noticeDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
