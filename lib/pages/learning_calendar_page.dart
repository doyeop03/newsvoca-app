part of '../main.dart';

class LearningCalendarScreen extends StatefulWidget {
  const LearningCalendarScreen({super.key});

  @override
  State<LearningCalendarScreen> createState() => _LearningCalendarScreenState();
}

class _LearningCalendarScreenState extends State<LearningCalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  Set<String> _studiedDates = const {};
  DailyLearningSummary? _dailySummary;
  int _currentStreak = 0;
  int _monthlyStudyDays = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final today = _todayDate();
    _visibleMonth = DateTime(today.year, today.month);
    _selectedDate = today;
    _loadCalendarData();
  }

  Future<void> _loadCalendarData() async {
    setState(() => _isLoading = true);
    try {
      final selectedDateString = _dateString(_selectedDate);
      final results = await Future.wait<dynamic>([
        CalendarLearningService.getMonthlyLearningDates(
          _visibleMonth.year,
          _visibleMonth.month,
        ),
        CalendarLearningService.getCurrentStreak(
          today: _dateString(_todayDate()),
        ),
        CalendarLearningService.getDailyLearningSummary(selectedDateString),
      ]);

      if (!mounted) {
        return;
      }
      setState(() {
        final studiedDates = results[0] as Set<String>;
        _studiedDates = studiedDates;
        _currentStreak = results[1] as int;
        _monthlyStudyDays = studiedDates.length;
        _dailySummary = results[2] as DailyLearningSummary;
        _isLoading = false;
      });
    } catch (error) {
      // ignore: avoid_print
      print('load learning calendar failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _studiedDates = const {};
        _currentStreak = 0;
        _monthlyStudyDays = 0;
        _dailySummary = DailyLearningSummary(
          date: _dateString(_selectedDate),
          completedCategories: const [],
          learnedWordCount: 0,
          reviewScore: 0,
          reviewTotal: 0,
          reviewAccuracyValue: null,
          hasReview: false,
          hasDailyQuiz: false,
          dailyQuizScore: 0,
          dailyQuizTotal: 0,
          dailyQuizAccuracyValue: null,
          hasArticleLearning: false,
        );
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int amount) {
    final nextMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + amount,
    );
    final today = _todayDate();
    setState(() {
      _visibleMonth = nextMonth;
      _selectedDate = DateTime(nextMonth.year, nextMonth.month, 1);
      if (nextMonth.year == today.year && nextMonth.month == today.month) {
        _selectedDate = today;
      }
    });
    _loadCalendarData();
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadCalendarData();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _dailySummary;

    return Scaffold(
      backgroundColor: _clayBackground,
      appBar: AppBar(
        backgroundColor: _clayBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _loadCalendarData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
            children: [
              Text('학습 캘린더', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              _CalendarSummaryCard(
                streak: _currentStreak,
                monthlyStudyDays: _monthlyStudyDays,
                loading: _isLoading,
              ),
              const SizedBox(height: 20),
              _CalendarMonthCard(
                visibleMonth: _visibleMonth,
                studiedDates: _studiedDates,
                selectedDate: _selectedDate,
                onPrevious: () => _changeMonth(-1),
                onNext: () => _changeMonth(1),
                onSelected: _selectDate,
              ),
              const SizedBox(height: 22),
              _DailyLearningCard(
                selectedDate: _selectedDate,
                summary: summary,
                loading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarSummaryCard extends StatelessWidget {
  const _CalendarSummaryCard({
    required this.streak,
    required this.monthlyStudyDays,
    required this.loading,
  });

  final int streak;
  final int monthlyStudyDays;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: _clayDecoration(
        color: Colors.white,
        radius: 26,
        shadowColor: const Color(0xFFC9CDDD),
      ),
      child: Row(
        children: [
          const _ClayIconBubble(
            icon: Icons.local_fire_department_rounded,
            color: _blue,
            iconColor: Colors.white,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loading ? '학습 기록을 불러오는 중' : '$streak일 연속 학습 중',
                  style: const TextStyle(
                    color: Color(0xFF343841),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading ? '잠시만 기다려주세요.' : '이번 달 $monthlyStudyDays일 학습',
                  style: const TextStyle(
                    color: Color(0xFF7B8190),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarMonthCard extends StatelessWidget {
  const _CalendarMonthCard({
    required this.visibleMonth,
    required this.studiedDates,
    required this.selectedDate,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });

  final DateTime visibleMonth;
  final Set<String> studiedDates;
  final DateTime selectedDate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
      decoration: _clayDecoration(
        color: Colors.white,
        radius: 26,
        shadowColor: const Color(0xFFC6CADD),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CalendarArrowButton(
                icon: Icons.chevron_left_rounded,
                onPressed: onPrevious,
              ),
              Expanded(
                child: Text(
                  '${visibleMonth.year}년 ${visibleMonth.month}월',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF343841),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _CalendarArrowButton(
                icon: Icons.chevron_right_rounded,
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Row(
            children: [
              _WeekdayLabel('일'),
              _WeekdayLabel('월'),
              _WeekdayLabel('화'),
              _WeekdayLabel('수'),
              _WeekdayLabel('목'),
              _WeekdayLabel('금'),
              _WeekdayLabel('토'),
            ],
          ),
          const SizedBox(height: 10),
          _CalendarGrid(
            month: visibleMonth,
            studiedDates: studiedDates,
            selectedDate: selectedDate,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _CalendarArrowButton extends StatelessWidget {
  const _CalendarArrowButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: const Color(0xFF3F4653), size: 22),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFFB7BBC6),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.studiedDates,
    required this.selectedDate,
    required this.onSelected,
  });

  final DateTime month;
  final Set<String> studiedDates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = _todayDate();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 42,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final day = index - firstWeekday + 1;
        final isOutsideMonth = day < 1 || day > daysInMonth;
        final date = isOutsideMonth
            ? null
            : DateTime(month.year, month.month, day);
        final dateString = date == null ? '' : _dateString(date);
        final studied = date != null && studiedDates.contains(dateString);
        final selected = date != null && _isSameDay(selectedDate, date);
        final isToday = date != null && _isSameDay(today, date);
        final isFuture = date != null && date.isAfter(today);

        return _CalendarDayCell(
          day: isOutsideMonth ? null : day,
          studied: studied,
          selected: selected,
          isToday: isToday,
          isFuture: isFuture,
          onTap: date == null ? null : () => onSelected(date),
        );
      },
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.studied,
    required this.selected,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final int? day;
  final bool studied;
  final bool selected;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    final hasFill = studied && !isFuture;
    final backgroundColor = selected && !hasFill
        ? const Color(0xFFEAF2FF)
        : hasFill
        ? _blue
        : Colors.transparent;
    final borderColor = selected || isToday ? _blue : null;
    final textColor = day == null
        ? const Color(0xFFD2D5DD)
        : hasFill
        ? Colors.white
        : const Color(0xFF3D4350);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: borderColor == null
                ? null
                : Border.all(color: borderColor, width: selected ? 2 : 1.8),
            boxShadow: hasFill || selected
                ? const [
                    BoxShadow(
                      color: Color(0x335B8EF3),
                      blurRadius: 14,
                      offset: Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Text(
            day == null ? '' : '$day',
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: hasFill || selected
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyLearningCard extends StatelessWidget {
  const _DailyLearningCard({
    required this.selectedDate,
    required this.summary,
    required this.loading,
  });

  final DateTime selectedDate;
  final DailyLearningSummary? summary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final summary = this.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '학습 상세',
                style: TextStyle(
                  color: Color(0xFF343841),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _DatePill(label: '${selectedDate.month}월 ${selectedDate.day}일'),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: _clayDecoration(
            color: Colors.white,
            radius: 28,
            shadowColor: const Color(0xFFC7CBDD),
          ),
          child: loading
              ? const SizedBox(
                  height: 132,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _DailyLearningContent(
                  summary: summary!,
                  selectedDate: selectedDate,
                ),
        ),
      ],
    );
  }
}

class _DailyLearningContent extends StatelessWidget {
  const _DailyLearningContent({
    required this.summary,
    required this.selectedDate,
  });

  final DailyLearningSummary summary;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasAnyLearning) {
      return const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClayIconBubble(
            icon: Icons.event_note_rounded,
            color: Color(0xFFE9ECF5),
            iconColor: Color(0xFF8A91A0),
            size: 44,
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '아직 학습 기록이 없어요',
                        style: TextStyle(
                          color: Color(0xFF343841),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _QuietStatusPill(label: '기록 없음'),
                  ],
                ),
                SizedBox(height: 9),
                Text(
                  '학습을 완료하면 오늘의 단어와 복습 결과가 여기에 표시돼요.',
                  style: TextStyle(
                    color: Color(0xFF8E94A3),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final categoryText = _completedCategoryLabel(summary.completedCategories);
    final status = summary.hasDailyQuiz
        ? '학습 완료'
        : summary.hasReview
        ? '복습 완료'
        : '기사 학습 완료';
    final quizAccuracy = summary.dailyQuizAccuracy;
    final quizValue = summary.dailyQuizTotal > 0
        ? '${summary.dailyQuizScore} / ${summary.dailyQuizTotal}'
        : '완료';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${selectedDate.month}월 ${selectedDate.day}일 학습 기록',
                    style: const TextStyle(
                      color: Color(0xFF343841),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (summary.hasDailyQuiz) ...[
                    const SizedBox(height: 13),
                    const Text(
                      '학습 분야',
                      style: TextStyle(
                        color: Color(0xFF8E94A3),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      categoryText.isEmpty ? '통합 학습' : categoryText,
                      style: const TextStyle(
                        color: Color(0xFF343841),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusPill(label: status),
          ],
        ),
        const SizedBox(height: 18),
        if (summary.hasDailyQuiz)
          Row(
            children: [
              Expanded(
                child: _LearningMetric(
                  label: '학습 단어 수',
                  value: '${summary.learnedWordCount}개',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LearningMetric(
                  label: '데일리 퀴즈',
                  value: quizAccuracy == null
                      ? quizValue
                      : '$quizValue · $quizAccuracy%',
                ),
              ),
            ],
          ),
        if (summary.hasDailyQuiz && summary.hasReview)
          const SizedBox(height: 12),
        if (summary.hasReview)
          Row(
            children: [
              Expanded(
                child: _LearningMetric(
                  label: '복습 정답률',
                  value: summary.reviewAccuracy == null
                      ? '완료'
                      : '${summary.reviewAccuracy}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LearningMetric(
                  label: '복습 문제',
                  value: '${summary.reviewTotal}문제',
                ),
              ),
            ],
          ),
        if (!summary.hasDailyQuiz &&
            !summary.hasReview &&
            summary.hasArticleLearning)
          const Text(
            '기사 학습을 완료했어요.',
            style: TextStyle(
              color: Color(0xFF5B6472),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _ClayIconBubble extends StatelessWidget {
  const _ClayIconBubble({
    required this.icon,
    required this.color,
    required this.iconColor,
    this.size = 48,
  });

  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(5, 7),
          ),
          const BoxShadow(
            color: Colors.white,
            blurRadius: 12,
            offset: Offset(-5, -6),
          ),
        ],
      ),
      child: Icon(icon, color: iconColor, size: size * 0.52),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDCE8FF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A5B8EF3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _blue,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x445B8EF3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _QuietStatusPill extends StatelessWidget {
  const _QuietStatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE9ECF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8A91A0),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LearningMetric extends StatelessWidget {
  const _LearningMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3FA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12A0A7BC),
            blurRadius: 12,
            offset: Offset(4, 7),
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 10,
            offset: Offset(-4, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9CA1AD),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF343841),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _completedCategoryLabel(List<String> categories) {
  if (categories.isEmpty) {
    return '';
  }
  return categories
      .map((category) => CalendarLearningService.categoryLabels[category])
      .whereType<String>()
      .join(' · ');
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime _todayDate() => _dateOnly(DateTime.parse(appDateString()));

bool _isSameDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _dateString(DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
}
