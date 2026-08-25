part of '../main.dart';

typedef OnboardingPreferenceSaver =
    Future<void> Function({
      required String userId,
      required List<String> categories,
      required int dailyWordGoal,
    });

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.userId,
    this.onCompleted,
    this.preferenceSaver,
    this.completionSaver,
    this.preferenceSaveTimeout = const Duration(seconds: 15),
    this.completionSaveTimeout = const Duration(seconds: 5),
  });

  final String userId;
  final VoidCallback? onCompleted;
  final OnboardingPreferenceSaver? preferenceSaver;
  final Future<void> Function(String uid)? completionSaver;
  final Duration preferenceSaveTimeout;
  final Duration completionSaveTimeout;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  static const int _pageCount = 4;
  final PageController _pageController = PageController();
  late final AnimationController _entranceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final AnimationController _floatController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  int _pageIndex = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _pageIndex = index);
    _entranceController.forward(from: 0);
  }

  Future<void> _next() async {
    if (_pageIndex < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    _logOnboardingSaveStep('save start');
    var saveStage = 'authentication';
    var didComplete = false;
    String? failureMessage;
    try {
      if (widget.preferenceSaver == null) {
        _logOnboardingSaveStep('auth uid check start');
        final currentUser = AuthService.currentUser;
        if (currentUser == null || currentUser.isAnonymous) {
          throw StateError('Authenticated user is unavailable.');
        }
        if (currentUser.uid != widget.userId) {
          throw StateError('Authenticated user does not match onboarding.');
        }
        _logOnboardingSaveStep('auth uid ready');
      }

      // V2 has no onboarding preferences. Do not overwrite the legacy
      // category or daily_word_goal fields when onboarding completes.

      saveStage = 'local_completion';
      _logOnboardingSaveStep('local completion flag start');
      await (widget.completionSaver ?? OnboardingService.setCompleted)(
        widget.userId,
      ).timeout(widget.completionSaveTimeout);
      _logOnboardingSaveStep('local completion flag done');

      if (!mounted) return;
      saveStage = 'navigation';
      final onCompleted = widget.onCompleted;
      if (onCompleted == null) {
        throw StateError('Onboarding completion handler is unavailable.');
      }
      _logOnboardingSaveStep('navigate home');
      onCompleted();
      didComplete = true;
    } on TimeoutException catch (error, stackTrace) {
      _logOnboardingSaveFailure(saveStage, error, stackTrace);
      failureMessage = '저장에 시간이 오래 걸리고 있어요. 다시 시도해 주세요.';
    } catch (error, stackTrace) {
      _logOnboardingSaveFailure(saveStage, error, stackTrace);
      failureMessage = '학습 설정을 저장하지 못했어요. 다시 시도해 주세요.';
    } finally {
      if (!didComplete && mounted) {
        setState(() => _finishing = false);
      }
    }

    if (failureMessage != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  void _logOnboardingSaveStep(String message) {
    if (kDebugMode) debugPrint('[Onboarding] $message');
  }

  void _logOnboardingSaveFailure(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;
    if (error is FirebaseException) {
      debugPrint(
        '[Onboarding] save failed stage=$stage '
        'plugin=${error.plugin} code=${error.code} message=${error.message}',
      );
    } else {
      debugPrint(
        '[Onboarding] save failed stage=$stage type=${error.runtimeType} '
        'error=$error',
      );
    }
    debugPrintStack(
      label: '[Onboarding] save failure stack',
      stackTrace: stackTrace,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_pageBackground, Color(0xFFFFFBFF), Color(0xFFEAF5FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  children: [
                    _IntroPageShell(
                      title: 'NEWSVOCA로\n시사와 영어공부를 한번에',
                      description: '뉴스를 통해 영어 단어와\n오늘의 이슈를 함께 익혀보세요.',
                      animation: _entranceController,
                      visual: _BrandIntroVisual(
                        animation: _entranceController,
                        floatAnimation: _floatController,
                      ),
                    ),
                    _IntroPageShell(
                      title: '매일 새로운 기사로\n오늘의 이슈를 배워요',
                      description: '기사는 매일 오전 6시에\n새롭게 업데이트돼요.',
                      animation: _entranceController,
                      visual: _NewsUpdateVisual(animation: _entranceController),
                    ),
                    _IntroPageShell(
                      title: '기사 속 단어와 표현을 익히고\n퀴즈로 확인해요',
                      description: '오늘 배운 내용은\n퀴즈로 바로 점검할 수 있어요.',
                      animation: _entranceController,
                      visual: _LearningFlowVisual(
                        animation: _entranceController,
                      ),
                    ),
                    _IntroPageShell(
                      title: '저장한 단어와 틀린 단어를\n다시 복습해요',
                      description:
                          '기사에서 저장한 단어와 퀴즈에서 틀린 단어를 모아\n필요한 순간에 다시 복습해요.',
                      animation: _entranceController,
                      visual: _ReviewIntroVisual(
                        animation: _entranceController,
                        active: _pageIndex == 3,
                      ),
                    ),
                  ],
                ),
              ),
              _OnboardingIndicator(
                currentIndex: _pageIndex,
                pageCount: _pageCount,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _finishing ? null : _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0x665B8EF3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(19),
                      ),
                    ),
                    child: Text(
                      _finishing
                          ? '저장 중...'
                          : _pageIndex == _pageCount - 1
                          ? '시작하기'
                          : '다음',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPageShell extends StatelessWidget {
  const _IntroPageShell({
    required this.title,
    required this.description,
    required this.visual,
    required this.animation,
  });

  final String title;
  final String description;
  final Widget visual;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _IntroReveal(
                animation: animation,
                begin: 0,
                end: 0.7,
                child: visual,
              ),
              const SizedBox(height: 30),
              _IntroReveal(
                animation: animation,
                begin: 0.18,
                end: 0.78,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 27,
                    height: 1.25,
                    letterSpacing: -0.7,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              _IntroReveal(
                animation: animation,
                begin: 0.38,
                end: 1,
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroReveal extends StatelessWidget {
  const _IntroReveal({
    required this.animation,
    required this.begin,
    required this.end,
    required this.child,
    this.offset = 22,
  });

  final Animation<double> animation;
  final double begin;
  final double end;
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          ((animation.value - begin) / (end - begin)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - progress)),
            child: Transform.scale(
              scale: 0.96 + (0.04 * progress),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _OnboardingIndicator extends StatelessWidget {
  const _OnboardingIndicator({
    required this.currentIndex,
    required this.pageCount,
  });

  final int currentIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) => AnimatedContainer(
          key: ValueKey('onboarding_indicator_$index'),
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          width: index == currentIndex ? 26 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: index == currentIndex ? _blue : const Color(0xFFD7D9E7),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _BrandIntroVisual extends StatelessWidget {
  const _BrandIntroVisual({
    required this.animation,
    required this.floatAnimation,
  });

  final Animation<double> animation;
  final Animation<double> floatAnimation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -4 + (floatAnimation.value * 8)),
        child: child,
      ),
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF79A7FF).withValues(alpha: 0.28),
                    const Color(0xFFEAF2FF).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Container(
              width: 132,
              height: 132,
              padding: const EdgeInsets.all(22),
              decoration: _introCardDecoration(radius: 38),
              child: Image.asset(
                'assets/categories/images/logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text(
                    'N',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsUpdateVisual extends StatelessWidget {
  const _NewsUpdateVisual({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    const news = [
      ('기술', 'AI regulation', Icons.memory_rounded),
      ('경제', 'Interest rate', Icons.trending_up_rounded),
      ('국제', 'Diplomacy', Icons.public_rounded),
    ];
    return SizedBox(
      width: 330,
      child: Column(
        children: [
          for (var index = 0; index < news.length; index++) ...[
            _IntroReveal(
              animation: animation,
              begin: 0.12 + (index * 0.13),
              end: 0.56 + (index * 0.13),
              child: _MiniNewsCard(
                category: news[index].$1,
                keyword: news[index].$2,
                icon: news[index].$3,
              ),
            ),
            if (index != news.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _MiniNewsCard extends StatelessWidget {
  const _MiniNewsCard({
    required this.category,
    required this.keyword,
    required this.icon,
  });
  final String category;
  final String keyword;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: _introCardDecoration(radius: 22),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF2FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _blue, size: 20),
          ),
          const SizedBox(width: 12),
          _IntroPill(label: category),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              keyword,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningFlowVisual extends StatelessWidget {
  const _LearningFlowVisual({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Column(
        children: [
          _IntroReveal(
            animation: animation,
            begin: 0,
            end: 0.45,
            child: _IntroCard(
              color: const Color(0xFFEAF2FF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      _IntroPill(label: '1/9', selected: true),
                      SizedBox(width: 7),
                      _IntroPill(label: '국제'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'diplomacy',
                    style: TextStyle(
                      color: _blue,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    '외교, 외교적 협상',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          ),
          const _FlowArrow(),
          _IntroReveal(
            animation: animation,
            begin: 0.18,
            end: 0.65,
            child: _IntroCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '이렇게 써요',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        color: Color(0xFF374151),
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                      children: buildHighlightedTextSpans(
                        'The success of diplomacy can ease tensions.',
                        'diplomacy',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _FlowArrow(),
          _IntroReveal(
            animation: animation,
            begin: 0.38,
            end: 0.86,
            child: const _IntroCard(
              color: Color(0xFF5B8EF3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mini Quiz',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '_____ helps ease tensions.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
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

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFB4B8C8)),
  );
}

class _ReviewIntroVisual extends StatefulWidget {
  const _ReviewIntroVisual({required this.animation, required this.active});
  final Animation<double> animation;
  final bool active;

  @override
  State<_ReviewIntroVisual> createState() => _ReviewIntroVisualState();
}

class _ReviewIntroVisualState extends State<_ReviewIntroVisual> {
  bool _isSaved = false;
  Timer? _demoTimer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _scheduleNextState();
  }

  @override
  void didUpdateWidget(covariant _ReviewIntroVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _isSaved = false;
      _scheduleNextState();
    } else if (oldWidget.active && !widget.active) {
      _demoTimer?.cancel();
      _demoTimer = null;
      _isSaved = false;
    }
  }

  void _scheduleNextState() {
    _demoTimer?.cancel();
    if (!widget.active) return;
    _demoTimer = Timer(
      _isSaved
          ? const Duration(milliseconds: 2800)
          : const Duration(milliseconds: 2200),
      () {
        if (!mounted || !widget.active) return;
        setState(() => _isSaved = !_isSaved);
        _scheduleNextState();
      },
    );
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Column(
        children: [
          _IntroReveal(
            animation: widget.animation,
            begin: 0,
            end: 0.45,
            child: _IntroCard(
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'sanction',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text('제재', style: TextStyle(color: Color(0xFF6B7280))),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isSaved ? _lime : const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Row(
                          key: ValueKey(_isSaved),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: const Color(0xFF397CF6),
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isSaved ? '저장됨' : '저장',
                              style: const TextStyle(
                                color: Color(0xFF397CF6),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _IntroReveal(
            animation: widget.animation,
            begin: 0.18,
            end: 0.65,
            child: _IntroCard(
              color: const Color(0xFFEAF2FF),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.replay_rounded, color: _blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey(_isSaved),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isSaved ? '복습 목록에 추가됐어요' : '저장한 단어는',
                            style: const TextStyle(
                              color: _blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _isSaved ? '다음 복습에서 다시 만나요' : '복습에 다시 나와요',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
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

class _SettingsIntroPage extends StatelessWidget {
  const _SettingsIntroPage({
    required this.title,
    required this.description,
    required this.animation,
    this.showCategorySelection = true,
    required this.selectedCategories,
    required this.dailyWordGoal,
    required this.onCategoryTap,
    required this.onGoalTap,
  });

  final String title;
  final String description;
  final Animation<double> animation;
  final bool showCategorySelection;
  final Set<String> selectedCategories;
  final int? dailyWordGoal;
  final ValueChanged<String> onCategoryTap;
  final ValueChanged<int> onGoalTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 26),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _IntroReveal(
                    animation: animation,
                    begin: 0,
                    end: 0.58,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 28,
                        height: 1.2,
                        letterSpacing: -0.7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _IntroReveal(
                    animation: animation,
                    begin: 0.12,
                    end: 0.7,
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _IntroReveal(
                    animation: animation,
                    begin: 0.22,
                    end: 0.88,
                    offset: 16,
                    child: _SettingsIntroVisual(
                      showCategorySelection: showCategorySelection,
                      selectedCategories: selectedCategories,
                      dailyWordGoal: dailyWordGoal,
                      onCategoryTap: onCategoryTap,
                      onGoalTap: onGoalTap,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsIntroVisual extends StatelessWidget {
  const _SettingsIntroVisual({
    this.showCategorySelection = true,
    required this.selectedCategories,
    required this.dailyWordGoal,
    required this.onCategoryTap,
    required this.onGoalTap,
  });

  static const _categories = [
    ('economy', '경제'),
    ('technology', '기술'),
    ('politics', '정치'),
    ('world', '국제'),
    ('society', '사회'),
  ];

  final bool showCategorySelection;
  final Set<String> selectedCategories;
  final int? dailyWordGoal;
  final ValueChanged<String> onCategoryTap;
  final ValueChanged<int> onGoalTap;

  @override
  Widget build(BuildContext context) {
    final availableGoals = showCategorySelection
        ? getAvailableDailyWordGoals(selectedCategories.length)
        : UserPreferenceService.dailyWordGoalOptions;
    return Column(
      children: [
        if (showCategorySelection)
          _OnboardingSectionCard(
            title: '관심 분야',
            description: '관심 있는 뉴스를 1개 이상 선택하세요.',
            child: LayoutBuilder(
              builder: (context, constraints) {
                const columns = 2;
                const spacing = 10.0;
                final itemWidth =
                    (constraints.maxWidth - (spacing * (columns - 1))) /
                    columns;
                return Wrap(
                  alignment: WrapAlignment.start,
                  spacing: spacing,
                  runSpacing: 10,
                  children: [
                    for (final category in _categories)
                      SizedBox(
                        width: itemWidth,
                        child: _CategoryChoiceCard(
                          label: category.$2,
                          selected: selectedCategories.contains(category.$1),
                          onTap: () => onCategoryTap(category.$1),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: showCategorySelection ? 16 : 0),
          child: _OnboardingSectionCard(
            title: '하루 학습 단어 수',
            description: showCategorySelection
                ? '선택한 관심 분야 수에 따라 가능한 개수가 달라져요.'
                : '하루에 학습할 단어 수를 선택하세요.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var index = 0; index < 3; index++) ...[
                      Expanded(
                        child: _DailyGoalChoiceCard(
                          goal: const [3, 9, 15][index],
                          timeLabel: const ['약 5분', '약 15분', '약 30분'][index],
                          selected: dailyWordGoal == const [3, 9, 15][index],
                          enabled: availableGoals.contains(
                            const [3, 9, 15][index],
                          ),
                          onTap: onGoalTap,
                        ),
                      ),
                      if (index != 2) const SizedBox(width: 10),
                    ],
                  ],
                ),
                if (showCategorySelection) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF6B82B8),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '분야별 하루 3개의 단어가 준비돼요. '
                          '9개는 3개 분야부터, 15개는 5개 분야부터 선택할 수 있어요. '
                          '(${selectedCategories.length}개 분야 선택)',
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingSectionCard extends StatelessWidget {
  const _OnboardingSectionCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8ECF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x168B96AB),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF202633),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF737B8C),
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _CategoryChoiceCard extends StatelessWidget {
  const _CategoryChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 관심 분야',
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: selected ? _blue : const Color(0xFFF6F8FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF5B8EF3) : const Color(0xFFE5E9F1),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? const Color(0x245B8EF3)
                  : const Color(0x128994AD),
              blurRadius: selected ? 10 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            hoverColor: selected
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE8F0FF),
            focusColor: selected
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE8F0FF),
            highlightColor: Colors.transparent,
            splashColor: _blue.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF3D4658),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyGoalChoiceCard extends StatelessWidget {
  const _DailyGoalChoiceCard({
    required this.goal,
    required this.timeLabel,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int goal;
  final String timeLabel;
  final bool selected;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '하루 $goal개 학습',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.42,
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            color: selected ? _blue : const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected
                  ? const Color(0xFF5B8EF3)
                  : const Color(0xFFE3E7EF),
              width: selected ? 1.4 : 1,
            ),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x1F8994AD),
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? () => onTap(goal) : null,
              hoverColor: selected
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE6EEFC),
              focusColor: selected
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE6EEFC),
              highlightColor: Colors.transparent,
              splashColor: _blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 14,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$goal개',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF374151),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.82)
                            : const Color(0xFF7B8190),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: _introCardDecoration(color: color, radius: 23),
    child: child,
  );
}

class _IntroPill extends StatelessWidget {
  const _IntroPill({required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: selected ? _blue : const Color(0xFFF0F2F8),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF596171),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

BoxDecoration _introCardDecoration({
  Color color = Colors.white,
  double radius = 26,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF9EA0B7).withValues(alpha: 0.16),
      blurRadius: 22,
      offset: const Offset(8, 11),
    ),
    BoxShadow(
      color: Colors.white.withValues(alpha: 0.72),
      blurRadius: 15,
      offset: const Offset(-6, -7),
    ),
  ],
);
