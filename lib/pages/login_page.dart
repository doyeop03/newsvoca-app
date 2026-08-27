part of '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.legalDocumentLoader});

  final Future<LegalDocument> Function(String documentId)? legalDocumentLoader;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  bool _termsAgreed = false;
  bool _privacyAgreed = false;
  bool _ageConfirmed = false;

  bool get _isAllAgreed => _termsAgreed && _privacyAgreed && _ageConfirmed;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _toggleMode() {
    if (_isLoading) return;
    setState(() {
      _isSignUp = !_isSignUp;
      _termsAgreed = false;
      _privacyAgreed = false;
      _ageConfirmed = false;
    });
  }

  void _toggleAllAgreements(bool value) {
    setState(() {
      _termsAgreed = value;
      _privacyAgreed = value;
      _ageConfirmed = value;
    });
  }

  Future<void> _openLegalDocument({
    required String documentId,
    required String fallbackTitle,
  }) {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentPage(
          documentId: documentId,
          fallbackTitle: fallbackTitle,
          loader: widget.legalDocumentLoader == null
              ? null
              : () => widget.legalDocumentLoader!(documentId),
        ),
      ),
    );
  }

  String? _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty) {
      return '이메일을 입력해 주세요.';
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return '올바른 이메일 주소를 입력해 주세요.';
    }
    if (password.isEmpty) {
      return '비밀번호를 입력해 주세요.';
    }
    if (_isSignUp && password.length < 6) {
      return '비밀번호는 6자리 이상이어야 합니다.';
    }
    if (_isSignUp && password != confirmPassword) {
      return '비밀번호 확인이 일치하지 않습니다.';
    }
    if (_isSignUp && !_isAllAgreed) {
      return '필수 약관에 모두 동의해 주세요.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final validationMessage = _validate();
    if (validationMessage != null) {
      _showSnackBar(validationMessage);
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        final result = await AuthService.signUpWithEmail(
          _emailController.text,
          _passwordController.text,
          termsAgreed: _termsAgreed,
          privacyAgreed: _privacyAgreed,
          ageConfirmed: _ageConfirmed,
        );
        if (mounted) {
          _showSnackBar(
            result.verificationEmailSent
                ? '가입한 이메일로 인증 메일을 보냈어요. 메일함과 스팸함을 확인해 주세요.'
                : '회원가입은 완료됐지만 인증 메일을 보내지 못했어요. 잠시 후 다시 시도해 주세요.',
          );
        }
      } else {
        await AuthService.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      }
    } on AccountRegistrationException catch (error) {
      _showSnackBar(error.message);
    } on FirebaseAuthException catch (error) {
      _showSnackBar(_authErrorMessage(error));
    } catch (error) {
      // ignore: avoid_print
      print('Auth submit failed: $error');
      _showSnackBar('처리 중 문제가 발생했습니다. 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final credential = await AuthService.signInWithGoogle();
      if (credential == null) {
        return;
      }
    } on FirebaseAuthException catch (error) {
      _showSnackBar(_authErrorMessage(error));
    } catch (error) {
      // ignore: avoid_print
      print('Google sign-in failed: $error');
      _showSnackBar('Google 로그인 중 문제가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openPasswordReset() {
    return Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PasswordResetPage(initialEmail: _emailController.text.trim()),
      ),
    );
  }

  String _authErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return '올바른 이메일 주소를 입력해 주세요.';
      case 'user-not-found':
        return '가입된 이메일을 찾을 수 없습니다.';
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호를 확인해 주세요.';
      case 'email-already-in-use':
        return '이미 가입된 이메일이에요.';
      case 'weak-password':
        return '비밀번호를 더 안전하게 설정해 주세요.';
      case 'network-request-failed':
        return '인터넷 연결을 확인해 주세요.';
      case 'too-many-requests':
        return '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.';
      default:
        return _isSignUp
            ? '회원가입을 완료하지 못했어요. 잠시 후 다시 시도해 주세요.'
            : '인증 처리 중 문제가 발생했습니다. 다시 시도해 주세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

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
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(26, 28, 26, 28 + bottomInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEWSVOCA로',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '시사와 영어공부를 한번에',
                      style: TextStyle(
                        color: Color(0xFF3F4653),
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Center(
                      child: SizedBox(
                        width: 148,
                        height: 148,
                        child: Center(
                          child: Image.asset(
                            'assets/categories/images/logo.png',
                            width: 120,
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      decoration: _clayDecoration(
                        color: Colors.white,
                        radius: 28,
                        shadowColor: const Color(0xFFC7CBDD),
                      ),
                      child: Column(
                        children: [
                          _LoginTextField(
                            controller: _emailController,
                            label: '이메일주소',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _LoginTextField(
                            controller: _passwordController,
                            label: '비밀번호',
                            icon: Icons.lock_outline_rounded,
                            obscureText: true,
                          ),
                          if (_isSignUp) ...[
                            const SizedBox(height: 12),
                            _LoginTextField(
                              controller: _confirmPasswordController,
                              label: '비밀번호 확인',
                              icon: Icons.verified_user_outlined,
                              obscureText: true,
                            ),
                            const SizedBox(height: 18),
                            _SignUpAgreementSection(
                              allAgreed: _isAllAgreed,
                              termsAgreed: _termsAgreed,
                              privacyAgreed: _privacyAgreed,
                              ageConfirmed: _ageConfirmed,
                              onAllChanged: _toggleAllAgreements,
                              onTermsChanged: (value) =>
                                  setState(() => _termsAgreed = value),
                              onPrivacyChanged: (value) =>
                                  setState(() => _privacyAgreed = value),
                              onAgeChanged: (value) =>
                                  setState(() => _ageConfirmed = value),
                              onViewTerms: () => _openLegalDocument(
                                documentId: 'terms',
                                fallbackTitle: '이용약관',
                              ),
                              onViewPrivacy: () => _openLegalDocument(
                                documentId: 'privacy_consent',
                                fallbackTitle: '개인정보 수집·이용 동의',
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFFAFC4FA,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : Text(_isSignUp ? '회원가입' : '로그인'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _signInWithGoogle,
                              icon: Padding(
                                padding: const EdgeInsets.only(right: 3),
                                child: Image.asset(
                                  'assets/images/google_g_logo.png',
                                  width: 20,
                                  height: 20,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              label: const Text('Google로 로그인'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF343841),
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFFE3E7F0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: _isSignUp
                          ? TextButton(
                              onPressed: _toggleMode,
                              child: const Text('이미 계정이 있으신가요? 로그인'),
                            )
                          : Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                TextButton(
                                  onPressed: _toggleMode,
                                  child: const Text('회원가입'),
                                ),
                                const Text(
                                  '|',
                                  style: TextStyle(color: _muted),
                                ),
                                TextButton(
                                  onPressed: _openPasswordReset,
                                  child: const Text('비밀번호 찾기'),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: obscureText
          ? TextInputAction.done
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _blue),
        filled: true,
        fillColor: const Color(0xFFF6F7FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.white, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _blue, width: 1.3),
        ),
      ),
    );
  }
}

class _SignUpAgreementSection extends StatelessWidget {
  const _SignUpAgreementSection({
    required this.allAgreed,
    required this.termsAgreed,
    required this.privacyAgreed,
    required this.ageConfirmed,
    required this.onAllChanged,
    required this.onTermsChanged,
    required this.onPrivacyChanged,
    required this.onAgeChanged,
    required this.onViewTerms,
    required this.onViewPrivacy,
  });

  final bool allAgreed;
  final bool termsAgreed;
  final bool privacyAgreed;
  final bool ageConfirmed;
  final ValueChanged<bool> onAllChanged;
  final ValueChanged<bool> onTermsChanged;
  final ValueChanged<bool> onPrivacyChanged;
  final ValueChanged<bool> onAgeChanged;
  final VoidCallback onViewTerms;
  final VoidCallback onViewPrivacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5EAFE)),
      ),
      child: Column(
        children: [
          _AgreementRow(
            value: allAgreed,
            label: '전체 동의',
            isAllAgreement: true,
            onChanged: onAllChanged,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 2, 8, 4),
            child: Divider(height: 1, color: Color(0xFFE1E6F2)),
          ),
          _AgreementRow(
            value: termsAgreed,
            label: '이용약관에 동의합니다.',
            requiredAgreement: true,
            onChanged: onTermsChanged,
            onView: onViewTerms,
          ),
          _AgreementRow(
            value: privacyAgreed,
            label: '개인정보 수집·이용에 동의합니다.',
            requiredAgreement: true,
            onChanged: onPrivacyChanged,
            onView: onViewPrivacy,
          ),
          _AgreementRow(
            value: ageConfirmed,
            label: '만 14세 이상입니다.',
            requiredAgreement: true,
            onChanged: onAgeChanged,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 4, 8, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'NEWSVOCA는 만 14세 이상만 가입할 수 있어요.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.value,
    required this.label,
    required this.onChanged,
    this.requiredAgreement = false,
    this.isAllAgreement = false,
    this.onView,
  });

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool requiredAgreement;
  final bool isAllAgreement;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onChanged(!value),
              borderRadius: BorderRadius.circular(13),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox.adaptive(
                      value: value,
                      onChanged: (checked) => onChanged(checked ?? false),
                      activeColor: _blue,
                      side: const BorderSide(
                        color: Color(0xFFABB4C6),
                        width: 1.5,
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            if (requiredAgreement)
                              const TextSpan(
                                text: '[필수] ',
                                style: TextStyle(color: _blue),
                              ),
                            TextSpan(text: label),
                          ],
                        ),
                        style: TextStyle(
                          color: const Color(0xFF343841),
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: isAllAgreement
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onView != null)
            TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                foregroundColor: _blue,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.underline,
                ),
              ),
              child: const Text('보기'),
            ),
        ],
      ),
    );
  }
}
