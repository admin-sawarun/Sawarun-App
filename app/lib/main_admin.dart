import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_web/admin_web_app.dart';
import 'firebase_options.dart';

/// Entry point for the standalone Savarun web admin dashboard.
///
///   flutter run -d chrome -t lib/main_admin.dart --web-port 5700
///
/// See ADMIN_WEB.md for build and deploy steps.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    // Errors are shown with an explicit Retry button, so turn off Riverpod's
    // automatic background retries.
    ProviderScope(retry: (_, _) => null, child: const AdminWebApp()),
  );
}
