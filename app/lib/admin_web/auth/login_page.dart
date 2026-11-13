import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';

/// Centered "Savarun Admin" sign-in card. Admins sign in with email and
/// password only (Firebase Auth → Email/Password must be enabled). The router
/// moves on once [AdminSession] has checked the admin claim.
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-login-credentials':
        return 'Wrong email or password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a few minutes or reset your password.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase yet.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      default:
        return e.message ?? e.code;
    }
  }

  Future<void> _signIn() async {
    if (!_emailValid) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      _error = _message(e);
    } catch (e) {
      _error = errorText(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_emailValid) {
      setState(() {
        _error = 'Enter your admin email above, then tap "Forgot password?".';
        _info = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim());
      // Same message whether or not the account exists (no account probing).
      _info = 'If ${_email.text.trim()} is an admin account, a password reset '
          'link has been sent to it.';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _info = 'If ${_email.text.trim()} is an admin account, a password reset '
            'link has been sent to it.';
      } else {
        _error = _message(e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F0FD), AdminPalette.background],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.fromLTRB(32, 36, 32, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AdminPalette.border),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x0F2A1A5E),
                        blurRadius: 40,
                        offset: Offset(0, 16)),
                  ],
                ),
                child: AutofillGroup(child: _content()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Brand(),
        const SizedBox(height: 28),
        const Text('Savarun Admin',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Sign in with your admin email and password.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AdminPalette.muted)),
        const SizedBox(height: 28),
        const Text('Email',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _email,
          enabled: !_busy,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            hintText: 'admin@example.com',
            prefixIcon: Icon(Icons.mail_outline_rounded, color: AdminPalette.muted),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Password',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _password,
          enabled: !_busy,
          obscureText: !_showPassword,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _signIn(),
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon:
                const Icon(Icons.lock_outline_rounded, color: AdminPalette.muted),
            suffixIcon: IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AdminPalette.muted,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : _resetPassword,
            child: const Text('Forgot password?'),
          ),
        ),
        const SizedBox(height: 4),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : const Text('Sign in'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _Notice(text: _error!, error: true),
        ],
        if (_info != null) ...[
          const SizedBox(height: 16),
          _Notice(text: _info!, error: false),
        ],
        const SizedBox(height: 20),
        const Text('Access is limited to accounts with the admin role.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AdminPalette.muted)),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.error});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: error ? const Color(0xFFFDECEA) : const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              color: error ? AdminPalette.danger : const Color(0xFF1E7B3A))),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8A5CF0), AdminPalette.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text('S',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}
