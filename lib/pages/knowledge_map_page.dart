part of '../main.dart';

class KnowledgeMapPage extends StatefulWidget {
  const KnowledgeMapPage({super.key, this.loadForTest});

  final Future<KnowledgeMapData> Function()? loadForTest;

  @override
  State<KnowledgeMapPage> createState() => _KnowledgeMapPageState();
}

class _KnowledgeMapPageState extends State<KnowledgeMapPage> {
  late final Future<KnowledgeMapData> _data;
  String? _selectedCategory;
  String? _selectedTopic;

  @override
  void initState() {
    super.initState();
    _data = (widget.loadForTest ?? KnowledgeMapService.load)();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _clayBackground,
      appBar: AppBar(
        title: const Text(
          '나의 학습 현황',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: FutureBuilder<KnowledgeMapData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _KnowledgeMapMessage(
              icon: Icons.cloud_off_outlined,
              title: '지식 지도를 불러오지 못했어요',
              body: '잠시 후 다시 열어 주세요.',
              onPressed: () => Navigator.pop(context),
              buttonLabel: '돌아가기',
            );
          }
          final data = snapshot.data ?? const KnowledgeMapData(categories: []);
          if (data.wordCount == 0) {
            return _KnowledgeMapMessage(
              icon: Icons.analytics_outlined,
              title: '아직 지식 지도가 작아요',
              body: '뉴스 단어를 학습하면 분야별 학습 현황이 채워져요.',
              onPressed: () => Navigator.pop(context),
              buttonLabel: '오늘 학습하러 가기',
            );
          }
          return _buildDashboard(data);
        },
      ),
    );
  }

  Widget _buildDashboard(KnowledgeMapData data) {
    final mappedTopicCount = data.categories.fold<int>(
      0,
      (total, category) => total + category.topics.where(_isMappedTopic).length,
    );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            const Text(
              '분야별로 얼마나 학습했는지 확인해보세요.',
              style: TextStyle(color: Color(0xFF667085), height: 1.4),
            ),
            const SizedBox(height: 22),
            _KnowledgeDashboardSummary(
              wordCount: data.wordCount,
              categoryCount: data.categoryCount,
              topicCount: mappedTopicCount,
            ),
            const SizedBox(height: 30),
            const Text(
              '분야별 학습 현황',
              style: TextStyle(
                color: Color(0xFF182230),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < data.categories.length; index++) ...[
              _KnowledgeCategoryRow(
                category: data.categories[index],
                selected: _selectedCategory == data.categories[index].key,
                selectedTopic: _selectedTopic,
                onTap: () => setState(() {
                  final key = data.categories[index].key;
                  _selectedCategory = _selectedCategory == key ? null : key;
                  _selectedTopic = null;
                }),
                onTopicTap: (topic) => setState(() {
                  final key = '${data.categories[index].key}/${topic.key}';
                  _selectedTopic = _selectedTopic == key ? null : key;
                }),
                onShowAllWords: _showAllWords,
              ),
              if (index != data.categories.length - 1)
                const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  void _showAllWords(KnowledgeMapTopic topic) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 2, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.label,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '단어 ${topic.words.length}개',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: topic.words.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _KnowledgeWordRow(word: topic.words[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isMappedTopic(KnowledgeMapTopic topic) => topic.key != '__legacy__';

Color _knowledgeCountColor(int count) {
  if (count <= 5) return const Color(0xFFF8FAFF);
  if (count <= 30) return const Color(0xFFF1F5FF);
  if (count <= 100) return const Color(0xFFE7EFFF);
  return const Color(0xFFDCE8FF);
}

List<KnowledgeMapTopic> _knowledgeDisplayTopics(KnowledgeMapCategory category) {
  final topics = category.topics.where(_isMappedTopic).toList(growable: true);
  final detailedCount = topics.fold<int>(
    0,
    (countSoFar, topic) => countSoFar + topic.words.length,
  );
  final totalCount = category.wordCount;
  if (detailedCount > totalCount) {
    debugPrint(
      '[knowledge-map] topic count exceeds category total: '
      'category=${category.key}, total=$totalCount, topics=$detailedCount',
    );
    return topics;
  }

  final missingCount = totalCount - detailedCount;
  if (missingCount == 0) return topics;
  final uncategorizedWords = category.topics
      .where((topic) => !_isMappedTopic(topic))
      .expand((topic) => topic.words)
      .take(missingCount)
      .toList(growable: false);
  topics.add(
    KnowledgeMapTopic(key: '__other__', label: '기타', words: uncategorizedWords),
  );
  return topics;
}

class _KnowledgeDashboardSummary extends StatelessWidget {
  const _KnowledgeDashboardSummary({
    required this.wordCount,
    required this.categoryCount,
    required this.topicCount,
  });

  final int wordCount;
  final int categoryCount;
  final int topicCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 17),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x145B6C91),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Color(0xFF26334D),
                fontSize: 18,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(
                  text: '단어 $wordCount개',
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(text: '를 배우며\n'),
                TextSpan(
                  text: '분야 $categoryCount개',
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(text: '를 넓혀가고 있어요.'),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '주제 $topicCount개',
            style: const TextStyle(
              color: Color(0xFF7B8496),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeCategoryRow extends StatelessWidget {
  const _KnowledgeCategoryRow({
    required this.category,
    required this.selected,
    required this.selectedTopic,
    required this.onTap,
    required this.onTopicTap,
    required this.onShowAllWords,
  });

  final KnowledgeMapCategory category;
  final bool selected;
  final String? selectedTopic;
  final VoidCallback onTap;
  final ValueChanged<KnowledgeMapTopic> onTopicTap;
  final ValueChanged<KnowledgeMapTopic> onShowAllWords;

  @override
  Widget build(BuildContext context) {
    final topics = _knowledgeDisplayTopics(category);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      decoration: BoxDecoration(
        color: _knowledgeCountColor(category.wordCount),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFFB8CCF7) : Colors.white,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x125B6C91),
            blurRadius: 15,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 17,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _categoryDisplayName(category.key),
                        style: const TextStyle(
                          color: Color(0xFF26334D),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '${category.wordCount}개',
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 5),
                    AnimatedRotation(
                      turns: selected ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF7D899D),
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 270),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: selected
                ? _KnowledgeTopicSection(
                    category: category,
                    topics: topics,
                    selectedTopic: selectedTopic,
                    onTopicTap: onTopicTap,
                    onShowAllWords: onShowAllWords,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeTopicSection extends StatelessWidget {
  const _KnowledgeTopicSection({
    required this.category,
    required this.topics,
    required this.selectedTopic,
    required this.onTopicTap,
    required this.onShowAllWords,
  });

  final KnowledgeMapCategory category;
  final List<KnowledgeMapTopic> topics;
  final String? selectedTopic;
  final ValueChanged<KnowledgeMapTopic> onTopicTap;
  final ValueChanged<KnowledgeMapTopic> onShowAllWords;

  @override
  Widget build(BuildContext context) {
    if (topics.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '세부 주제 없음',
            style: TextStyle(color: Color(0xFF7B8496), fontSize: 12),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Color(0xFFDCE5F5)),
          const SizedBox(height: 15),
          const Text(
            '세부 주제',
            style: TextStyle(
              color: Color(0xFF5F6B80),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < topics.length; index++) ...[
            _KnowledgeTopicRow(
              topic: topics[index],
              selected: selectedTopic == '${category.key}/${topics[index].key}',
              onTap: () => onTopicTap(topics[index]),
              onShowAllWords: () => onShowAllWords(topics[index]),
            ),
            if (index != topics.length - 1) const SizedBox(height: 13),
          ],
        ],
      ),
    );
  }
}

class _KnowledgeTopicRow extends StatelessWidget {
  const _KnowledgeTopicRow({
    required this.topic,
    required this.selected,
    required this.onTap,
    required this.onShowAllWords,
  });

  final KnowledgeMapTopic topic;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onShowAllWords;

  @override
  Widget build(BuildContext context) {
    final visibleWords = topic.words.take(5).toList();
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            key: ValueKey('knowledge-topic-row-${topic.key}'),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    topic.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF354158),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${topic.words.length}개',
                  style: const TextStyle(
                    color: Color(0xFF68758A),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  selected
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF8A94A7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: selected
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 11, 2, 0),
                  child: Column(
                    children: [
                      for (final word in visibleWords)
                        _KnowledgeWordRow(word: word),
                      if (topic.words.length > visibleWords.length)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: onShowAllWords,
                            child: Text('단어 ${topic.words.length}개 모두 보기'),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _KnowledgeWordRow extends StatelessWidget {
  const _KnowledgeWordRow({required this.word});

  final KnowledgeMapWord word;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('knowledge-word-row-${word.id}'),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              word.word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2F3B52),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              word.meaning.isEmpty ? '뜻 정보 없음' : word.meaning,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF758095), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgeMapMessage extends StatelessWidget {
  const _KnowledgeMapMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.onPressed,
    required this.buttonLabel,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onPressed;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _blue, size: 48),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 22),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
