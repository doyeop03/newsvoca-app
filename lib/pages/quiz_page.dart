part of '../main.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, this.words = learningWords});

  final List<LearningWord> words;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _questionIndex = 0;
  int? _selected;
  bool _checked = false;
  bool _completed = false;
  int _score = 0;

  LearningWord get _word => widget.words[_questionIndex];

  List<String> get _choices {
    final meanings = widget.words.map((word) => word.meaning).toList();
    if (meanings.length <= 1) return meanings;
    final shift = _questionIndex % meanings.length;
    return [...meanings.skip(shift), ...meanings.take(shift)];
  }

  int get _correctIndex => _choices.indexOf(_word.meaning);

  void _handleBottomButton() {
    if (_completed) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
      return;
    }

    if (!_checked) {
      setState(() {
        _checked = true;
        if (_selected == _correctIndex) _score++;
      });
      return;
    }

    if (_questionIndex == widget.words.length - 1) {
      setState(() => _completed = true);
      return;
    }

    setState(() {
      _questionIndex++;
      _selected = null;
      _checked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomLabel = _completed
        ? '홈으로 돌아가기'
        : _checked
        ? (_questionIndex == widget.words.length - 1 ? '결과 보기' : '다음 문제')
        : '정답 확인';

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
            padding: const EdgeInsets.fromLTRB(22, 17, 22, 125),
            children: [
              Text(
                _completed ? '퀴즈 완료' : '오늘 배운 단어 퀴즈',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 9),
              Text(
                _completed ? '오늘 학습한 단어를 모두 복습했어요.' : '예문에 나온 단어의 뜻을 골라보세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 31),
              _completed
                  ? _QuizResult(score: _score, total: widget.words.length)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _QuizQuestionCard(
                          label:
                              '문제 ${_questionIndex + 1} / ${widget.words.length}',
                          sentence: _word.examples.first.sentence,
                        ),
                        const SizedBox(height: 22),
                        ...List.generate(_choices.length, (index) {
                          final isSelected = _selected == index;
                          final isCorrect = _checked && index == _correctIndex;
                          final isWrong =
                              _checked && isSelected && index != _correctIndex;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AnswerOption(
                              label: '${String.fromCharCode(65 + index)}.',
                              text: _choices[index],
                              selected: isSelected,
                              correct: isCorrect,
                              wrong: isWrong,
                              disabled: _checked,
                              onTap: () => setState(() => _selected = index),
                            ),
                          );
                        }),
                        if (_checked) ...[
                          const SizedBox(height: 8),
                          _QuizFeedbackCard(
                            correct: _selected == _correctIndex,
                            word: _word.word,
                            meaning: _word.meaning,
                          ),
                        ],
                      ],
                    ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
          child: SizedBox(
            height: 58,
            width: double.infinity,
            child: FilledButton(
              onPressed: (_completed || _selected != null)
                  ? _handleBottomButton
                  : null,
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
                    bottomLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (!_completed) ...[
                    const SizedBox(width: 9),
                    Icon(
                      _checked
                          ? Icons.arrow_forward_rounded
                          : Icons.check_rounded,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({required this.label, required this.sentence});

  final String label;
  final String sentence;

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
          Container(
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
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            sentence,
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

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.disabled,
    required this.onTap,
    this.meaning = '',
  });

  final String label;
  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final bool disabled;
  final VoidCallback onTap;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = correct
        ? const Color(0xFFE6F8EC)
        : wrong
        ? const Color(0xFFFFEBEB)
        : selected
        ? const Color(0xFFEAF2FF)
        : Colors.white;
    final borderColor = correct
        ? const Color(0xFF42B86A)
        : wrong
        ? const Color(0xFFE45E5E)
        : selected
        ? _blue
        : Colors.white.withOpacity(0.78);
    final icon = correct
        ? Icons.check_circle_rounded
        : wrong
        ? Icons.cancel_rounded
        : selected
        ? Icons.radio_button_checked_rounded
        : Icons.radio_button_unchecked_rounded;
    final iconColor = correct
        ? const Color(0xFF2E9D55)
        : wrong
        ? const Color(0xFFD74B4B)
        : selected
        ? _blue
        : const Color(0xFFC1C7D3);

    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: borderColor,
            width: selected || correct || wrong ? 1.5 : 1.2,
          ),
          boxShadow: _clayShadows(const Color(0xFFC7CBDD)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF191C21),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF191C21),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (meaning.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      meaning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: iconColor, size: 22),
          ],
        ),
      ),
    );
  }
}

