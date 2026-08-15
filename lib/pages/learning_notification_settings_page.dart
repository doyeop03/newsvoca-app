part of '../main.dart';

class LearningNotificationSettingsPage extends StatefulWidget {
  const LearningNotificationSettingsPage({super.key});

  @override
  State<LearningNotificationSettingsPage> createState() =>
      _LearningNotificationSettingsPageState();
}

class _LearningNotificationSettingsPageState
    extends State<LearningNotificationSettingsPage> {
  LearningNotificationSettings _settings = const LearningNotificationSettings();
  bool _loading = true;
  bool _saving = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var settings = await LearningNotificationService.loadSettings();
    if (settings.dailyEnabled || settings.noStudyEnabled) {
      final granted = await LocalNotificationService.instance
          .requestPermission();
      if (!granted) {
        settings = settings.copyWith(
          dailyEnabled: false,
          noStudyEnabled: false,
        );
        await LearningNotificationService.updateSettings(settings);
      }
      _permissionDenied = !granted;
    }
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _update(LearningNotificationSettings next) async {
    if (_saving) return;
    final turningOn =
        (!_settings.dailyEnabled && next.dailyEnabled) ||
        (!_settings.noStudyEnabled && next.noStudyEnabled);
    if (turningOn) {
      final granted = await LocalNotificationService.instance
          .requestPermission();
      if (!granted) {
        if (mounted) setState(() => _permissionDenied = true);
        return;
      }
    }
    setState(() {
      _settings = next;
      _saving = true;
      _permissionDenied = false;
    });
    try {
      await LearningNotificationService.updateSettings(next);
    } catch (error) {
      // ignore: avoid_print
      print('[notification] settings update failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('알림 설정을 저장하지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _clayBackground,
      appBar: AppBar(
        title: const Text(
          '학습 알림 설정',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: _clayBackground,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_pageBackground, _clayBackground, Color(0xFFEAF7FF)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _blue))
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 36),
                children: [
                  const Text(
                    '데일리 학습과 미학습 리마인더를 관리해요',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _NotificationSettingCard(
                    icon: Icons.wb_sunny_outlined,
                    title: '데일리 학습 알림',
                    description: '매일 오전 8:00 오늘의 뉴스 단어를 알려드려요',
                    value: _settings.dailyEnabled,
                    enabled: !_saving,
                    onChanged: (value) =>
                        _update(_settings.copyWith(dailyEnabled: value)),
                  ),
                  const SizedBox(height: 14),
                  _NotificationSettingCard(
                    icon: Icons.nightlight_outlined,
                    title: '미학습 리마인더',
                    description: '밤 9시까지 학습을 시작하지 않으면 알려드려요',
                    value: _settings.noStudyEnabled,
                    enabled: !_saving,
                    onChanged: (value) =>
                        _update(_settings.copyWith(noStudyEnabled: value)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _clayDecoration(
                      color: Colors.white,
                      radius: 22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _permissionDenied
                              ? '기기 설정에서 NEWSVOCA 알림을 허용해 주세요.'
                              : '알림을 받으려면 기기 설정에서 NEWSVOCA 알림이 허용되어 있어야 해요.',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: LocalNotificationService
                              .instance
                              .openSystemNotificationSettings,
                          style: TextButton.styleFrom(foregroundColor: _blue),
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: const Text('알림 설정 열기'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NotificationSettingCard extends StatelessWidget {
  const _NotificationSettingCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _clayDecoration(color: Colors.white, radius: 24),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: _blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: _blue,
            inactiveThumbColor: const Color(0xFF8D96A8),
            inactiveTrackColor: const Color(0xFFDCE3EF),
            trackOutlineColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? _blue
                  : const Color(0xFFC6CFDD),
            ),
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
