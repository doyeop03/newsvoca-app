part of '../main.dart';

typedef DailyLearningGuideVisibilityChecker = Future<bool> Function();
typedef DailyLearningGuideHideHandler = Future<void> Function();

class WordDetailScreen extends StatefulWidget {
  const WordDetailScreen({
    super.key,
    this.category = 'daily',
    this.integratedSet,
    this.dailyLearningGuideShouldShow,
    this.hideDailyLearningGuidePermanently,
  });

  final String category;
  final IntegratedDailyLearningSet? integratedSet;
  final DailyLearningGuideVisibilityChecker? dailyLearningGuideShouldShow;
  final DailyLearningGuideHideHandler? hideDailyLearningGuidePermanently;

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen>
    with WidgetsBindingObserver {
  int _wordIndex = 0;
  final Set<String> _savedWords = {};
  Set<String> _completedArticleIds = {};
  List<LearningWord> _words = const [];
  DailyIssueSet? _dailyIssueSet;
  bool _isLoading = true;
  String? _emptyMessage;
  String? _loadedLearningDate;
  Timer? _publishTimer;
  bool _hasUnsavedLearningProgress = true;
  bool _hasCheckedDailyLearningGuide = false;

  LearningWord get _word => _words[_wordIndex];
  bool get _isSaved => _savedWords.contains(_word.word);
  bool get _isLastWord => _wordIndex == _words.length - 1;

  bool _isArticleCompleted(RelatedArticle article) {
    return _completedArticleIds.contains(
      UserWordService.articleIdForArticle(article.data),
    );
  }

  Future<void> _refreshCompletedArticles() async {
    try {
      final ids = await UserWordService.getCompletedArticleIds();
      if (!mounted) return;
      setState(() => _completedArticleIds = ids);
    } catch (error) {
      // ignore: avoid_print
      print('getCompletedArticleIds failed: $error');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDailyWords();
    _schedulePublishReload();
  }

  @override
  void dispose() {
    _publishTimer?.cancel();
    TtsService.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final learningDate = appDateString();
    if (_loadedLearningDate != learningDate) {
      _loadDailyWords();
    }
    _schedulePublishReload();
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
      _loadDailyWords();
      _schedulePublishReload();
    });
  }

  Future<void> _loadDailyWords() async {
    final date = widget.integratedSet?.date ?? appDateString();
    _loadedLearningDate = date;
    // ignore: avoid_print
    print('Daily word date: $date');
    DailyIssueSet? loadedIssueSet = widget.integratedSet?.dailyIssueSet;
    if (widget.integratedSet == null) {
      loadedIssueSet = await DailyIssueService().load(date: date);
    }
    final data = widget.integratedSet == null
        ? (loadedIssueSet == null
              ? null
              : <String, dynamic>{'words': loadedIssueSet.learningWords})
        : <String, dynamic>{'words': widget.integratedSet!.words};

    if (!mounted) {
      return;
    }
    _dailyIssueSet = loadedIssueSet;

    if (data == null) {
      setState(() {
        _isLoading = false;
        _emptyMessage = '오늘의 단어 데이터가 없습니다.';
      });
      return;
    }

    final rawWords = data['words'];
    if (rawWords is! List || rawWords.isEmpty) {
      setState(() {
        _isLoading = false;
        _emptyMessage = '단어 데이터가 없습니다.';
      });
      return;
    }

    final completedArticleIds = await UserWordService.getCompletedArticleIds()
        .catchError((error) {
          // ignore: avoid_print
          print('getCompletedArticleIds failed: $error');
          return <String>{};
        });

    final loadedWords = <LearningWord>[];
    for (final item in rawWords) {
      if (item is! Map) {
        // ignore: avoid_print
        print('Skipping invalid word item: $item');
        continue;
      }

      final currentWord = item;
      final word = _stringValue(currentWord['word']);
      if (word.isEmpty) {
        // ignore: avoid_print
        print('Warning: skipping word item without word field: $currentWord');
        continue;
      }

      // ignore: avoid_print
      print('Current word data: $currentWord');
      // ignore: avoid_print
      print('word: ${_stringValue(currentWord['word'])}');
      // ignore: avoid_print
      print('meaning: ${_stringValue(currentWord['meaning'])}');
      // ignore: avoid_print
      print('description_ko: ${_stringValue(currentWord['description_ko'])}');

      loadedWords.add(_wordFromMap(currentWord, word));
    }

    // ignore: avoid_print
    print('Current word index: 0');
    if (loadedWords.isNotEmpty) {
      // ignore: avoid_print
      print('Current word: ${loadedWords.first.word}');
      // ignore: avoid_print
      print('description_ko: ${loadedWords.first.descriptionKo}');
      // ignore: avoid_print
      print(
        'Related articles count: ${loadedWords.first.relatedArticles.length}',
      );
    }

    setState(() {
      _words = loadedWords;
      _completedArticleIds = completedArticleIds;
      _wordIndex = 0;
      _isLoading = false;
      _emptyMessage = loadedWords.isEmpty ? '단어 데이터가 없습니다.' : null;
    });
    if (loadedWords.isNotEmpty) {
      _scheduleDailyLearningGuideCheck();
    }
  }

