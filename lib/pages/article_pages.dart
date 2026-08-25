part of '../main.dart';

class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FlowScaffold(
      title: '기사로 익히기',
      subtitle: '단어 학습 화면의 관련 기사에서 선택해 주세요.',
      child: Text('표시할 관련 기사가 없습니다.'),
    );
  }
}

class ArticleStudyScreen extends StatelessWidget {
  const ArticleStudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ArticleLearningPage(article: {});
  }
}

class ArticleLearningPage extends StatefulWidget {
  const ArticleLearningPage({super.key, required this.article});

  final Map<String, dynamic> article;

  @override
  State<ArticleLearningPage> createState() => _ArticleLearningPageState();
}

class _ArticleLearningPageState extends State<ArticleLearningPage> {
  bool _isCompleted = false;
  bool _isCheckingCompletion = true;
  bool _hasCheckedRelatedWordsGuide = false;

  Map<String, dynamic> get article => widget.article;

  @override
  void initState() {
    super.initState();
    _loadCompletionStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowRelatedWordsGuide();
    });
  }

  @override
  void dispose() {
    TtsService.stop();
    super.dispose();
  }

  Future<void> _checkAndShowRelatedWordsGuide() async {
    if (_hasCheckedRelatedWordsGuide) return;
    _hasCheckedRelatedWordsGuide = true;
    final shouldShow = await ArticleRelatedWordsGuideService.shouldShow(
      article,
    );
    if (!mounted || !shouldShow) return;
    await _showRelatedWordsGuideDialog();
  }

  Future<void> _showRelatedWordsGuideDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _RelatedWordsGuideDialog(
        onHidePermanently: () async {
          await ArticleRelatedWordsGuideService.hidePermanently();
          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
        },
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _loadCompletionStatus() async {
    try {
      final completed = await UserWordService.isArticleCompleted(article);
      if (!mounted) return;
      setState(() {
        _isCompleted = completed;
        _isCheckingCompletion = false;
      });
    } catch (error) {
      // ignore: avoid_print
      print('isArticleCompleted failed: $error');
      if (!mounted) return;
      setState(() => _isCheckingCompletion = false);
    }
  }

  Future<void> _handleCompleteTap() async {
    if (_isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 학습 완료한 기사예요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final alreadyCompleted = await UserWordService.isArticleCompleted(article)
        .catchError((error) {
          // ignore: avoid_print
          print('isArticleCompleted failed: $error');
          return false;
        });
    if (!mounted) return;

    if (alreadyCompleted) {
      setState(() => _isCompleted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 학습 완료한 기사예요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ArticleMiniQuizPage(article: article)),
    );
    if (!mounted) return;
    if (completed == true) {
      setState(() => _isCompleted = true);
    } else {
      await _loadCompletionStatus();
    }
  }

  String _text(String key, [String fallback = '']) {
    final text = article[key]?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  List<Map<String, dynamic>> _mapList(String key) {
    final value = article[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = _text('title', '기사 제목 없음');
    final url = _text('url');
    final learningSentences = _mapList('learning_sentences');
    final expressions = _mapList('expressions');

    return _FlowScaffold(
      title: '기사로 익히기',
      subtitle: 'AI 핵심 요약부터 주요 표현까지 차근차근 익혀보세요.',
      bottom: _PrimaryButton(
        label: _isCompleted ? '학습 완료됨' : '학습 완료',
        enabled: !_isCheckingCompletion && !_isCompleted,
        showArrow: false,
        onTap: () {
          _handleCompleteTap();
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ArticleHeadline(
            category: _text('category'),
            title: title,
            source: _text('source'),
            publishedAt: _text('publishedAt'),
          ),
          const SizedBox(height: 28),
          const _StudySectionTitle(title: 'AI 핵심 요약'),
          const SizedBox(height: 11),
          _SummaryCard(summary: _text('ai_summary_ko', 'AI 핵심 요약이 없습니다.')),
          const SizedBox(height: 14),
          url.isEmpty
              ? _PrimaryButton(
                  label: '기사 원문 보기',
                  enabled: false,
                  showArrow: false,
                  onTap: () {},
                )
              : _PrimaryButton(
                  label: '기사 원문 보기',
                  showArrow: false,
                  onTap: () async => openArticleUrl(context, url),
                ),
          const SizedBox(height: 27),
          const _StudySectionTitle(title: '학습 중인 핵심 단어'),
          const SizedBox(height: 11),
          _KeyWordStudyCard(article: article),
          const SizedBox(height: 27),
          const _StudySectionTitle(title: '문장으로 익히기'),
          const SizedBox(height: 11),
          if (learningSentences.isEmpty)
            const Text('학습 문장이 없습니다.')
          else
            ...List.generate(learningSentences.length, (index) {
              final sentence = learningSentences[index];
              final vocabulary = _highlightWords(sentence);
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == learningSentences.length - 1 ? 0 : 12,
                ),
                child: _SentenceStudyCard(
                  number: index + 1,
                  label: index == 0 ? '핵심 단어 문장' : '기사 내용 표현',
                  sentence: _mapText(sentence, 'sentence'),
                  translation: _mapText(sentence, 'sentence_ko'),
                  highlights: vocabulary.map((item) => item.$1).toList(),
                  vocabulary: vocabulary,
                  category: _text('category'),
                ),
              );
            }),
          const SizedBox(height: 27),
          const _StudySectionTitle(title: '같이 익힐 주요 표현'),
          const SizedBox(height: 11),
          if (expressions.isEmpty)
            const Text('표현 데이터가 없습니다.')
          else
            _ExpressionGrid(
              expressions: expressions,
              category: _text('category'),
            ),
        ],
      ),
    );
  }

  String _mapText(Map<String, dynamic> map, String key) {
    return map[key]?.toString() ?? '';
  }

  Future<void> openArticleUrl(BuildContext context, String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기사 URL이 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('기사 URL을 열 수 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final mode = kIsWeb
        ? LaunchMode.platformDefault
        : LaunchMode.inAppBrowserView;

    final success = await launchUrl(uri, mode: mode);
    if (!success) {
      final fallbackSuccess = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!fallbackSuccess && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('기사 원문을 열지 못했습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<(String, String, bool)> _highlightWords(Map<String, dynamic> sentence) {
    final value = sentence['highlight_words'];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) {
          return (
            item['text']?.toString() ?? '',
            _preferredKoreanText(item),
            item['is_focus_word'] == true,
          );
        })
        .where((item) => item.$1.trim().isNotEmpty)
        .toList();
  }

  String _preferredKoreanText(Map<dynamic, dynamic> item) {
    final meaning = item['meaning']?.toString().trim() ?? '';
    if (meaning.isNotEmpty) return meaning;
    return item['description_ko']?.toString().trim() ?? '';
  }
}

class _RelatedWordsGuideDialog extends StatefulWidget {
  const _RelatedWordsGuideDialog({
    required this.onHidePermanently,
    required this.onClose,
  });

  final Future<void> Function() onHidePermanently;
  final VoidCallback onClose;

  @override
  State<_RelatedWordsGuideDialog> createState() =>
      _RelatedWordsGuideDialogState();
}

class _RelatedWordsGuideDialogState extends State<_RelatedWordsGuideDialog> {
  bool _previewSaved = false;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _scheduleNextPreviewState();
  }

  void _scheduleNextPreviewState() {
    _previewTimer?.cancel();
    _previewTimer = Timer(
      _previewSaved
          ? const Duration(milliseconds: 2800)
          : const Duration(milliseconds: 2200),
      () {
        if (!mounted) return;
        setState(() => _previewSaved = !_previewSaved);
        _scheduleNextPreviewState();
      },
    );
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE9E8EE)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'sanction',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '제재',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    key: const ValueKey('related-words-guide-save-preview'),
                    onTap: () {
                      setState(() => _previewSaved = !_previewSaved);
                      _scheduleNextPreviewState();
                    },
                    borderRadius: BorderRadius.circular(15),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _previewSaved ? _lime : const Color(0xFFE8F0FF),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Row(
                          key: ValueKey(_previewSaved),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _previewSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              color: _blue,
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _previewSaved ? '저장됨' : '저장',
                              style: const TextStyle(
                                color: _blue,
                                fontSize: 11,
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
            const SizedBox(height: 18),
            const Text(
              '관련 단어를 저장할 수 있어요',
              style: TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              '저장된 단어는 이후 복습 문제에서 다시 학습할 수 있어요.',
              style: TextStyle(color: _muted, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 21),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: TextButton(
                      onPressed: widget.onHidePermanently,
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
                      onPressed: widget.onClose,
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

class _ArticleHeadline extends StatelessWidget {
  const _ArticleHeadline({
    required this.category,
    required this.title,
    required this.source,
    required this.publishedAt,
  });

  final String category;
  final String title;
  final String source;
  final String publishedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF397CF6),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            height: 1.2,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (source.isNotEmpty)
              Text(
                source,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (source.isNotEmpty && publishedAt.isNotEmpty) ...[
              const SizedBox(width: 8),
              const CircleAvatar(radius: 2, backgroundColor: _muted),
              const SizedBox(width: 8),
            ],
            if (publishedAt.isNotEmpty)
              Text(
                publishedAt,
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
          ],
        ),
      ],
    );
  }
}

class _StudySectionTitle extends StatelessWidget {
  const _StudySectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECE9FF), Color(0xFFF4F2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        summary,
        softWrap: true,
        maxLines: null,
        overflow: TextOverflow.visible,
        style: const TextStyle(
          height: 1.65,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _KeyWordStudyCard extends StatelessWidget {
  const _KeyWordStudyCard({required this.article});

  final Map<String, dynamic> article;

  String _text(String key, [String fallback = '']) {
    final text = article[key]?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final focusWord = _text('focus_word');
    final word = focusWord.isEmpty ? '핵심 단어 없음' : focusWord;
    final partOfSpeech = _text('focus_word_part_of_speech');
    final partOfSpeechLabel = formatPartOfSpeech(partOfSpeech);
    final meaning = _text(
      'focus_word_meaning',
      focusWord.isEmpty ? '핵심 단어 뜻 없음' : focusWord,
    );
    final description = _text('focus_word_description_ko');

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word,
                      style: const TextStyle(
                        color: Color(0xFF397CF6),
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (meaning.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meaning,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (partOfSpeechLabel.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        partOfSpeechLabel,
                        style: const TextStyle(color: _muted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: () => TtsService.speakEnglishText(focusWord),
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.volume_up_outlined,
                    color: Color(0xFF397CF6),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE8D3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  '핵심 단어',
                  style: TextStyle(
                    color: Color(0xFFE87924),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 17),
            Text(
              description,
              style: const TextStyle(color: _muted, height: 1.5, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SentenceStudyCard extends StatefulWidget {
  const _SentenceStudyCard({
    required this.number,
    required this.label,
    required this.sentence,
    required this.translation,
    required this.highlights,
    required this.vocabulary,
    required this.category,
  });

  final int number;
  final String label;
  final String sentence;
  final String translation;
  final List<String> highlights;
  final List<(String, String, bool)> vocabulary;
  final String category;

  @override
  State<_SentenceStudyCard> createState() => _SentenceStudyCardState();
}

class _SentenceStudyCardState extends State<_SentenceStudyCard> {
  bool _expanded = true;
  final Set<String> _saved = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E3DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFFE8F0FF),
                child: Text(
                  '${widget.number}',
                  style: const TextStyle(
                    color: Color(0xFF397CF6),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                widget.label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => TtsService.speakEnglishText(widget.sentence),
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.volume_up_outlined, size: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _HighlightedSentence(
            sentence: widget.sentence,
            highlights: widget.highlights,
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                const Divider(height: 1),
                if (widget.translation.isNotEmpty) ...[
                  const SizedBox(height: 13),
                  Text(
                    widget.translation,
                    style: const TextStyle(
                      color: _muted,
                      height: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (widget.vocabulary.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7FC),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      children: widget.vocabulary
                          .map(
                            (item) => _VocabularyRow(
                              word: item.$1,
                              meaning: item.$2,
                              isMain: item.$3,
                              saved: _saved.contains(item.$1),
                              onSave: () => setState(() {
                                if (_saved.contains(item.$1)) {
                                  _saved.remove(item.$1);
                                } else {
                                  _saved.add(item.$1);
                                  UserWordService.saveWord({
                                    'word': item.$1,
                                    'meaning': item.$2,
                                    'description_ko': item.$2,
                                    'example': widget.sentence,
                                    'example_ko': widget.translation,
                                    'category': widget.category,
                                  }, widget.category).catchError((error) {
                                    // ignore: avoid_print
                                    print('saveWord failed: $error');
                                  });
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              style: TextButton.styleFrom(
                foregroundColor: _ink,
                backgroundColor: const Color(0xFFF0F3F7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _expanded ? '해석 / 단어 접기' : '해석 / 단어 펼치기',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
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

class _VocabularyRow extends StatelessWidget {
  const _VocabularyRow({
    required this.word,
    required this.meaning,
    required this.isMain,
    required this.saved,
    required this.onSave,
  });

  final String word;
  final String meaning;
  final bool isMain;
  final bool saved;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              word,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              meaning,
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          if (isMain)
            const _MainWordBadge()
          else
            _SaveChip(saved: saved, onTap: onSave),
        ],
      ),
    );
  }
}

class _MainWordBadge extends StatelessWidget {
  const _MainWordBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        '메인',
        style: TextStyle(
          color: Color(0xFF397CF6),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SaveChip extends StatelessWidget {
  const _SaveChip({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: saved ? _lime : const Color(0xFFE8F0FF),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          saved ? '저장됨' : '+ 저장',
          style: const TextStyle(
            color: Color(0xFF397CF6),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HighlightedSentence extends StatelessWidget {
  const _HighlightedSentence({
    required this.sentence,
    required this.highlights,
  });

  final String sentence;
  final List<String> highlights;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var remaining = sentence;

    while (remaining.isNotEmpty) {
      String? nextHighlight;
      var nextIndex = remaining.length;
      for (final highlight in highlights) {
        final index = remaining.toLowerCase().indexOf(highlight.toLowerCase());
        if (index >= 0 && index < nextIndex) {
          nextIndex = index;
          nextHighlight = highlight;
        }
      }

      if (nextHighlight == null) {
        spans.add(TextSpan(text: remaining));
        break;
      }
      if (nextIndex > 0) {
        spans.add(TextSpan(text: remaining.substring(0, nextIndex)));
      }
      final matched = remaining.substring(
        nextIndex,
        nextIndex + nextHighlight.length,
      );
      spans.add(
        TextSpan(
          text: matched,
          style: const TextStyle(
            color: Color(0xFF397CF6),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      remaining = remaining.substring(nextIndex + nextHighlight.length);
    }

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        color: _ink,
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ExpressionGrid extends StatefulWidget {
  const _ExpressionGrid({required this.expressions, required this.category});

  final List<Map<String, dynamic>> expressions;
  final String category;

  @override
  State<_ExpressionGrid> createState() => _ExpressionGridState();
}

class _ExpressionGridState extends State<_ExpressionGrid> {
  final Set<String> _saved = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E3DD)),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.expressions.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
        ),
        itemBuilder: (context, index) {
          final item = widget.expressions[index];
          final text = item['text']?.toString() ?? '';
          final rawMeaning = item['meaning']?.toString().trim() ?? '';
          final meaning = rawMeaning.isNotEmpty
              ? rawMeaning
              : item['description_ko']?.toString().trim() ?? '';
          final saved = _saved.contains(text);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FC),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      meaning,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _SaveChip(
                      saved: saved,
                      onTap: () => setState(() {
                        if (saved) {
                          _saved.remove(text);
                        } else {
                          _saved.add(text);
                          UserWordService.saveWord({
                            'word': text,
                            'meaning': meaning,
                            'description_ko': meaning,
                            'category': widget.category,
                          }, widget.category).catchError((error) {
                            // ignore: avoid_print
                            print('saveWord failed: $error');
                          });
                        }
                      }),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 21,
                  child: InkWell(
                    onTap: () => TtsService.speakEnglishText(text),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.volume_up_outlined,
                        color: Color(0xFF397CF6),
                        size: 16,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: saved ? const Color(0xFF397CF6) : _muted,
                    size: 16,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
