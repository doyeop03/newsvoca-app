part of '../main.dart';

enum _ReviewQuestionType {
  wordToMeaning,
  meaningToWord,
  descriptionToWord,
  blankExample,
  sentenceMeaning,
  spelling,
}

DateTime? getLastSeenTimestampFromUserWord(Map<String, dynamic> wordData) {
  DateTime? latest;
  for (final key in const [
    'last_seen_at',
    'last_reviewed_at',
    'last_quizzed_at',
    'last_learned_at',
    'last_saved_at',
    'updated_at',
    'first_learned_at',
  ]) {
    final value = wordData[key];
    final date = switch (value) {
      Timestamp timestamp => timestamp.toDate(),
      DateTime dateTime => dateTime,
      String text => DateTime.tryParse(text),
      _ => null,
    };
    if (date != null && (latest == null || date.isAfter(latest))) {
      latest = date;
    }
  }
  return latest;
}

String buildLastSeenLabel(DateTime? lastSeenAt, {DateTime? now}) {
  if (lastSeenAt == null) return '학습 기록 없음';

  final nowKst = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 9));
  final seenKst = lastSeenAt.toUtc().add(const Duration(hours: 9));
  final today = DateTime(nowKst.year, nowKst.month, nowKst.day);
  final seenDay = DateTime(seenKst.year, seenKst.month, seenKst.day);
  final diffDays = today.difference(seenDay).inDays;

  if (diffDays <= 0) return '오늘 학습';
  if (diffDays == 1) return '어제 학습';
  if (diffDays < 30) return '$diffDays일 전 학습';
  if (diffDays < 365) return '${diffDays ~/ 30}개월 전 학습';
  return '${diffDays ~/ 365}년 전 학습';
}

class _ReviewQuestion {
  const _ReviewQuestion({
    required this.type,
    required this.wordData,
    required this.prompt,
    required this.body,
    required this.correctAnswer,
    required this.choices,
    this.choiceMeanings = const {},
    this.hintKo = '',
    this.sentenceKo = '',
    this.exampleKo = '',
    this.answerMeaning = '',
    this.lastSeenAt,
  });

  final _ReviewQuestionType type;
  final Map<String, dynamic> wordData;
  final String prompt;
  final String body;
  final String correctAnswer;
  final List<String> choices;
  final Map<String, String> choiceMeanings;
  final String hintKo;
  final String sentenceKo;
  final String exampleKo;
  final String answerMeaning;
  final DateTime? lastSeenAt;
}

typedef ReviewWordResultUpdater =
    Future<void> Function(Map<String, dynamic> wordData, bool isCorrect);
typedef ReviewWordExcluder =
    Future<void> Function(Map<String, dynamic> wordData);
typedef ReviewWordRestorer =
    Future<void> Function(Map<String, dynamic> wordData);
typedef ReviewCompletionChecker = Future<bool> Function(String date);
typedef ReviewGuideVisibilityChecker = Future<bool> Function();
typedef ReviewGuideHideHandler = Future<void> Function();

class ReviewQuizPage extends StatefulWidget {
  const ReviewQuizPage({
    super.key,
    required this.reviewWords,
    this.questionLimit,
    this.dailyLearningFlow = false,
    this.dailyCorrectCount = 0,
    this.dailyQuestionCount = 0,
    this.reviewAlreadyCompleted = false,
    this.learningDate = '',
    this.feedbackCategory = 'daily',
    this.learnedWords = const [],
    this.completeDailyFlowForTest,
    this.notifyCompletionForTest,
    this.feedbackStatusForTest,
    this.saveFeedbackForTest,
    this.completionHoldDuration = const Duration(milliseconds: 900),
    this.completionFadeDuration = const Duration(milliseconds: 220),
    this.leaveDailyFlowForTest,
    this.updateReviewResultForWord,
    this.excludeWordFromReview,
    this.restoreWordToReview,
    this.reviewCompletionChecker,
    this.reviewGuideShouldShow,
    this.hideReviewGuidePermanently,
  });

  final List<Map<String, dynamic>> reviewWords;
  final int? questionLimit;
  final bool dailyLearningFlow;
  final int dailyCorrectCount;
  final int dailyQuestionCount;
  final bool reviewAlreadyCompleted;
  final String learningDate;
  final String feedbackCategory;
  final List<Map<String, dynamic>> learnedWords;
  final Future<void> Function()? completeDailyFlowForTest;
  final Future<void> Function()? notifyCompletionForTest;
  final Future<bool> Function(String date, String category)?
  feedbackStatusForTest;
  final Future<void> Function(
    String date,
    String category,
    String rating,
    List<Map<String, dynamic>> words,
  )?
  saveFeedbackForTest;
  final Duration completionHoldDuration;
  final Duration completionFadeDuration;
  final VoidCallback? leaveDailyFlowForTest;
  final ReviewWordResultUpdater? updateReviewResultForWord;
  final ReviewWordExcluder? excludeWordFromReview;
  final ReviewWordRestorer? restoreWordToReview;
  final ReviewCompletionChecker? reviewCompletionChecker;
  final ReviewGuideVisibilityChecker? reviewGuideShouldShow;
  final ReviewGuideHideHandler? hideReviewGuidePermanently;

  @override
  State<ReviewQuizPage> createState() => _ReviewQuizPageState();
}

class _ReviewQuizPageState extends State<ReviewQuizPage> {
  late final List<_ReviewQuestion> _questions = _buildReviewQuestions(
    widget.reviewWords,
    limit: widget.questionLimit,
    distractorWords: [...widget.reviewWords, ...widget.learnedWords],
  );
  int _questionIndex = 0;
  int? _selectedIndex;
  int _score = 0;
  late bool _completed = widget.dailyLearningFlow && _questions.isEmpty;
  bool _resultSaved = false;
  bool _allowExit = false;
  bool _isExcludingCurrentWord = false;
  bool _isCurrentWordExcluded = false;
  bool _isExclusionLockedForCurrentQuestion = false;
  bool _hasCheckedReviewGuide = false;
  bool _isFinishingDailyFlow = false;
  bool _completionOverlayMounted = false;
  bool _completionOverlayVisible = false;
  bool _didLeaveDailyFlow = false;
  final Set<String> _wrongWords = {};
  final Set<String> _correctWords = {};
  final Set<String> _excludedDuringSession = {};

