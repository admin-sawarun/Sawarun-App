import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        _goToOtp();
      } else {
        await auth.sendOtpMobile(
          _phoneE164,
          onCodeSent: (id) {
            _verificationId = id;
            _goToOtp();
          },
          onFailed: (e) => _toast(e.message ?? 'Could not send OTP'),
        );
      }
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? 'Could not send OTP');
    } catch (e) {
      _toast('Could not send OTP: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: isPhone ? _phoneStep() : _otpStep(),
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _phoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('Enter your\nphone number',
            style: TextStyle(
                fontSize: 26,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 12),
        const Text("We'll send you a 6-digit verification code.",
            style: TextStyle(fontSize: 14, color: AppColors.inkMuted)),
        const SizedBox(height: 32),
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
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(AppColors.white),
                  ),
                )
              : const Text('Send OTP'),
        ),
        // reCAPTCHA (web) renders here automatically when needed.
      ],
    );
  }

  Widget _otpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text('Enter the code',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        const SizedBox(height: 12),
        Text(
          _isDemo ? 'Verifying automatically…' : 'Sent to $_phoneE164',
          style: const TextStyle(fontSize: 14, color: AppColors.inkMuted),
        ),
        const SizedBox(height: 32),
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
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(AppColors.white),
                  ),
                )
              : const Text('Verify & Continue'),
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
