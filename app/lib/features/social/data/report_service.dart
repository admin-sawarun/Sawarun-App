import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

/// What is being reported.
enum ReportTarget { user, post, message, analysis }

/// Reasons accepted by POST /api/reports, with user-facing labels.
const kReportReasons = <(String, String)>[
  ('spam', 'Spam'),
  ('harassment', 'Harassment or bullying'),
  ('nudity', 'Nudity or sexual content'),
  ('hate', 'Hate speech'),
  ('violence', 'Violence or threats'),
  ('fake', 'Fake account or impersonation'),
  ('other', 'Something else'),
];

final reportRepoProvider = Provider((ref) => const ReportRepository());

class ReportRepository {
  const ReportRepository();

  /// For messages, [targetId] is `chatId/messageId`. The backend replies
  /// 201 { ok: true, id } — any 2xx counts as success.
  Future<void> submit({
    required ReportTarget targetType,
    required String targetId,
    required String targetUid,
    required String reason,
    String? details,
  }) async {
    final trimmed = details?.trim() ?? '';
    await const ApiClient().post('${AppConfig.backendBaseUrl}/api/reports', {
      'targetType': targetType.name,
      'targetId': targetId,
      'targetUid': targetUid,
      'reason': reason,
      if (trimmed.isNotEmpty) 'details': trimmed,
    });
  }
}
