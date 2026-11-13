import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Public legal/support pages served by the backend, plus the support inbox.
class LegalLinks {
  LegalLinks._();

  static const String privacyPolicy =
      '${AppConfig.backendBaseUrl}/privacy-policy';
  static const String terms = '${AppConfig.backendBaseUrl}/terms';
  static const String accountDeletion =
      '${AppConfig.backendBaseUrl}/account-deletion';
  static const String supportEmail = 'admin-sawarun@savarun.in';

  /// Opens [url] in an in-app browser view (Custom Tab / SFSafariViewController).
  static Future<void> open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url),
          mode: LaunchMode.inAppBrowserView);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the page.')));
    }
  }

  /// Opens the mail app addressed to the support inbox.
  static Future<void> contactSupport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=${Uri.encodeComponent('Savarun support')}',
    );
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No email app found. Write to $supportEmail')));
    }
  }
}
