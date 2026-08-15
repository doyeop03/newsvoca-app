part of '../main.dart';

enum _ArticleQuizType {
  focusMeaning,
  blankSentence,
  highlightMeaning,
  expressionMeaning,
  meaningToExpression,
}

class _ArticleQuizQuestion {
  const _ArticleQuizQuestion({
    required this.type,
    required this.typeLabel,
    required this.prompt,
    required this.body,
    required this.correctAnswer,
    required this.choices,
    this.choiceMeanings = const {},
    this.answerText = '',
    this.answerMeaning = '',
    this.explanation = '',
    this.hintKo = '',
    this.sentenceKo = '',
    this.exampleKo = '',
    this.learnedType = '',
  });

  final _ArticleQuizType type;
  final String typeLabel;
  final String prompt;
  final String body;
  final String correctAnswer;
  final List<String> choices;
  final Map<String, String> choiceMeanings;
  final String answerText;
  final String answerMeaning;
  final String explanation;
  final String hintKo;
  final String sentenceKo;
  final String exampleKo;
  final String learnedType;
}

class ArticleMiniQuizPage extends StatefulWidget {
  const ArticleMiniQuizPage({
    super.key,
    required this.article,
    this.saveResultForTest,
    this.notifyCompletionForTest,
    this.completionHoldDuration = const Duration(milliseconds: 1500),
    this.completionFadeDuration = const Duration(milliseconds: 250),
  });

  final Map<String, dynamic> article;
  final Future<void> Function(int score, int total)? saveResultForTest;
  final Future<void> Function()? notifyCompletionForTest;
  final Duration completionHoldDuration;
  final Duration completionFadeDuration;

  @override
  State<ArticleMiniQuizPage> createState() => _ArticleMiniQuizPageState();
}

class _ArticleMiniQuizPageState extends State<ArticleMiniQuizPage> {
  late final List<_ArticleQuizQuestion> _questions = _buildArticleQuizQuestions(
    widget.article,
  );
  int _questionIndex = 0;
  int? _selectedIndex;
  int _score = 0;
  bool _resultSaved = false;
  bool _isCompleting = false;
  bool _completionOverlayMounted = false;
  bool _completionOverlayVisible = false;
  bool _didNavigateAfterCompletion = false;

  _ArticleQuizQuestion get _question => _questions[_questionIndex];

  void _selectAnswer(int index) {
    if (_selectedIndex != null) return;
    final isCorrect = _question.choices[index] == _question.correctAnswer;
    setState(() {
      _selectedIndex = index;
      if (isCorrect) _score++;
    });
  }

