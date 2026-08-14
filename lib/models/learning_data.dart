part of '../main.dart';

class Topic {
  const Topic(this.name, this.icon, this.color);
  final String name;
  final IconData icon;
  final Color color;
}

const topics = [
  Topic('경제', Icons.trending_up_rounded, Color(0xFFFFF3C9)),
  Topic('정치', Icons.account_balance_rounded, Color(0xFFE4EDFF)),
  Topic('기술', Icons.memory_rounded, Color(0xFFEAE5FF)),
  Topic('국제', Icons.public_rounded, Color(0xFFDFF1FF)),
  Topic('사회', Icons.groups_rounded, Color(0xFFFFE5EC)),
];

class MainCategory {
  const MainCategory({
    required this.name,
    required this.categoryKey,
    required this.subtitle,
    required this.icon,
    required this.word,
    required this.meaning,
    required this.background,
    required this.imageAsset,
  });

  final String name;
  final String categoryKey;
  final String subtitle;
  final IconData icon;
  final String word;
  final String meaning;
  final Color background;
  final String imageAsset;
}

const mainCategories = [
  MainCategory(
    name: '사회',
    categoryKey: 'society',
    subtitle: '생활, 사건, 교육, 환경 이슈를 단어로 익혀요.',
    icon: Icons.groups_rounded,
    word: 'influence',
    meaning: '영향, 영향력',
    background: Color(0xFFD9D9D9),
    imageAsset: 'assets/categories/social.png',
  ),
  MainCategory(
    name: '경제',
    categoryKey: 'economy',
    subtitle: '금리, 물가, 시장 흐름을 영어로 학습해요.',
    icon: Icons.trending_up_rounded,
    word: 'breakthrough',
    meaning: '획기적인 발전, 돌파구',
    background: Color(0xFFD9D9D9),
    imageAsset: 'assets/categories/economy.png',
  ),
  MainCategory(
    name: '정치',
    categoryKey: 'politics',
    subtitle: '정책, 선거, 외교 이슈의 핵심 표현을 배워요.',
    icon: Icons.account_balance_rounded,
    word: 'reform',
    meaning: '개혁, 개선',
    background: Color(0xFFD9D9D9),
    imageAsset: 'assets/categories/politics.png',
  ),
  MainCategory(
    name: '기술',
    categoryKey: 'technology',
    subtitle: 'AI, 반도체, 플랫폼 뉴스를 영어 단어로 훑어요.',
    icon: Icons.memory_rounded,
    word: 'innovation',
    meaning: '혁신, 새로운 변화',
    background: Color(0xFFD9D9D9),
    imageAsset: 'assets/categories/technology.png',
  ),
  MainCategory(
    name: '국제',
    categoryKey: 'world',
    subtitle: '세계 이슈와 글로벌 뉴스를 영어로 접해요.',
    icon: Icons.public_rounded,
    word: 'alliance',
    meaning: '동맹, 연합',
    background: Color(0xFFD9D9D9),
    imageAsset: 'assets/categories/international.png',
  ),
];

class WordExample {
  const WordExample(this.sentence, this.translation);

  final String sentence;
  final String translation;
}

class RelatedArticle {
  const RelatedArticle({
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.url,
    this.data = const {},
  });

  final String title;
  final String source;
  final String publishedAt;
  final String url;
  final Map<String, dynamic> data;
}

class LearningWord {
  const LearningWord({
    required this.word,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.meaning,
    required this.description,
    this.descriptionKo = '',
    required this.collocations,
    required this.examples,
    required this.articleTitles,
    required this.relatedArticles,
    required this.color,
    required this.topics,
    required this.difficulty,
    required this.week,
    this.category = '',
    this.topic = '',
    this.topicLabelKo = '',
  });

  final String word;
  final String pronunciation;
  final String partOfSpeech;
  final String meaning;
  final String description;
  final String descriptionKo;
  final List<String> collocations;
  final List<WordExample> examples;
  final List<String> articleTitles;
  final List<RelatedArticle> relatedArticles;
  final Color color;
  final List<String> topics;
  final String difficulty;
  final int week;
  final String category;
  final String topic;
  final String topicLabelKo;
}

