import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordapp/models/app_notice.dart';
import 'package:wordapp/widgets/app_notice_banner.dart';

DateTime kst(int hour) => DateTime.utc(2026, 8, 25, hour - 9);

AppNotice manual({
  bool enabled = true,
  String title = '\uC11C\uBE44\uC2A4 \uC810\uAC80 \uC548\uB0B4',
  String message =
      '\uC624\uB298 \uC624\uD6C4\uC5D0 \uC810\uAC80\uC774 \uC9C4\uD589\uB429\uB2C8\uB2E4.',
  AppNoticeType type = AppNoticeType.info,
  DateTime? startAt,
  DateTime? endAt,
}) => AppNotice(
  enabled: enabled,
  title: title,
  message: message,
  type: type,
  startAt: startAt,
  endAt: endAt,
);

void main() {
  group('AppNotice policy', () {
    test('1. disabled manual notice is hidden', () {
      expect(
        resolveHomeNotice(
          manualNotice: manual(enabled: false),
          dailyIssueAvailability: DailyIssueAvailability.ready,
          now: kst(10),
        ),
        isNull,
      );
    });

    test('2. enabled manual notice is shown', () {
      final notice = manual();
      expect(
        resolveHomeNotice(
          manualNotice: notice,
          dailyIssueAvailability: DailyIssueAvailability.ready,
          now: kst(10),
        ),
        same(notice),
      );
    });

    testWidgets('3. manual title and message render', (tester) async {
      final notice = manual();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppNoticeBanner(notice: notice)),
        ),
      );
      expect(find.text(notice.title), findsOneWidget);
      expect(find.text(notice.message), findsOneWidget);
    });

    test('4. notice is hidden before start_at', () {
      expect(manual(startAt: kst(11)).isActiveAt(kst(10)), isFalse);
    });

    test('5. notice is shown between start_at and end_at', () {
      expect(
        manual(startAt: kst(9), endAt: kst(11)).isActiveAt(kst(10)),
        isTrue,
      );
    });

    test('6. notice is hidden after end_at', () {
      expect(manual(endAt: kst(9)).isActiveAt(kst(10)), isFalse);
    });

    test('7. invalid type falls back to info', () {
      expect(
        AppNotice.fromMap({
          'enabled': true,
          'title': 'title',
          'message': 'message',
          'type': 'unexpected',
        }).type,
        AppNoticeType.info,
      );
    });

    test('8. no manual notice and ready daily issue shows nothing', () {
      expect(
        resolveHomeNotice(
          manualNotice: null,
          dailyIssueAvailability: DailyIssueAvailability.ready,
          now: kst(10),
        ),
        isNull,
      );
    });

    test('9. failed daily issue after publish time shows automatic notice', () {
      final notice = resolveHomeNotice(
        manualNotice: null,
        dailyIssueAvailability: DailyIssueAvailability.failed,
        now: kst(10),
      );
      expect(notice?.isAutomatic, isTrue);
    });

    test('10. manual notice wins over automatic failure notice', () {
      final notice = manual();
      expect(
        resolveHomeNotice(
          manualNotice: notice,
          dailyIssueAvailability: DailyIssueAvailability.failed,
          now: kst(10),
        ),
        same(notice),
      );
    });

    test('11. missing daily issue before 06:00 KST shows nothing', () {
      expect(
        resolveHomeNotice(
          manualNotice: null,
          dailyIssueAvailability: DailyIssueAvailability.missing,
          now: kst(5),
        ),
        isNull,
      );
    });

    test('12. malformed document is safe and not renderable', () {
      final notice = AppNotice.fromMap({
        'enabled': 'yes',
        'title': 42,
        'message': null,
        'type': <String>[],
        'start_at': Object(),
      });
      expect(notice.enabled, isFalse);
      expect(notice.isRenderable, isFalse);
      expect(notice.type, AppNoticeType.info);
      expect(() => notice.isActiveAt(kst(10)), returnsNormally);
    });
  });
}
