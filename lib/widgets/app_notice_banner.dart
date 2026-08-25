import 'package:flutter/material.dart';

import '../models/app_notice.dart';

class AppNoticeBanner extends StatelessWidget {
  const AppNoticeBanner({super.key, required this.notice});

  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    final icon = switch (notice.type) {
      AppNoticeType.info => Icons.info_outline_rounded,
      AppNoticeType.warning => Icons.schedule_rounded,
      AppNoticeType.error => Icons.error_outline_rounded,
    };
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${notice.title}. ${notice.message}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: const TextStyle(
                      color: Color(0xFF17171C),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notice.message,
                    style: const TextStyle(
                      color: Color(0xFF74747E),
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
