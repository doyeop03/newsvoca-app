import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../constants/legal_document_versions.dart';
import 'app_local_data_service.dart';

enum AccountLoginProvider { password, google }

class AccountDeletionException implements Exception {
  const AccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountRegistrationException implements Exception {
  const AccountRegistrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmailSignUpResult {
  const EmailSignUpResult({
    required this.credential,
    required this.verificationEmailSent,
  });

  final UserCredential credential;
  final bool verificationEmailSent;
}

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  static User? get currentUser => _auth.currentUser;
  static String? get currentUid => _auth.currentUser?.uid;
  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static AccountLoginProvider resolveAccountLoginProvider(
    Iterable<String> providerIds,
  ) {
    final ids = providerIds.toSet();
    if (ids.contains(EmailAuthProvider.PROVIDER_ID)) {
      return AccountLoginProvider.password;
    }
    if (ids.contains(GoogleAuthProvider.PROVIDER_ID)) {
      return AccountLoginProvider.google;
    }
    throw const AccountDeletionException('지원하지 않는 로그인 방식입니다. 고객센터에 문의해 주세요.');
  }

  static AccountLoginProvider currentAccountLoginProvider() {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionException('로그인 정보가 없습니다. 다시 로그인해 주세요.');
    }
    return resolveAccountLoginProvider(
      user.providerData.map((provider) => provider.providerId),
    );
  }

