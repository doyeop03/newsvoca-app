part of '../main.dart';

class InterestCategoryPage extends StatefulWidget {
  const InterestCategoryPage({super.key});

  @override
  State<InterestCategoryPage> createState() => _InterestCategoryPageState();
}

class _InterestCategoryPageState extends State<InterestCategoryPage> {
  Set<String> _selectedCategories = {
    ...UserPreferenceService.defaultInterestCategories,
  };
  bool _loading = true;
  bool _saving = false;
  int _dailyWordGoal = UserPreferenceService.defaultDailyWordGoal;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final preferences = await UserPreferenceService.getLearningPreferences();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCategories = preferences.interestCategories.toSet();
        _dailyWordGoal = preferences.dailyWordGoal;
        _loading = false;
      });
    } catch (error) {
      // ignore: avoid_print
      print('Interest categories load failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCategories = {
          ...UserPreferenceService.defaultInterestCategories,
        };
        _loading = false;
      });
    }
  }

  void _toggleCategory(String categoryId) {
    final selected = _selectedCategories.contains(categoryId);
    setState(() {
      if (selected) {
        _selectedCategories.remove(categoryId);
      } else {
        _selectedCategories.add(categoryId);
      }
      _dailyWordGoal = normalizeDailyWordGoal(
        currentGoal: _dailyWordGoal,
        selectedCategoryCount: _selectedCategories.length,
      );
    });

    // ignore: avoid_print
    print('Interest category toggled: $categoryId');
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('관심 분야를 1개 이상 선택해주세요.')));
      return;
    }
    setState(() => _saving = true);

    try {
      final orderedCategories = UserPreferenceService.defaultInterestCategories
          .where(_selectedCategories.contains)
          .toList();
      final normalizedGoal = normalizeDailyWordGoal(
        currentGoal: _dailyWordGoal,
        selectedCategoryCount: orderedCategories.length,
      );
      await UserPreferenceService.updateLearningPreferences(
        categories: orderedCategories,
        dailyWordGoal: normalizedGoal,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('관심 분야가 저장되었습니다.')));
      Navigator.pop(context, true);
    } catch (error) {
      // ignore: avoid_print
      print('Interest categories save failed: $error');
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('저장 중 오류가 발생했습니다.')));
    }
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
            colors: [_pageBackground, _pageBackground, _pageBackground],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = math.min(constraints.maxWidth, 480.0);
              final horizontalPadding = contentWidth < 380 ? 18.0 : 24.0;

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: contentWidth,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      18,
                      horizontalPadding,
                      22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF111827),
                              shadowColor: const Color(0x229EA0B7),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                        ),
                        const SizedBox(height: 36),
                        const Text(
                          '관심 있는 뉴스 분야를\n선택해주세요',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 28,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '선택한 분야만 홈 화면에 보여드릴게요.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 15,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                if (_loading)
                                  ...List.generate(
                                    5,
                                    (index) =>
                                        const _InterestCategorySkeleton(),
                                  )
                                else
                                  ..._orderedCategories.map(
                                    (category) => _InterestCategoryCard(
                                      category: category,
                                      selected: _selectedCategories.contains(
                                        category.categoryKey,
                                      ),
                                      onTap: () =>
                                          _toggleCategory(category.categoryKey),
                                    ),
                                  ),
                                if (!_loading) ...[
                                  const SizedBox(height: 18),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '하루에 몇 개의 단어를 학습할까요?',
                                      style: TextStyle(
                                        color: Color(0xFF111827),
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      for (final goal
                                          in UserPreferenceService
                                              .dailyWordGoalOptions)
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              right: goal == 15 ? 0 : 10,
                                            ),
                                            child: ChoiceChip(
                                              label: SizedBox(
                                                width: double.infinity,
                                                child: Text(
                                                  '$goal개',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              selected: _dailyWordGoal == goal,
                                              onSelected:
                                                  goal <=
                                                      getMaxAvailableWords(
                                                        _selectedCategories
                                                            .length,
                                                      )
                                                  ? (_) => setState(
                                                      () =>
                                                          _dailyWordGoal = goal,
                                                    )
                                                  : null,
                                              selectedColor: _blue,
                                              backgroundColor: Colors.white,
                                              disabledColor: const Color(
                                                0xFFE5E7EB,
                                              ),
                                              labelStyle: TextStyle(
                                                color:
                                                    goal >
                                                        getMaxAvailableWords(
                                                          _selectedCategories
                                                              .length,
                                                        )
                                                    ? const Color(0xFF9CA3AF)
                                                    : _dailyWordGoal == goal
                                                    ? Colors.white
                                                    : const Color(0xFF4B5563),
                                                fontWeight: FontWeight.w800,
                                              ),
                                              side: BorderSide(
                                                color:
                                                    goal >
                                                        getMaxAvailableWords(
                                                          _selectedCategories
                                                              .length,
                                                        )
                                                    ? const Color(0xFFD1D5DB)
                                                    : _dailyWordGoal == goal
                                                    ? _blue
                                                    : const Color(0xFFD8DCE4),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      _selectedCategories.isEmpty
                                          ? '관심 분야를 먼저 선택해주세요.'
                                          : '분야별로 하루 3개의 단어가 제공돼요. 선택한 분야 수에 따라 가능한 목표가 달라져요.',
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 58,
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading || _saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              disabledBackgroundColor: const Color(0xFFD7DCE8),
                              foregroundColor: Colors.white,
                              shadowColor: const Color(0x665B8EF3),
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '선택 완료',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
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

  List<MainCategory> get _orderedCategories {
    return UserPreferenceService.defaultInterestCategories
        .map(
          (id) => mainCategories.firstWhere(
            (category) => category.categoryKey == id,
          ),
        )
        .toList();
  }
}

class _InterestCategoryCard extends StatelessWidget {
  const _InterestCategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final MainCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? _blue.withValues(alpha: 0.36)
                  : Colors.white.withValues(alpha: 0.84),
              width: 1.2,
            ),
            boxShadow: selected
                ? _clayShadows(const Color(0xFF7EA4F4))
                : _clayShadows(const Color(0xFFC7CBDD)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? category.background
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  category.icon,
                  color: selected ? _blue : const Color(0xFF9CA3AF),
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? _blue : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _blue : const Color(0xFFD8DCE4),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: selected ? Colors.white : Colors.transparent,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestCategorySkeleton extends StatelessWidget {
  const _InterestCategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        height: 74,
        decoration: _clayDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          radius: 24,
          shadowColor: const Color(0xFFC7CBDD),
        ),
      ),
    );
  }
}
