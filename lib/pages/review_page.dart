part of '../main.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  // ignore: unused_field
  static const _methods = [
    _ReviewMethod(
      type: _ReviewType.topic,
      title: '분야별로 복습',
      icon: Icons.category_rounded,
      color: Color(0xFFE8E9ED),
      badge: 'TOPIC',
      accentColor: Color(0xFF6B7280),
    ),
    _ReviewMethod(
      type: _ReviewType.week,
      title: '주차별로 복습',
      icon: Icons.calendar_view_week_rounded,
      color: Color(0xFFE8E9ED),
      badge: 'WEEK',
      accentColor: Color(0xFF6B7280),
    ),
    _ReviewMethod(
      type: _ReviewType.difficulty,
      title: '난이도별로 복습',
      icon: Icons.signal_cellular_alt_rounded,
      color: Color(0xFFE8E9ED),
      badge: 'LEVEL',
      accentColor: Color(0xFF6B7280),
    ),
  ];

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  Map<String, bool> _weeklyReviewCompletion = _emptyWeeklyReviewCompletion();
  bool _weeklyReviewLoading = true;
  bool _todayReviewCompleted = false;
  bool _todayReviewLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshReviewCompletion();
  }

  Future<void> _refreshReviewCompletion() async {
    await Future.wait([
      _loadWeeklyReviewCompletion(),
      _loadTodayReviewCompletion(),
    ]);
  }

  Future<void> _loadTodayReviewCompletion() async {
    try {
      final completed = await ReviewService.hasReviewResultForDate(
        appDateString(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _todayReviewCompleted = completed;
        _todayReviewLoading = false;
      });
      // ignore: avoid_print
      print('Today review completion loaded: $completed');
    } catch (error) {
      // ignore: avoid_print
      print('Today review completion load failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _todayReviewCompleted = false;
        _todayReviewLoading = false;
      });
    }
  }

  Future<void> _loadWeeklyReviewCompletion() async {
    try {
      final completion = await ReviewService.getWeeklyReviewCompletion();
      if (!mounted) {
        return;
      }
      setState(() {
        _weeklyReviewCompletion = completion;
        _weeklyReviewLoading = false;
      });
      // ignore: avoid_print
      print('Review weekly completion refresh completed');
    } catch (error) {
      // ignore: avoid_print
      print('Review weekly completion refresh failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _weeklyReviewCompletion = _emptyWeeklyReviewCompletion();
        _weeklyReviewLoading = false;
      });
    }
  }

  Future<void> _openRecommendedReview(BuildContext context) async {
    final alreadyCompleted = await ReviewService.hasReviewResultForDate(
      appDateString(),
    );
    if (!context.mounted) {
      return;
    }
    if (alreadyCompleted) {
      setState(() {
        _todayReviewCompleted = true;
        _todayReviewLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘의 복습은 이미 완료했어요.')));
      return;
    }

    final reviewWordData = await ReviewService.getTodayReviewWords(limit: 10);
    // ignore: avoid_print
    print('Review words loaded: ${reviewWordData.length}');

    if (!context.mounted) {
      return;
    }

    if (reviewWordData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오늘 복습할 단어가 아직 없습니다. 먼저 단어를 학습하거나 저장해보세요.'),
        ),
      );
      return;
    }

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewQuizPage(reviewWords: reviewWordData),
      ),
    );
    if (!mounted) {
      return;
    }
    if (completed == true) {
      await _refreshReviewCompletion();
    }
  }

  // ignore: unused_element
  void _openSelection(BuildContext context, _ReviewMethod method) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ReviewSelectionScreen(method: method)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: ColoredBox(
        color: _pageBackground,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 44, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '복습하기',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '오늘 나에게 필요한 방식으로 단어를 다시 만나보세요.',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                _WeeklyReviewCard(
                  completion: _weeklyReviewCompletion,
                  loading: _weeklyReviewLoading,
                ),
                const SizedBox(height: 16),
                _RecommendedReviewCard(
                  completed: _todayReviewCompleted,
                  loading: _todayReviewLoading,
                  onStart: () => _openRecommendedReview(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Map<String, bool> _emptyWeeklyReviewCompletion() {
    return const {
      'mon': false,
      'tue': false,
      'wed': false,
      'thu': false,
      'fri': false,
      'sat': false,
      'sun': false,
    };
  }
}

class _WeeklyReviewCard extends StatelessWidget {
  const _WeeklyReviewCard({required this.completion, required this.loading});

  final Map<String, bool> completion;
  final bool loading;

  static const _days = [
    ('월', 'mon'),
    ('화', 'tue'),
    ('수', 'wed'),
    ('목', 'thu'),
    ('금', 'fri'),
    ('토', 'sat'),
    ('일', 'sun'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 주 복습현황',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _days
                .map(
                  (day) => _WeekDayItem(
                    label: day.$1,
                    completed: !loading && (completion[day.$2] ?? false),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _WeekDayItem extends StatelessWidget {
  const _WeekDayItem({required this.label, required this.completed});

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed ? const Color(0xFF5B8DEF) : const Color(0xFF9CA3AF);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department_rounded, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RecommendedReviewCard extends StatelessWidget {
  const _RecommendedReviewCard({
    required this.completed,
    required this.loading,
    required this.onStart,
  });

  final bool completed;
  final bool loading;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF5B8DEF),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B8DEF).withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '오늘의 자동 추천',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            '헷갈리는 단어 정복하기',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '회원님의 퀴즈에서 틀린 횟수를 분석해 최적의 복습을 제공합니다.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: loading ? null : onStart,
              style: FilledButton.styleFrom(
                backgroundColor: completed
                    ? Colors.white.withValues(alpha: 0.82)
                    : Colors.white,
                foregroundColor: const Color(0xFF4B5563),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.55),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (completed) ...[
                    const Icon(Icons.check_circle_rounded, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    loading
                        ? '복습 상태 확인 중'
                        : completed
                        ? '오늘 복습 완료됨'
                        : '오늘의 복습 시작하기',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ReviewType { topic, week, difficulty }

class _ReviewSelectionScreen extends StatefulWidget {
  const _ReviewSelectionScreen({required this.method});

  final _ReviewMethod method;

  @override
  State<_ReviewSelectionScreen> createState() => _ReviewSelectionScreenState();
}

class _ReviewSelectionScreenState extends State<_ReviewSelectionScreen> {
  late final List<_ReviewChoice> _choices = _choicesFor(widget.method.type);
  final Set<Object> _selectedValues = {};

  String get _title => switch (widget.method.type) {
    _ReviewType.topic => '어떤 분야를\n복습할까요?',
    _ReviewType.week => '몇 주차 단어를\n복습할까요?',
    _ReviewType.difficulty => '어떤 난이도로\n복습할까요?',
  };

  String get _subtitle => switch (widget.method.type) {
    _ReviewType.topic => '경제, 정치, 기술, 국제, 사회 중 하나를 선택해 주세요.',
    _ReviewType.week => '학습한 주차를 골라 해당 단어만 다시 풀어보세요.',
    _ReviewType.difficulty => '지금 맞는 난이도를 선택해 부담 없이 복습해요.',
  };

  List<LearningWord> _wordsFor(_ReviewChoice choice) {
    return switch (widget.method.type) {
      _ReviewType.topic =>
        learningWords
            .where((word) => word.topics.contains(choice.label))
            .toList(),
      _ReviewType.week =>
        learningWords.where((word) => word.week == choice.value).toList(),
      _ReviewType.difficulty =>
        learningWords.where((word) => word.difficulty == choice.label).toList(),
    };
  }

  List<LearningWord> _selectedWords() {
    return learningWords.where((word) {
      return switch (widget.method.type) {
        _ReviewType.topic => word.topics.any(
          (topic) => _selectedValues.contains(topic),
        ),
        _ReviewType.week => _selectedValues.contains(word.week),
        _ReviewType.difficulty => _selectedValues.contains(word.difficulty),
      };
    }).toList();
  }

  void _startReview() {
    final words = _selectedWords();
    if (words.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(words: words)),
    );
  }

  List<_ReviewChoice> _choicesFor(_ReviewType type) {
    switch (type) {
      case _ReviewType.topic:
        return topics
            .map(
              (topic) => _ReviewChoice(
                label: topic.name,
                icon: topic.icon,
                color: topic.color,
                value: topic.name,
              ),
            )
            .toList();
      case _ReviewType.week:
        final weeks = learningWords.map((word) => word.week).toSet().toList()
          ..sort();
        return weeks
            .map(
              (week) => _ReviewChoice(
                label: '$week주차',
                icon: Icons.event_note_rounded,
                color: Colors.white,
                value: week,
              ),
            )
            .toList();
      case _ReviewType.difficulty:
        return ['초급', '중급', '고급'].map((level) {
          final levelColor = switch (level) {
            '초급' => Colors.white,
            '중급' => Colors.white,
            _ => Colors.white,
          };
          final levelIcon = switch (level) {
            '초급' => Icons.looks_one_rounded,
            '중급' => Icons.looks_two_rounded,
            _ => Icons.looks_3_rounded,
          };
          return _ReviewChoice(
            label: level,
            icon: levelIcon,
            color: levelColor,
            value: level,
          );
        }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      title: _title,
      subtitle: _subtitle,
      bottom: _PrimaryButton(
        label: '복습하기',
        enabled: _selectedValues.isNotEmpty,
        onTap: _startReview,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _choices.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
        ),
        itemBuilder: (_, index) {
          final choice = _choices[index];
          final active = _selectedValues.contains(choice.value);
          final count = _wordsFor(choice).length;

          return _ReviewChoiceCard(
            choice: choice,
            count: count,
            active: active,
            onTap: () {
              setState(() {
                if (active) {
                  _selectedValues.remove(choice.value);
                } else {
                  _selectedValues.add(choice.value);
                }
              });
            },
          );
        },
      ),
    );
  }
}

class _ReviewChoice {
  const _ReviewChoice({
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Object value;
}

class _ReviewChoiceCard extends StatelessWidget {
  const _ReviewChoiceCard({
    required this.choice,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final _ReviewChoice choice;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? _blue : Colors.white.withValues(alpha: 0.8),
            width: active ? 2 : 1,
          ),
          boxShadow: active
              ? [
                  const BoxShadow(
                    color: Color(0x335B8EF3),
                    blurRadius: 22,
                    offset: Offset(8, 10),
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    blurRadius: 18,
                    offset: Offset(-7, -8),
                  ),
                ]
              : _clayShadows(const Color(0xFFB9B0C8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  choice.icon,
                  size: 29,
                  color: active ? _blue : const Color(0xFF191C21),
                ),
                if (active)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: _blue,
                    size: 21,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  choice.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$count개 단어',
                  style: const TextStyle(
                    color: Color(0xFF6D7480),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewMethod {
  const _ReviewMethod({
    required this.type,
    required this.title,
    required this.icon,
    required this.color,
    required this.badge,
    required this.accentColor,
  });

  final _ReviewType type;
  final String title;
  final IconData icon;
  final Color color;
  final String badge;
  final Color accentColor;
}

// ignore: unused_element
class _ReviewMethodCard extends StatelessWidget {
  const _ReviewMethodCard({required this.method, required this.onTap});

  final _ReviewMethod method;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _clayDecoration(radius: 30, shadowColor: method.color),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: method.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: method.accentColor.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(5, 6),
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    blurRadius: 10,
                    offset: Offset(-4, -5),
                  ),
                ],
              ),
              child: Icon(method.icon, size: 25, color: method.accentColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 5,
                children: [
                  Text(
                    method.title,
                    style: const TextStyle(
                      color: Color(0xFF191C21),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: method.color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      method.badge,
                      style: TextStyle(
                        color: method.accentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFC1C7D3),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _WrongAnswerRecommendation extends StatelessWidget {
  const _WrongAnswerRecommendation({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onStart,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF75A4FF), _blue, Color(0xFF8A78FF)],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.48),
            width: 1.2,
          ),
          boxShadow: _clayShadows(const Color(0xFF6D8FE8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.bolt_rounded, color: _blue, size: 25),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  '오늘의 자동 추천',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '자주 틀리는 단어 먼저 복습',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '최근 학습에서 헷갈렸던 단어를 골라 빠르게 다시 확인해요.',
              style: TextStyle(color: Colors.white, fontSize: 15, height: 1.55),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Colors.white,
                  foregroundColor: _blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  '추천 단어 바로 복습',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _WeeklyReviewProgress extends StatelessWidget {
  const _WeeklyReviewProgress();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _clayDecoration(
        color: const Color(0xFFF5F1FF),
        radius: 30,
        shadowColor: const Color(0xFFBBB0D6),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 0.75,
                  strokeWidth: 6,
                  color: _blue,
                  backgroundColor: Color(0xFFE1E2E9),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  '75%',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '이번 주 복습 달성도',
                  style: TextStyle(
                    color: Color(0xFF191C21),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '목표까지 12단어 남았어요.',
                  style: TextStyle(color: Color(0xFF414751), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