  Future<void> _goNext() async {
    if (_questionIndex == _questions.length - 1) {
      if (_isCompleting) return;
      setState(() => _isCompleting = true);
      await _saveResult();
      final notifyCompletion =
          widget.notifyCompletionForTest ??
          LearningNotificationService.onLearningCompletedToday;
      await notifyCompletion();
      if (!mounted) return;
      setState(() => _completionOverlayMounted = true);
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      setState(() => _completionOverlayVisible = true);
      await Future<void>.delayed(widget.completionHoldDuration);
      if (!mounted) return;
      setState(() => _completionOverlayVisible = false);
      await Future<void>.delayed(widget.completionFadeDuration);
      if (!mounted || _didNavigateAfterCompletion) return;
      _didNavigateAfterCompletion = true;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop(true);
      if (navigator.canPop()) navigator.pop(true);
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedIndex = null;
    });
  }

  Future<void> _saveResult() async {
    if (_resultSaved) return;
    _resultSaved = true;
    try {
      if (widget.saveResultForTest != null) {
        await widget.saveResultForTest!(_score, _questions.length);
        return;
      }
      await UserWordService.saveArticleLearningResult(
        article: widget.article,
        score: _score,
        total: _questions.length,
        learnedItems: _articleLearnedItems(_questions),
      );
    } catch (error) {
      // ignore: avoid_print
      print('saveArticleLearningResult failed: $error');
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
        body: const Center(child: Text('퀴즈를 만들 기사 데이터가 부족합니다.')),
      );
    }

    final actionButtonStyle = FilledButton.styleFrom(
      backgroundColor: _blue,
      disabledBackgroundColor: const Color(0xFFD7DCE8),
      foregroundColor: Colors.white,
      shadowColor: const Color(0x665B8EF3),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
    );
    final isLastQuestion = _questionIndex == _questions.length - 1;

    return PopScope(
      canPop: !_isCompleting,
      child: Scaffold(
        backgroundColor: _clayBackground,
        appBar: AppBar(
          backgroundColor: _clayBackground,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: _isCompleting ? null : () => Navigator.maybePop(context),
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
                    Text(
                      '기사 학습 퀴즈',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '방금 본 기사 내용을 간단히 확인해보세요.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 31),
                    _ArticleQuizQuestionView(
                      question: _question,
                      questionIndex: _questionIndex,
                      total: _questions.length,
                      selectedIndex: _selectedIndex,
                      article: widget.article,
                      onSelect: _selectAnswer,
                    ),
                  ],
                ),
              ),
            ),
            if (_completionOverlayMounted)
              _ArticleQuizCompletionOverlay(
                visible: _completionOverlayVisible,
                score: _score,
                total: _questions.length,
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
            child: SizedBox(
              height: 58,
              width: double.infinity,
              child: isLastQuestion
                  ? FilledButton(
                      onPressed: _selectedIndex == null || _isCompleting
                          ? null
                          : _goNext,
                      style: actionButtonStyle,
                      child: const Text('완료'),
                    )
                  : FilledButton.icon(
                      onPressed: _selectedIndex == null || _isCompleting
                          ? null
                          : _goNext,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('다음 문제'),
                      style: actionButtonStyle,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleQuizQuestionView extends StatelessWidget {
  const _ArticleQuizQuestionView({
    required this.question,
    required this.questionIndex,
    required this.total,
    required this.selectedIndex,
    required this.article,
    required this.onSelect,
  });

  final _ArticleQuizQuestion question;
  final int questionIndex;
  final int total;
  final int? selectedIndex;
  final Map<String, dynamic> article;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex;
    final answered = selected != null;
    final correctIndex = question.choices.indexOf(question.correctAnswer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArticleQuestionCard(
          label: '${questionIndex + 1} / $total',
          typeLabel: question.typeLabel,
          prompt: question.prompt,
          body: question.body,
        ),
        if (question.type == _ArticleQuizType.blankSentence) ...[
          const SizedBox(height: 14),
          QuizTranslationHint(
            key: ValueKey('article-hint-$questionIndex'),
            koreanSentence: _firstNonEmptyText([
              question.hintKo,
              question.sentenceKo,
              question.exampleKo,
              _articleText(article, 'example_ko'),
            ]),
            answerMeaning: _firstNonEmptyText([
              question.answerMeaning,
              question.choiceMeanings[question.correctAnswer] ?? '',
              _articleText(article, 'meaning'),
              question.explanation,
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
          _ArticleQuizFeedbackCard(
            correct: selected == correctIndex,
            question: question,
            article: article,
          ),
        ],
      ],
    );
  }
}

class _ArticleQuestionCard extends StatelessWidget {
  const _ArticleQuestionCard({
    required this.label,
    required this.typeLabel,
    required this.prompt,
    required this.body,
  });

  final String label;
  final String typeLabel;
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [_ReviewCardPill(label), _ReviewCardPill(typeLabel)],
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
              fontSize: 22,
              height: 1.45,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleQuizFeedbackCard extends StatelessWidget {
  const _ArticleQuizFeedbackCard({
    required this.correct,
    required this.question,
    required this.article,
  });

  final bool correct;
  final _ArticleQuizQuestion question;
  final Map<String, dynamic> article;

  @override
  Widget build(BuildContext context) {
    final answerText = question.answerText.isNotEmpty
        ? question.answerText
        : question.correctAnswer;
    final answerMeaning = question.answerMeaning;
    final explanation = question.explanation;
    final sentenceKo = question.sentenceKo;

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
            answerMeaning.isEmpty ? answerText : '$answerText - $answerMeaning',
            style: const TextStyle(
              color: Color(0xFF191C21),
              fontWeight: FontWeight.w900,
            ),
          ),
          if (explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(explanation, style: const TextStyle(height: 1.45)),
          ],
          if (sentenceKo.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              sentenceKo,
              style: const TextStyle(color: _muted, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _ArticleQuizCompletionOverlay extends StatelessWidget {
  const _ArticleQuizCompletionOverlay({
    required this.visible,
    required this.score,
    required this.total,
  });

  final bool visible;
  final int score;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          child: ColoredBox(
            color: const Color(0x520F172A),
            child: Center(
              child: AnimatedScale(
                scale: visible ? 1 : 0.92,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Container(
                    key: const ValueKey('article-completion-popup-surface'),
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 26,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: _blue,
                          size: 38,
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '기사 학습이 완료되었어요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF191C21),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$score / $total',
                          style: const TextStyle(
                            color: _blue,
                            fontSize: 28,
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
      ),
    );
  }
}

List<_ArticleQuizQuestion> _buildArticleQuizQuestions(
  Map<String, dynamic> article,
) {
  final random = math.Random();
  final candidates = _articleQuizCandidates(article);
  if (candidates.isEmpty) return const [];

  final focus = _firstArticleCandidate(
    candidates.where((item) => item.type == 'focus_word'),
  );
  final highlights = candidates
      .where((item) => item.type == 'highlight_word')
      .toList();
  final nonFocusHighlights = highlights
      .where((item) => !item.isFocusWord)
      .toList();
  final expressions = candidates
      .where((item) => item.type == 'expression')
      .toList();
  final questions = <_ArticleQuizQuestion>[];

  if (focus != null) {
    questions.add(
      _meaningQuestion(
        candidate: focus,
        type: _ArticleQuizType.focusMeaning,
        typeLabel: '핵심 단어 뜻',
        prompt: '"${focus.text}"의 뜻으로 알맞은 것은?',
        body: focus.text,
        candidates: candidates,
        random: random,
      ),
    );
  }

  final blankQuestion = _buildBlankQuestion(
    candidates: [
      ...nonFocusHighlights,
      ...highlights,
      ...candidates.where((item) => item.sentence.isNotEmpty),
    ],
    allCandidates: candidates,
    random: random,
  );
  if (blankQuestion != null) questions.add(blankQuestion);

  final highlight =
      _firstArticleCandidate(nonFocusHighlights) ??
      _firstArticleCandidate(highlights);
  if (highlight != null) {
    questions.add(
      _meaningQuestion(
        candidate: highlight,
        type: _ArticleQuizType.highlightMeaning,
        typeLabel: '문장 속 단어',
        prompt: '"${highlight.text}"의 뜻으로 알맞은 것은?',
        body: highlight.sentence.isEmpty ? highlight.text : highlight.sentence,
        candidates: candidates,
        random: random,
      ),
    );
  }

  final expression = _firstArticleCandidate(expressions);
  if (expression != null) {
    questions.add(
      _meaningQuestion(
        candidate: expression,
        type: _ArticleQuizType.expressionMeaning,
        typeLabel: '기사 표현',
        prompt: '"${expression.text}"의 뜻으로 알맞은 것은?',
        body: expression.text,
        candidates: candidates,
        random: random,
      ),
    );
  }

  final reverse = expressions.length > 1
      ? expressions[1]
      : _firstArticleCandidate(expressions) ??
            (nonFocusHighlights.length > 1
                ? nonFocusHighlights[1]
                : _firstArticleCandidate(nonFocusHighlights)) ??
            (questions.length < 3 ? focus : null);
  if (reverse != null) {
    questions.add(
      _reverseQuestion(
        candidate: reverse,
        candidates: candidates,
        random: random,
      ),
    );
  }

  final fallbackCandidate = focus ?? candidates.first;
  if (questions.length < 3) {
    questions.add(
      _descriptionQuestion(
        candidate: fallbackCandidate,
        candidates: candidates,
        random: random,
      ),
    );
  }

  var useReverse = false;
  for (final candidate in candidates) {
    if (questions.length >= 5) break;
    if (candidate.type == 'focus_word' &&
        questions.where((item) => item.learnedType == 'focus_word').length >=
            1) {
      continue;
    }

    questions.add(
      useReverse
          ? _reverseQuestion(
              candidate: candidate,
              candidates: candidates,
              random: random,
            )
          : _meaningQuestion(
              candidate: candidate,
              type: candidate.type == 'expression'
                  ? _ArticleQuizType.expressionMeaning
                  : _ArticleQuizType.highlightMeaning,
              typeLabel: candidate.type == 'expression' ? '기사 표현' : '문장 속 단어',
              prompt: '"${candidate.text}"의 뜻으로 알맞은 것은?',
              body: candidate.sentence.isEmpty
                  ? candidate.text
                  : candidate.sentence,
              candidates: candidates,
              random: random,
            ),
    );
    useReverse = !useReverse;
  }

  final uniqueQuestions = _uniqueArticleQuestions(questions);
  uniqueQuestions.shuffle(random);
  return uniqueQuestions
      .take(5)
      .map((question) => _withArticleChoiceMeanings(question, candidates))
      .toList();
}

_ArticleQuizQuestion _withArticleChoiceMeanings(
  _ArticleQuizQuestion question,
  List<_ArticleQuizCandidate> candidates,
) {
  final showsWordChoices =
      question.type == _ArticleQuizType.meaningToExpression ||
      question.type == _ArticleQuizType.blankSentence;
  if (!showsWordChoices) return question;

  final meaningsByText = {
    for (final candidate in candidates)
      candidate.text.trim().toLowerCase(): candidate.meaning.trim(),
  };
  return _ArticleQuizQuestion(
    type: question.type,
    typeLabel: question.typeLabel,
    prompt: question.prompt,
    body: question.body,
    correctAnswer: question.correctAnswer,
    choices: question.choices,
    choiceMeanings: {
      for (final choice in question.choices)
        if (hasValidArticleQuizMeaning(
          meaningsByText[choice.trim().toLowerCase()],
        ))
          choice: _articleQuizOptionMeaning(
            meaningsByText[choice.trim().toLowerCase()]!,
          ),
    },
    answerText: question.answerText,
    answerMeaning: question.answerMeaning,
    explanation: question.explanation,
    hintKo: question.hintKo,
    sentenceKo: question.sentenceKo,
    exampleKo: question.exampleKo,
    learnedType: question.learnedType,
  );
}

_ArticleQuizQuestion _meaningQuestion({
  required _ArticleQuizCandidate candidate,
  required _ArticleQuizType type,
  required String typeLabel,
  required String prompt,
  required String body,
  required List<_ArticleQuizCandidate> candidates,
  required math.Random random,
}) {
  return _ArticleQuizQuestion(
    type: type,
    typeLabel: typeLabel,
    prompt: prompt,
    body: body,
    correctAnswer: candidate.meaning,
    choices: _articleChoices(
      answer: candidate,
      candidates: candidates,
      optionField: 'meaning',
      random: random,
    ),
    answerText: candidate.text,
    answerMeaning: candidate.meaning,
    explanation: candidate.description,
    sentenceKo: candidate.sentenceKo,
    learnedType: candidate.type,
  );
}

_ArticleQuizQuestion _reverseQuestion({
  required _ArticleQuizCandidate candidate,
  required List<_ArticleQuizCandidate> candidates,
  required math.Random random,
}) {
  final safeBody = _safeWordChoiceQuestionText(
    meaning: candidate.meaning,
    description: candidate.description,
    exampleKo: candidate.sentenceKo,
    answerWord: candidate.text,
  );
  if (safeBody.isEmpty) {
    return _meaningQuestion(
      candidate: candidate,
      type: candidate.type == 'expression'
          ? _ArticleQuizType.expressionMeaning
          : _ArticleQuizType.highlightMeaning,
      typeLabel: candidate.type == 'expression' ? '기사 표현' : '문장 속 단어',
      prompt: '"${candidate.text}"의 뜻으로 알맞은 것은?',
      body: candidate.text,
      candidates: candidates,
      random: random,
    );
  }
  return _ArticleQuizQuestion(
    type: _ArticleQuizType.meaningToExpression,
    typeLabel: '뜻 보고 고르기',
    prompt: '다음 설명에 해당하는 영어 단어는?',
    body: safeBody,
    correctAnswer: candidate.text,
    choices: _articleChoices(
      answer: candidate,
      candidates: candidates,
      optionField: 'word',
      random: random,
    ),
    answerText: candidate.text,
    answerMeaning: candidate.meaning,
    explanation: candidate.description,
    sentenceKo: candidate.sentenceKo,
    learnedType: candidate.type,
  );
}

_ArticleQuizQuestion _descriptionQuestion({
  required _ArticleQuizCandidate candidate,
  required List<_ArticleQuizCandidate> candidates,
  required math.Random random,
}) {
  final description = _safeWordChoiceQuestionText(
    meaning: candidate.meaning,
    description: candidate.description,
    exampleKo: candidate.sentenceKo,
    answerWord: candidate.text,
  );
  if (description.isEmpty) {
    return _meaningQuestion(
      candidate: candidate,
      type: candidate.type == 'expression'
          ? _ArticleQuizType.expressionMeaning
          : _ArticleQuizType.highlightMeaning,
      typeLabel: candidate.type == 'expression' ? '기사 표현' : '문장 속 단어',
      prompt: '"${candidate.text}"의 뜻으로 알맞은 것은?',
      body: candidate.text,
      candidates: candidates,
      random: random,
    );
  }
  return _ArticleQuizQuestion(
    type: _ArticleQuizType.meaningToExpression,
    typeLabel: '설명 이해',
    prompt: '다음 설명에 해당하는 영어 단어는?',
    body: description,
    correctAnswer: candidate.text,
    choices: _articleChoices(
      answer: candidate,
      candidates: candidates,
      optionField: 'word',
      random: random,
    ),
    answerText: candidate.text,
    answerMeaning: candidate.meaning,
    explanation: candidate.description,
    sentenceKo: candidate.sentenceKo,
    learnedType: candidate.type,
  );
}

_ArticleQuizQuestion? _buildBlankQuestion({
  required List<_ArticleQuizCandidate> candidates,
  required List<_ArticleQuizCandidate> allCandidates,
  required math.Random random,
}) {
  for (final candidate in candidates) {
    final sentence = candidate.sentence;
    final answer = candidate.text;
    if (sentence.isEmpty || answer.isEmpty) continue;
    if (!sentence.toLowerCase().contains(answer.toLowerCase())) continue;

    final blanked = sentence.replaceAll(
      RegExp(RegExp.escape(answer), caseSensitive: false),
      '_____',
    );
    return _ArticleQuizQuestion(
      type: _ArticleQuizType.blankSentence,
      typeLabel: '문장 빈칸',
      prompt: '빈칸에 들어갈 단어는?',
      body: blanked,
      correctAnswer: answer,
      choices: _articleChoices(
        answer: candidate,
        candidates: allCandidates,
        optionField: 'word',
        random: random,
      ),
      answerText: candidate.text,
      answerMeaning: candidate.meaning,
      explanation: candidate.description,
      sentenceKo: candidate.sentenceKo,
      learnedType: candidate.type,
    );
  }
  return null;
}

List<String> _articleChoices({
  required _ArticleQuizCandidate answer,
  required Iterable<_ArticleQuizCandidate> candidates,
  required String optionField,
  required math.Random random,
}) {
  return buildPrioritizedDistractorChoices(
    answer: answer.toWordData(),
    candidates: candidates.map((item) => item.toWordData()),
    optionField: optionField,
    random: random,
  );
}

List<_ArticleQuizCandidate> _articleQuizCandidates(
  Map<String, dynamic> article,
) {
  final candidates = <_ArticleQuizCandidate>[];
  final focusWord = _articleText(article, 'focus_word');
  final focusMeaning = _articleText(article, 'focus_word_meaning');
  if (focusWord.isNotEmpty && hasValidArticleQuizMeaning(focusMeaning)) {
    candidates.add(
      _ArticleQuizCandidate(
        type: 'focus_word',
        text: focusWord,
        meaning: focusMeaning,
        description: _articleText(article, 'focus_word_description_ko'),
        category: _articleText(article, 'category'),
        topic: _articleText(
          article,
          'focus_word_topic',
          _articleText(article, 'topic'),
        ),
        topicLabelKo: _articleText(
          article,
          'focus_word_topic_label_ko',
          _articleText(article, 'topic_label_ko'),
        ),
        partOfSpeech: _articleText(article, 'focus_word_part_of_speech'),
        level: _articleText(
          article,
          'focus_word_level',
          _articleText(article, 'level'),
        ),
        isFocusWord: true,
      ),
    );
  }

  for (final sentence in _articleMapList(article, 'learning_sentences')) {
    final sentenceText = _articleText(sentence, 'sentence');
    final sentenceKo = _articleText(sentence, 'sentence_ko');
    final highlightWords = sentence['highlight_words'];
    if (highlightWords is! List) continue;
    for (final item in highlightWords.whereType<Map>()) {
      final word = Map<String, dynamic>.from(item);
      final text = _articleText(word, 'text');
      final meaning = _articleText(word, 'meaning');
      if (text.isEmpty || !hasValidArticleQuizMeaning(meaning)) continue;
      candidates.add(
        _ArticleQuizCandidate(
          type: 'highlight_word',
          text: text,
          meaning: meaning,
          sentence: sentenceText,
          sentenceKo: sentenceKo,
          category: _articleText(
            word,
            'category',
            _articleText(article, 'category'),
          ),
          topic: _articleText(
            word,
            'topic',
            _articleText(sentence, 'topic', _articleText(article, 'topic')),
          ),
          topicLabelKo: _articleText(
            word,
            'topic_label_ko',
            _articleText(article, 'topic_label_ko'),
          ),
          partOfSpeech: _articleText(word, 'part_of_speech'),
          level: _articleText(word, 'level', _articleText(article, 'level')),
          isFocusWord: word['is_focus_word'] == true,
        ),
      );
    }
  }

  for (final expression in _articleMapList(article, 'expressions')) {
    final text = _articleText(expression, 'text');
    final meaning = _articleText(expression, 'meaning');
    if (text.isEmpty || !hasValidArticleQuizMeaning(meaning)) continue;
    candidates.add(
      _ArticleQuizCandidate(
        type: 'expression',
        text: text,
        meaning: meaning,
        category: _articleText(
          expression,
          'category',
          _articleText(article, 'category'),
        ),
        topic: _articleText(
          expression,
          'topic',
          _articleText(article, 'topic'),
        ),
        topicLabelKo: _articleText(
          expression,
          'topic_label_ko',
          _articleText(article, 'topic_label_ko'),
        ),
        partOfSpeech: _articleText(expression, 'part_of_speech'),
        level: _articleText(
          expression,
          'level',
          _articleText(article, 'level'),
        ),
      ),
    );
  }

  final deduped = <_ArticleQuizCandidate>[];
  final seen = <String>{};
  for (final candidate in candidates) {
    final key = candidate.text.toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    deduped.add(candidate);
  }
  return deduped;
}

bool hasValidArticleQuizMeaning(String? meaning) {
  if (meaning == null) return false;
  final normalized = meaning.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  const invalidValues = {
    '뜻 정보 없음',
    '정보 없음',
    '의미 정보 없음',
    '-',
    'n/a',
    'null',
    'none',
  };
  return !invalidValues.contains(normalized);
}

String _articleQuizOptionMeaning(String meaning) {
  if (!hasValidArticleQuizMeaning(meaning)) return '';
  final displayMeaning = _koreanOptionMeaning(meaning);
  return displayMeaning == '뜻 정보 없음' ? '' : displayMeaning;
}

List<_ArticleQuizQuestion> _uniqueArticleQuestions(
  List<_ArticleQuizQuestion> questions,
) {
  final unique = <_ArticleQuizQuestion>[];
  final seen = <String>{};
  for (final question in questions) {
    if (question.correctAnswer.trim().isEmpty || question.choices.length != 4) {
      continue;
    }
    final key =
        '${question.typeLabel}:${question.body}:${question.correctAnswer}'
            .toLowerCase();
    if (seen.contains(key)) continue;
    seen.add(key);
    unique.add(question);
  }
  return unique;
}

List<Map<String, dynamic>> _articleLearnedItems(
  List<_ArticleQuizQuestion> questions,
) {
  final items = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final question in questions) {
    final type = question.learnedType.trim();
    final text = question.answerText.trim();
    final meaning = question.answerMeaning.trim();
    if (type.isEmpty || text.isEmpty || meaning.isEmpty) continue;
    final key = '$type:${text.toLowerCase()}';
    if (seen.contains(key)) continue;
    seen.add(key);
    items.add({'type': type, 'text': text, 'meaning': meaning});
  }
  return items;
}

_ArticleQuizCandidate? _firstArticleCandidate(
  Iterable<_ArticleQuizCandidate> candidates,
) {
  for (final candidate in candidates) {
    return candidate;
  }
  return null;
}

List<Map<String, dynamic>> _articleMapList(
  Map<String, dynamic> article,
  String key,
) {
  final value = article[key];
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _articleText(
  Map<String, dynamic> data,
  String key, [
  String fallback = '',
]) {
  final value = data[key]?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

class _ArticleQuizCandidate {
  const _ArticleQuizCandidate({
    required this.type,
    required this.text,
    required this.meaning,
    this.description = '',
    this.sentence = '',
    this.sentenceKo = '',
    this.category = '',
    this.topic = '',
    this.topicLabelKo = '',
    this.partOfSpeech = '',
    this.level = '',
    this.isFocusWord = false,
  });

  final String type;
  final String text;
  final String meaning;
  final String description;
  final String sentence;
  final String sentenceKo;
  final String category;
  final String topic;
  final String topicLabelKo;
  final String partOfSpeech;
  final String level;
  final bool isFocusWord;

  Map<String, dynamic> toWordData() => {
    'word': text,
    'meaning': meaning,
    if (category.isNotEmpty) 'category': category,
    if (topic.isNotEmpty) 'topic': topic,
    if (topicLabelKo.isNotEmpty) 'topic_label_ko': topicLabelKo,
    if (partOfSpeech.isNotEmpty) 'part_of_speech': partOfSpeech,
    if (level.isNotEmpty) 'level': level,
  };
}
