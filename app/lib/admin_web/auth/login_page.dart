import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/auth/data/countries.dart';
import '../widgets/common.dart';

/// Centered "Savarun Admin" sign-in card: Google popup or phone OTP (web).
/// The router moves on once [AdminSession] has checked the admin claim.
class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  Country _country = kCountries.first;
  ConfirmationResult? _confirmation;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  String get _digits =>
      _phone.text.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');

  Future<void> _run(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'popup-closed-by-user' &&
          e.code != 'cancelled-popup-request') {
        _error = e.message ?? e.code;
      }
    } catch (e) {
      _error = errorText(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() =>
      _run(() => ref.read(authServiceProvider).signInWithGoogle());

  Future<void> _sendCode() async {
    final n = _digits.length;
    final expected = _country.digits;
    if (n == 0 ||
        (expected != null && n != expected) ||
        (expected == null && (n < 4 || n > 14))) {
      setState(() => _error = expected != null
          ? 'Enter a valid $expected-digit ${_country.name} number'
          : 'Enter a valid phone number');
      return;
    }
    await _run(() async {
      _confirmation = await ref
          .read(authServiceProvider)
          .sendOtpWeb('${_country.dialCode}$_digits');
    });
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    await _run(() =>
        ref.read(authServiceProvider).confirmOtpWeb(_confirmation!, code));
  }

  Future<void> _pickCountry() async {
    final picked = await showDialog<Country>(
      context: context,
      builder: (_) => const _CountryDialog(),
    );
    if (picked != null) setState(() => _country = picked);
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
                child: _content(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final otpStep = _confirmation != null;
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
        const Text('Sign in with an admin account to continue.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AdminPalette.muted)),
        const SizedBox(height: 28),
        if (!otpStep) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : _google,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const _GoogleG(),
            label: const Text('Continue with Google',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 22),
          const Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or use your phone',
                    style: TextStyle(fontSize: 12, color: AdminPalette.muted)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _phone,
            enabled: !_busy,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
            onSubmitted: (_) => _sendCode(),
            decoration: InputDecoration(
              hintText: 'Phone number',
              prefixIcon: InkWell(
                onTap: _busy ? null : _pickCountry,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_country.iso,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AdminPalette.muted)),
                      const SizedBox(width: 6),
                      Text(_country.dialCode,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Icon(Icons.arrow_drop_down_rounded,
                          color: AdminPalette.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _sendCode,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Send verification code'),
          ),
        ] else ...[
          Text('Enter the 6-digit code sent to ${_country.dialCode} $_digits',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AdminPalette.inkSoft)),
          const SizedBox(height: 16),
          TextField(
            controller: _otp,
            enabled: !_busy,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w600),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            onSubmitted: (_) => _verify(),
            decoration: const InputDecoration(hintText: '••••••'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _verify,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            child: const Text('Verify & sign in'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _confirmation = null;
                      _otp.clear();
                      _error = null;
                    }),
            child: const Text('Use a different number'),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!,
                style: const TextStyle(
                    fontSize: 13, color: AdminPalette.danger)),
          ),
        ],
        const SizedBox(height: 20),
        const Text('Access is limited to accounts with the admin role.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AdminPalette.muted)),
      ],
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

/// Simple multi-colour "G" mark without bundling an image asset.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => const SweepGradient(colors: [
        Color(0xFFEA4335),
        Color(0xFFFBBC05),
        Color(0xFF34A853),
        Color(0xFF4285F4),
        Color(0xFFEA4335),
      ]).createShader(r),
      child: const Text('G',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }
}

class _CountryDialog extends StatefulWidget {
  const _CountryDialog();

  @override
  State<_CountryDialog> createState() => _CountryDialogState();
}

class _CountryDialogState extends State<_CountryDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = kCountries
        .where((c) =>
            q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.dialCode.contains(q) ||
            c.iso.toLowerCase() == q)
        .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _q = v.trim()),
                decoration: const InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final c = list[i];
                  return ListTile(
                    dense: true,
                    leading: Text(c.iso,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AdminPalette.muted)),
                    title: Text(c.name),
                    trailing: Text(c.dialCode),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