String _koreanOptionMeaning(String primary, [String fallback = '']) {
  for (final value in [primary.trim(), fallback.trim()]) {
    if (value.isNotEmpty && RegExp(r'[가-힣]').hasMatch(value)) {
      return value;
    }
  }
  return '뜻 정보 없음';
}

bool _questionTextContainsAnswer(String text, String answerWord) {
  final answer = answerWord.trim();
  return answer.isNotEmpty && text.toLowerCase().contains(answer.toLowerCase());
}

String sanitizeQuestionText({
  required String text,
  required String answerWord,
}) {
  final answer = answerWord.trim();
  var cleaned = text.trim();
  if (answer.isEmpty || cleaned.isEmpty) return cleaned;

  final leaked = _questionTextContainsAnswer(cleaned, answer);
  final escaped = RegExp.escape(answer);
  cleaned = cleaned.replaceAll(
    RegExp(
      '(?:뉴스에서\\s*)?[\\\'"‘’“”]?\\s*$escaped\\s*[\\\'"‘’“”]?\\s*(?:은|는)?',
      caseSensitive: false,
    ),
    '',
  );
  cleaned = cleaned
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r'^\s*[,.:;·-]+\s*'), '')
      .trim();

  if (leaked && kDebugMode) {
    debugPrint('[quiz] sanitized description for answer: $answer');
  }
  if (_questionTextContainsAnswer(cleaned, answer)) {
    if (kDebugMode) {
      debugPrint(
        '[quiz] rejected question because answer leaked in prompt: $answer',
      );
    }
    return '';
  }
  return cleaned;
}

String normalizeWordChoiceDescription(String value) {
  return value
      .trim()
      .replaceFirst(
        RegExp(
          r'\s*(?:을 의미하는 단어입니다|를 의미하는 단어입니다|라는 뜻입니다|이라는 뜻입니다|인 단어입니다)\s*[.!?]?\s*$',
        ),
        '',
      )
      .trim();
}

String _safeWordChoiceQuestionText({
  required String meaning,
  required String description,
  required String exampleKo,
  required String answerWord,
}) {
  final koreanMeaning = _koreanOptionMeaning(meaning);
  final candidates = <String>[
    description,
    if (koreanMeaning != '뜻 정보 없음') koreanMeaning,
    exampleKo,
  ];
  for (final candidate in candidates) {
    final cleaned = sanitizeQuestionText(
      text: normalizeWordChoiceDescription(candidate),
      answerWord: answerWord,
    );
    if (cleaned.isNotEmpty) return cleaned;
  }
  if (kDebugMode) {
    debugPrint(
      '[quiz] rejected question because answer leaked in prompt: $answerWord',
    );
  }
  return '';
}

class _QuizFeedbackCard extends StatelessWidget {
  const _QuizFeedbackCard({
    required this.correct,
    required this.word,
    required this.meaning,
  });