const learningWords = [
  LearningWord(
    word: 'breakthrough',
    pronunciation: '/ˈbreɪk.θruː/',
    partOfSpeech: 'noun',
    meaning: '획기적인 발전, 돌파구',
    description: '오랫동안 해결되지 않던 문제를 해결하거나 어떤 분야에서 매우 중요한 진전을 이룬 순간.',
    collocations: ['major breakthrough', 'economic breakthrough'],
    examples: [
      WordExample(
        'The agreement marks a major breakthrough for small businesses.',
        '그 합의는 소상공인에게 중요한 돌파구가 된다.',
      ),
      WordExample(
        'Analysts called the policy a breakthrough in market recovery.',
        '분석가들은 그 정책을 시장 회복의 돌파구라고 불렀다.',
      ),
    ],
    articleTitles: [
      'New investment plan creates a breakthrough for local businesses',
      'Markets rise after signs of a breakthrough in trade talks',
      'Startups look for their next commercial breakthrough',
    ],
    relatedArticles: [],
    color: Color(0xFFFFF3C9),
    topics: ['경제'],
    difficulty: '중급',
    week: 1,
  ),
  LearningWord(
    word: 'reform',
    pronunciation: '/rɪˈfɔːrm/',
    partOfSpeech: 'noun',
    meaning: '개혁, 개선',
    description: '제도나 조직의 문제점을 고쳐 더 나은 방향으로 바꾸는 것.',
    collocations: ['policy reform', 'electoral reform'],
    examples: [
      WordExample(
        'Lawmakers debated a new education reform bill.',
        '의원들은 새로운 교육 개혁 법안을 논의했다.',
      ),
      WordExample(
        'The mayor promised reform in city administration.',
        '시장은 시 행정 개혁을 약속했다.',
      ),
    ],
    articleTitles: [
      'Parliament discusses a broad package of policy reforms',
      'Local leaders call for reform after public hearings',
      'Voters focus on reform pledges ahead of election day',
    ],
    relatedArticles: [],
    color: Color(0xFFE4EDFF),
    topics: ['정치'],
    difficulty: '초급',
    week: 1,
  ),
  LearningWord(
    word: 'innovation',
    pronunciation: '/ˌɪn.əˈveɪ.ʃən/',
    partOfSpeech: 'noun',
    meaning: '혁신, 새로운 변화',
    description: '새로운 아이디어나 기술을 도입해 기존 방식이나 제품을 더 나은 방향으로 바꾸는 것.',
    collocations: ['drive innovation', 'technological innovation'],
    examples: [
      WordExample(
        'The company is known for innovation in mobile technology.',
        '그 회사는 모바일 기술 혁신으로 잘 알려져 있다.',
      ),
      WordExample(
        'Investment in research can drive innovation.',
        '연구 투자는 혁신을 촉진할 수 있다.',
      ),
    ],
    articleTitles: [
      'Small AI companies lead the next wave of innovation',
      'How battery innovation is reshaping electric cars',
      'Schools create new spaces for educational innovation',
    ],
    relatedArticles: [],
    color: Color(0xFFEAE5FF),
    topics: ['기술'],
    difficulty: '중급',
    week: 2,
  ),
  LearningWord(
    word: 'alliance',
    pronunciation: '/əˈlaɪ.əns/',
    partOfSpeech: 'noun',
    meaning: '동맹, 연합',
    description: '공통의 목표나 이익을 위해 여러 나라나 단체가 협력하는 관계.',
    collocations: ['strategic alliance', 'global alliance'],
    examples: [
      WordExample(
        'The two countries formed a strategic alliance.',
        '두 나라는 전략적 동맹을 맺었다.',
      ),
      WordExample(
        'A global alliance agreed to reduce carbon emissions.',
        '국제 연합체가 탄소 배출 감축에 합의했다.',
      ),
    ],
    articleTitles: [
      'New regional alliance aims to strengthen supply chains',
      'Countries expand alliance during climate summit',
      'Diplomats discuss security alliance in Seoul',
    ],
    relatedArticles: [],
    color: Color(0xFFDFF1FF),
    topics: ['국제'],
    difficulty: '고급',
    week: 3,
  ),
  LearningWord(
    word: 'influence',
    pronunciation: '/ˈɪn.flu.əns/',
    partOfSpeech: 'noun',
    meaning: '영향, 영향력',
    description: '사람의 생각이나 행동, 또는 어떤 상황의 변화에 영향을 미치고 방향을 바꾸는 작용.',
    collocations: ['have an influence', 'social influence'],
    examples: [
      WordExample(
        'Social media has a strong influence on consumer choices.',
        '소셜 미디어는 소비자의 선택에 강한 영향을 미친다.',
      ),
      WordExample(
        'Her work continues to influence young artists.',
        '그녀의 작품은 젊은 예술가들에게 계속 영향을 준다.',
      ),
    ],
    articleTitles: [
      'The growing influence of short-form video',
      'Community groups gain influence in local planning',
      'Young creators gain influence in the fashion industry',
    ],
    relatedArticles: [],
    color: Color(0xFFFFE5EC),
    topics: ['사회'],
    difficulty: '초급',
    week: 2,
  ),
];
