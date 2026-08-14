part of '../main.dart';

// TODO: 카카오톡 오픈채팅방을 만든 뒤 실제 URL을 입력하세요.
const String _kakaoOpenChatUrl = 'https://open.kakao.com/o/s6RvKWHi';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _isDeletingAccount = false;
  bool _isOpeningContact = false;

  Future<void> _confirmOpenKakaoChat(BuildContext context) async {
    if (_isOpeningContact) return;

    final shouldOpen = await _showKakaoChatConfirmation(context);
    if (shouldOpen != true || !context.mounted) return;

    await _openKakaoChat(context);
  }

  Future<void> _openKakaoChat(BuildContext context) async {
    if (_isOpeningContact) return;

    final url = _kakaoOpenChatUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null || !uri.hasScheme) {
      _showContactLaunchFailure(context);
      return;
    }

    setState(() => _isOpeningContact = true);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        _showContactLaunchFailure(context);
      }
    } catch (error) {
      debugPrint('Failed to open Kakao open chat: $error');
      if (context.mounted) {
        _showContactLaunchFailure(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningContact = false);
      }
    }
  }

  void _showContactLaunchFailure(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('문의 페이지를 열지 못했어요.\n잠시 후 다시 시도해 주세요.'),
      ),
    );
  }

  Future<bool> _showKakaoChatConfirmation(BuildContext context) async {
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBFF),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.78),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9EA0B7).withValues(alpha: 0.22),
                blurRadius: 30,
                spreadRadius: 1,
                offset: const Offset(12, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '카카오톡으로 문의하기',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '카카오톡 오픈채팅으로 이동해\n서비스 이용 중 불편한 점이나 오류를 문의할 수 있어요.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 10),
              const Text(
                '문의 시 비밀번호 등 민감한 개인정보는 보내지 마세요.',
                style: TextStyle(
                  color: Color(0xFF9A7B45),
                  fontSize: 11.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE8F0FF),
                          foregroundColor: _blue,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: const Color(0x665B8EF3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '문의하기',
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
      ),
    );
    return shouldOpen == true;
  }

  Future<void> _openNotificationSettings(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const LearningNotificationSettingsPage(),
      ),
    );
  }

  Future<void> _openInterestCategories(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const InterestCategoryPage()),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => const LegalDocumentPage(
          documentId: 'privacy',
          fallbackTitle: '개인정보처리방침',
        ),
      ),
    );
  }

  Future<void> _openTermsOfService(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LegalDocumentPage(documentId: 'terms', fallbackTitle: '이용약관'),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await _showSignOutConfirmation(context);
    if (shouldSignOut != true) return;

    try {
      await AuthService.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const _AuthGate()),
          (route) => false,
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그아웃 중 문제가 발생했습니다.')));
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    if (_isDeletingAccount) {
      return;
    }

    final firstConfirmed = await _showDeleteConfirmation(
      context,
      title: '계정을 삭제할까요?',
      message: '계정을 삭제하면 학습 기록, 저장 단어, 복습 기록이 모두 삭제되며 되돌릴 수 없어요.',
      confirmLabel: '삭제',
    );

    if (firstConfirmed != true || !context.mounted) {
      return;
    }

    final finalConfirmed = await _showDeleteConfirmation(
      context,
      title: '정말 삭제할까요?',
      message: '이 작업은 되돌릴 수 없습니다.',
      confirmLabel: '영구 삭제',
    );

    if (finalConfirmed == true && context.mounted) {
      await _deleteAccount(context);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    setState(() => _isDeletingAccount = true);
    try {
      final provider = AuthService.currentAccountLoginProvider();
      String? password;
      if (provider == AccountLoginProvider.password) {
        password = await _showReauthenticationDialog(context);
        if (password == null || password.isEmpty || !context.mounted) {
          return;
        }
      }

      await AuthService.deleteAccount(password: password);
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const _AuthGate()),
          (route) => false,
        );
      }
    } on AccountDeletionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FirebaseAuthException catch (error) {
      // ignore: avoid_print
      print('Delete account failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_deleteAccountErrorMessage(error))),
        );
      }
    } catch (error) {
      // ignore: avoid_print
      print('Delete account failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('계정 삭제 중 문제가 발생했습니다.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  Future<String?> _showReauthenticationDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('다시 로그인해 주세요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('보안을 위해 비밀번호를 다시 입력한 뒤 계정을 삭제할 수 있어요.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  String _deleteAccountErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'requires-recent-login':
        return '보안을 위해 다시 로그인한 뒤 계정을 삭제해주세요.';
      case 'wrong-password':
      case 'invalid-credential':
        return '비밀번호를 확인해 주세요.';
      default:
        return error.message ?? '계정 삭제 중 문제가 발생했습니다.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.currentUser?.email;

    return Scaffold(
      backgroundColor: _clayBackground,
      appBar: AppBar(
        title: const Text('마이', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: _clayBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF75A4FF), _blue],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: _clayShadows(const Color(0xFF6D8FE8)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 29,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person_rounded, color: _blue, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        email?.isNotEmpty == true ? email! : '이메일 정보 없음',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Text('학습 설정', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _MenuTile(
                icon: Icons.tune_rounded,
                title: '관심 분야 설정',
                color: Color(0xFFE8E9ED),
                iconColor: Color(0xFF6B7280),
                onTap: () => _openInterestCategories(context),
              ),
              _MenuTile(
                icon: Icons.notifications_none_rounded,
                title: '학습 알림 설정',
                color: const Color(0xFFE8E9ED),
                iconColor: const Color(0xFF6B7280),
                onTap: () => _openNotificationSettings(context),
              ),
              const SizedBox(height: 18),
              Text('약관 및 정책', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _MenuTile(
                icon: Icons.privacy_tip_outlined,
                title: '개인정보 처리방침',
                color: const Color(0xFFE8E9ED),
                iconColor: const Color(0xFF6B7280),
                onTap: () => _openPrivacyPolicy(context),
              ),
              _MenuTile(
                icon: Icons.description_outlined,
                title: '이용약관',
                color: const Color(0xFFE8E9ED),
                iconColor: const Color(0xFF6B7280),
                onTap: () => _openTermsOfService(context),
              ),
              const SizedBox(height: 18),
              Text('앱 정보', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _MenuTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: _isOpeningContact ? '문의 페이지 여는 중...' : '문의하기',
                color: const Color(0xFFE8E9ED),
                iconColor: const Color(0xFF6B7280),
                onTap: _isOpeningContact
                    ? null
                    : () => _confirmOpenKakaoChat(context),
              ),
              _MenuTile(
                icon: Icons.logout_rounded,
                title: '로그아웃',
                color: const Color(0xFFFFE7EA),
                iconColor: const Color(0xFFE15A6A),
                onTap: () => _confirmSignOut(context),
              ),
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                title: _isDeletingAccount ? '계정 삭제 중...' : '계정 삭제',
                color: const Color(0xFFFFE4E6),
                iconColor: const Color(0xFFDC2626),
                onTap: _isDeletingAccount
                    ? null
                    : () => _confirmDeleteAccount(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AccountManagementPage extends StatelessWidget {
  const AccountManagementPage({super.key});

  Future<void> _sendPasswordReset(BuildContext context) async {
    final user = AuthService.currentUser;
    final email = user?.email ?? '';
    final supportsPassword =
        user?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ==
        true;

    if (!supportsPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 계정의 비밀번호는 Google에서 관리해 주세요.')),
      );
      return;
    }
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 이메일을 확인할 수 없습니다.')));
      return;
    }

    try {
      await AuthService.sendPasswordResetEmail(email);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$email 주소로 비밀번호 변경 메일을 보냈어요.')));
      }
    } on FirebaseAuthException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? '비밀번호 변경 메일을 보내지 못했습니다.')),
        );
      }
    }
  }

  Future<void> _openInterestCategories(BuildContext context) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const InterestCategoryPage()),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final shouldSignOut = await _showSignOutConfirmation(context);
    if (shouldSignOut != true) return;

    try {
      await AuthService.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const _AuthGate()),
          (route) => false,
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그아웃 중 문제가 발생했습니다.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.currentUser?.email;

    return Scaffold(
      backgroundColor: _clayBackground,
      appBar: AppBar(
        title: const Text(
          '계정 관리',
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
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _clayDecoration(
                  color: Colors.white,
                  radius: 24,
                  shadowColor: const Color(0xFFC7CBDD),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '로그인 이메일',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      email?.isNotEmpty == true ? email! : '이메일 정보 없음',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _MenuTile(
                icon: Icons.lock_reset_rounded,
                title: '비밀번호 변경',
                color: const Color(0xFFE8F0FF),
                iconColor: _blue,
                onTap: () => _sendPasswordReset(context),
              ),
              _MenuTile(
                icon: Icons.tune_rounded,
                title: '관심 분야 수정',
                color: const Color(0xFFE8E9ED),
                iconColor: const Color(0xFF6B7280),
                onTap: () => _openInterestCategories(context),
              ),
              _MenuTile(
                icon: Icons.logout_rounded,
                title: '로그아웃',
                color: const Color(0xFFFFE7EA),
                iconColor: const Color(0xFFE15A6A),
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.iconColor,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _clayDecoration(
            radius: 20,
            shadowColor: const Color(0xFFC7CBDD),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(4, 6),
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      blurRadius: 10,
                      offset: Offset(-4, -5),
                    ),
                  ],
                ),
                child: Icon(icon, size: 21, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF191C21),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFC1C7D3),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