  static Future<UserCredential> signInWithEmail(
    String email,
    String password,
  ) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await createOrUpdateUserDoc(user, provider: 'password');
    }
    return credential;
  }

  static Future<EmailSignUpResult> signUpWithEmail(
    String email,
    String password, {
    required bool termsAgreed,
    required bool privacyAgreed,
    required bool ageConfirmed,
  }) async {
    if (!termsAgreed || !privacyAgreed || !ageConfirmed) {
      throw const AccountRegistrationException('필수 약관에 모두 동의해 주세요.');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      try {
        await createOrUpdateUserDoc(
          user,
          provider: 'password',
          agreements: buildRequiredAgreementData(
            timestamp: FieldValue.serverTimestamp(),
          ),
        );
      } catch (error) {
        // Avoid leaving a usable Auth account without its required profile and
        // agreement history when Firestore persistence fails.
        try {
          await user.delete();
        } catch (rollbackError) {
          // ignore: avoid_print
          print('Sign-up rollback failed: $rollbackError');
          await _auth.signOut();
        }
        throw const AccountRegistrationException(
          '회원 정보를 저장하지 못했어요. 잠시 후 다시 시도해 주세요.',
        );
      }

      var verificationEmailSent = true;
      try {
        await user.sendEmailVerification();
      } catch (error) {
        verificationEmailSent = false;
        // ignore: avoid_print
        print('Send email verification failed: $error');
      }
      return EmailSignUpResult(
        credential: credential,
        verificationEmailSent: verificationEmailSent,
      );
    }
    return EmailSignUpResult(
      credential: credential,
      verificationEmailSent: false,
    );
  }

  static Map<String, dynamic> buildRequiredAgreementData({
    required Object timestamp,
  }) {
    return {
      'terms': {
        'agreed': true,
        'version': LegalDocumentVersions.terms,
        'agreed_at': timestamp,
      },
      'privacy_collection': {
        'agreed': true,
        'version': LegalDocumentVersions.privacyCollection,
        'agreed_at': timestamp,
      },
      'age_over_14': {'confirmed': true, 'confirmed_at': timestamp},
    };
  }

  static Future<UserCredential?> signInWithGoogle() async {
    const googleSignInStage = '1_google_sign_in';
    const idTokenStage = '2_google_id_token';
    const firebaseAuthStage = '3_firebase_auth';
    const userDocumentStage = '4_firestore_user_document';

    debugPrint('[GoogleAuth][stage=$googleSignInStage][status=start]');
    GoogleSignInAccount? googleUser;
    try {
      googleUser = await _googleSignIn.signIn();
    } catch (error, stackTrace) {
      _logGoogleAuthFailure(googleSignInStage, error, stackTrace);
      rethrow;
    }
    if (googleUser == null) {
      debugPrint('[GoogleAuth][stage=$googleSignInStage][status=cancelled]');
      return null;
    }
    debugPrint('[GoogleAuth][stage=$googleSignInStage][status=success]');

    debugPrint('[GoogleAuth][stage=$idTokenStage][status=start]');
    GoogleSignInAuthentication googleAuth;
    try {
      googleAuth = await googleUser.authentication;
    } catch (error, stackTrace) {
      _logGoogleAuthFailure(idTokenStage, error, stackTrace);
      rethrow;
    }
    debugPrint(
      '[GoogleAuth][stage=$idTokenStage][status=success] '
      'idTokenPresent=${googleAuth.idToken != null}',
    );

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    debugPrint('[GoogleAuth][stage=$firebaseAuthStage][status=start]');
    UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithCredential(credential);
    } catch (error, stackTrace) {
      _logGoogleAuthFailure(firebaseAuthStage, error, stackTrace);
      rethrow;
    }
    debugPrint('[GoogleAuth][stage=$firebaseAuthStage][status=success]');

    final user = userCredential.user;
    if (user != null) {
      debugPrint('[GoogleAuth][stage=$userDocumentStage][status=start]');
      try {
        await createOrUpdateUserDoc(user, provider: 'google');
      } catch (error, stackTrace) {
        _logGoogleAuthFailure(userDocumentStage, error, stackTrace);
        rethrow;
      }
      debugPrint('[GoogleAuth][stage=$userDocumentStage][status=success]');
    } else {
      debugPrint('[GoogleAuth][stage=$userDocumentStage][status=skipped]');
    }
    return userCredential;
  }

  static void _logGoogleAuthFailure(
    String stage,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint('[GoogleAuth][stage=$stage][status=failure]');
    debugPrint('[GoogleAuth][stage=$stage] runtimeType=${error.runtimeType}');
    debugPrint(
      '[GoogleAuth][stage=$stage] exceptionMessage='
      '${_sanitizeAuthLogValue(error.toString())}',
    );

    if (error is FirebaseAuthException) {
      debugPrint('[GoogleAuth][stage=$stage] firebaseAuthCode=${error.code}');
      debugPrint(
        '[GoogleAuth][stage=$stage] firebaseAuthMessage='
        '${_sanitizeAuthLogValue(error.message)}',
      );
    } else if (error is FirebaseException) {
      debugPrint('[GoogleAuth][stage=$stage] firebaseCode=${error.code}');
      debugPrint(
        '[GoogleAuth][stage=$stage] firebaseMessage='
        '${_sanitizeAuthLogValue(error.message)}',
      );
    }
    if (error is PlatformException) {
      debugPrint('[GoogleAuth][stage=$stage] platformCode=${error.code}');
      debugPrint(
        '[GoogleAuth][stage=$stage] platformMessage='
        '${_sanitizeAuthLogValue(error.message)}',
      );
    }

    debugPrintStack(
      label: '[GoogleAuth][stage=$stage] stackTrace',
      stackTrace: stackTrace,
    );
  }

  static String _sanitizeAuthLogValue(Object? value) {
    if (value == null) return 'null';

    var sanitized = value.toString();
    final currentUser = _auth.currentUser;
    final uid = currentUser?.uid;
    final email = currentUser?.email;
    if (uid != null && uid.isNotEmpty) {
      sanitized = sanitized.replaceAll(uid, '[REDACTED_UID]');
    }
    if (email != null && email.isNotEmpty) {
      sanitized = sanitized.replaceAll(email, '[REDACTED_EMAIL]');
    }
    sanitized = sanitized.replaceAll(
      RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
      '[REDACTED_EMAIL]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
      '[REDACTED_TOKEN]',
    );
    sanitized = sanitized.replaceAll(
      RegExp(
        r'(access[_ ]?token|id[_ ]?token)\s*[:=]\s*[^,\s}\]]+',
        caseSensitive: false,
      ),
      '[REDACTED_TOKEN_FIELD]',
    );
    return sanitized;
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw ArgumentError('이메일을 입력해 주세요.');
    }
    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      // ignore: avoid_print
      print('Google sign-out failed: $error');
    }
    await _auth.signOut();
  }

  static Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AccountDeletionException('로그인 정보가 없습니다. 다시 로그인해 주세요.');
    }

    // Keep the identifiers needed by every cleanup step before Auth can become
    // null. Deleting the Auth user is deliberately the final asynchronous step.
    final uid = user.uid;
    await runAccountDeletionSteps(
      reauthenticate: () =>
          _reauthenticateForAccountDeletion(user, password: password),
      deleteRemoteData: () => _deleteUserData(uid),
      clearLocalData: () => AppLocalDataService.clearAppPreferences(uid: uid),
      deleteAuthUser: user.delete,
    );
  }

  @visibleForTesting
  static Future<void> runAccountDeletionSteps({
    required Future<void> Function() reauthenticate,
    required Future<void> Function() deleteRemoteData,
    required Future<void> Function() clearLocalData,
    required Future<void> Function() deleteAuthUser,
  }) async {
    await reauthenticate();
    // Do not delete the Auth account unless every data cleanup succeeds.
    await deleteRemoteData();
    await clearLocalData();
    await deleteAuthUser();
  }

  static Future<void> _reauthenticateForAccountDeletion(
    User user, {
    String? password,
  }) async {
    final provider = resolveAccountLoginProvider(
      user.providerData.map((item) => item.providerId),
    );

    switch (provider) {
      case AccountLoginProvider.password:
        final email = user.email;
        if (email == null || email.isEmpty) {
          throw const AccountDeletionException(
            '이메일 로그인 정보를 확인할 수 없습니다. 다시 로그인해 주세요.',
          );
        }
        if (password == null || password.isEmpty) {
          throw const AccountDeletionException('계정 삭제를 위해 비밀번호를 입력해 주세요.');
        }
        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        return;
      case AccountLoginProvider.google:
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw const AccountDeletionException('Google 계정 확인이 취소되었습니다.');
        }
        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(credential);
        return;
    }
  }

  static Future<void> _deleteUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);
    final subcollections = [
      'user_words',
      'quiz_results',
      'review_results',
      'article_learning_results',
    ];

    for (final name in subcollections) {
      await _deleteCollection(userRef.collection(name));
    }
    await userRef.delete();

    // ignore: avoid_print
    print('Deleted Firestore user data: users/$uid');
  }

  static Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection, {
    int batchSize = 100,
  }) async {
    while (true) {
      final snapshot = await collection.limit(batchSize).get();
      if (snapshot.docs.isEmpty) {
        return;
      }

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  // Kept for existing data services. It no longer performs anonymous sign-in.
  static Future<String> ensureAnonymousLogin() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('Login is required.');
    }

    return user.uid;
  }

  static Future<void> createOrUpdateUserDoc(
    User? user, {
    required String provider,
    Map<String, dynamic>? agreements,
  }) async {
    if (user == null) {
      return;
    }

    final ref = _firestore.collection('users').doc(user.uid);
    final snapshot = await ref.get();
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'uid': user.uid,
      'email_verified': user.emailVerified,
      'is_anonymous': false,
      'provider': provider,
      'last_login_at': now,
      'updated_at': now,
      'agreements': ?agreements,
      if (!snapshot.exists) ...{
        'created_at': now,
        'subscription_status': 'free',
        'subscription_plan': 'free',
      },
    };
    final email = user.email;
    final displayName = user.displayName;
    final photoUrl = user.photoURL;
    if (email != null && email.isNotEmpty) {
      data['email'] = email;
    }
    if (displayName != null && displayName.isNotEmpty) {
      data['display_name'] = displayName;
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      data['photo_url'] = photoUrl;
    }

    await ref.set(data, SetOptions(merge: true));

    // ignore: avoid_print
    print(
      'User document ${snapshot.exists ? 'updated' : 'created'}: users/${user.uid}',
    );
  }
}
