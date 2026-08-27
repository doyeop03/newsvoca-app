part of '../main.dart';

Future<void> _confirmIssueLearningExit(BuildContext context) async {
  if (!await _showLearningExitConfirmation(context) || !context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (route) => false,
  );
}

class IssueLearningPage extends StatelessWidget {
  const IssueLearningPage({
    super.key,
    required this.issueSet,
    this.issueIndex = 0,
    this.completedIssueScore = 0,
    this.issueQuizCompleted = false,
    this.completedIssueIndexes = const <int>{},
    this.loadQuizCandidateWordsForTest,
    this.loadReviewWordsForTest,
    this.reviewPageBuilderForTest,
  });
  final DailyIssueSet issueSet;
  final int issueIndex;
  final int completedIssueScore;
  final bool issueQuizCompleted;
  final Set<int> completedIssueIndexes;
  final Future<List<Map<String, dynamic>>> Function()?
  loadQuizCandidateWordsForTest;
  final Future<List<Map<String, dynamic>>> Function(int limit)?
  loadReviewWordsForTest;
  final Widget Function(List<Map<String, dynamic>> words)?
  reviewPageBuilderForTest;

  bool get _currentIssueQuizCompleted =>
      issueQuizCompleted || completedIssueIndexes.contains(issueIndex);

  String get _currentIssueIdentity {
    final id = issueSet.issues[issueIndex].id.trim();
    return id.isEmpty ? 'index_$issueIndex' : id;
  }

