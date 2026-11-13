import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to the Savarun Firebase project (savarun-app).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Debug builds aren't installed from Play, so Play Integrity always fails
  // and Firebase falls back to a browser reCAPTCHA (which some phones' default
  // browsers break with ads). Skip app verification in debug only; this works
  // with the test phone numbers set in Firebase Auth, never with real numbers.
  if (kDebugMode && !kIsWeb) {
    await FirebaseAuth.instance
        .setSettings(appVerificationDisabledForTesting: true);
  }

  runApp(
    const ProviderScope(
      child: SavarunApp(),
    ),
  );
}
