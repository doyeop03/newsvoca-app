part of '../main.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key, required this.initialSelection});
  final Set<String> initialSelection;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  late final Set<String> selected = {...widget.initialSelection};

  @override
  Widget build(BuildContext context) {
    return _FlowScaffold(
      title: '어떤 뉴스가\n궁금한가요?',
      subtitle: '관심 분야를 2개 이상 선택해 주세요.',
      bottom: _PrimaryButton(
        label: '선택 완료 (${selected.length})',
        enabled: selected.length >= 2,
        onTap: () => Navigator.pop(context, selected),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: topics.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
        ),
        itemBuilder: (_, index) {
          final topic = topics[index];
          final active = selected.contains(topic.name);
          return InkWell(
            onTap: () => setState(
              () => active
                  ? selected.remove(topic.name)
                  : selected.add(topic.name),
            ),
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: active ? topic.color : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: active ? _ink : const Color(0xFFE5E3DD),
                  width: active ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(topic.icon, size: 29),
                      if (active)
                        const Icon(Icons.check_circle_rounded, size: 21),
                    ],
                  ),
                  Text(
                    topic.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
