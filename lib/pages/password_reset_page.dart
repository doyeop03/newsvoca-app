part of '../main.dart';

typedef PasswordResetSender = Future<void> Function(String email);

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({
    super.key,
    this.initialEmail = '',
    this.sendPasswordResetEmail,
  });

  final String initialEmail;
  final PasswordResetSender? sendPasswordResetEmail;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail.trim());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return '이메일 주소를 입력해 주세요.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return '올바른 이메일 주소를 입력해 주세요.';
    }
    return null;
  }

  Future<void> _sendResetEmail() async {
    if (_isSending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSending = true);
    try {
      final sender =
          widget.sendPasswordResetEmail ?? AuthService.sendPasswordResetEmail;
      await sender(_emailController.text.trim());
      if (mounted) await _showSuccessDialog();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      if (error.code == 'user-not-found') {
        await _showSuccessDialog();
      } else {
        _showError(_firebaseErrorMessage(error.code));
      }
    } on ArgumentError catch (error) {
      if (mounted) _showError(error.message?.toString() ?? '이메일 주소를 입력해 주세요.');
    } catch (error) {
      debugPrint('Password reset failed: $error');
      if (mounted) {
        _showError('재설정 메일을 보내지 못했어요.\n잠시 후 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _firebaseErrorMessage(String code) {
    return switch (code) {
      'invalid-email' => '올바른 이메일 주소를 입력해 주세요.',
      'too-many-requests' => '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.',
      'network-request-failed' => '인터넷 연결을 확인해 주세요.',
      'user-disabled' => '현재 사용할 수 없는 계정입니다.',
      _ => '재설정 메일을 보내지 못했어요.\n잠시 후 다시 시도해 주세요.',
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showSuccessDialog() async {
    final shouldReturn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
                '메일을 확인해 주세요',
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '입력한 이메일로 비밀번호 재설정 링크를 보냈어요.\n메일이 보이지 않으면 스팸함도 확인해 주세요.',
                style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '로그인으로 돌아가기',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (shouldReturn == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: _clayBackground,
      appBar: AppBar(
        title: const Text(
          '비밀번호 재설정',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: _clayBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_pageBackground, _clayBackground, Color(0xFFEAF7FF)],
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 32 + bottomInset),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '비밀번호를 잊으셨나요?',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '가입한 이메일 주소를 입력하면\n비밀번호를 다시 설정할 수 있는 링크를 보내드려요.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: _clayDecoration(
                          color: Colors.white,
                          radius: 26,
                          shadowColor: const Color(0xFFC7CBDD),
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailController,
                              autofocus: true,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              validator: _validateEmail,
                              onFieldSubmitted: (_) => _sendResetEmail(),
                              decoration: InputDecoration(
                                labelText: '이메일 주소',
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                  color: _blue,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF6F7FC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: const BorderSide(
                                    color: _blue,
                                    width: 1.3,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton(
                                onPressed: _isSending ? null : _sendResetEmail,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _blue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(
                                    0xFFAFC4FA,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: _isSending
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.4,
                                        ),
                                      )
                                    : const Text(
                                        '재설정 메일 보내기',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Google로 가입한 경우 비밀번호 재설정 대신\n로그인 화면의 ‘Google로 로그인’을 이용해 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF53627D),
                            fontSize: 12.5,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }
}
