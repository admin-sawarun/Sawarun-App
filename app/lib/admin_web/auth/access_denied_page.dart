import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/common.dart';
import 'admin_session.dart';

/// Shown when the signed-in account lacks the `admin` custom claim.
class AccessDeniedPage extends ConsumerWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(adminSessionProvider);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: PanelCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDECEA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline_rounded,
                        size: 28, color: AdminPalette.danger),
                  ),
                  const SizedBox(height: 20),
                  const Text('Access denied — this account is not an admin',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(
                    'Signed in as ${session.contact ?? session.displayName}. '
                    'Ask an existing admin to grant this account the admin '
                    'role, then check again.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5, height: 1.5, color: AdminPalette.muted),
                  ),
                  if (session.error != null) ...[
                    const SizedBox(height: 10),
                    Text(session.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12, color: AdminPalette.danger)),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: session.recheck,
                          child: const Text('Check again'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: session.signOut,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Sign out'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
