import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        await createOrUpdateUserDoc(user, provider: 'google');
      }
      return userCredential;
    } catch (error) {
      // ignore: avoid_print
      print(
        'Google sign-in failed. If this happens on Android, register SHA-1/SHA-256 in Firebase Console > Project Settings > Android app and download google-services.json again. error=$error',
      );
      rethrow;
    }
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

    await _reauthenticateForAccountDeletion(user, password: password);

    final uid = user.uid;
    // Do not delete the Auth account unless every Firestore deletion succeeds.
    await _deleteUserData(uid);
    await user.delete();
    await AppLocalDataService.clearAppPreferences(uid: uid);
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