  void _showIssue(BuildContext context, int index) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => IssueLearningPage(
          issueSet: issueSet,
          issueIndex: index,
          completedIssueScore: completedIssueScore,
          completedIssueIndexes: completedIssueIndexes,
          loadQuizCandidateWordsForTest: loadQuizCandidateWordsForTest,
          loadReviewWordsForTest: loadReviewWordsForTest,
          reviewPageBuilderForTest: reviewPageBuilderForTest,
        ),
      ),
    );
  }

  Future<void> _startReview(BuildContext context) async {
    try {
      final loader =
          loadReviewWordsForTest ??
          (int limit) => ReviewService.getTodayReviewWords(limit: limit);
      final reviewWords = await loader(10);
      if (!context.mounted) return;
      if (reviewWords.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('복습할 단어를 준비하지 못했어요. 다시 시도해 주세요.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              reviewPageBuilderForTest?.call(reviewWords) ??
              ReviewQuizPage(
                reviewWords: reviewWords,
                questionLimit: 10,
                dailyLearningFlow: true,
                dailyCorrectCount: completedIssueScore,
                dailyQuestionCount: 25,
                learningDate: issueSet.date,
                feedbackCategory: 'daily',
                learnedWords: issueSet.learningWords,
              ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복습 문제를 준비하지 못했어요. 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = issueSet.issues[issueIndex];
    final isLastIssue = issueIndex == issueSet.issues.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmIssueLearningExit(context);
      },
      child: Scaffold(
        backgroundColor: _clayBackground,
        appBar: AppBar(
          backgroundColor: _clayBackground,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => _confirmIssueLearningExit(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_pageBackground, _pageBackground, _pageBackground],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 17, 22, 125),
            children: [
              _IssueLearningHeader(
                currentIndex: issueIndex,
                issueCount: issueSet.issues.length,
                issue: issue,
              ),
              const SizedBox(height: 26),
              _IssueSection(
                title: '무슨 일이 있었나요?',
                body: issue.whatHappened,
                trailing: issue.article.url.isEmpty
                    ? null
                    : TextButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(issue.article.url);
                          if (uri != null && uri.hasScheme) {
                            await launchUrl(
                              uri,
                              mode: kIsWeb
                                  ? LaunchMode.platformDefault
                                  : LaunchMode.inAppBrowserView,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('기사 원문 보기'),
                      ),
              ),
              const SizedBox(height: 20),
              _IssueSection(title: '왜 중요한가요?', body: issue.whyItMatters),
              if (issue.context.isNotEmpty) ...[
                const SizedBox(height: 20),
                _IssueSection(
                  title: '알아두면 좋아요',
                  body: issue.context,
                  muted: true,
                ),
              ],
              if (issue.flow.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _StudySectionTitle(title: '흐름으로 이해하기'),
                const SizedBox(height: 10),
                ...List.generate(
                  issue.flow.length,
                  (index) => _IssueFlowRow(
                    number: issue.flow[index].step,
                    text: issue.flow[index].description,
                    showArrow: index < issue.flow.length - 1,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _StudySectionTitle(title: '핵심 단어 ${issue.words.length}개'),
              const SizedBox(height: 10),
              ...issue.words.map(
                (word) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _IssueWordCard(word),
                ),
              ),
              if (issue.extraExpressions.isNotEmpty) ...[
                const SizedBox(height: 14),
                const _StudySectionTitle(title: '같이 알아두면 좋은 표현'),
                const SizedBox(height: 8),
                ...issue.extraExpressions.map(
                  (item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.expression,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(item.meaning),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const _StudySectionTitle(title: '한 줄 요약'),
              const SizedBox(height: 10),
              _SummaryCard(summary: issue.keyTakeaway),
              const SizedBox(height: 24),
              _IssueQuizCta(
                initiallyCompleted: _currentIssueQuizCompleted,
                learningDate: issueSet.date,
                issueIdentity: _currentIssueIdentity,
                onStart: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IssueQuizPage(
                      issueSet: issueSet,
                      issueIndex: issueIndex,
                      completedIssueScore: completedIssueScore,
                      completedIssueIndexes: completedIssueIndexes,
                      loadQuizCandidateWordsForTest:
                          loadQuizCandidateWordsForTest,
                      loadReviewWordsForTest: loadReviewWordsForTest,
                      reviewPageBuilderForTest: reviewPageBuilderForTest,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
            child: _LearningWordNavigationButtons(
              previousEnabled: issueIndex > 0,
              nextEnabled: true,
              onPrevious: () => _showIssue(context, issueIndex - 1),
              onNext: isLastIssue
                  ? () => _startReview(context)
                  : () => _showIssue(context, issueIndex + 1),
              showDisabledButtons: false,
              previousLabel: '이전 기사',
              nextLabel: isLastIssue ? '복습 퀴즈 풀기' : '다음 기사',
            ),
          ),
        ),
      ),
    );
  }
}

class _IssueLearningHeader extends StatelessWidget {
  const _IssueLearningHeader({
    required this.currentIndex,
    required this.issueCount,
    required this.issue,
  });

  final int currentIndex;
  final int issueCount;
  final IssueLearningItem issue;

  String get _topicLabel {
    if (issue.topicLabelKo.trim().isNotEmpty) return issue.topicLabelKo.trim();
    final topic = issue.topic.trim().toLowerCase();
    const topicLabels = {
      'robotics': '로보틱스',
      'artificial_intelligence': '인공지능',
      'monetary_policy': '통화 정책',
    };
    if (topicLabels[topic] case final label?) return label;
    final category = issue.category.trim();
    return CalendarLearningService.categoryLabels[category] ?? category;
  }

  String get _publishedDate {
    final value = issue.article.publishedAt.trim();
    return value.isEmpty ? '' : value.split('T').first;
  }

  @override
  Widget build(BuildContext context) {
    final source = issue.article.source.trim().isEmpty
        ? '출처 미상'
        : issue.article.source.trim();
    final date = _publishedDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${currentIndex + 1} / $issueCount',
              style: const TextStyle(
                color: _blue,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (_topicLabel.isNotEmpty) ...[
              const SizedBox(width: 10),
              _Pill(label: _topicLabel),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          issue.titleKo,
          style: const TextStyle(
            color: _ink,
            fontSize: 25,
            height: 1.25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          date.isEmpty ? source : '$source  •  $date',
          style: const TextStyle(
            color: _muted,
            fontSize: 11,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class IssueQuizPage extends StatefulWidget {
  const IssueQuizPage({
    super.key,
    required this.issueSet,
    required this.issueIndex,
    this.completedIssueScore = 0,
    this.saveLearnedWordsForTest,
    this.completedIssueIndexes = const <int>{},
    this.loadQuizCandidateWordsForTest,
    this.loadReviewWordsForTest,
    this.reviewPageBuilderForTest,
  });
  final DailyIssueSet issueSet;
  final int issueIndex;
  final int completedIssueScore;
  final Future<void> Function(List<Map<String, dynamic>> words)?
  saveLearnedWordsForTest;
  final Set<int> completedIssueIndexes;
  final Future<List<Map<String, dynamic>>> Function()?
  loadQuizCandidateWordsForTest;
  final Future<List<Map<String, dynamic>>> Function(int limit)?
  loadReviewWordsForTest;
  final Widget Function(List<Map<String, dynamic>> words)?
  reviewPageBuilderForTest;
  @override
  State<IssueQuizPage> createState() => _IssueQuizPageState();
}

class _IssueQuizCta extends StatefulWidget {
  const _IssueQuizCta({
    required this.initiallyCompleted,
    required this.learningDate,
    required this.issueIdentity,
    required this.onStart,
  });

  final bool initiallyCompleted;
  final String learningDate;
  final String issueIdentity;
  final VoidCallback onStart;

  @override
  State<_IssueQuizCta> createState() => _IssueQuizCtaState();
}

class _IssueQuizCtaState extends State<_IssueQuizCta> {
  late bool _completed = widget.initiallyCompleted;

  @override
  void initState() {
    super.initState();
    if (!_completed) _loadCompletion();
  }

  Future<void> _loadCompletion() async {
    final completed = await IssueQuizCompletionService.isCompleted(
      learningDate: widget.learningDate,
      issueIdentity: widget.issueIdentity,
    );
    if (mounted && completed) setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) => _PrimaryButton(
    label: _completed ? '퀴즈 완료' : '퀴즈 시작하기',
    enabled: !_completed,
    showArrow: false,
    onTap: widget.onStart,
  );
}

class _IssueQuizPageState extends State<IssueQuizPage> {
  int index = 0;
  int score = 0;
  int? selectedIndex;
  bool moving = false;
  List<_DailyQuizQuestion>? questions;
  Object? loadError;

  @override
  void initState() {
    super.initState();
    _prepareQuestions();
  }

  Future<void> _prepareQuestions() async {
    try {
      final loader =
          widget.loadQuizCandidateWordsForTest ??
          UserWordService.getReviewWords;
      final candidateWords = await loader();
      final built = _buildIssueQuizQuestions(
        widget.issueSet.issues[widget.issueIndex],
        [...widget.issueSet.learningWords, ...candidateWords],
      );
      if (!mounted) return;
      setState(() => questions = built);
    } catch (error) {
      final built = _buildIssueQuizQuestions(
        widget.issueSet.issues[widget.issueIndex],
        widget.issueSet.learningWords,
      );
      if (!mounted) return;
      setState(() {
        questions = built;
        loadError = error;
      });
    }
  }

  void _selectAnswer(int choiceIndex) {
    if (selectedIndex != null) return;
    final question = questions![index];
    setState(() {
      selectedIndex = choiceIndex;
      if (question.choices[choiceIndex] == question.correctAnswer) score++;
    });
  }

  Future<void> next() async {
    final quizQuestions = questions;
    if (quizQuestions == null || selectedIndex == null || moving) return;
    if (index < quizQuestions.length - 1) {
      setState(() {
        index++;
        selectedIndex = null;
      });
      return;
    }
    moving = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: _clayDecoration(radius: 28).copyWith(boxShadow: const []),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: _blue, size: 42),
              const SizedBox(height: 14),
              const Text(
                '퀴즈가 완료되었어요',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                '$score / ${quizQuestions.length}',
                style: const TextStyle(
                  color: _blue,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      final learnedWords = widget.issueSet.learningWordsForIssue(
        widget.issueIndex,
      );
      if (widget.saveLearnedWordsForTest case final save?) {
        await save(learnedWords);
      } else {
        await UserWordService.completeDailyWordsAfterQuiz(
          date: widget.issueSet.date,
          words: learnedWords,
        );
      }
      final issue = widget.issueSet.issues[widget.issueIndex];
      await IssueQuizCompletionService.markCompleted(
        learningDate: widget.issueSet.date,
        issueIdentity: issue.id.trim().isEmpty
            ? 'index_${widget.issueIndex}'
            : issue.id.trim(),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      moving = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습한 단어를 저장하지 못했어요. 다시 시도해 주세요.')),
      );
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    Navigator.of(context).pop();
    final completedIndexes = <int>{
      ...widget.completedIssueIndexes,
      widget.issueIndex,
    };
    final completedScore =
        widget.completedIssueScore +
        (widget.completedIssueIndexes.contains(widget.issueIndex) ? 0 : score);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => IssueLearningPage(
          issueSet: widget.issueSet,
          issueIndex: widget.issueIndex,
          completedIssueScore: completedScore,
          issueQuizCompleted: true,
          completedIssueIndexes: completedIndexes,
          loadReviewWordsForTest: widget.loadReviewWordsForTest,
          loadQuizCandidateWordsForTest: widget.loadQuizCandidateWordsForTest,
          reviewPageBuilderForTest: widget.reviewPageBuilderForTest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizQuestions = questions;
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: _clayBackground,
        appBar: AppBar(
          backgroundColor: _clayBackground,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_pageBackground, _pageBackground, _pageBackground],
            ),
          ),
          child: quizQuestions == null
              ? const Center(child: CircularProgressIndicator())
              : quizQuestions.isEmpty
              ? Center(
                  child: Text(
                    loadError == null
                        ? '퀴즈를 만들 단어 데이터가 부족합니다.'
                        : '퀴즈 후보를 준비하지 못했습니다.',
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(22, 17, 22, 125),
                  children: [
                    _DailyQuizQuestionView(
                      question: quizQuestions[index],
                      questionIndex: index,
                      total: quizQuestions.length,
                      selectedIndex: selectedIndex,
                      onSelect: _selectAnswer,
                    ),
                  ],
                ),
        ),
        bottomNavigationBar: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
            child: _PrimaryButton(
              label:
                  quizQuestions != null &&
                      quizQuestions.isNotEmpty &&
                      index == quizQuestions.length - 1
                  ? '완료'
                  : '다음 문제',
              onTap: next,
              enabled: selectedIndex != null,
            ),
          ),
        ),
      ),
    );
  }
}

List<_DailyQuizQuestion> _buildIssueQuizQuestions(
  IssueLearningItem issue,
  List<Map<String, dynamic>> candidateWordData, {
  math.Random? random,
}) {
  if (issue.words.length != 3) return const [];
  final coreWords = issue.words
      .map(
        (word) => _DailyQuizWord(
          word: word.word,
          meaning: _koreanOptionMeaning(word.meaning, word.descriptionKo),
          description: _fallback(word.descriptionKo, word.meaning),
          example: _fallback(word.example, '오늘 뉴스에 나온 단어입니다.'),
          exampleKo: word.exampleKo,
          category: issue.category,
          topic: issue.topic,
          topicLabelKo: issue.topicLabelKo,
          partOfSpeech: word.partOfSpeech,
          level: word.level,
        ),
      )
      .toList();
  final allWords = <_DailyQuizWord>[...coreWords];
  final seenWords = {
    for (final word in coreWords) normalizeDistractorValue(word.word),
  };
  for (final data in candidateWordData) {
    final word = data['word']?.toString().trim() ?? '';
    final meaning = data['meaning']?.toString().trim() ?? '';
    if (word.isEmpty || meaning.isEmpty) continue;
    if (!seenWords.add(normalizeDistractorValue(word))) continue;
    allWords.add(
      _DailyQuizWord(
        word: word,
        meaning: _koreanOptionMeaning(
          meaning,
          data['description_ko']?.toString() ?? '',
        ),
        description: _fallback(
          data['description_ko']?.toString() ?? '',
          meaning,
        ),
        example: data['example']?.toString().trim() ?? '',
        exampleKo: data['example_ko']?.toString().trim() ?? '',
        category: data['category']?.toString().trim() ?? '',
        topic: data['topic']?.toString().trim() ?? '',
        topicLabelKo: data['topic_label_ko']?.toString().trim() ?? '',
        partOfSpeech: data['part_of_speech']?.toString().trim() ?? '',
        level: data['level']?.toString().trim() ?? '',
      ),
    );
  }

  final quizRandom = random ?? math.Random();
  const plan = <(_DailyQuizType, int)>[
    (_DailyQuizType.meaningToKorean, 0),
    (_DailyQuizType.descriptionToWord, 1),
    (_DailyQuizType.blankExample, 2),
    (_DailyQuizType.koreanToWord, 0),
    (_DailyQuizType.meaningToKorean, 1),
  ];
  return [
    for (final entry in plan)
      _buildDailyQuizQuestion(
        entry.$1,
        coreWords[entry.$2],
        allWords,
        quizRandom,
      ),
  ];
}

@visibleForTesting
List<Map<String, String>> buildIssueQuizQuestionSummariesForTest(
  IssueLearningItem issue,
  List<Map<String, dynamic>> candidateWordData,
) => _buildIssueQuizQuestions(issue, candidateWordData, random: math.Random(0))
    .map(
      (question) => {
        'word': question.word.word,
        'type': question.type.name,
        'answer': question.correctAnswer,
        'choice_count': '${question.choices.length}',
        for (var index = 0; index < question.choices.length; index++)
          'choice_$index': question.choices[index],
      },
    )
    .toList();

class _IssueSection extends StatelessWidget {
  const _IssueSection({
    required this.title,
    required this.body,
    this.trailing,
    this.muted = false,
  });
  final String title;
  final String body;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final paragraphs = body
        .split(RegExp(r'\n\s*\n'))
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StudySectionTitle(title: title),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 21),
          decoration: BoxDecoration(
            color: muted ? const Color(0xFFF4F7FC) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE5E3DD)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < paragraphs.length; index++) ...[
                Text(
                  paragraphs[index].trim(),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 15,
                    height: 1.75,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (index < paragraphs.length - 1) const SizedBox(height: 16),
              ],
              if (trailing != null) ...[
                const SizedBox(height: 18),
                Align(alignment: Alignment.centerRight, child: trailing!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _IssueFlowRow extends StatelessWidget {
  const _IssueFlowRow({
    required this.number,
    required this.text,
    required this.showArrow,
  });
  final int number;
  final String text;
  final bool showArrow;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _blue,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E3DD)),
              ),
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      if (showArrow)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 3),
          child: Icon(Icons.arrow_downward_rounded, size: 17, color: _muted),
        ),
    ],
  );
}

class _IssueWordCard extends StatelessWidget {
  const _IssueWordCard(this.word);
  final IssueWord word;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final metadata = formatLearningMetadata(
      partOfSpeech: word.partOfSpeech,
      level: word.level,
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF8EB7FF), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D397CF6),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  word.word,
                  style: textTheme.titleLarge?.copyWith(
                    color: _blue,
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '발음 듣기',
                onPressed: () => TtsService.speakEnglish(word.word),
                icon: const Icon(Icons.volume_up_outlined, color: _blue),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            word.meaning,
            style: textTheme.bodyLarge?.copyWith(
              color: _ink,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (metadata.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                metadata,
                style: textTheme.bodyMedium?.copyWith(
                  color: _muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          if (word.descriptionKo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                word.descriptionKo,
                style: textTheme.bodyLarge?.copyWith(
                  color: _ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  height: 1.55,
                ),
              ),
            ),
          if (word.example.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text.rich(
                TextSpan(
                  children: buildHighlightedTextSpans(word.example, word.word),
                ),
                style: textTheme.bodyLarge?.copyWith(
                  color: _ink,
                  fontSize: 15.5,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          if (word.exampleKo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                word.exampleKo,
                style: textTheme.bodyMedium?.copyWith(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
