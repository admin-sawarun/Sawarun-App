import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_assets.dart';
import '../../core/theme/app_colors.dart';
import 'data/auth_providers.dart';
import 'data/countries.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

enum _Step { enterPhone, enterOtp }

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  // Demo login: this number + code are registered as a Firebase "test phone
  // number" (Auth → Sign-in method → Phone → Phone numbers for testing). No
  // real SMS is sent and app verification is skipped, yet it produces a real
  // Firebase session. When this number is used the OTP auto-fills and submits.
  static const _demoPhone = '+919876543210';
  static const _demoOtp = '123456';

  _Step _step = _Step.enterPhone;
  bool _busy = false;

  bool get _isDemo => _phoneE164 == _demoPhone;

  // Platform-specific handles between the two steps.
  ConfirmationResult? _webConfirmation; // web
  String? _verificationId; // mobile

  Country _country = kCountries.first; // India

  /// The national number typed by the user, digits only, without a leading 0.
  String get _nationalDigits => _phoneController.text
      .replaceAll(RegExp(r'\D'), '')
      .replaceFirst(RegExp(r'^0+'), '');

  String get _phoneE164 => '${_country.dialCode}$_nationalDigits';

  /// Returns an error message, or null when the number looks valid.
  String? _validatePhone() {
    final n = _nationalDigits.length;
    if (n == 0) return 'Enter your phone number';
    final expected = _country.digits;
    if (expected != null && n != expected) {
      return 'Enter a valid $expected-digit ${_country.name} number';
    }
    if (expected == null && (n < 4 || n > 14)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.canvas,
      builder: (ctx) => _CountryPickerSheet(selected: _country),
    );
    if (picked != null) setState(() => _country = picked);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_busy) return; // ignore extra taps while a request is in flight
    final error = _validatePhone();
    if (error != null) {
      _toast(error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    try {
      if (kIsWeb) {
        _webConfirmation = await auth.sendOtpWeb(_phoneE164);
        if (mounted) setState(() => _busy = false);
        _goToOtp();
      } else {
        // On mobile verifyPhoneNumber returns almost immediately, but the SMS
        // is only really "sent" when codeSent fires. So we keep the loader
        // running until a callback below arrives — not when this await ends.
        await auth.sendOtpMobile(
          _phoneE164,
          onCodeSent: (id) {
            _verificationId = id;
            if (mounted) setState(() => _busy = false);
            _goToOtp();
          },
          onFailed: (e) {
            if (mounted) setState(() => _busy = false);
            _toast(e.message ?? 'Could not send OTP');
          },
          onAutoVerified: (_) {
            // Auto-verification signs the user in; the router redirects. Just
            // clear the loader in case we're still on this screen.
            if (mounted) setState(() => _busy = false);
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _busy = false);
      _toast(e.message ?? 'Could not send OTP');
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      _toast('Could not send OTP: $e');
    }
  }

  void _goToOtp() {
    if (!mounted) return;
    setState(() => _step = _Step.enterOtp);

    // Demo bypass: pre-fill the known test code and auto-verify so the login
    // completes on its own — no typing needed.
    if (_isDemo) {
      _otpController.text = _demoOtp;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted && _step == _Step.enterOtp && !_busy) _verifyOtp();
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length < 6) {
      _toast('Enter the 6-digit code');
      return;
    }
    setState(() => _busy = true);
    final auth = ref.read(authServiceProvider);
    try {
      if (kIsWeb) {
        await auth.confirmOtpWeb(_webConfirmation!, code);
      } else {
        await auth.confirmOtpMobile(_verificationId!, code);
      }
      // Router redirect handles navigation to Home on success.
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? 'Invalid code');
    } catch (e) {
      _toast('Verification failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 6),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = _step == _Step.enterPhone;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(isPhone ? 'Login with Phone' : 'Verify OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_step == _Step.enterOtp) {
              setState(() => _step = _Step.enterPhone);
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
      ),
      body: SafeArea(
        // Centered vertically (client wanted the form in the middle), but in a
        // scroll view so it never overflows when the keyboard opens. Only ONE
        // loader runs — the dots inside the button.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: isPhone ? _phoneStep() : _otpStep(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BrandHeader(),
        const SizedBox(height: 36),
        const Text('Enter your phone number',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 10),
        const Text("We'll send you a 6-digit verification code.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.inkMuted)),
        const SizedBox(height: 28),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          decoration: InputDecoration(
            hintText: '98765 43210',
            // Tappable country code, e.g. "🇮🇳 +91 ▾".
            prefixIcon: InkWell(
              onTap: _busy ? null : _pickCountry,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_country.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 6),
                    Text(_country.dialCode,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink)),
                    const Icon(Icons.arrow_drop_down_rounded,
                        color: AppColors.inkMuted),
                    const SizedBox(width: 4),
                    Container(
                        width: 1,
                        height: 24,
                        color: AppColors.inkMuted.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _busy ? null : _sendOtp,
          child: _busy ? const _LoadingDots() : const Text('Send OTP'),
        ),
        // reCAPTCHA (web) renders here automatically when needed.
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BrandHeader(),
        const SizedBox(height: 36),
        const Text('Enter the code',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 10),
        Text(
          _isDemo ? 'Verifying automatically…' : 'Sent to $_phoneE164',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
          decoration:
              const InputDecoration(hintText: '••••••', counterText: ''),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _busy ? null : _verifyOtp,
          child: _busy ? const _LoadingDots() : const Text('Verify & Continue'),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _sendOtp,
            child: const Text('Resend code'),
          ),
        ),
      ],
    );
  }
}

/// Logo + brand name shown at the top of the phone and OTP screens (CR-6), so
/// the pages don't look empty.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(AppAssets.logoMark, height: 54),
        const SizedBox(height: 12),
        const Text(
          'SAVARUN',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'AI Fashion & Style',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

/// Three dots that bounce up and down — the in-button loader shown while an
/// OTP is being sent or verified (CR-4). One continuous loader, inside the
/// button, so it's obvious the tap registered.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const double s = 7;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: s * 2.4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Each dot is a fifth of a cycle behind the one before it, so the
              // bounce travels left-to-right like a wave.
              final t = (_c.value + i * 0.2) % 1.0;
              final dy = -math.sin(t * math.pi) * s;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: s * 0.35),
                child: Transform.translate(
                  offset: Offset(0, dy),
                  child: Container(
                    width: s,
                    height: s,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// Searchable list of every country calling code.
class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({required this.selected});
  final Country selected;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase().replaceAll('+', '');
    final list = q.isEmpty
        ? kCountries
        : kCountries
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.dialCode.substring(1).startsWith(q) ||
                c.iso.toLowerCase() == q)
            .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search country or code',
                prefixIcon:
                    Icon(Icons.search_rounded, color: AppColors.inkMuted),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('No country found',
                        style: TextStyle(color: AppColors.inkMuted)))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return ListTile(
                        leading:
                            Text(c.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(c.name),
                        trailing: Text(c.dialCode,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink)),
                        selected: identical(c, widget.selected),
                        onTap: () => Navigator.of(context).pop(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