  _ReviewQuestion get _question => _questions[_questionIndex];
  String get _learningDate => widget.learningDate.trim().isEmpty
      ? appDateString()
      : widget.learningDate.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_questions.isEmpty && widget.dailyLearningFlow) {
        await _completeEmptyIntegratedReview();
      } else {
        final didClose = await _closeIfAlreadyCompleted();
        if (!didClose) await _checkAndShowReviewGuide();
      }
    });
  }

  Future<void> _checkAndShowReviewGuide() async {
    if (_hasCheckedReviewGuide || _questions.isEmpty || _completed) return;
    _hasCheckedReviewGuide = true;

    final checker =
        widget.reviewGuideShouldShow ?? ReviewCurveGuideService.shouldShow;
    final shouldShow = await checker();
    if (!mounted || !shouldShow || _completed) return;

    // The preference check can finish after the route's first frame. Merely
    // registering another post-frame callback at that point does not request a
    // frame on a static Android screen, so the guide may wait for user input.
    // endOfFrame schedules a frame when needed and lets the new route finish
    // rendering before the dialog is attached to it.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _completed || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await _showReviewGuideDialog();
  }

  Future<void> _showReviewGuideDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ReviewCurveGuideDialog(
        onHidePermanently: () async {
          final hide =
              widget.hideReviewGuidePermanently ??
              ReviewCurveGuideService.hidePermanently;
          await hide();
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _completeEmptyIntegratedReview() async {
    if (widget.completeDailyFlowForTest != null) {
      await widget.completeDailyFlowForTest!();
    } else {
      await UserWordService.completeDailyLearningFlow(
        date: _learningDate,
        reviewRequired: widget.reviewAlreadyCompleted,
        reviewCompleted: widget.reviewAlreadyCompleted,
        reviewSkipped: !widget.reviewAlreadyCompleted,
      );
    }
    final notify =
        widget.notifyCompletionForTest ??
        LearningNotificationService.onLearningCompletedToday;
    await notify();
    if (!mounted) return;
    setState(() => _completed = true);
    await _finishDailyLearningFlow();
  }

  Future<bool> _closeIfAlreadyCompleted() async {
    if (widget.reviewAlreadyCompleted && widget.dailyLearningFlow) {
      await _completeEmptyIntegratedReview();
      return true;
    }
    final checker =
        widget.reviewCompletionChecker ?? ReviewService.hasReviewResultForDate;
    final completed = await checker(_learningDate);
    if (!mounted || !completed) {
      return false;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('오늘의 복습은 이미 완료했어요.')));
    setState(() => _allowExit = true);
    Navigator.of(context).pop(true);
    return true;
  }

  void _selectAnswer(int index) {
    if (_selectedIndex != null) {
      return;
    }

    final selectedAnswer = _question.choices[index];
    final isCorrect = selectedAnswer == _question.correctAnswer;
    _recordAnswer(isCorrect: isCorrect, selectedIndex: index);
  }

  void _submitSpelling(String input) {
    if (_selectedIndex != null) return;
    final isCorrect = reviewSpellingMatches(input, _question.correctAnswer);
    _recordAnswer(isCorrect: isCorrect, selectedIndex: isCorrect ? 0 : -1);
  }

  void _recordAnswer({required bool isCorrect, required int selectedIndex}) {
    final word = _text(_question.wordData, 'word', '단어');

    setState(() {
      _selectedIndex = selectedIndex;
      if (isCorrect) {
        _score++;
        _correctWords.add(word);
      } else {
        _wrongWords.add(word);
      }
    });

    final updater =
        widget.updateReviewResultForWord ??
        ReviewService.updateReviewResultForWord;
    updater(_question.wordData, isCorrect).catchError((error) {
      // ignore: avoid_print
      print('updateReviewResultForWord failed: $error');
    });
  }

  Future<void> _requestExcludeCurrentWord() async {
    if (_selectedIndex == null || _isExcludingCurrentWord) {
      return;
    }

    final shouldExclude = !_isCurrentWordExcluded;
    final currentWordData = _question.wordData;
    final currentWordKey = _reviewWordIdentity(currentWordData);
    if (shouldExclude && _excludedDuringSession.contains(currentWordKey)) {
      return;
    }
    setState(() => _isExcludingCurrentWord = true);
    try {
      if (shouldExclude) {
        final excluder =
            widget.excludeWordFromReview ?? ReviewService.excludeWordFromReview;
        await excluder(currentWordData);
      } else {
        final restorer =
            widget.restoreWordToReview ?? ReviewService.restoreWordToReview;
        await restorer(currentWordData);
      }
      if (!mounted) return;

      setState(() {
        _isExcludingCurrentWord = false;
        _isCurrentWordExcluded = shouldExclude;
        _isExclusionLockedForCurrentQuestion = false;
        if (shouldExclude) {
          // Keep this session's question plan unchanged. Firestore's
          // review_excluded flag is applied when the next session is built.
          _excludedDuringSession.add(currentWordKey);
        } else {
          _excludedDuringSession.remove(currentWordKey);
        }
      });
    } catch (error) {
      // ignore: avoid_print
      print('toggleReviewExclusion failed: $error');
      if (!mounted) return;
      setState(() => _isExcludingCurrentWord = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldExclude
                ? '복습 제외 처리를 완료하지 못했어요.\n잠시 후 다시 시도해 주세요.'
                : '복습 제외 취소를 완료하지 못했어요.\n잠시 후 다시 시도해 주세요.',
          ),
        ),
      );
    }
  }

  Future<void> _goNext() async {
    if (_questionIndex == _questions.length - 1) {
      await _saveReviewResult();
      await LearningNotificationService.onLearningCompletedToday();
      if (!mounted) {
        return;
      }
      if (widget.dailyLearningFlow) {
        setState(() => _completed = true);
        return;
      }
      setState(() => _completed = true);
      return;
    }

    setState(() {
      _questionIndex++;
      _selectedIndex = null;
      _isExcludingCurrentWord = false;
      _isCurrentWordExcluded = _excludedDuringSession.contains(
        _reviewWordIdentity(_question.wordData),
      );
      _isExclusionLockedForCurrentQuestion = _isCurrentWordExcluded;
    });
  }

  Future<void> _saveReviewResult() async {
    if (_resultSaved) {
      return;
    }
    _resultSaved = true;

    try {
      await ReviewService.saveReviewResult(
        score: _score,
        total: _questions.length,
        wrongWords: _wrongWords.toList(),
        correctWords: _correctWords.toList(),
        date: _learningDate,
      );
      if (widget.dailyLearningFlow) {
        if (widget.completeDailyFlowForTest != null) {
          await widget.completeDailyFlowForTest!();
        } else {
          await UserWordService.completeDailyLearningFlow(
            date: _learningDate,
            reviewRequired: true,
            reviewCompleted: true,
            reviewSkipped: false,
          );
        }
      }
    } catch (error) {
      // ignore: avoid_print
      print('saveReviewResult failed: $error');
    }
  }

  Future<void> _returnToReview() async {
    if (widget.dailyLearningFlow) {
      await _finishDailyLearningFlow();
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _finishDailyLearningFlow() async {
    if (_isFinishingDailyFlow || _didLeaveDailyFlow || !mounted) return;
    setState(() => _isFinishingDailyFlow = true);

    var alreadySubmitted = false;
    try {
      alreadySubmitted = widget.feedbackStatusForTest != null
          ? await widget.feedbackStatusForTest!(
              _learningDate,
              widget.feedbackCategory,
            )
          : await LearningDifficultyFeedbackService.hasFeedback(
              learningDate: _learningDate,
              category: widget.feedbackCategory,
            );
    } catch (error) {
      // A feedback read failure must not block the completed learning flow.
      // ignore: avoid_print
      print('difficulty feedback status failed: $error');
    }
    if (!mounted) return;

    if (!alreadySubmitted) {
      final rating = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _DailyDifficultyFeedbackDialog(
          onSelect: (value) => Navigator.of(dialogContext).pop(value),
          onSkip: () => Navigator.of(dialogContext).pop('skip'),
        ),
      );
      if (!mounted) return;
      if (rating != null && rating != 'skip') {
        try {
          if (widget.saveFeedbackForTest != null) {
            await widget.saveFeedbackForTest!(
              _learningDate,
              widget.feedbackCategory,
              rating,
              widget.learnedWords,
            );
          } else {
            await LearningDifficultyFeedbackService.save(
              learningDate: _learningDate,
              category: widget.feedbackCategory,
              rating: rating,
              learnedWords: widget.learnedWords,
            );
          }
        } catch (error) {
          // ignore: avoid_print
          print('save difficulty feedback failed: $error');
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('피드백 저장에 실패했어요.')));
          }
        }
      }
    }
    if (!mounted) return;

    if (widget.leaveDailyFlowForTest != null) {
      setState(() {
        _completionOverlayMounted = true;
        _completionOverlayVisible = true;
      });
      _didLeaveDailyFlow = true;
      widget.leaveDailyFlowForTest!();
      return;
    }

    setState(() => _completionOverlayMounted = true);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() => _completionOverlayVisible = true);
    await Future<void>.delayed(widget.completionHoldDuration);
    if (!mounted) return;
    setState(() => _completionOverlayVisible = false);
    await Future<void>.delayed(widget.completionFadeDuration);
    if (!mounted || _didLeaveDailyFlow) return;
    _didLeaveDailyFlow = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _requestExitReview() async {
    if (_completed) {
      Navigator.of(context).pop(true);
      return;
    }
    if (!await _showLearningExitConfirmation(context) || !mounted) {
      return;
    }
    setState(() => _allowExit = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty && !widget.dailyLearningFlow) {
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
        body: const Center(child: Text('오늘 복습할 단어가 없습니다.')),
      );
    }

    return PopScope(
      canPop: (_completed && !_isFinishingDailyFlow) || _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _requestExitReview();
        }
      },
      child: Scaffold(
        backgroundColor: _clayBackground,
        appBar: AppBar(
          backgroundColor: _clayBackground,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: _isFinishingDailyFlow ? null : _requestExitReview,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Stack(
          children: [
            Container(
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
                  padding: const EdgeInsets.fromLTRB(22, 17, 22, 125),
                  children: [
                    if (_completed)
                      _ReviewResultCard(
                        score: _score,
                        total: _questions.length,
                        wrongWords: _wrongWords.toList(),
                        correctWords: _correctWords.toList(),
                        dailyScore: widget.dailyCorrectCount,
                        dailyTotal: widget.dailyQuestionCount,
                        integrated: widget.dailyLearningFlow,
                      )
                    else if (!_completed)
                      Column(
                        children: [
                          _ReviewQuestionView(
                            key: ValueKey('review-question-$_questionIndex'),
                            question: _question,
                            questionIndex: _questionIndex,
                            total: _questions.length,
                            selectedIndex: _selectedIndex,
                            onSelect: _selectAnswer,
                            onSubmitSpelling: _submitSpelling,
                          ),
                        ],
                      )
                    else
                      const SizedBox(height: 220),
                  ],
                ),
              ),
            ),
            if (_completionOverlayMounted)
              _DailyLearningCompletionOverlay(
                visible: _completionOverlayVisible,
              ),
          ],
        ),
        bottomNavigationBar: _isFinishingDailyFlow
            ? null
            : SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_completed && _selectedIndex != null) ...[
                        _ReviewExclusionAction(
                          isSaving: _isExcludingCurrentWord,
                          isExcluded: _isCurrentWordExcluded,
                          lockedForSession:
                              _isExclusionLockedForCurrentQuestion,
                          onPressed: _isExclusionLockedForCurrentQuestion
                              ? null
                              : _requestExcludeCurrentWord,
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        height: 58,
                        width: double.infinity,
                        child: _completed && widget.dailyLearningFlow
                            ? FilledButton(
                                onPressed: _returnToReview,
                                style: _reviewBottomButtonStyle(),
                                child: const Text('오늘 학습 완료하기'),
                              )
                            : FilledButton.icon(
                                onPressed: _completed
                                    ? _returnToReview
                                    : _selectedIndex == null
                                    ? null
                                    : () {
                                        _goNext();
                                      },
                                iconAlignment: IconAlignment.end,
                                icon:
                                    !_completed &&
                                        _questionIndex == _questions.length - 1
                                    ? const SizedBox.shrink()
                                    : Icon(
                                        _completed
                                            ? Icons.replay_rounded
                                            : Icons.arrow_forward_rounded,
                                      ),
                                label: Text(
                                  _completed
                                      ? (widget.dailyLearningFlow
                                            ? '오늘 학습 완료하기'
                                            : '복습 화면으로 돌아가기')
                                      : _questionIndex == _questions.length - 1
                                      ? '결과 보기'
                                      : '다음 문제',
                                ),
                                style: _reviewBottomButtonStyle(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

ButtonStyle _reviewBottomButtonStyle() => FilledButton.styleFrom(
  backgroundColor: _blue,
  disabledBackgroundColor: const Color(0xFFD7DCE8),
  foregroundColor: Colors.white,
  shadowColor: const Color(0x665B8EF3),
  elevation: 3,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  textStyle: const TextStyle(fontWeight: FontWeight.w900),
);

String _reviewWordIdentity(Map<String, dynamic> wordData) {
  final documentId = _text(wordData, 'id');
  if (documentId.isNotEmpty) return documentId;
  return UserWordService.wordIdFor(_text(wordData, 'word'));
}

class _ReviewCurveGuideDialog extends StatelessWidget {
  const _ReviewCurveGuideDialog({
    required this.onHidePermanently,
    required this.onClose,
  });

  final Future<void> Function() onHidePermanently;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        key: const ValueKey('review-guide-popup-surface'),
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '자동 복습 안내',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '학습 결과에 맞춰 필요한 단어를\n자동으로 복습해요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                height: 1.45,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE1E9FA)),
              ),
              child: const Text(
                '다음 복습 시점도 자동으로 조정돼요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF66748D),
                  height: 1.45,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 21),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: onHidePermanently,
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
                      onPressed: onClose,
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

class _ReviewExclusionAction extends StatelessWidget {
  const _ReviewExclusionAction({
    required this.isSaving,
    required this.isExcluded,
    required this.lockedForSession,
    required this.onPressed,
  });

  final bool isSaving;
  final bool isExcluded;
  final bool lockedForSession;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = isExcluded ? _blue : const Color(0xFF667085);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: isExcluded
                ? const Color(0xFFE6EFFF)
                : const Color(0xFFF2F5FB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExcluded ? _blue : const Color(0xFFD8DFEC),
              width: isExcluded ? 1.4 : 1,
            ),
            boxShadow: isExcluded
                ? [
                    BoxShadow(
                      color: _blue.withValues(alpha: 0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSaving ? null : onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Row(
                    key: ValueKey((isSaving, isExcluded, lockedForSession)),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSaving)
                        SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            color: foregroundColor,
                            strokeWidth: 2,
                          ),
                        )
                      else
                        Icon(
                          isExcluded
                              ? Icons.check_circle_rounded
                              : Icons.visibility_off_outlined,
                          color: foregroundColor,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        isSaving
                            ? (isExcluded ? '제외 취소 중...' : '제외하는 중...')
                            : lockedForSession
                            ? '다음 복습부터 제외돼요'
                            : isExcluded
                            ? '복습에서 제외했어요'
                            : '그만 볼래요',
                        style: TextStyle(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          lockedForSession
              ? '이번 복습의 남은 문제는 그대로 진행해요.'
              : isExcluded
              ? '다시 누르면 다음 복습에 포함돼요.'
              : '이 단어는 다음 복습부터 나오지 않아요.',
          style: const TextStyle(
            color: _muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ReviewQuestionView extends StatelessWidget {
  const _ReviewQuestionView({
    super.key,
    required this.question,
    required this.questionIndex,
    required this.total,
    required this.selectedIndex,
    required this.onSelect,
    required this.onSubmitSpelling,
  });

  final _ReviewQuestion question;
  final int questionIndex;
  final int total;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onSubmitSpelling;

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex;
    final answered = selected != null;
    final correctIndex = question.choices.indexOf(question.correctAnswer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewQuestionCard(
          label: '${questionIndex + 1} / $total',
          categoryLabel: _reviewCategoryLabel(question.wordData),
          lastSeenLabel: buildLastSeenLabel(question.lastSeenAt),
          prompt: question.prompt,
          body: question.body,
          typeLabel: question.type == _ReviewQuestionType.spelling
              ? '직접 입력'
              : '',
        ),
        if (question.type == _ReviewQuestionType.spelling) ...[
          const SizedBox(height: 18),
          _ReviewSpellingInput(
            answer: question.correctAnswer,
            answered: answered,
            onSubmit: onSubmitSpelling,
          ),
        ],
        if (question.type == _ReviewQuestionType.blankExample) ...[
          const SizedBox(height: 14),
          QuizTranslationHint(
            key: ValueKey('review-hint-$questionIndex'),
            koreanSentence: _firstNonEmptyText([
              question.hintKo,
              question.sentenceKo,
              question.exampleKo,
              _text(question.wordData, 'example_ko'),
            ]),
            answerMeaning: _firstNonEmptyText([
              question.answerMeaning,
              question.choiceMeanings[question.correctAnswer] ?? '',
              _text(question.wordData, 'meaning'),
              _text(question.wordData, 'description_ko'),
            ]),
            answerText: question.correctAnswer,
          ),
        ],
        if (question.type != _ReviewQuestionType.spelling)
          const SizedBox(height: 22),
        if (question.type != _ReviewQuestionType.spelling)
          ...List.generate(question.choices.length, (index) {
            final isSelected = selected == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AnswerOption(
                label: '${String.fromCharCode(65 + index)}.',
                text: question.choices[index],
                selected: isSelected,
                correct: answered && index == correctIndex,
                wrong: answered && isSelected && index != correctIndex,
                disabled: answered,
                meaning: answered
                    ? question.choiceMeanings[question.choices[index]] ?? ''
                    : '',
                onTap: () => onSelect(index),
              ),
            );
          }),
        if (answered) ...[
          const SizedBox(height: 8),
          _ReviewFeedbackCard(
            correct: question.type == _ReviewQuestionType.spelling
                ? selected == 0
                : selected == correctIndex,
            question: question,
          ),
        ],
      ],
    );
  }
}

class _ReviewSpellingInput extends StatefulWidget {
  const _ReviewSpellingInput({
    required this.answer,
    required this.answered,
    required this.onSubmit,
  });

  final String answer;
  final bool answered;
  final ValueChanged<String> onSubmit;

  @override
  State<_ReviewSpellingInput> createState() => _ReviewSpellingInputState();
}

class _ReviewSpellingInputState extends State<_ReviewSpellingInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hintUsed = false;

  @override
  void didUpdateWidget(covariant _ReviewSpellingInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.answered && widget.answered) {
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.answered) return;
    _focusNode.unfocus();
    widget.onSubmit(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final firstLetter = widget.answer.trim().isEmpty
        ? ''
        : widget.answer.trim().characters.first.toLowerCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !widget.answered,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (!widget.answered) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => setState(() => _hintUsed = !_hintUsed),
            icon: Icon(
              _hintUsed
                  ? Icons.visibility_off_outlined
                  : Icons.lightbulb_outline_rounded,
              size: 18,
            ),
            label: Text(_hintUsed ? '힌트 숨기기' : '힌트 보기'),
            style: TextButton.styleFrom(
              foregroundColor: _blue,
              backgroundColor: const Color(0xFFEAF2FF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          if (_hintUsed && firstLetter.isNotEmpty) ...[
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
                        '스펠링 힌트',
                        style: TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '첫 글자는 “$firstLetter”예요.',
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
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: const Text('정답 확인'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  const _ReviewQuestionCard({
    required this.label,
    required this.categoryLabel,
    required this.lastSeenLabel,
    required this.prompt,
    required this.body,
    this.typeLabel = '',
  });

  final String label;
  final String categoryLabel;
  final String lastSeenLabel;
  final String prompt;
  final String body;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (typeLabel.isNotEmpty) _ReviewCardPill(typeLabel),
              _ReviewCardPill(label),
              if (categoryLabel.isNotEmpty) _ReviewCardPill(categoryLabel),
              _ReviewLastSeenPill(lastSeenLabel),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            prompt,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              height: 1.45,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewLastSeenPill extends StatelessWidget {
  const _ReviewLastSeenPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECFF).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF62558A),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

String _reviewCategoryLabel(Map<String, dynamic> wordData) {
  final category = _text(wordData, 'category');
  return switch (category) {
    'society' => '사회',
    'economy' => '경제',
    'politics' => '정치',
    'technology' => '기술',
    'world' => '국제',
    _ => category,
  };
}

class _ReviewCardPill extends StatelessWidget {
  const _ReviewCardPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
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

class _ReviewFeedbackCard extends StatelessWidget {
  const _ReviewFeedbackCard({required this.correct, required this.question});

  final bool correct;
  final _ReviewQuestion question;

  @override
  Widget build(BuildContext context) {
    final word = _text(question.wordData, 'word', '단어');
    final meaning = _text(question.wordData, 'meaning', '뜻 정보가 없습니다.');
    final description = _text(
      question.wordData,
      'description_ko',
      '설명 정보가 없습니다.',
    );
    final example = _text(question.wordData, 'example');
    final exampleKo = _text(question.wordData, 'example_ko');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _clayDecoration(
        color: correct ? const Color(0xFFE6F8EC) : const Color(0xFFFFEBEB),
        radius: 22,
        shadowColor: const Color(0xFFC7CBDD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                correct ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
                color: correct
                    ? const Color(0xFF2E9D55)
                    : const Color(0xFFD74B4B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  correct
                      ? '정답입니다!'
                      : '오답입니다. 정답은 ${question.correctAnswer}입니다.',
                  style: const TextStyle(
                    color: Color(0xFF191C21),
                    fontWeight: FontWeight.w900,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$word - $meaning',
            style: const TextStyle(
              color: Color(0xFF191C21),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(height: 1.45)),
          if (example.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(example, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          if (exampleKo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(exampleKo, style: const TextStyle(color: _muted)),
          ],
        ],
      ),
    );
  }
}

class _DailyDifficultyFeedbackDialog extends StatelessWidget {
  const _DailyDifficultyFeedbackDialog({
    required this.onSelect,
    required this.onSkip,
  });

  final ValueChanged<String> onSelect;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '오늘 단어 난이도는 어땠나요?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF191C21),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '응답은 더 좋은 단어를 제공하는 데 도움이 돼요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.45),
              ),
              const SizedBox(height: 22),
              for (final option in const [
                ('too_hard', '매우 어려웠어요'),
                ('just_right', '적당했어요'),
                ('too_easy', '너무 쉬웠어요'),
              ]) ...[
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => onSelect(option.$1),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _blue,
                      backgroundColor: const Color(0xFFF5F8FF),
                      side: const BorderSide(color: Color(0xFFDCE6FA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: Text(option.$2),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextButton(onPressed: onSkip, child: const Text('건너뛰기')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyLearningCompletionOverlay extends StatelessWidget {
  const _DailyLearningCompletionOverlay({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 240),
          child: ColoredBox(
            color: const Color(0x520F172A),
            child: Center(
              child: AnimatedScale(
                scale: visible ? 1 : 0.94,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 25,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFDCE8FF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x260F172A),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: _blue, size: 38),
                      SizedBox(height: 14),
                      Text(
                        '오늘 학습을 완료했어요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF191C21),
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewResultCard extends StatelessWidget {
  const _ReviewResultCard({
    required this.score,
    required this.total,
    required this.wrongWords,
    required this.correctWords,
    this.dailyScore = 0,
    this.dailyTotal = 0,
    this.integrated = false,
  });

  final int score;
  final int total;
  final List<String> wrongWords;
  final List<String> correctWords;
  final int dailyScore;
  final int dailyTotal;
  final bool integrated;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
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
        children: [
          const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 54),
          const SizedBox(height: 16),
          Text(
            integrated ? '오늘의 학습을 완료했어요' : '$score / $total',
            textAlign: TextAlign.center,
            maxLines: integrated ? 2 : 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: integrated ? 27 : 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (integrated) ...[
            const SizedBox(height: 18),
            _IntegratedScoreLine(
              label: '오늘의 퀴즈',
              score: dailyScore,
              total: dailyTotal,
            ),
            const SizedBox(height: 10),
            _IntegratedScoreLine(label: '복습 퀴즈', score: score, total: total),
            const SizedBox(height: 10),
            _IntegratedScoreLine(
              label: '전체 결과',
              score: dailyScore + score,
              total: dailyTotal + total,
            ),
          ],
          if (!integrated) ...[
            const SizedBox(height: 18),
            _ReviewResultLine(
              title: '다시 볼 단어',
              words: wrongWords,
              emptyText: '다시 볼 단어가 없습니다.',
            ),
          ],
          if (!integrated) ...[
            const SizedBox(height: 12),
            _ReviewResultLine(
              title: '가까워진 단어',
              words: correctWords,
              emptyText: '이번에는 맞힌 단어가 없습니다.',
            ),
          ],
        ],
      ),
    );
  }
}

class _IntegratedScoreLine extends StatelessWidget {
  const _IntegratedScoreLine({
    required this.label,
    required this.score,
    required this.total,
  });

  final String label;
  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '맞음 $score · 틀림 ${total - score}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ReviewResultLine extends StatelessWidget {
  const _ReviewResultLine({
    required this.title,
    required this.words,
    required this.emptyText,
  });

  final String title;
  final List<String> words;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '$title: ${words.isEmpty ? emptyText : words.join(', ')}',
        style: const TextStyle(
          color: Colors.white,
          height: 1.45,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String normalizeReviewQuizText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[-\s]+'), ' ')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
    .trim();

String _normalizeReviewMeaning(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9가-힣]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String normalizeReviewPartOfSpeech(String value) {
  final text = value.toLowerCase().trim();
  if (text.contains('noun') || text == 'phrase') return 'noun';
  if (text.contains('verb')) return 'verb';
  if (text.contains('adjective')) return 'adjective';
  if (text.contains('adverb')) return 'adverb';
  return 'other';
}

RegExp? _reviewAnswerPattern(String answer) {
  final tokens = answer
      .trim()
      .split(RegExp(r'[-\s]+'))
      .where((token) => token.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return null;
  final phrase = tokens.map(RegExp.escape).join(r'[-\s]+');
  return RegExp(
    r'(?<![A-Za-z0-9])' + phrase + r'(?![A-Za-z0-9])',
    caseSensitive: false,
  );
}

bool containsExactReviewAnswerPhrase(String sentence, String answer) {
  if (sentence.trim().isEmpty || answer.trim().isEmpty) return false;
  return _reviewAnswerPattern(answer)?.hasMatch(sentence) ?? false;
}

String? buildReviewCloze(String sentence, String answer) {
  final pattern = _reviewAnswerPattern(answer);
  if (pattern == null || !pattern.hasMatch(sentence)) return null;
  final blanked = sentence.replaceFirst(pattern, '_____').trim();
  if (blanked == sentence.trim() ||
      !blanked.contains('_____') ||
      blanked == '_____') {
    return null;
  }
  return blanked;
}

String _normalizedReviewCategory(Map<String, dynamic> data) {
  final context = [
    _text(data, 'word'),
    _text(data, 'meaning'),
    _text(data, 'description_ko'),
    _text(data, 'article_title'),
    _text(data, 'title'),
  ].join(' ').toLowerCase();
  if (RegExp(
    r'\b(military|missile|warfare|ceasefire|territorial|naval|army|air dominance)\b|군사|미사일|전쟁|제공권',
  ).hasMatch(context)) {
    return 'world';
  }
  final category = _text(data, 'category').toLowerCase();
  return category == 'international' ? 'world' : category;
}

bool _isAmbiguousReviewCandidate(
  String answerWord,
  String answerMeaning,
  String candidateWord,
  String candidateMeaning,
) {
  if (candidateMeaning == answerMeaning ||
      (answerMeaning.length >= 2 &&
          candidateMeaning.length >= 2 &&
          (candidateMeaning.contains(answerMeaning) ||
              answerMeaning.contains(candidateMeaning)))) {
    return true;
  }
  final answerTokens = answerWord.split(' ').where((item) => item.length > 2);
  final candidateTokens = candidateWord
      .split(' ')
      .where((item) => item.length > 2)
      .toSet();
  return answerWord.contains(' ') &&
      candidateWord.contains(' ') &&
      answerTokens.any(candidateTokens.contains);
}

int reviewDistractorScore(
  Map<String, dynamic> answer,
  Map<String, dynamic> candidate,
) {
  var score = 0;
  final answerTopic = _distractorTopic(answer);
  final candidateTopic = _distractorTopic(candidate);
  final answerCategory = _normalizedReviewCategory(answer);
  final candidateCategory = _normalizedReviewCategory(candidate);
  if (answerTopic.isNotEmpty && answerTopic == candidateTopic) score += 100;
  if (answerCategory.isNotEmpty && answerCategory == candidateCategory) {
    score += 20;
  }

  final answerPart = normalizeReviewPartOfSpeech(
    _text(answer, 'part_of_speech'),
  );
  final candidatePart = normalizeReviewPartOfSpeech(
    _text(candidate, 'part_of_speech'),
  );
  if (answerPart != 'other' && answerPart == candidatePart) score += 10;

  final answerLevel = _text(answer, 'level').toLowerCase();
  final candidateLevel = _text(candidate, 'level').toLowerCase();
  if (answerLevel.isNotEmpty && answerLevel == candidateLevel) score += 3;

  final answerLength = _text(answer, 'word').split(RegExp(r'[-\s]+')).length;
  final candidateLength = _text(
    candidate,
    'word',
  ).split(RegExp(r'[-\s]+')).length;
  if ((answerLength - candidateLength).abs() <= 1) score += 1;
  return score;
}

List<Map<String, dynamic>> rankReviewDistractorCandidates(
  Map<String, dynamic> answer,
  Iterable<Map<String, dynamic>> candidates, {
  bool requireMatchingPartOfSpeech = false,
}) {
  final answerWord = normalizeReviewQuizText(_text(answer, 'word'));
  final answerMeaning = _normalizeReviewMeaning(_text(answer, 'meaning'));
  final unique = <String, Map<String, dynamic>>{};
  for (final candidate in candidates) {
    final word = normalizeReviewQuizText(_text(candidate, 'word'));
    final meaning = _normalizeReviewMeaning(_text(candidate, 'meaning'));
    if (word.isEmpty ||
        meaning.isEmpty ||
        word == answerWord ||
        _isAmbiguousReviewCandidate(answerWord, answerMeaning, word, meaning)) {
      continue;
    }
    unique.putIfAbsent('$word|$meaning', () => candidate);
  }
  return selectDistractorWordData(
    answer: answer,
    candidates: unique.values,
    count: unique.length,
    random: math.Random(0),
    excludeReviewExcluded: true,
    requireMatchingPartOfSpeech: requireMatchingPartOfSpeech,
  );
}

List<_ReviewQuestion> _buildReviewQuestions(
  List<Map<String, dynamic>> words, {
  int? limit,
  List<Map<String, dynamic>>? distractorWords,
}) {
  final usableWords = words
      .map((word) => Map<String, dynamic>.from(word))
      .where(
        (word) =>
            _text(word, 'word').isNotEmpty && _text(word, 'meaning').isNotEmpty,
      )
      .toList();
  if (usableWords.isEmpty) {
    return const [];
  }

  final random = math.Random();
  final choicePool = distractorWords ?? usableWords;
  final fullPlan = <_ReviewQuestionType>[
    _ReviewQuestionType.wordToMeaning,
    _ReviewQuestionType.wordToMeaning,
    _ReviewQuestionType.wordToMeaning,
    _ReviewQuestionType.wordToMeaning,
    _ReviewQuestionType.meaningToWord,
    _ReviewQuestionType.meaningToWord,
    _ReviewQuestionType.meaningToWord,
    _ReviewQuestionType.descriptionToWord,
    _ReviewQuestionType.descriptionToWord,
    _ReviewQuestionType.descriptionToWord,
    _ReviewQuestionType.blankExample,
    _ReviewQuestionType.blankExample,
    _ReviewQuestionType.blankExample,
    _ReviewQuestionType.sentenceMeaning,
    _ReviewQuestionType.sentenceMeaning,
  ];
  final plan = fullPlan.take(limit ?? fullPlan.length).toList();

  final spellingWords = usableWords.where(isReviewSpellingCandidate).toList()
    ..shuffle(random);
  final spellingCount = math.min(
    spellingWords.length,
    maxReviewSpellingQuestions(plan.length),
  );

  final questions = <_ReviewQuestion>[];
  for (var index = 0; index < plan.length; index++) {
    if (index < spellingCount) {
      questions.add(
        _buildReviewQuestion(
          _ReviewQuestionType.spelling,
          spellingWords[index],
          choicePool,
          random,
        ),
      );
      continue;
    }
    var type = plan[index];
    final exampleWords = usableWords
        .where((word) => _reviewExample(word).isNotEmpty)
        .toList();
    if ((type == _ReviewQuestionType.blankExample ||
            type == _ReviewQuestionType.sentenceMeaning) &&
        exampleWords.isEmpty) {
      type = _ReviewQuestionType.wordToMeaning;
    }
    final sourceWords =
        type == _ReviewQuestionType.blankExample ||
            type == _ReviewQuestionType.sentenceMeaning
        ? exampleWords
        : usableWords;
    final wordData = sourceWords[index % sourceWords.length];
    questions.add(_buildReviewQuestion(type, wordData, choicePool, random));
  }
  questions.shuffle(random);

  // ignore: avoid_print
  print('ReviewQuizPage question count=${questions.length}');
  return questions;
}

_ReviewQuestion _buildReviewQuestion(
  _ReviewQuestionType type,
  Map<String, dynamic> wordData,
  List<Map<String, dynamic>> words,
  math.Random random,
) {
  final word = _text(wordData, 'word', '단어');
  final meaning = _text(wordData, 'meaning', '뜻 정보가 없습니다.');
  final description = _text(wordData, 'description_ko', meaning);
  final example = _reviewExample(wordData);
  final exampleKo = _text(wordData, 'example_ko');
  final lastSeenAt = getLastSeenTimestampFromUserWord(wordData);

  switch (type) {
    case _ReviewQuestionType.wordToMeaning:
      return _ReviewQuestion(
        type: type,
        wordData: wordData,
        lastSeenAt: lastSeenAt,
        prompt: '"$word"의 뜻은?',
        body: word,
        correctAnswer: meaning,
        choices: buildReviewChoiceOptions(
          correctAnswer: meaning,
          answerWordData: wordData,
          words: words,
          useMeaning: true,
          random: random,
        ),
      );
    case _ReviewQuestionType.meaningToWord:
      final meaningBody = _safeWordChoiceQuestionText(
        meaning: meaning,
        description: description,
        exampleKo: exampleKo,
        answerWord: word,
      );
      if (meaningBody.isEmpty) {
        return _buildReviewQuestion(
          _ReviewQuestionType.wordToMeaning,
          wordData,
          words,
          random,
        );
      }
      return _ReviewQuestion(
        type: type,
        wordData: wordData,
        lastSeenAt: lastSeenAt,
        prompt: '다음 설명에 해당하는 영어 단어는?',
        body: meaningBody,
        correctAnswer: word,
        choices: buildReviewChoiceOptions(
          correctAnswer: word,
          answerWordData: wordData,
          words: words,
          useMeaning: false,
          random: random,
        ),
        choiceMeanings: _reviewChoiceMeanings(words),
      );
    case _ReviewQuestionType.descriptionToWord:
      final descriptionBody = _safeWordChoiceQuestionText(
        meaning: meaning,
        description: description,
        exampleKo: exampleKo,
        answerWord: word,
      );
      if (descriptionBody.isEmpty) {
        return _buildReviewQuestion(
          _ReviewQuestionType.wordToMeaning,
          wordData,
          words,
          random,
        );
      }
      return _ReviewQuestion(
        type: type,
        wordData: wordData,
        lastSeenAt: lastSeenAt,
        prompt: '다음 설명에 해당하는 영어 단어는?',
        body: descriptionBody,
        correctAnswer: word,
        choices: buildReviewChoiceOptions(
          correctAnswer: word,
          answerWordData: wordData,
          words: words,
          useMeaning: false,
          random: random,
        ),
        choiceMeanings: _reviewChoiceMeanings(words),
      );
    case _ReviewQuestionType.blankExample:
      final blankedExample = buildReviewCloze(example, word);
      if (blankedExample == null) {
        assert(() {
          // ignore: avoid_print
          print(
            '[review quiz] answer=$word cloze rejected: '
            'exact phrase not found in sentence',
          );
          return true;
        }());
        return _buildReviewQuestion(
          _ReviewQuestionType.wordToMeaning,
          wordData,
          words,
          random,
        );
      }
      final blankChoices = buildReviewChoiceOptions(
        correctAnswer: word,
        answerWordData: wordData,
        words: words,
        useMeaning: false,
        random: random,
        requireMatchingPartOfSpeech: true,
      );
      if (blankChoices.length < 4) {
        return _buildReviewQuestion(
          _ReviewQuestionType.wordToMeaning,
          wordData,
          words,
          random,
        );
      }
      return _ReviewQuestion(
        type: type,
        wordData: wordData,
        lastSeenAt: lastSeenAt,
        prompt: '빈칸에 들어갈 단어를 고르세요.',
        body: blankedExample,
        correctAnswer: word,
        choices: blankChoices,
        choiceMeanings: _reviewChoiceMeanings(words),
        hintKo: _text(wordData, 'hint_ko'),
        sentenceKo: _text(wordData, 'sentence_ko'),
        exampleKo: exampleKo,
        answerMeaning: meaning,
      );
    case _ReviewQuestionType.sentenceMeaning:
      return _ReviewQuestion(
        type: type,
        wordData: wordData,
        lastSeenAt: lastSeenAt,
        prompt: '이 문장에서 "$word"의 의미는?',
        body: example,
        correctAnswer: meaning,
        choices: buildReviewChoiceOptions(
          correctAnswer: meaning,
          answerWordData: wordData,
          words: words,
          useMeaning: true,
          random: random,
        ),
      );
    case _ReviewQuestionType.spelling:
      return _ReviewQuestion(
        type: type,
        wordData: wordData,
        lastSeenAt: lastSeenAt,
        prompt: '다음 뜻에 해당하는 영어 단어를 입력하세요.',
        body: meaning,
        correctAnswer: word,
        choices: const [],
        answerMeaning: meaning,
      );
  }
}

String normalizeReviewSpelling(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool reviewSpellingMatches(String input, String answer) =>
    normalizeReviewSpelling(input) == normalizeReviewSpelling(answer);

int maxReviewSpellingQuestions(int totalQuestions) {
  if (totalQuestions <= 0) return 0;
  return (totalQuestions * 0.3).floor();
}

bool isReviewSpellingCandidate(Map<String, dynamic> wordData) {
  final word = _text(wordData, 'word');
  final meaning = _text(wordData, 'meaning');
  final rawLevel = wordData['review_level'];
  final reviewLevel = rawLevel is num
      ? rawLevel.toInt()
      : int.tryParse(rawLevel?.toString() ?? '') ?? 0;
  final wordCount = word
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .length;

  return wordData['review_excluded'] != true &&
      reviewLevel >= 2 &&
      hasValidArticleQuizMeaning(meaning) &&
      word.isNotEmpty &&
      word.length <= 30 &&
      wordCount <= 3 &&
      RegExp(r'[A-Za-z]').hasMatch(word);
}

Map<String, String> _reviewChoiceMeanings(List<Map<String, dynamic>> words) => {
  for (final item in words)
    if (_text(item, 'word').isNotEmpty)
      _text(item, 'word'): _koreanOptionMeaning(
        _text(item, 'meaning'),
        _text(item, 'description_ko'),
      ),
};

List<String> buildReviewChoiceOptions({
  required String correctAnswer,
  required Map<String, dynamic> answerWordData,
  required List<Map<String, dynamic>> words,
  required bool useMeaning,
  required math.Random random,
  bool requireMatchingPartOfSpeech = false,
}) {
  final correct = correctAnswer.trim();
  final ranked = rankReviewDistractorCandidates(
    answerWordData,
    words,
    requireMatchingPartOfSpeech: requireMatchingPartOfSpeech,
  );
  final normalizedCorrect = useMeaning
      ? _normalizeReviewMeaning(correct)
      : normalizeReviewQuizText(correct);
  final distractors = <String>[];
  for (final candidate in ranked) {
    final option = _text(candidate, useMeaning ? 'meaning' : 'word').trim();
    final normalizedOption = useMeaning
        ? _normalizeReviewMeaning(option)
        : normalizeReviewQuizText(option);
    if (normalizedOption.isEmpty ||
        normalizedOption == normalizedCorrect ||
        distractors.any((item) {
          final normalizedItem = useMeaning
              ? _normalizeReviewMeaning(item)
              : normalizeReviewQuizText(item);
          return normalizedItem == normalizedOption;
        })) {
      continue;
    }
    distractors.add(option);
    if (distractors.length == 3) break;
  }
  assert(() {
    final answer = _text(answerWordData, 'word');
    for (final option in distractors) {
      final candidate = ranked.firstWhere(
        (item) => _text(item, useMeaning ? 'meaning' : 'word') == option,
      );
      // ignore: avoid_print
      print(
        '[review quiz] answer=$answer selected distractor=$option '
        'score=${reviewDistractorScore(answerWordData, candidate)}',
      );
    }
    return true;
  }());
  final choices = <String>[correct, ...distractors]..shuffle(random);
  return choices;
}

String _reviewExample(Map<String, dynamic> wordData) {
  for (final key in const ['example', 'sentence', 'example_sentence']) {
    final value = _text(wordData, key);
    if (value.isNotEmpty) {
      return value;
    }
  }

  final examples = wordData['examples'];
  if (examples is List) {
    for (final item in examples) {
      if (item is String && item.trim().isNotEmpty) {
        return item.trim();
      }
      if (item is Map) {
        final mapped = Map<String, dynamic>.from(item);
        for (final key in const ['sentence', 'example', 'text']) {
          final value = _text(mapped, key);
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }
  }
  return '';
}

String _text(Map<String, dynamic> data, String key, [String fallback = '']) {
  final value = data[key]?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}
