import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_assets.dart';
import '../../core/legal/legal_links.dart';
import '../../core/theme/app_colors.dart';
import 'data/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String label) async {
    setState(() => _busy = true);
    try {
      await action();
      // Router redirect sends us to Home once the auth state updates.
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? '$label sign-in failed');
    } catch (e) {
      _showError('$label sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Image.asset(AppAssets.logoMark, height: 52),
                  const SizedBox(height: 36),
                  const Text(
                    'Welcome Back! 👋',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login to continue',
                    style: TextStyle(fontSize: 14, color: AppColors.inkMuted),
                  ),
                  const Spacer(flex: 2),
                  _AuthButton(
                    icon: Icons.g_mobiledata_rounded,
                    iconColor: AppColors.danger,
                    label: 'Continue with Google',
                    onTap: _busy
                        ? null
                        : () => _run(auth.signInWithGoogle, 'Google'),
                  ),
                  const SizedBox(height: 14),
                  _AuthButton(
                    icon: Icons.phone_rounded,
                    iconColor: AppColors.ink,
                    label: 'Login with Phone',
                    onTap:
                        _busy ? null : () => context.push(Routes.phoneLogin),
                  ),
                  const Spacer(flex: 3),
                  const _LegalFooter(),
                  const SizedBox(height: 16),
                ],
              ),
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
}

/// White pill button with a leading brand icon, as used on the design's
/// login screen.
class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(width: 14),
          Text(label),
        ],
      ),
    );
  }
}

/// "By continuing you agree to our Terms & Privacy Policy" with both
/// document names opening the backend-hosted pages in an in-app browser.
class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  static const _muted = TextStyle(fontSize: 12, color: AppColors.inkMuted);
  static const _link = TextStyle(
    fontSize: 12,
    color: AppColors.ink,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
  );

  @override
  Widget build(BuildContext context) {
    Widget link(String label, String url) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => LegalLinks.open(context, url),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(label, style: _link),
          ),
        );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('By continuing you agree to our ', style: _muted),
        link('Terms', LegalLinks.terms),
        const Text(' & ', style: _muted),
        link('Privacy Policy', LegalLinks.privacyPolicy),
      ],
    );
  }
}