  void _scheduleDailyLearningGuideCheck() {
    if (_hasCheckedDailyLearningGuide) return;
    _hasCheckedDailyLearningGuide = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final checker =
          widget.dailyLearningGuideShouldShow ??
          DailyLearningGuideService.shouldShow;
      final shouldShow = await checker();
      if (!mounted ||
          !shouldShow ||
          _isLoading ||
          _emptyMessage != null ||
          _words.isEmpty ||
          _wordIndex != 0) {
        return;
      }
      await _showDailyLearningGuideDialog();
    });
  }

  Future<void> _showDailyLearningGuideDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _DailyLearningGuideDialog(
        onHidePermanently: () async {
          final hide =
              widget.hideDailyLearningGuidePermanently ??
              DailyLearningGuideService.hidePermanently;
          await hide();
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Map<String, dynamic> _wordData(LearningWord word) {
    final example = word.examples.isNotEmpty ? word.examples.first : null;
    return {
      'word': word.word,
      'meaning': word.meaning,
      'description_ko': word.descriptionKo.isNotEmpty
          ? word.descriptionKo
          : word.description,
      'example': example?.sentence ?? '',
      'example_ko': example?.translation ?? '',
      'category': word.category.isEmpty ? widget.category : word.category,
      if (word.topic.isNotEmpty) 'topic': word.topic,
      if (word.topicLabelKo.isNotEmpty) 'topic_label_ko': word.topicLabelKo,
      if (word.difficulty.isNotEmpty) 'level': word.difficulty,
    };
  }

  LearningWord _wordFromMap(Map<dynamic, dynamic> item, String word) {
    final currentWord = item;
    final rawMeaning = _stringValue(currentWord['meaning']);
    final meaning = rawMeaning.isNotEmpty ? rawMeaning : word;
    final descriptionText = _stringValue(currentWord['description_ko']);
    final example = _stringValue(currentWord['example']);
    final exampleKo = _stringValue(currentWord['example_ko']);
    final examples = <WordExample>[
      if (example.isNotEmpty || exampleKo.isNotEmpty)
        WordExample(example, exampleKo),
    ];

    final rawArticles = currentWord['related_articles'];
    final articleCandidates = rawArticles is List
        ? rawArticles
              .whereType<Map>()
              .map((article) {
                final articleData = Map<String, dynamic>.from(article);
                articleData['_learning_word'] = word;
                return RelatedArticle(
                  title: _stringValue(articleData['title']),
                  source: _stringValue(articleData['source']),
                  publishedAt: _stringValue(articleData['publishedAt']),
                  url: _stringValue(articleData['url']),
                  data: articleData,
                );
              })
              .where((article) => article.title.isNotEmpty)
              .toList()
        : <RelatedArticle>[];
    final relatedArticles = _selectTwoRelatedArticles(articleCandidates);

    return LearningWord(
      word: word,
      pronunciation: '',
      partOfSpeech: _stringValue(currentWord['part_of_speech']),
      meaning: meaning,
      description: descriptionText,
      descriptionKo: descriptionText,
      collocations: [
        if (_stringValue(currentWord['level']).isNotEmpty)
          _stringValue(currentWord['level']),
      ],
      examples: examples,
      articleTitles: relatedArticles.map((article) => article.title).toList(),
      relatedArticles: relatedArticles,
      color: _categoryColor(
        _stringValue(currentWord['category']).isEmpty
            ? widget.category
            : _stringValue(currentWord['category']),
      ),
      topics: [
        _stringValue(currentWord['category']).isEmpty
            ? widget.category
            : _stringValue(currentWord['category']),
      ],
      difficulty: _stringValue(currentWord['level']),
      week: 0,
      category: _stringValue(currentWord['category']).isEmpty
          ? widget.category
          : _stringValue(currentWord['category']),
      topic: _stringValue(currentWord['topic']),
      topicLabelKo: _stringValue(currentWord['topic_label_ko']),
    );
  }

  String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  List<RelatedArticle> _selectTwoRelatedArticles(
    List<RelatedArticle> candidates,
  ) {
    if (candidates.length <= 1) return candidates;

    final first = candidates.first;
    final differentSource = candidates.skip(1).where((article) {
      if (first.source.isEmpty || article.source.isEmpty) return false;
      return article.source.toLowerCase() != first.source.toLowerCase();
    });
    final second = differentSource.isNotEmpty
        ? differentSource.first
        : candidates[1];
    return [first, second];
  }

  Color _categoryColor(String category) {
    for (final mainCategory in mainCategories) {
      if (mainCategory.categoryKey == category) {
        return mainCategory.background;
      }
    }
    return const Color(0xFFEAF2FF);
  }

  // ignore: unused_element
  void _toggleSaved() {
    setState(() {
      if (_isSaved) {
        _savedWords.remove(_word.word);
      } else {
        _savedWords.add(_word.word);
      }
    });
    if (_isSaved) {
      UserWordService.saveWord(
        _wordData(_word),
        _word.category.isEmpty ? widget.category : _word.category,
      ).catchError((error) {
        // ignore: avoid_print
        print('saveWord failed: $error');
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isSaved ? '${_word.word}를 복습 목록에 추가했어요.' : '복습 목록에서 제거했어요.',
        ),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showNextWord() async {
    if (_isLastWord) {
      setState(() => _hasUnsavedLearningProgress = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _dailyIssueSet != null
              ? IssueQuizPage(issueSet: _dailyIssueSet!, issueIndex: 0)
              : DailyQuizPage(
                  category: widget.integratedSet == null
                      ? widget.category
                      : 'daily',
                  words: _words,
                  learningDate: _loadedLearningDate ?? appDateString(),
                  categories: widget.integratedSet?.categories ?? const [],
                  dailyWordGoal: widget.integratedSet?.requestedGoal,
                ),
        ),
      );
      if (mounted) {
        setState(() => _hasUnsavedLearningProgress = true);
      }
      return;
    }

    if (_isLastWord) {
      setState(() => _wordIndex = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('학습 완료'),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _wordIndex++);
    // ignore: avoid_print
    print('Current word index: $_wordIndex');
    // ignore: avoid_print
    print('Current word: ${_word.word}');
    // ignore: avoid_print
    print('description_ko: ${_word.descriptionKo}');
    // ignore: avoid_print
    print('Related articles count: ${_word.relatedArticles.length}');
  }

  void _showPreviousWord() {
    if (_wordIndex == 0) {
      return;
    }
    setState(() => _wordIndex--);
  }

  Future<bool> _confirmExitLearning() async {
    // ignore: avoid_print
    print('[learning-exit] back requested');
    if (!_hasUnsavedLearningProgress) return true;
    // ignore: avoid_print
    print('[learning-exit] show confirm dialog');
    final shouldExit = await _showLearningExitConfirmation(context);
    if (shouldExit == true) {
      // ignore: avoid_print
      print('[learning-exit] exit confirmed');
      return true;
    }
    // ignore: avoid_print
    print('[learning-exit] continue learning');
    return false;
  }

  Future<void> _requestExitLearning() async {
    if (!await _confirmExitLearning() || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _emptyMessage != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _requestExitLearning();
        },
        child: Scaffold(
          backgroundColor: _clayBackground,
          appBar: AppBar(
            backgroundColor: _clayBackground,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              onPressed: _requestExitLearning,
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
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(22),
                      child: Text(
                        _emptyMessage!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExitLearning();
      },
      child: Scaffold(
        backgroundColor: _clayBackground,
        appBar: AppBar(
          backgroundColor: _clayBackground,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: _requestExitLearning,
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
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 35),
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Column(
                    key: ValueKey(_word.word),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WordCardLabels(
                        word: _word,
                        current: _wordIndex + 1,
                        total: _words.length,
                      ),
                      const SizedBox(height: 10),
                      _FlipWordCard(
                        key: ValueKey('card-${_word.word}'),
                        word: _word,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        '이렇게 써요',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_word.examples.isEmpty)
                        const Text('예문이 없습니다.')
                      else
                        ...List.generate(_word.examples.length, (index) {
                          final example = _word.examples[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _word.examples.length - 1
                                  ? 0
                                  : 12,
                            ),
                            child: _ExampleCard(
                              number: '${index + 1}'.padLeft(2, '0'),
                              sentence: example.sentence,
                              translation: example.translation,
                              keyword: _word.word,
                            ),
                          );
                        }),
                      const SizedBox(height: 30),
                      Text(
                        '이 단어가 나온 기사',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_word.relatedArticles.isEmpty)
                        const Text('관련 기사가 없습니다.')
                      else
                        ...List.generate(_word.relatedArticles.length, (index) {
                          final article = _word.relatedArticles[index];
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _word.relatedArticles.length - 1
                                  ? 0
                                  : 10,
                            ),
                            child: _RelatedArticleTitleCard(
                              title: article.title,
                              source: article.source,
                              publishedTime: article.publishedAt,
                              url: article.url,
                              completed: _isArticleCompleted(article),
                              onTap: () => _openArticle(context, article.data),
                            ),
                          );
                        }),
                      const SizedBox(height: 30),
                      _LearningWordNavigationButtons(
                        previousEnabled: _wordIndex > 0,
                        nextEnabled: !_isLastWord,
                        onPrevious: _showPreviousWord,
                        onNext: _showNextWord,
                        showDisabledButtons: false,
                      ),
                      if (_isLastWord) ...[
                        const SizedBox(height: 12),
                        _PrimaryButton(
                          label: _dailyIssueSet == null
                              ? '데일리 퀴즈 풀기'
                              : '이슈 퀴즈 시작하기',
                          onTap: _showNextWord,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openArticle(
    BuildContext context,
    Map<String, dynamic> article,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleLearningPage(article: article)),
    );
    if (mounted) {
      await _refreshCompletedArticles();
    }
  }
}

enum _DailyLearningGuideStepType { word, article, next }

class _DailyLearningGuideDialog extends StatefulWidget {
  const _DailyLearningGuideDialog({
    required this.onHidePermanently,
    required this.onClose,
  });

  final Future<void> Function() onHidePermanently;
  final VoidCallback onClose;

  @override
  State<_DailyLearningGuideDialog> createState() =>
      _DailyLearningGuideDialogState();
}

class _DailyLearningGuideDialogState extends State<_DailyLearningGuideDialog>
    with WidgetsBindingObserver {
  static const _autoAdvanceDelay = Duration(milliseconds: 2800);
  static const _pageAnimationDuration = Duration(milliseconds: 380);

  final PageController _pageController = PageController();
  Timer? _autoAdvanceTimer;
  int _currentPage = 0;
  bool _isClosing = false;

  static const _steps = [
    (
      type: _DailyLearningGuideStepType.word,
      title: '오늘의 단어를 확인해 보세요',
      description: '최신 뉴스에서 뽑은 관련 영어 단어를\n뜻과 예문으로 먼저 익혀보세요.',
    ),
    (
      type: _DailyLearningGuideStepType.article,
      title: '단어가 쓰인 기사를 확인해 보세요',
      description: '관련 기사를 함께 보면서\n단어가 실제 뉴스에서 어떻게 쓰였는지 확인해 보세요.',
    ),
    (
      type: _DailyLearningGuideStepType.next,
      title: '확인했다면 다음 단어로 넘어가세요',
      description: '단어와 관련 기사를 모두 확인한 뒤\n다음 단어로 넘어가 오늘의 학습을 이어가세요.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleAutoAdvance();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleAutoAdvance();
    } else {
      _autoAdvanceTimer?.cancel();
    }
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (_isClosing) return;
    _autoAdvanceTimer = Timer(_autoAdvanceDelay, () {
      if (!mounted || !_pageController.hasClients || _isClosing) return;
      _goToPage((_currentPage + 1) % _steps.length);
    });
  }

  void _goToPage(int page) {
    if (!_pageController.hasClients || _isClosing) return;
    _pageController.animateToPage(
      page,
      duration: _pageAnimationDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int page) {
    if (!mounted) return;
    setState(() => _currentPage = page);
    _scheduleAutoAdvance();
  }

  Future<void> _hidePermanently() async {
    if (_isClosing) return;
    setState(() => _isClosing = true);
    _autoAdvanceTimer?.cancel();
    await widget.onHidePermanently();
  }

  void _close() {
    if (_isClosing) return;
    _isClosing = true;
    _autoAdvanceTimer?.cancel();
    widget.onClose();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoAdvanceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height;
    final dialogHeight = math.min(600.0, availableHeight * 0.86);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Container(
        width: double.infinity,
        height: dialogHeight,
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE5E3EA)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '오늘의 단어, 이렇게 학습해요',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                height: 1.3,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final step = _steps[index];
                  return _DailyLearningGuideStep(
                    type: step.type,
                    title: step.title,
                    description: step.description,
                    active: index == _currentPage,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_steps.length, (index) {
                final selected = index == _currentPage;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: '${index + 1}단계 안내',
                  child: InkWell(
                    onTap: () => _goToPage(index),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: AnimatedContainer(
                        key: ValueKey('daily-learning-guide-dot-$index'),
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        width: selected ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: selected ? _blue : const Color(0xFFD9DEEA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: _isClosing ? null : _hidePermanently,
                      style: TextButton.styleFrom(
                        foregroundColor: _muted,
                        backgroundColor: const Color(0xFFF1F2F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        '다시 보지 않기',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: _isClosing ? null : _close,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0x665B8EF3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        '닫기',
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
    );
  }
}

class _DailyLearningGuideStep extends StatelessWidget {
  const _DailyLearningGuideStep({
    required this.type,
    required this.title,
    required this.description,
    required this.active,
  });

  final _DailyLearningGuideStepType type;
  final String title;
  final String description;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Column(
        children: [
          AnimatedSlide(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            offset: active ? Offset.zero : const Offset(0, 0.08),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 360),
              opacity: active ? 1 : 0.35,
              child: _DailyLearningGuidePreview(type: type),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyLearningGuidePreview extends StatelessWidget {
  const _DailyLearningGuidePreview({required this.type});

  final _DailyLearningGuideStepType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E9FA)),
      ),
      child: switch (type) {
        _DailyLearningGuideStepType.word => const _GuideWordPreview(),
        _DailyLearningGuideStepType.article => const _GuideArticlePreview(),
        _DailyLearningGuideStepType.next => const _GuideNextWordPreview(),
      },
    );
  }
}

class _GuideWordPreview extends StatelessWidget {
  const _GuideWordPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF78A6FF), _blue]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x305B8EF3),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MARKET',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '시장, 시장 상황  ·  noun',
                  style: TextStyle(
                    color: Color(0xFFEAF2FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 19,
            backgroundColor: Color(0xFFEAF2FF),
            child: Icon(Icons.volume_up_rounded, color: _blue, size: 20),
          ),
        ],
      ),
    );
  }
}

class _GuideArticlePreview extends StatelessWidget {
  const _GuideArticlePreview();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'MARKET',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(height: 2, color: const Color(0xFFB9CCF6)),
              const CircleAvatar(radius: 4, backgroundColor: _blue),
            ],
          ),
        ),
        Container(
          width: 142,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E6EF)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.article_outlined, color: _blue, size: 24),
              SizedBox(height: 8),
              _GuideLine(widthFactor: 1),
              SizedBox(height: 6),
              _GuideLine(widthFactor: 0.68),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideNextWordPreview extends StatelessWidget {
  const _GuideNextWordPreview();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _GuideMiniWordCard(word: 'MARKET', muted: true),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 9),
              child: Icon(Icons.arrow_forward_rounded, color: _blue, size: 23),
            ),
            _GuideMiniWordCard(word: 'POLICY'),
          ],
        ),
        const SizedBox(height: 13),
        AnimatedContainer(
          duration: const Duration(milliseconds: 360),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE2EBFF),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            '1 / 3  →  2 / 3',
            style: TextStyle(
              color: _blue,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideMiniWordCard extends StatelessWidget {
  const _GuideMiniWordCard({required this.word, this.muted = false});

  final String word;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFDDE5F5) : _blue,
        borderRadius: BorderRadius.circular(15),
        boxShadow: muted
            ? null
            : const [
                BoxShadow(
                  color: Color(0x305B8EF3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Text(
        word,
        style: TextStyle(
          color: muted ? const Color(0xFF758198) : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFDDE3EE),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _FlipWordCard extends StatefulWidget {
  const _FlipWordCard({super.key, required this.word});

  final LearningWord word;

  @override
  State<_FlipWordCard> createState() => _FlipWordCardState();
}

class _FlipWordCardState extends State<_FlipWordCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  bool get _showingMeaning => _controller.value >= 0.5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() =>
      _showingMeaning ? _controller.reverse() : _controller.forward();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '단어 카드를 뒤집어서 뜻 확인하기',
      child: GestureDetector(
        onTap: _flip,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final angle = _controller.value * math.pi;
            final showBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(showBack ? math.pi : 0),
                child: showBack
                    ? _WordCardBack(word: widget.word)
                    : _WordCardFront(word: widget.word),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WordCardLabels extends StatelessWidget {
  const _WordCardLabels({
    required this.word,
    required this.current,
    required this.total,
  });

  final LearningWord word;
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF315FAF).withValues(alpha: 0.24),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.20),
                blurRadius: 5,
                offset: const Offset(-2, -2),
              ),
            ],
          ),
          child: Text(
            '$current/$total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (word.category.isNotEmpty) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: word.color,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
            ),
            child: Text(
              _categoryDisplayName(word.category),
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _WordCardFront extends StatelessWidget {
  const _WordCardFront({required this.word});
  final LearningWord word;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF75A4FF), _blue],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: _clayShadows(const Color(0xFF6D8FE8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            word.word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          _ListenButton(word: word.word),
          const Spacer(),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rotate_right_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                '눌러서 뜻 보기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEAF2FF),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: () => TtsService.speakEnglishText(word),
        borderRadius: BorderRadius.circular(30),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_up_rounded, color: _blue, size: 19),
              SizedBox(width: 7),
              Text(
                '듣기',
                style: TextStyle(
                  color: _blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCardBack extends StatelessWidget {
  const _WordCardBack({required this.word});
  final LearningWord word;

  @override
  Widget build(BuildContext context) {
    final description = word.descriptionKo;
    final metadata = [
      formatPartOfSpeech(word.partOfSpeech),
      formatLearningLevel(word.difficulty),
    ].where((item) => item.isNotEmpty).toList(growable: false);

    return Container(
      width: double.infinity,
      height: 260,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF75A4FF), _blue],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: _clayShadows(const Color(0xFF6D8FE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            word.meaning,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: metadata.map((item) => _Pill(label: item)).toList(),
          ),
          const Spacer(),
          const Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.rotate_left_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelatedArticleTitleCard extends StatelessWidget {
  const _RelatedArticleTitleCard({
    required this.title,
    required this.source,
    required this.publishedTime,
    required this.url,
    required this.completed,
    required this.onTap,
  });
  final String title;
  final String source;
  final String publishedTime;
  final String url;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: _clayDecoration(
          radius: 20,
          shadowColor: const Color(0xFFC7CBDD),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF191C21),
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFF8A91A0),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            if (source.isNotEmpty) source,
                            if (publishedTime.isNotEmpty) publishedTime,
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8A91A0),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (completed)
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC1C7D3),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.number,
    required this.sentence,
    required this.translation,
    required this.keyword,
  });

  final String number;
  final String sentence;
  final String translation;
  final String keyword;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: _clayDecoration(
        radius: 22,
        shadowColor: const Color(0xFFC7CBDD),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: const TextStyle(color: _blue, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: buildHighlightedTextSpans(sentence, keyword),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  translation,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
