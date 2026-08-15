import 'dart:math' as math;
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        debugPaintBaselinesEnabled,
        debugPaintLayerBordersEnabled,
        debugPaintSizeEnabled,
        debugPaintTextLayoutBoxes,
        debugRepaintRainbowEnabled,
        debugRepaintTextRainbowEnabled;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'models/legal_document.dart';
import 'services/auth_service.dart';
import 'services/article_related_words_guide_service.dart';
import 'services/calendar_learning_service.dart';
import 'services/daily_word_service.dart';
import 'services/daily_learning_guide_service.dart';
import 'services/integrated_daily_learning_service.dart';
import 'services/learning_difficulty_feedback_service.dart';
import 'services/review_service.dart';
import 'services/review_curve_guide_service.dart';
import 'services/tts_service.dart';
import 'services/user_word_service.dart';
import 'services/user_preference_service.dart';
import 'services/local_notification_service.dart';
import 'services/learning_notification_service.dart';
import 'services/knowledge_map_service.dart';
import 'services/legal_document_service.dart';
import 'services/onboarding_service.dart';
import 'utils/learning_date.dart';

part 'models/learning_data.dart';
part 'utils/distractor_selector.dart';
part 'pages/article_pages.dart';
part 'pages/article_mini_quiz_page.dart';
part 'pages/home_page.dart';
part 'pages/interest_category_page.dart';
part 'pages/login_page.dart';
part 'pages/learning_calendar_page.dart';
part 'pages/learning_notification_settings_page.dart';
part 'pages/knowledge_map_page.dart';
part 'pages/legal_pages.dart';
part 'pages/my_page.dart';
part 'pages/onboarding_page.dart';
part 'pages/password_reset_page.dart';
part 'pages/quiz_page.dart';
part 'pages/review_page.dart';
part 'pages/review_quiz_page.dart';
part 'pages/topic_page.dart';
part 'pages/word_detail_page.dart';
part 'widgets/common_widgets.dart';

String appDateString([DateTime? date]) {
  return date == null ? getCurrentLearningDateKst() : formatDate(date);
}

String dailyQuizCompletedKey(String date, String category) =>
    'daily_quiz_completed_${date}_$category';

Future<void> main() async {
  _disableDebugPaintOverlays();
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.pageBackground,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await LocalNotificationService.instance.initialize();
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }
    final user = FirebaseAuth.instance.currentUser;
    debugPrint('[auth] currentUser: ${user?.uid}, email=${user?.email}');
    runApp(const VocaBriefApp());
  } catch (error) {
    // ignore: avoid_print
    print('Firebase startup failed: $error');
    runApp(VocaBriefApp(startupError: error.toString()));
  }
}

void _disableDebugPaintOverlays() {
  assert(() {
    debugPaintSizeEnabled = false;
    debugPaintBaselinesEnabled = false;
    debugPaintTextLayoutBoxes = false;
    debugPaintLayerBordersEnabled = false;
    debugRepaintRainbowEnabled = false;
    debugRepaintTextRainbowEnabled = false;
    return true;
  }());
}

const _ink = Color(0xFF17171C);
const _muted = Color(0xFF74747E);
const _lime = Color(0xFFDDF86A);
const _blue = Color(0xFF5B8EF3);
const _purple = _blue;

abstract final class AppColors {
  static const pageBackground = Color(0xFFF6F0FF);
  static const primaryText = _ink;
}

const _pageBackground = AppColors.pageBackground;

class VocaBriefApp extends StatelessWidget {
  const VocaBriefApp({super.key, this.startupError});

  final String? startupError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VocaBrief',
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: AppColors.pageBackground,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: ColoredBox(
          color: AppColors.pageBackground,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.pageBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _purple,
          surface: AppColors.pageBackground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.pageBackground,
          foregroundColor: AppColors.primaryText,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
            systemNavigationBarColor: AppColors.pageBackground,
            systemNavigationBarIconBrightness: Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        ),
        fontFamily: 'sans-serif',
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 34,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: _ink,
          ),
          headlineMedium: TextStyle(
            fontSize: 27,
            height: 1.2,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: _ink,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
          bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: _ink),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: _muted),
        ),
      ),
      home: startupError == null
          ? const _AuthGate()
          : _StartupErrorScreen(message: startupError!),
    );
  }
}

class _IntroOnboardingGate extends StatefulWidget {
  const _IntroOnboardingGate({required this.uid});

  final String uid;

  @override
  State<_IntroOnboardingGate> createState() => _IntroOnboardingGateState();
}

class _IntroOnboardingGateState extends State<_IntroOnboardingGate> {
  late Future<bool> _completion = OnboardingService.isCompleted(widget.uid);

  void _continueToHome() {
    setState(() => _completion = Future.value(true));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completion,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const _SplashPage();
        if (snapshot.data == true) {
          return const _NotificationBootstrap(child: HomeScreen());
        }
        return OnboardingScreen(
          userId: widget.uid,
          onCompleted: _continueToHome,
        );
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashPage();
        }

        final user = snapshot.data;
        debugPrint(
          '[auth] authStateChanges user=${user?.uid}, email=${user?.email}',
        );
        if (user == null || user.isAnonymous) {
          return const LoginPage();
        }

        return _IntroOnboardingGate(uid: user.uid);
      },
    );
  }
}

class _NotificationBootstrap extends StatefulWidget {
  const _NotificationBootstrap({required this.child});
  final Widget child;

  @override
  State<_NotificationBootstrap> createState() => _NotificationBootstrapState();
}

class _NotificationBootstrapState extends State<_NotificationBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LearningNotificationService.rescheduleAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LearningNotificationService.rescheduleAll();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(child: Center(child: CircularProgressIndicator())),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '앱 초기화 중 문제가 발생했습니다.\n$message',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