  final bool correct;
  final String word;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _clayDecoration(
        color: correct ? const Color(0xFFE6F8EC) : const Color(0xFFFFEBEB),
        radius: 22,
        shadowColor: const Color(0xFFC7CBDD),
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle_rounded : Icons.lightbulb_rounded,
            color: correct ? const Color(0xFF2E9D55) : const Color(0xFFD74B4B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              correct ? '정답이에요! 문맥까지 완벽해요.' : '아쉬워요. $word의 뜻은 "$meaning"이에요.',
              style: const TextStyle(
                color: Color(0xFF191C21),
                fontWeight: FontWeight.w900,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizResult extends StatelessWidget {
  const _QuizResult({required this.score, required this.total});

  final int score;
  final int total;

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
            '$score / $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score == total ? '오늘 단어를 모두 맞혔어요!' : '틀린 단어는 복습 페이지에서 다시 확인해 보세요.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

enum _DailyQuizType {
  meaningToKorean,
  descriptionToWord,
  blankExample,
  koreanToWord,
}

class _DailyQuizWord {
  const _DailyQuizWord({
    required this.word,
    required this.meaning,
    required this.description,
    required this.example,
    required this.exampleKo,
    this.category = '',
    this.topic = '',
    this.topicLabelKo = '',
    this.level = '',
  });

  final String word;
  final String meaning;
  final String description;
  final String example;
  final String exampleKo;
  final String category;
  final String topic;
  final String topicLabelKo;
  final String level;

  Map<String, dynamic> toWordData(String category) {
    return {
      'word': word,
      'meaning': meaning,
      'description_ko': description,
      'example': example,
      'example_ko': exampleKo,
      'category': category,
      if (topic.isNotEmpty) 'topic': topic,
      if (topicLabelKo.isNotEmpty) 'topic_label_ko': topicLabelKo,
      if (level.isNotEmpty) 'level': level,
    };
  }
}

class _DailyQuizQuestion {
  const _DailyQuizQuestion({
    required this.type,
    required this.word,
    required this.prompt,
    required this.body,
    required this.correctAnswer,
    required this.choices,
    this.choiceMeanings = const {},
    this.hintKo = '',
    this.sentenceKo = '',
    this.exampleKo = '',
    this.answerMeaning = '',
  });

  final _DailyQuizType type;
  final _DailyQuizWord word;
  final String prompt;
  final String body;
  final String correctAnswer;
  final List<String> choices;
  final Map<String, String> choiceMeanings;
  final String hintKo;
  final String sentenceKo;
  final String exampleKo;
  final String answerMeaning;
}

class DailyQuizPage extends StatefulWidget {
  const DailyQuizPage({
    super.key,
    required this.category,
    required this.words,
    required this.learningDate,
    this.categories = const [],
    this.dailyWordGoal,
  });

  final String category;
  final List<LearningWord> words;
  final String learningDate;
  final List<String> categories;
  final int? dailyWordGoal;

  @override
  State<DailyQuizPage> createState() => _DailyQuizPageState();
}

class _DailyQuizPageState extends State<DailyQuizPage> {
  late final List<_DailyQuizQuestion> _questions = _buildDailyQuizQuestions(
    widget.words,
  );
  int _questionIndex = 0;
  int? _selectedIndex;
  int _score = 0;
  final Set<String> _wrongWords = {};
  bool _completed = false;
  bool _resultSaved = false;
  bool _preparingReview = false;

  _DailyQuizQuestion get _question => _questions[_questionIndex];

  List<Map<String, dynamic>> get _learnedWordSnapshots => widget.words
      .map(
        (word) => <String, dynamic>{
          'word': word.word,
          'meaning': word.meaning,
          if (word.difficulty.trim().isNotEmpty) 'level': word.difficulty,
        },
      )
      .toList();

  void _selectAnswer(int index) {
    if (_selectedIndex != null) {
      return;
    }

    final selectedAnswer = _question.choices[index];
    final isCorrect = selectedAnswer == _question.correctAnswer;
    setState(() {
      _selectedIndex = index;
      if (isCorrect) {
        _score++;
      } else {
        _wrongWords.add(_question.word.word);
      }
    });
    UserWordService.updateDailyQuizResultForWord(
      _question.word.toWordData(
        _question.word.category.isEmpty
            ? widget.category
            : _question.word.category,
      ),
      _question.word.category.isEmpty
          ? widget.category
          : _question.word.category,
      isCorrect,
    ).catchError((error) {
      // ignore: avoid_print
      print('updateQuizResultForWord failed: $error');
    });
  }

  Future<void> _goNext() async {
    if (_questionIndex == _questions.length - 1) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(
        dailyQuizCompletedKey(appDateString(), widget.category),
        true,
      );
      await _saveQuizResult();
      if (!mounted) {
        return;
      }
      if (widget.category == 'daily') {
        await _startIntegratedReview();
        return;
      }
      await LearningNotificationService.onLearningCompletedToday();
      if (!mounted) return;
      setState(() => _completed = true);
      return;
    }

    setState(() {
      _questionIndex++;
      _selectedIndex = null;
    });
  }

  Future<void> _returnHome() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      dailyQuizCompletedKey(appDateString(), widget.category),
      true,
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  int get _reviewLimit => getReviewCountForDailyGoal(
    widget.dailyWordGoal ?? UserPreferenceService.defaultDailyWordGoal,
  );

  Future<void> _startIntegratedReview() async {
    if (_preparingReview) return;
    setState(() => _preparingReview = true);
    try {
      final reviewAlreadyCompleted = await ReviewService.hasReviewResultForDate(
        appDateString(),
      );
      final reviewWords = reviewAlreadyCompleted
          ? <Map<String, dynamic>>[]
          : await ReviewService.getTodayReviewWords(limit: _reviewLimit);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewQuizPage(
            reviewWords: reviewWords,
            dailyLearningFlow: true,
            dailyCorrectCount: _score,
            dailyQuestionCount: _questions.length,
            reviewAlreadyCompleted: reviewAlreadyCompleted,
            learningDate: widget.learningDate,
            feedbackCategory: widget.category,
            learnedWords: _learnedWordSnapshots,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _preparingReview = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('복습 문제를 준비하지 못했어요. 다시 시도해 주세요.'),
          action: SnackBarAction(
            label: '재시도',
            onPressed: _startIntegratedReview,
          ),
        ),
      );
    }
  }

  Future<void> _continueDailyFlow() async {
    final reviewAlreadyCompleted = await ReviewService.hasReviewResultForDate(
      appDateString(),
    );
    if (reviewAlreadyCompleted) {
      await UserWordService.completeDailyLearningFlow(
        date: appDateString(),
        reviewRequired: true,
        reviewCompleted: true,
        reviewSkipped: false,
      );
      await _returnHome();
      return;
    }
    final reviewWords = await ReviewService.getTodayReviewWords(
      limit: _reviewLimit,
    );
    if (!mounted) return;
    if (reviewWords.isEmpty) {
      await UserWordService.completeDailyLearningFlow(
        date: appDateString(),
        reviewRequired: false,
        reviewCompleted: false,
        reviewSkipped: true,
      );
      await LearningNotificationService.onLearningCompletedToday();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오늘 복습할 단어가 아직 없어서 오늘 학습을 완료했어요.')),
      );
      await _returnHome();
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReviewQuizPage(
          reviewWords: reviewWords,
          dailyLearningFlow: true,
          learningDate: widget.learningDate,
          feedbackCategory: widget.category,
          learnedWords: _learnedWordSnapshots,
        ),
      ),
    );
  }

  Future<void> _saveQuizResult() async {
    if (_resultSaved) {
      return;
    }
    _resultSaved = true;

    try {
      await UserWordService.saveQuizResult(
        date: appDateString(),
        category: widget.category,
        score: _score,
        total: _questions.length,
        wrongWords: _wrongWords.toList(),
        categories: widget.categories,
        wordCount: widget.words.length,
        dailyWordGoal: widget.dailyWordGoal,
      );
      await UserWordService.completeDailyWordsAfterQuiz(
        date: appDateString(),
        words: widget.words.map((word) {
          final category = word.category.isEmpty
              ? widget.category
              : word.category;
          final example = word.examples.isEmpty ? null : word.examples.first;
          return <String, dynamic>{
            'word': word.word,
            'meaning': word.meaning,
            'description_ko': word.descriptionKo,
            'example': example?.sentence ?? '',
            'example_ko': example?.translation ?? '',
            'category': category,
          };
        }),
      );
    } catch (error) {
      // ignore: avoid_print
      print('saveQuizResult failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
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
        body: const Center(child: Text('오늘 학습한 단어가 없습니다.')),
      );
    }

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
            padding: const EdgeInsets.fromLTRB(22, 17, 22, 125),
            children: [
              if (_preparingReview)
                const Column(
                  children: [
                    SizedBox(height: 80),
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('복습 문제를 준비하고 있어요.'),
                  ],
                )
              else if (_completed)
                _DailyQuizResultCard(
                  score: _score,
                  total: _questions.length,
                  wrongWords: _wrongWords.toList(),
                )
              else
                _DailyQuizQuestionView(
                  question: _question,
                  questionIndex: _questionIndex,
                  total: _questions.length,
                  selectedIndex: _selectedIndex,
                  onSelect: _selectAnswer,
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
          child: SizedBox(
            height: 58,
            width: double.infinity,
            child: FilledButton(
              onPressed: _preparingReview
                  ? null
                  : _completed
                  ? _continueDailyFlow
                  : _selectedIndex == null
                  ? null
                  : _goNext,
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                disabledBackgroundColor: const Color(0xFFD7DCE8),
                foregroundColor: Colors.white,
                shadowColor: const Color(0x665B8EF3),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_completed ? '복습을 이어서 하기' : '다음 문제'),
                  if (!_completed) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyQuizQuestionView extends StatelessWidget {
  const _DailyQuizQuestionView({
    required this.question,
    required this.questionIndex,
    required this.total,
    required this.selectedIndex,
    required this.onSelect,
  });

  final _DailyQuizQuestion question;
  final int questionIndex;
  final int total;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex;
    final answered = selected != null;
    final correctIndex = question.choices.indexOf(question.correctAnswer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DailyQuestionCard(
          label: '${questionIndex + 1} / $total',
          prompt: question.prompt,
          body: question.body,
        ),
        if (question.type == _DailyQuizType.blankExample) ...[
          const SizedBox(height: 14),
          QuizTranslationHint(
            key: ValueKey('daily-hint-$questionIndex'),
            koreanSentence: _firstNonEmptyText([
              question.hintKo,
              question.sentenceKo,
              question.exampleKo,
              question.word.exampleKo,
            ]),
            answerMeaning: _firstNonEmptyText([
              question.answerMeaning,
              question.choiceMeanings[question.correctAnswer] ?? '',
              question.word.meaning,
              question.word.description,
            ]),
            answerText: question.correctAnswer,
          ),
        ],
        const SizedBox(height: 22),
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
          _DailyQuizFeedbackCard(
            correct: selected == correctIndex,
            question: question,
          ),
        ],
      ],
    );
  }
}

class _DailyQuestionCard extends StatelessWidget {
  const _DailyQuestionCard({
    required this.label,
    required this.prompt,
    required this.body,
  });

  final String label;
  final String prompt;
  final String body;

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
          Container(
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

class _DailyQuizFeedbackCard extends StatelessWidget {
  const _DailyQuizFeedbackCard({required this.correct, required this.question});

  final bool correct;
  final _DailyQuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final word = question.word;
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
            '${word.word} - ${word.meaning}',
            style: const TextStyle(
              color: Color(0xFF191C21),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(word.description, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 8),
          Text(
            word.example,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (word.exampleKo.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(word.exampleKo, style: const TextStyle(color: _muted)),
          ],
        ],
      ),
    );
  }
}

class _DailyQuizResultCard extends StatelessWidget {
  const _DailyQuizResultCard({
    required this.score,
    required this.total,
    required this.wrongWords,
  });

  final int score;
  final int total;
  final List<String> wrongWords;

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
            '$score / $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              wrongWords.isEmpty
                  ? '오늘 틀린 단어가 없습니다.'
                  : '틀린 단어: ${wrongWords.join(', ')}',
              style: const TextStyle(
                color: Colors.white,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<_DailyQuizQuestion> _buildDailyQuizQuestions(List<LearningWord> source) {
  final words = _sanitizeDailyQuizWords(source);
  if (words.isEmpty) {
    return const [];
  }

  final random = math.Random();
  const basePlan = <_DailyQuizType>[
    _DailyQuizType.meaningToKorean,
    _DailyQuizType.meaningToKorean,
    _DailyQuizType.meaningToKorean,
    _DailyQuizType.descriptionToWord,
    _DailyQuizType.descriptionToWord,
    _DailyQuizType.blankExample,
    _DailyQuizType.blankExample,
    _DailyQuizType.blankExample,
    _DailyQuizType.koreanToWord,
    _DailyQuizType.koreanToWord,
  ];
  final questionCount = words.length <= 3
      ? 6
      : words.length <= 9
      ? 10
      : 15;
  final plan = List.generate(
    questionCount,
    (index) => basePlan[index % basePlan.length],
  );

  final questions = <_DailyQuizQuestion>[];
  for (var index = 0; index < plan.length; index++) {
    final word = words[index % words.length];
    questions.add(_buildDailyQuizQuestion(plan[index], word, words, random));
  }
  questions.shuffle(random);
  return questions;
}

List<_DailyQuizWord> _sanitizeDailyQuizWords(List<LearningWord> source) {
  return [
    for (var index = 0; index < source.length; index++)
      _DailyQuizWord(
        word: _fallback(source[index].word, '단어 ${index + 1}'),
        meaning: _koreanOptionMeaning(
          source[index].meaning,
          source[index].descriptionKo,
        ),
        description: _fallback(source[index].descriptionKo, '설명 정보가 없습니다.'),
        example: _fallback(
          source[index].examples.isNotEmpty
              ? source[index].examples.first.sentence
              : '',
          '오늘 뉴스에 나온 단어입니다.',
        ),
        exampleKo: source[index].examples.isNotEmpty
            ? source[index].examples.first.translation
            : '',
        category: source[index].category,
        topic: source[index].topic,
        topicLabelKo: source[index].topicLabelKo,
        level: source[index].difficulty,
      ),
  ];
}

_DailyQuizQuestion _buildDailyQuizQuestion(
  _DailyQuizType type,
  _DailyQuizWord word,
  List<_DailyQuizWord> words,
  math.Random random,
) {
  switch (type) {
    case _DailyQuizType.meaningToKorean:
      return _DailyQuizQuestion(
        type: type,
        word: word,
        prompt: '"${word.word}"의 뜻은 무엇일까요?',
        body: word.word,
        correctAnswer: word.meaning,
        choices: _choices(
          correctAnswer: word.meaning,
          pool: words.map((item) => item.meaning),
          random: random,
        ),
      );
    case _DailyQuizType.descriptionToWord:
      final descriptionBody = _safeWordChoiceQuestionText(
        meaning: word.meaning,
        description: word.description,
        exampleKo: word.exampleKo,
        answerWord: word.word,
      );
      if (descriptionBody.isEmpty) {
        return _buildDailyQuizQuestion(
          _DailyQuizType.meaningToKorean,
          word,
          words,
          random,
        );
      }
      return _DailyQuizQuestion(
        type: type,
        word: word,
        prompt: '다음 설명에 해당하는 영어 단어는?',
        body: descriptionBody,
        correctAnswer: word.word,
        choices: _choices(
          correctAnswer: word.word,
          pool: words.map((item) => item.word),
          random: random,
        ),
        choiceMeanings: _dailyChoiceMeanings(words),
      );
    case _DailyQuizType.blankExample:
      return _DailyQuizQuestion(
        type: type,
        word: word,
        prompt: '빈칸에 들어갈 단어를 고르세요.',
        body: _blankExample(word.example, word.word, word.meaning),
        correctAnswer: word.word,
        choices: _choices(
          correctAnswer: word.word,
          pool: words.map((item) => item.word),
          random: random,
        ),
        choiceMeanings: _dailyChoiceMeanings(words),
        hintKo: word.exampleKo,
        sentenceKo: word.exampleKo,
        exampleKo: word.exampleKo,
        answerMeaning: word.meaning,
      );
    case _DailyQuizType.koreanToWord:
      final meaningBody = _safeWordChoiceQuestionText(
        meaning: word.meaning,
        description: word.description,
        exampleKo: word.exampleKo,
        answerWord: word.word,
      );
      if (meaningBody.isEmpty) {
        return _buildDailyQuizQuestion(
          _DailyQuizType.meaningToKorean,
          word,
          words,
          random,
        );
      }
      return _DailyQuizQuestion(
        type: type,
        word: word,
        prompt: '다음 설명에 해당하는 영어 단어는?',
        body: meaningBody,
        correctAnswer: word.word,
        choices: _choices(
          correctAnswer: word.word,
          pool: words.map((item) => item.word),
          random: random,
        ),
        choiceMeanings: _dailyChoiceMeanings(words),
      );
  }
}

Map<String, String> _dailyChoiceMeanings(List<_DailyQuizWord> words) => {
  for (final item in words)
    if (item.word.trim().isNotEmpty)
      item.word.trim(): _fallback(item.meaning, item.description),
};

List<String> _choices({
  required String correctAnswer,
  required Iterable<String> pool,
  required math.Random random,
}) {
  final normalizedCorrect = correctAnswer.trim();
  final distractors =
      pool
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty && item != normalizedCorrect)
          .toSet()
          .toList()
        ..shuffle(random);
  final choices = <String>[normalizedCorrect, ...distractors.take(3)]
    ..shuffle(random);
  return choices;
}

String _blankExample(String example, String word, String meaning) {
  final safeExample = example.trim();
  final safeWord = word.trim();
  if (safeExample.isEmpty || safeWord.isEmpty) {
    return '_____ : $meaning';
  }

  final expression = RegExp(RegExp.escape(safeWord), caseSensitive: false);
  if (expression.hasMatch(safeExample)) {
    return safeExample.replaceAll(expression, '_____');
  }
  final cleaned = sanitizeQuestionText(text: safeExample, answerWord: safeWord);
  return cleaned.isEmpty ? '_____ : $meaning' : '$cleaned\n_____ = $meaning';
}

String _fallback(String value, String fallback) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}
