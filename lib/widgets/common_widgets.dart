part of '../main.dart';

const _clayBackground = AppColors.pageBackground;
const _claySurface = Color(0xFFFFFBFF);
const _clayLilac = Color(0xFFEBDDFF);
const _clayPeach = Color(0xFFFFE1D7);
const _clayMint = Color(0xFFDFF8EF);

List<TextSpan> buildHighlightedTextSpans(String text, String keyword) {
  final normalizedKeyword = keyword.trim();
  if (text.isEmpty || normalizedKeyword.isEmpty) {
    return [TextSpan(text: text)];
  }

  final lowerText = text.toLowerCase();
  final lowerKeyword = normalizedKeyword.toLowerCase();
  final spans = <TextSpan>[];
  var cursor = 0;

  while (cursor < text.length) {
    final matchStart = lowerText.indexOf(lowerKeyword, cursor);
    if (matchStart == -1) {
      spans.add(TextSpan(text: text.substring(cursor)));
      break;
    }

    if (matchStart > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, matchStart)));
    }

    final matchEnd = matchStart + normalizedKeyword.length;
    spans.add(
      TextSpan(
        text: text.substring(matchStart, matchEnd),
        style: const TextStyle(color: _blue, fontWeight: FontWeight.w700),
      ),
    );
    cursor = matchEnd;
  }

  return spans.isEmpty ? [TextSpan(text: text)] : spans;
}

const quizHintUnavailableMessage = '힌트를 준비 중이에요.';

