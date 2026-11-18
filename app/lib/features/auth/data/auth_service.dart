import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// FirebaseAuthPlatform isn't re-exported by firebase_auth, so import it here
// for the web RecaptchaVerifier.
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart'
    show FirebaseAuthPlatform;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps Firebase Auth for Savarun — Google, Apple and Phone OTP — and makes sure a
/// matching `users/{uid}` profile document exists in Firestore on first login.
class AuthService {
  AuthService(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Google ──
  /// On mobile this uses the NATIVE Google account-picker (the device's email
  /// list) via `google_sign_in`, then hands the credential to Firebase — so
  /// there is no browser/Custom-Tab redirect. On web we use the popup.
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      final cred = await _auth.signInWithPopup(provider);
      await _ensureUserDoc(cred.user);
      return;
    }

    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      // The user closed the account picker — treat as a cancel, not an error.
      throw FirebaseAuthException(
        code: 'canceled',
        message: 'Google sign-in was cancelled',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    await _ensureUserDoc(cred.user);
  }

  // ── Apple ──
  /// Requires the Apple provider to be enabled in the Firebase console
  /// (and an Apple Developer account for the native iOS flow).
  Future<void> signInWithApple() async {
    final provider = AppleAuthProvider()..addScope('email')..addScope('name');
    final cred = kIsWeb
        ? await _auth.signInWithPopup(provider)
        : await _auth.signInWithProvider(provider);
    await _ensureUserDoc(cred.user);
  }

  // ── Phone OTP (web) ──
  /// Web sends the SMS and returns a confirmation object you later `.confirm()`.
  ///
  /// We pass an explicit invisible [RecaptchaVerifier]. Without it, the auto
  /// verifier can produce "invalid application verifier / reCAPTCHA token
  /// invalid or expired" and the send fails with HTTP 400.
  Future<ConfirmationResult> sendOtpWeb(String phoneE164) {
    final verifier = RecaptchaVerifier(
      auth: FirebaseAuthPlatform.instance,
      size: RecaptchaVerifierSize.compact,
      theme: RecaptchaVerifierTheme.light,
    );
    return _auth.signInWithPhoneNumber(phoneE164, verifier);
  }

  Future<void> confirmOtpWeb(ConfirmationResult result, String smsCode) async {
    final cred = await result.confirm(smsCode);
    await _ensureUserDoc(cred.user);
  }

  // ── Phone OTP (mobile) ──
  Future<void> sendOtpMobile(
    String phoneE164, {
    required void Function(String verificationId) onCodeSent,
    required void Function(FirebaseAuthException e) onFailed,
    void Function(PhoneAuthCredential cred)? onAutoVerified,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      verificationCompleted: (cred) async {
        await _auth.signInWithCredential(cred);
        await _ensureUserDoc(_auth.currentUser);
        onAutoVerified?.call(cred);
      },
      verificationFailed: onFailed,
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> confirmOtpMobile(String verificationId, String smsCode) async {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCred = await _auth.signInWithCredential(cred);
    await _ensureUserDoc(userCred.user);
  }

  Future<void> signOut() async {
    // Clear the cached Google account too, so the next sign-in shows the
    // account picker again instead of silently reusing the last one.
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Non-fatal — Firebase sign-out below is what matters.
      }
    }
    await _auth.signOut();
  }

  /// Create the user's profile doc the first time they sign in.
  ///
  /// `users/{uid}` is readable by every signed-in user, so email and phone go
  /// to the owner-only `users/{uid}/private/contact` doc instead. That doc is
  /// refreshed on every sign-in so existing users get one too.
  Future<void> _ensureUserDoc(User? user) async {
    if (user == null) return;
    final ref = _db.collection('users').doc(user.uid);
    // Never let this block sign-in (e.g. if the deployed rules are older
    // than this build); the contact doc is refreshed on the next sign-in.
    try {
      await ref.collection('private').doc('contact').set({
        'email': user.email,
        'phone': user.phoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not save private contact: $e');
    }
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'uid': user.uid,
      'name': user.displayName ?? 'Savarun User',
      'photoURL': user.photoURL,
      'bio': '',
      'style': null,
      'wardrobePublic': true,
      'followers': 0,
      'following': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
