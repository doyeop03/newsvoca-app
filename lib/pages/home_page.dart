part of '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _isTestingFirestore = false;
  bool _isLoadingInterests = true;
  // ignore: unused_field
  String _firestoreTestResult = '';
  Map<String, bool> _completedCategories = const {};
  List<String> _interestCategories =
      UserPreferenceService.defaultInterestCategories;
  String? _selectedExpandedTaskId;
  bool _reviewCompletedToday = false;
  bool _isLoadingHomeStats = true;
  bool _hasLoadedHomeStats = false;
  bool _isRefreshingHomeStats = false;
  int? _homeStreakCount = 0;
  int? _homeMonthlyStudyDays = 0;
  Timer? _publishTimer;
  IntegratedDailyLearningSet? _integratedDailySet;
  bool _dailyLearningCompleted = false;
  Map<String, bool> _weeklyReviewCompletion = const {
    'mon': false,
    'tue': false,
    'wed': false,
    'thu': false,
    'fri': false,
    'sat': false,
    'sun': false,
  };
  bool _weeklyReviewLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInterestCategories();
    _loadIntegratedDailyLearning();
    _loadWeeklyReviewCompletion();
    _loadDailyQuizCompletionStatus();
    _loadReviewCompletionStatus();
    _refreshHomeStats();
    _schedulePublishReload();
  }

  @override
  void dispose() {
    _publishTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadDailyQuizCompletionStatus();
      _loadIntegratedDailyLearning();
      _loadWeeklyReviewCompletion();
      _loadReviewCompletionStatus();
      _refreshHomeStats();
      _schedulePublishReload();
    }
  }

  void _schedulePublishReload() {
    _publishTimer?.cancel();
    final delay = durationUntilNextPublishKst();
    // ignore: avoid_print
    print('[publish-timer] scheduled reload at 06:00');
    _publishTimer = Timer(delay, () {
      if (!mounted) return;
      // ignore: avoid_print
      print('[publish-timer] reload triggered');
      _loadDailyQuizCompletionStatus();
      _loadIntegratedDailyLearning();
      _loadWeeklyReviewCompletion();
      _loadReviewCompletionStatus();
      _refreshHomeStats();
      _schedulePublishReload();
    });
  }

  Future<void> _refreshHomeStats() async {
    if (_isRefreshingHomeStats) {
      return;
    }

    _isRefreshingHomeStats = true;
    final learningDate = appDateString();

    try {
      final today = _homeDateFromString(learningDate);
      final monthDates = await CalendarLearningService.getMonthlyLearningDates(
        today.year,
        today.month,
      );
      final streakDates =
          await CalendarLearningService.getCurrentStreakLearningDates(
            today: learningDate,
          );

      if (!mounted) {
        return;
      }
      setState(() {
        _homeStreakCount = streakDates.length;
        _homeMonthlyStudyDays = monthDates.length;
        _hasLoadedHomeStats = true;
        _isLoadingHomeStats = false;
      });
      if (kDebugMode) {
        debugPrint(
          '[home-stats] loaded date=$learningDate '
          'streak=${streakDates.length} monthly=${monthDates.length}',
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[home-stats] load failed: $error');
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (!_hasLoadedHomeStats) {
          _homeStreakCount = 0;
          _homeMonthlyStudyDays = 0;
        }
        _isLoadingHomeStats = false;
      });
    } finally {
      _isRefreshingHomeStats = false;
    }
  }

  Future<void> _openLearningCalendar() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LearningCalendarScreen()),
    );
    if (!mounted) {
      return;
    }
    _refreshHomeStats();
  }

  Future<void> _loadInterestCategories() async {
    try {
      final categories = await UserPreferenceService.getInterestCategories();
      if (!mounted) {
        return;
      }
      setState(() {
        _interestCategories = categories;
        _isLoadingInterests = false;
        _syncExpandedTask();
      });
      // ignore: avoid_print
      print('Home visible categories: $categories');
    } catch (error) {
      // ignore: avoid_print
      print('Home interest categories load failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _interestCategories = UserPreferenceService.defaultInterestCategories;
        _isLoadingInterests = false;
        _syncExpandedTask();
      });
    }
  }

  Future<void> _loadDailyQuizCompletionStatus() async {
    final preferences = await SharedPreferences.getInstance();
    final date = appDateString();
    final completed = <String, bool>{
      for (final category in mainCategories)
        category.categoryKey:
            preferences.getBool(
              dailyQuizCompletedKey(date, category.categoryKey),
            ) ??
            false,
    };

    try {
      _dailyLearningCompleted = await UserWordService.hasDailyQuizResult(date);
      final serverCompleted = await UserWordService.getCompletedQuizCategories(
        date: date,
        categories: mainCategories.map((category) => category.categoryKey),
      );
      for (final category in serverCompleted) {
        completed[category] = true;
        await preferences.setBool(dailyQuizCompletedKey(date, category), true);
      }
    } catch (error) {
      // Keep the locally persisted state when the server is unavailable.
      // ignore: avoid_print
      print('Home quiz completion sync failed: $error');
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _completedCategories = completed;
      _syncExpandedTask();
    });
  }

  Future<void> _loadIntegratedDailyLearning() async {
    try {
      final set = await IntegratedDailyLearningService().load();
      final completed = await UserWordService.hasDailyQuizResult(set.date);
      if (!mounted) return;
      setState(() {
        _integratedDailySet = set;
        _interestCategories = set.categories.isEmpty
            ? _interestCategories
            : set.categories;
        _dailyLearningCompleted = completed;
        _isLoadingInterests = false;
      });
    } catch (error) {
      // ignore: avoid_print
      print('[daily-learning] load failed: $error');
      if (mounted) setState(() => _isLoadingInterests = false);
    }
  }

  Future<void> _loadWeeklyReviewCompletion() async {
    try {
      final completion = await UserWordService.getWeeklyLearningCompletion();
      if (!mounted) return;
      setState(() {
        _weeklyReviewCompletion = completion;
        _weeklyReviewLoading = false;
      });
    } catch (error) {
      // ignore: avoid_print
      print('Home weekly review load failed: $error');
      if (mounted) setState(() => _weeklyReviewLoading = false);
    }
  }

  Future<void> _loadReviewCompletionStatus() async {
    try {
      final completed = await ReviewService.hasReviewResultForDate(
        appDateString(),
      );
      if (!mounted) {
        return;
      }
      setState(() => _reviewCompletedToday = completed);
    } catch (error) {
      // ignore: avoid_print
      print('Home review completion load failed: $error');
    }
  }

  Future<void> _startLearning(String category) async {
    final set = _integratedDailySet;
    if (set == null || set.words.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘 학습할 단어를 준비하고 있어요.')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WordDetailScreen(integratedSet: set)),
    );
    if (!mounted) {
      return;
    }
    await _loadInterestCategories();
    await _loadDailyQuizCompletionStatus();
    await _loadIntegratedDailyLearning();
    await _loadReviewCompletionStatus();
    _refreshHomeStats();
  }

  Future<void> _startReview() async {
    final alreadyCompleted = await ReviewService.hasReviewResultForDate(
      appDateString(),
    );
    if (!mounted) {
      return;
    }
    if (alreadyCompleted) {
      setState(() => _reviewCompletedToday = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘의 복습은 이미 완료했어요.')));
      return;
    }

    final reviewWordData = await ReviewService.getTodayReviewWords(limit: 10);
    // ignore: avoid_print
    print('Home review words loaded: ${reviewWordData.length}');

    if (!mounted) {
      return;
    }

    if (reviewWordData.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오늘 복습할 단어가 아직 없습니다.')));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewQuizPage(reviewWords: reviewWordData),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadReviewCompletionStatus();
    _refreshHomeStats();
  }

  // ignore: unused_element
  Future<void> _testFirestoreDailyWordSet() async {
    if (_isTestingFirestore) {
      return;
    }

    setState(() {
      _isTestingFirestore = true;
      _firestoreTestResult = 'Firestore 읽기 중...';
    });

    final dailyWordService = DailyWordService();
    final data = await dailyWordService.getDailyWordSet(
      date: '2026-06-30',
      category: 'economy',
    );

    if (!mounted) {
      return;
    }

    final message = data != null
        ? (data['main_issue']?.toString() ?? 'main_issue 값이 없습니다')
        : dailyWordService.lastError != null
        ? 'Firestore 읽기 오류'
        : '문서를 찾을 수 없습니다';

    setState(() {
      _isTestingFirestore = false;
      _firestoreTestResult = message;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _clayBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_pageBackground, _clayBackground, Color(0xFFEAF7FF)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = math.min(constraints.maxWidth, 480.0);
              final horizontalPadding = contentWidth < 380 ? 16.0 : 20.0;
              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: contentWidth,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      38,
                      horizontalPadding,
                      22,
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              const _HomeLogo(),
                              const Spacer(),
                              _HomeAccountButton(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MyPageScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        _StreakBanner(
                          onTap: _openLearningCalendar,
                          streakCount: _homeStreakCount,
                          monthlyStudyDays: _homeMonthlyStudyDays,
                          loading: _isLoadingHomeStats,
                        ),
                        const SizedBox(height: 28),
                        Expanded(
                          child: _TodayLearningDashboardSection(
                            learningSet: _integratedDailySet,
                            learningCompleted: _dailyLearningCompleted,
                            weeklyReviewCompletion: _weeklyReviewCompletion,
                            weeklyReviewLoading: _weeklyReviewLoading,
                            reviewCompleted: _reviewCompletedToday,
                            isLoading: _isLoadingInterests,
                            onStudy: _startLearning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<MainCategory> get _visibleCategories {
    final categories = _interestCategories
        .map(
          (id) =>
              mainCategories.where((category) => category.categoryKey == id),
        )
        .expand((items) => items)
        .toList();
    return categories.isEmpty ? mainCategories : categories;
  }

  List<_LearningTask> get _timelineTasks => [
    for (final category in _visibleCategories)
      _LearningTask.category(
        category,
        completed: _completedCategories[category.categoryKey] ?? false,
      ),
    const _LearningTask.review(),
  ];

  void _toggleExpandedTask(String taskId) {
    setState(() {
      _selectedExpandedTaskId = _selectedExpandedTaskId == taskId
          ? null
          : taskId;
    });
  }

  void _syncExpandedTask() {
    final tasks = _timelineTasks;
    if (tasks.isEmpty) {
      _selectedExpandedTaskId = null;
      return;
    }

    if (_selectedExpandedTaskId != null &&
        tasks.any((task) => task.id == _selectedExpandedTaskId)) {
      return;
    }

    for (final task in tasks) {
      if (!task.completed) {
        _selectedExpandedTaskId = task.id;
        return;
      }
    }
    _selectedExpandedTaskId = null;
  }
}

class _LearningTask {
  _LearningTask.category(MainCategory source, {required this.completed})
    : id = source.categoryKey,
      category = source,
      isReview = false;

  const _LearningTask.review()
    : id = 'review',
      category = null,
      completed = false,
      isReview = true;

  final String id;
  final MainCategory? category;
  final bool completed;
  final bool isReview;

  String get title => isReview ? '복습' : category!.name;
  String get expandedTitle =>
      isReview ? '오늘의 복습하기' : '${category!.name} 분야 학습하기';
  String get description {
    if (isReview) {
      return '헷갈렸던 단어를 다시 확인해보세요.';
    }
    return switch (category!.categoryKey) {
      'economy' => '오늘의 경제 뉴스 단어를 학습해보세요.',
      'society' => '오늘의 사회 이슈 단어를 학습해보세요.',
      'technology' => 'AI, 플랫폼, 기술 뉴스를 단어로 따라가 보세요.',
      'politics' => '정책과 정치 이슈의 핵심 단어를 학습해보세요.',
      'world' => '세계 이슈와 글로벌 뉴스를 영어 단어로 만나보세요.',
      _ => category!.subtitle,
    };
  }

  IconData get icon => isReview ? Icons.replay_rounded : category!.icon;
  String get actionLabel => isReview ? '복습 시작' : '시작';
}

class _TodayLearningDashboardSection extends StatelessWidget {
  const _TodayLearningDashboardSection({
    required this.learningSet,
    required this.learningCompleted,
    required this.weeklyReviewCompletion,
    required this.weeklyReviewLoading,
    required this.reviewCompleted,
    required this.isLoading,
    required this.onStudy,
  });

  final IntegratedDailyLearningSet? learningSet;
  final bool learningCompleted;
  final Map<String, bool> weeklyReviewCompletion;
  final bool weeklyReviewLoading;
  final bool reviewCompleted;
  final bool isLoading;
  final ValueChanged<String> onStudy;

  int get _completedDailyCount =>
      (learningCompleted ? 1 : 0) + (reviewCompleted ? 1 : 0);

  int get _totalDailyCount => 2;

  double get _progress =>
      _totalDailyCount == 0 ? 0 : _completedDailyCount / _totalDailyCount;

  String get _reviewStatusText => reviewCompleted
      ? '\uBCF5\uC2B5 1\uAC1C \uC644\uB8CC'
      : '\uBCF5\uC2B5 \uBBF8\uC644\uB8CC';

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KnowledgeMapEntryCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KnowledgeMapPage()),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '\uC624\uB298\uC758 \uD559\uC2B5',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            '\uB9E4\uC77C \uC624\uC804 6\uC2DC \uC5C5\uB370\uC774\uD2B8',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          _IntegratedDailyLearningCard(
            learningSet: learningSet,
            completed: learningCompleted,
            onStudy: () => onStudy('daily'),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeMapEntryCard extends StatelessWidget {
  const _KnowledgeMapEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 138,
          padding: const EdgeInsets.fromLTRB(22, 20, 18, 20),
          decoration: _dashboardClayDecoration(radius: 24),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '나의 학습 현황',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '분야별로 얼마나 학습했는지 확인해보세요.',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 82,
                height: 82,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Transform.scale(
                    scale: 1.42,
                    child: Image.asset(
                      'assets/categories/learn_count.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.bar_chart_rounded,
                        size: 52,
                        color: _blue,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: _blue),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntegratedDailyLearningCard extends StatelessWidget {
  const _IntegratedDailyLearningCard({
    required this.learningSet,
    required this.completed,
    required this.onStudy,
  });

  final IntegratedDailyLearningSet? learningSet;
  final bool completed;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    final set = learningSet;
    final categoryNames = (set?.categories ?? const <String>[])
        .map(_categoryDisplayName)
        .join(' · ');
    final canStart = !completed && set != null && set.words.isNotEmpty;
    final countText = set == null
        ? '오늘의 단어 준비 중'
        : completed
        ? '${set.actualWordCount}개 단어 학습 완료'
        : '${set.actualWordCount}개 단어';

    return Semantics(
      button: canStart,
      label: completed ? countText : '$countText 학습 시작',
      child: SizedBox(
        height: 190,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 26,
              bottom: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canStart ? onStudy : null,
                  borderRadius: BorderRadius.circular(28),
                  child: Ink(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: completed
                            ? const [Color(0xFFE2E6EE), Color(0xFFCBD2DE)]
                            : const [Color(0xFF6898F4), Color(0xFF386FE2)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: completed ? 0.55 : 0.3,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (completed
                                      ? const Color(0xFF8D96A8)
                                      : const Color(0xFF386FE2))
                                  .withValues(alpha: 0.24),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 20,
                          top: 19,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: completed
                                  ? const Color(0xFFF1F3F7)
                                  : Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              completed
                                  ? Icons.check_rounded
                                  : Icons.play_arrow_rounded,
                              color: completed
                                  ? const Color(0xFF667085)
                                  : Colors.white,
                              size: 23,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 20,
                          right: 124,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                countText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: completed
                                      ? const Color(0xFF465063)
                                      : Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                set == null || categoryNames.isEmpty
                                    ? '학습 정보를 불러오고 있어요'
                                    : categoryNames,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: completed
                                      ? const Color(0xFF697386)
                                      : Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 2,
              top: -2,
              child: IgnorePointer(
                child: Opacity(
                  opacity: completed ? 0.52 : 1,
                  child: _learningPlayImage(completed: completed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _learningPlayImage({bool completed = false}) => Image.asset(
    completed
        ? 'assets/categories/playicon_completed.png'
        : 'assets/categories/playicon_transparent.png',
    width: 150,
    height: 150,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    errorBuilder: (context, error, stackTrace) => const SizedBox(
      width: 150,
      height: 150,
      child: Icon(Icons.menu_book_rounded, size: 82, color: Colors.white70),
    ),
  );
}

class _LearningProgressSummaryCard extends StatelessWidget {
  const _LearningProgressSummaryCard({
    required this.progress,
    required this.completedDailyCount,
    required this.totalDailyCount,
    required this.completedCategoryCount,
    required this.reviewStatusText,
  });

  final double progress;
  final int completedDailyCount;
  final int totalDailyCount;
  final int completedCategoryCount;
  final String reviewStatusText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: _dashboardClayDecoration(radius: 28),
      child: Row(
        children: [
          _CircularLearningProgress(progress: progress),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completedDailyCount/$totalDailyCount \uD559\uC2B5 \uC9C4\uD589',
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '\uCE74\uD14C\uACE0\uB9AC $completedCategoryCount\uAC1C \uC644\uB8CC',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  reviewStatusText,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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

class _CircularLearningProgress extends StatelessWidget {
  const _CircularLearningProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0.0, 1.0) * 100).round();
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size.square(104),
            painter: _CircularLearningProgressPainter(progress: progress),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '\uC9C4\uD589 \uD604\uD669',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircularLearningProgressPainter extends CustomPainter {
  const _CircularLearningProgressPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const strokeWidth = 8.0;
    final trackPaint = Paint()
      ..color = const Color(0xFFE5ECF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = const Color(0xFF5B8DEF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      0,
      math.pi * 2,
      false,
      trackPaint,
    );
    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularLearningProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _CategoryCarousel extends StatelessWidget {
  const _CategoryCarousel({
    required this.categories,
    required this.completedCategories,
    required this.onStudy,
  });

  final List<MainCategory> categories;
  final Map<String, bool> completedCategories;
  final ValueChanged<String> onStudy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = math.max(148.0, constraints.maxWidth * 0.40);
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final category = categories[index];
              return SizedBox(
                width: cardWidth,
                child: _CategoryLearningCard(
                  category: category,
                  completed: completedCategories[category.categoryKey] ?? false,
                  onStudy: () => onStudy(category.categoryKey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryLearningCard extends StatelessWidget {
  const _CategoryLearningCard({
    required this.category,
    required this.completed,
    required this.onStudy,
  });

  final MainCategory category;
  final bool completed;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _dashboardClayDecoration(radius: 26, completed: completed),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _categoryDisplayName(category.categoryKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: completed ? _blue : const Color(0xFF111827),
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Image.asset(
              category.imageAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: completed ? null : onStudy,
              style: FilledButton.styleFrom(
                backgroundColor: completed
                    ? const Color(0xFFEAF2FF)
                    : const Color(0xFF5B8DEF),
                disabledBackgroundColor: const Color(0xFFEAF2FF),
                foregroundColor: completed ? _blue : Colors.white,
                disabledForegroundColor: _blue,
                elevation: completed ? 0 : 3,
                shadowColor: const Color(0x665B8EF3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: completed
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 18),
                        SizedBox(width: 5),
                        Text('\uC644\uB8CC'),
                      ],
                    )
                  : const Text('\uD559\uC2B5\uD558\uAE30'),
            ),
          ),
        ],
      ),
    );
  }
}

String _categoryDisplayName(String categoryKey) {
  return switch (categoryKey) {
    'economy' => '\uACBD\uC81C',
    'technology' => '\uAE30\uC220',
    'politics' => '\uC815\uCE58',
    'world' => '\uAD6D\uC81C',
    'society' => '\uC0AC\uD68C',
    _ => categoryKey,
  };
}

BoxDecoration _dashboardClayDecoration({
  double radius = 26,
  bool completed = false,
}) {
  return BoxDecoration(
    color: completed ? const Color(0xFFEAF2FF) : const Color(0xFFFDFEFF),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFEAF2FF), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.06),
        offset: const Offset(0, 8),
        blurRadius: 18,
      ),
    ],
  );
}

// ignore: unused_element
class _TodayLearningCleanSection extends StatelessWidget {
  const _TodayLearningCleanSection({
    required this.topPadding,
    required this.tasks,
    required this.selectedTaskId,
    required this.isLoading,
    required this.onTaskTap,
    required this.onStudy,
    required this.onReview,
  });

  final double topPadding;
  final List<_LearningTask> tasks;
  final String? selectedTaskId;
  final bool isLoading;
  final ValueChanged<String> onTaskTap;
  final ValueChanged<String> onStudy;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: EdgeInsets.only(top: topPadding, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 학습',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 17),
          _AlignedLearningTimeline(
            tasks: tasks,
            selectedTaskId: selectedTaskId,
            onTaskTap: onTaskTap,
            onStudy: onStudy,
            onReview: onReview,
          ),
        ],
      ),
    );
  }
}

class _TodayLearningStackedSection extends StatelessWidget {
  const _TodayLearningStackedSection({
    required this.topPadding,
    required this.tasks,
    required this.selectedTaskId,
    required this.isLoading,
    required this.onTaskTap,
    required this.onStudy,
    required this.onReview,
  });

  final double topPadding;
  final List<_LearningTask> tasks;
  final String? selectedTaskId;
  final bool isLoading;
  final ValueChanged<String> onTaskTap;
  final ValueChanged<String> onStudy;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return SingleChildScrollView(
      clipBehavior: Clip.none,
      padding: EdgeInsets.only(top: topPadding, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 학습',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 17),
          _AlignedLearningTimeline(
            tasks: tasks,
            selectedTaskId: selectedTaskId,
            onTaskTap: onTaskTap,
            onStudy: onStudy,
            onReview: onReview,
          ),
        ],
      ),
    );
  }
}

class _AlignedLearningTimeline extends StatelessWidget {
  const _AlignedLearningTimeline({
    required this.tasks,
    required this.selectedTaskId,
    required this.onTaskTap,
    required this.onStudy,
    required this.onReview,
  });

  final List<_LearningTask> tasks;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskTap;
  final ValueChanged<String> onStudy;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(tasks.length, (index) {
        final task = tasks[index];
        final expanded = selectedTaskId == task.id;
        return _AlignedTimelineRow(
          task: task,
          expanded: expanded,
          isFirst: index == 0,
          isLast: index == tasks.length - 1,
          previousCompleted: index > 0 && tasks[index - 1].completed,
          onTap: () => onTaskTap(task.id),
          onStart: () =>
              task.isReview ? onReview() : onStudy(task.category!.categoryKey),
        );
      }),
    );
  }
}

class _AlignedTimelineRow extends StatelessWidget {
  const _AlignedTimelineRow({
    required this.task,
    required this.expanded,
    required this.isFirst,
    required this.isLast,
    required this.previousCompleted,
    required this.onTap,
    required this.onStart,
  });

  final _LearningTask task;
  final bool expanded;
  final bool isFirst;
  final bool isLast;
  final bool previousCompleted;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final rowHeight = expanded ? 182.0 : 72.0;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 38,
            height: rowHeight,
            child: _AlignedTimelineNode(
              completed: task.completed,
              active: expanded,
              isFirst: isFirst,
              isLast: isLast,
              previousCompleted: previousCompleted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: expanded
                  ? _ExpandedClayTaskCard(
                      key: ValueKey('expanded-clay-${task.id}'),
                      task: task,
                      onTap: onTap,
                      onStart: onStart,
                    )
                  : _CollapsedClayTaskCard(
                      key: ValueKey('collapsed-clay-${task.id}'),
                      task: task,
                      onTap: onTap,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlignedTimelineNode extends StatelessWidget {
  const _AlignedTimelineNode({
    required this.completed,
    required this.active,
    required this.isFirst,
    required this.isLast,
    required this.previousCompleted,
  });

  final bool completed;
  final bool active;
  final bool isFirst;
  final bool isLast;
  final bool previousCompleted;

  @override
  Widget build(BuildContext context) {
    final nodeColor = completed || active ? _blue : const Color(0xFFBDBDBD);
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: isFirst
                        ? Colors.transparent
                        : previousCompleted
                        ? _blue
                        : const Color(0xFFD0D4DC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: isLast
                        ? Colors.transparent
                        : completed
                        ? _blue
                        : const Color(0xFFD0D4DC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: completed ? _blue : const Color(0xFFFBFCFF),
            shape: BoxShape.circle,
            border: Border.all(color: nodeColor, width: active ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.85),
                blurRadius: 8,
                offset: const Offset(-3, -3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(
                  completed || active ? 0.10 : 0.05,
                ),
                blurRadius: 12,
                offset: const Offset(5, 6),
              ),
            ],
          ),
          child: completed
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : null,
        ),
      ],
    );
  }
}

class _CollapsedClayTaskCard extends StatelessWidget {
  const _CollapsedClayTaskCard({
    super.key,
    required this.task,
    required this.onTap,
  });

  final _LearningTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = task.completed;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: _taskClayDecoration(completed: completed),
        child: Row(
          children: [
            Expanded(
              child: Text(
                completed && !task.isReview ? '${task.title} 완료' : task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: completed ? _blue : const Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: completed ? _blue : const Color(0xFFC1C7D3),
              size: completed ? 24 : 27,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedClayTaskCard extends StatelessWidget {
  const _ExpandedClayTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onStart,
  });

  final _LearningTask task;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final completed = task.completed;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _taskClayDecoration(completed: completed, expanded: true),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: completed ? Colors.white : const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 8,
                        offset: const Offset(-3, -3),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(4, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    completed ? Icons.check_rounded : task.icon,
                    color: _blue,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        completed && !task.isReview
                            ? '${task.title} 학습 완료'
                            : task.expandedTitle,
                        style: TextStyle(
                          color: completed ? _blue : const Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        task.description,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFFC1C7D3),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: completed ? null : onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: Colors.white,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: _blue,
                  elevation: completed ? 0 : 3,
                  shadowColor: const Color(0x665B8EF3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: Text(completed ? '완료' : task.actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _taskClayDecoration({
  required bool completed,
  bool expanded = false,
}) {
  return BoxDecoration(
    color: completed ? const Color(0xFFEAF2FF) : const Color(0xFFFBFCFF),
    borderRadius: BorderRadius.circular(expanded ? 28 : 24),
    border: Border.all(
      color: completed
          ? _blue.withOpacity(0.18)
          : Colors.white.withOpacity(0.86),
      width: 1.2,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.white.withOpacity(0.76),
        offset: const Offset(-4, -4),
        blurRadius: 10,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(completed ? 0.075 : 0.06),
        offset: const Offset(8, 10),
        blurRadius: 20,
      ),
    ],
  );
}

class _TodayLearningSection extends StatelessWidget {
  const _TodayLearningSection({
    required this.tasks,
    required this.selectedTaskId,
    required this.isLoading,
    required this.onTaskTap,
    required this.onStudy,
    required this.onReview,
  });

  final List<_LearningTask> tasks;
  final String? selectedTaskId;
  final bool isLoading;
  final ValueChanged<String> onTaskTap;
  final ValueChanged<String> onStudy;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '오늘의 학습',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LearningTimeline(
                    tasks: tasks,
                    selectedTaskId: selectedTaskId,
                    onTaskTap: onTaskTap,
                    onStudy: onStudy,
                    onReview: onReview,
                  ),
                ),
        ),
      ],
    );
  }
}

class _LearningTimeline extends StatelessWidget {
  const _LearningTimeline({
    required this.tasks,
    required this.selectedTaskId,
    required this.onTaskTap,
    required this.onStudy,
    required this.onReview,
  });

  final List<_LearningTask> tasks;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskTap;
  final ValueChanged<String> onStudy;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TimelineColumn(tasks: tasks, selectedTaskId: selectedTaskId),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            children: List.generate(tasks.length, (index) {
              final task = tasks[index];
              final expanded = selectedTaskId == task.id;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == tasks.length - 1 ? 0 : 12,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: expanded
                      ? _ExpandedLearningTaskCard(
                          key: ValueKey('expanded-${task.id}'),
                          task: task,
                          onTap: () => onTaskTap(task.id),
                          onStart: () => task.isReview
                              ? onReview()
                              : onStudy(task.category!.categoryKey),
                        )
                      : _LearningTaskCard(
                          key: ValueKey('collapsed-${task.id}'),
                          task: task,
                          onTap: () => onTaskTap(task.id),
                        ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _TimelineColumn extends StatelessWidget {
  const _TimelineColumn({required this.tasks, required this.selectedTaskId});

  final List<_LearningTask> tasks;
  final String? selectedTaskId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(tasks.length, (index) {
        final task = tasks[index];
        final active = selectedTaskId == task.id;
        final isLast = index == tasks.length - 1;
        return _TimelineNode(
          completed: task.completed,
          active: active,
          isLast: isLast,
        );
      }),
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.completed,
    required this.active,
    required this.isLast,
  });

  final bool completed;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final nodeColor = completed || active ? _blue : const Color(0xFFBDBDBD);
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: completed ? _blue : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: nodeColor, width: active ? 3 : 2),
            boxShadow: completed || active
                ? [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: completed
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
              : null,
        ),
        if (!isLast)
          Container(
            width: 3,
            height: active ? 116 : 72,
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: completed ? _blue : const Color(0xFFBDBDBD),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}

class _LearningTaskCard extends StatelessWidget {
  const _LearningTaskCard({super.key, required this.task, required this.onTap});

  final _LearningTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = task.completed;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: completed ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: _clayShadows(const Color(0xFFC7CBDD)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                completed && !task.isReview ? '${task.title} 완료' : task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: completed ? _blue : const Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              completed
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: completed ? _blue : const Color(0xFFC1C7D3),
              size: completed ? 23 : 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedLearningTaskCard extends StatelessWidget {
  const _ExpandedLearningTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onStart,
  });

  final _LearningTask task;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final completed = task.completed;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: completed ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: completed ? _blue.withValues(alpha: 0.24) : Colors.white,
            width: 1.2,
          ),
          boxShadow: _clayShadows(const Color(0xFFC7CBDD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: completed ? Colors.white : const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    completed ? Icons.check_rounded : task.icon,
                    color: _blue,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        completed && !task.isReview
                            ? '${task.title} 학습 완료'
                            : task.expandedTitle,
                        style: TextStyle(
                          color: completed ? _blue : const Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        task.description,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Color(0xFFC1C7D3),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: completed ? null : onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  disabledBackgroundColor: Colors.white,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: _blue,
                  elevation: completed ? 0 : 3,
                  shadowColor: const Color(0x665B8EF3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900),
                ),
                child: Text(completed ? '완료' : task.actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StickyStreakLayer extends StatelessWidget {
  const _StickyStreakLayer({required this.onCalendarTap});

  final VoidCallback onCalendarTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Column(
        children: [
          _StreakBanner(onTap: onCalendarTap),
          const IgnorePointer(child: _HeaderBlurMask()),
        ],
      ),
    );
  }
}

class _HeaderBlurMask extends StatelessWidget {
  const _HeaderBlurMask();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _clayBackground.withOpacity(0.72),
            _clayBackground.withOpacity(0.28),
            _clayBackground.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onCalendarTap});

  final VoidCallback onCalendarTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HomeLogo(),
        const SizedBox(height: 15),
        _StreakBanner(onTap: onCalendarTap),
      ],
    );
  }
}

class _HomeLogo extends StatelessWidget {
  const _HomeLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 34,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SvgPicture.asset(
          'assets/categories/images/logo.svg',
          width: 32,
          height: 32,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _HomeAccountButton extends StatelessWidget {
  const _HomeAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.person_outline_rounded,
            color: Color(0xFF4B5563),
            size: 23,
          ),
        ),
      ),
    );
  }
}

DateTime _homeDateFromString(String value) {
  final parts = value.split('-').map(int.tryParse).toList(growable: false);
  if (parts.length != 3 ||
      parts[0] == null ||
      parts[1] == null ||
      parts[2] == null) {
    return DateTime.now();
  }
  return DateTime(parts[0]!, parts[1]!, parts[2]!);
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({
    required this.onTap,
    this.streakCount = 0,
    this.monthlyStudyDays = 0,
    this.loading = false,
  });

  final VoidCallback onTap;
  final int? streakCount;
  final int? monthlyStudyDays;
  final bool? loading;

  @override
  Widget build(BuildContext context) {
    final safeStreakCount = streakCount ?? 0;
    final safeMonthlyStudyDays = monthlyStudyDays ?? 0;
    final isLoading = loading == true;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF75A4FF), _blue],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
          boxShadow: _clayShadows(const Color(0xFF6D8FE8)),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 17,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.local_fire_department_rounded,
                color: _blue,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isLoading ? '학습 기록 불러오는 중' : '$safeStreakCount일 연속 학습 중',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '이번 달 $safeMonthlyStudyDays일 학습 · 캘린더 보기',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _MainCategoryCard extends StatelessWidget {
  const _MainCategoryCard({
    required this.category,
    required this.completed,
    required this.onStudy,
  });

  final MainCategory category;
  final bool completed;
  final VoidCallback onStudy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
      decoration: _clayDecoration(
        radius: 30,
        shadowColor: const Color(0xFFB6A8D4),
      ),
      child: Column(
        children: [
          Text(
            category.name,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Image.asset(
                category.imageAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                semanticLabel: '${category.name} 분야 이미지',
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: completed ? null : onStudy,
              style: FilledButton.styleFrom(
                backgroundColor: completed ? const Color(0xFFAEB4C0) : _blue,
                disabledBackgroundColor: const Color(0xFFAEB4C0),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 3,
                shadowColor: completed
                    ? const Color(0x33000000)
                    : const Color(0x665B8EF3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: completed
                  ? const Text(
                      '학습 완료',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  : const Text(
                      '학습하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: index == currentIndex ? 18 : 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: index == currentIndex ? _ink : const Color(0xFFD8DCE4),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