String _firstNonEmptyText(Iterable<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String buildMaskedKoreanHint({
  required String koreanSentence,
  required String answerMeaning,
}) {
  final sentence = koreanSentence.trim();
  final meaning = answerMeaning.trim();
  if (sentence.isEmpty || meaning.isEmpty) return '';

  final candidates = <String>{};
  for (final part in meaning.split(RegExp(r'[,;/\n·・]|\(|\)'))) {
    final cleaned = part
        .replaceAll(RegExp(r'^[\s\-\u2022]+|[\s.!?]+$'), '')
        .replaceAll(RegExp(r'''^["'“”‘’]+|["'“”‘’]+$'''), '')
        .trim();
    if (cleaned.length >= 2) candidates.add(cleaned);

    for (final ending in const ['하다', '되다', '이다']) {
      if (cleaned.endsWith(ending) && cleaned.length > ending.length) {
        final stem = cleaned.substring(0, cleaned.length - ending.length);
        if (stem.length >= 2) candidates.add(stem);
      }
    }
  }

  final ordered = candidates.toList()
    ..sort((left, right) => right.length.compareTo(left.length));
  for (final candidate in ordered) {
    if (sentence.contains(candidate)) {
      return sentence.replaceAll(candidate, '_____');
    }
  }
  return '';
}

class QuizTranslationHint extends StatefulWidget {
  const QuizTranslationHint({
    super.key,
    required this.koreanSentence,
    required this.answerMeaning,
    required this.answerText,
  });

  final String koreanSentence;
  final String answerMeaning;
  final String answerText;

  @override
  State<QuizTranslationHint> createState() => _QuizTranslationHintState();
}

class _QuizTranslationHintState extends State<QuizTranslationHint> {
  bool _expanded = false;

  String get _maskedHint {
    final masked = buildMaskedKoreanHint(
      koreanSentence: widget.koreanSentence,
      answerMeaning: widget.answerMeaning,
    );
    final answer = widget.answerText.trim();
    if (masked.isEmpty ||
        (answer.isNotEmpty &&
            masked.toLowerCase().contains(answer.toLowerCase()))) {
      return quizHintUnavailableMessage;
    }
    return masked;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.koreanSentence.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(
            _expanded
                ? Icons.visibility_off_outlined
                : Icons.lightbulb_outline_rounded,
            size: 18,
          ),
          label: Text(_expanded ? '힌트 숨기기' : '힌트 보기'),
          style: TextButton.styleFrom(
            foregroundColor: _blue,
            backgroundColor: const Color(0xFFEAF2FF),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _clayDecoration(
              color: const Color(0xFFF5F9FF),
              radius: 18,
              shadowColor: const Color(0xFFC7D5ED),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: _blue,
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Text(
                      '해석 힌트',
                      style: TextStyle(
                        color: _blue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _maskedHint,
                  style: const TextStyle(
                    color: Color(0xFF374151),
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

List<BoxShadow> _clayShadows([Color color = const Color(0xFF9EA0B7)]) {
  return [
    BoxShadow(
      color: color.withOpacity(0.22),
      blurRadius: 30,
      spreadRadius: 1,
      offset: const Offset(12, 16),
    ),
    const BoxShadow(
      color: Color(0xEFFFFFFF),
      blurRadius: 24,
      spreadRadius: 1,
      offset: Offset(-10, -12),
    ),
  ];
}

BoxDecoration _clayDecoration({
  Color color = _claySurface,
  double radius = 28,
  Color shadowColor = const Color(0xFF9EA0B7),
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withOpacity(0.78), width: 1.3),
    boxShadow: _clayShadows(shadowColor),
  );
}

Future<bool> _showLearningExitConfirmation(BuildContext context) async {
  final shouldExit = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.78),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9EA0B7).withValues(alpha: 0.22),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(12, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '학습을 종료할까요?',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '나가면 현재 학습 중인 내용이 저장되지 않습니다.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F0FF),
                        foregroundColor: _blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '나가기',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0x665B8EF3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '계속 학습하기',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return shouldExit == true;
}

Future<bool> _showSignOutConfirmation(BuildContext context) async {
  final shouldSignOut = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.78),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9EA0B7).withValues(alpha: 0.22),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(12, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '로그아웃할까요?',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '다시 로그인하면 학습 기록을 이어서 볼 수 있어요.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F0FF),
                        foregroundColor: _blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0x665B8EF3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '로그아웃',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return shouldSignOut == true;
}

Future<bool> _showDeleteConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.78),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF9EA0B7).withValues(alpha: 0.22),
              blurRadius: 30,
              spreadRadius: 1,
              offset: const Offset(12, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8F0FF),
                        foregroundColor: _blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        '취소',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE15A6A),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0x55E15A6A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return shouldDelete == true;
}

class _FlowScaffold extends StatelessWidget {
  const _FlowScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottom,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _clayBackground,
      appBar: AppBar(
        backgroundColor: _clayBackground,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_pageBackground, _clayBackground, Color(0xFFEAF7FF)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(22, 17, 22, bottom == null ? 35 : 125),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 9),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 31),
              child,
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
                child: bottom!,
              ),
            ),
    );
  }
}

class _AppBottomBar extends StatelessWidget {
  const _AppBottomBar({this.currentIndex});
  final int? currentIndex;

  static const _items = [
    _BottomNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: '홈',
    ),
    _BottomNavItem(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      label: '복습',
    ),
    _BottomNavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: '마이',
    ),
  ];

  void _openTab(BuildContext context, int index) {
    if (index == currentIndex) return;
    final Widget page = switch (index) {
      0 => const HomeScreen(),
      1 => const ReviewScreen(),
      _ => const MyPageScreen(),
    };
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E4EA), width: 1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, -7),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 86,
          child: Row(
            children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = index == (currentIndex ?? 0);
              final color = selected ? Colors.white : const Color(0xFF858B96);

              return Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () => _openTab(context, index),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: selected ? _blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Color(0x665B8EF3),
                                  blurRadius: 16,
                                  offset: Offset(0, 7),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selected ? item.selectedIcon : item.icon,
                            color: color,
                            size: 25,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onTap : null,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          disabledBackgroundColor: const Color(0xFFD7DCE8),
          foregroundColor: Colors.white,
          shadowColor: const Color(0x665B8EF3),
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (showArrow) ...[
              const SizedBox(width: 9),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE9E6DF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _ink,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
