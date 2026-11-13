import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/report_service.dart';

/// Opens the "Report" bottom sheet: pick a reason, add optional details, and
/// submit to POST /api/reports. Shows the thank-you snackbar on success.
///
/// [context] must sit under a Scaffold (for the snackbar).
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget targetType,
  required String targetId,
  required String targetUid,
  String? contextNote,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      targetUid: targetUid,
      contextNote: contextNote,
    ),
  );
  if (sent == true) {
    messenger.showSnackBar(const SnackBar(
        content: Text('Thanks, our team will review this within 24 hours.')));
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    required this.targetUid,
    this.contextNote,
  });

  final ReportTarget targetType;
  final String targetId;
  final String targetUid;

  /// Extra machine context appended to the details (e.g. the chat id).
  final String? contextNote;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String get _title => switch (widget.targetType) {
        ReportTarget.user => 'Report user',
        ReportTarget.post => 'Report post',
        ReportTarget.message => 'Report message',
      };

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final typed = _details.text.trim();
    final note = widget.contextNote;
    final details = [
      if (typed.isNotEmpty) typed,
      if (note != null && note.isNotEmpty) note,
    ].join('\n');
    try {
      await ref.read(reportRepoProvider).submit(
            targetType: widget.targetType,
            targetId: widget.targetId,
            targetUid: widget.targetUid,
            reason: reason,
            details: details,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              const SizedBox(height: 4),
              const Text(
                'Why are you reporting this? Your report is anonymous.',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) {
                  if (!_busy) setState(() => _reason = v);
                },
                child: Column(
                  children: [
                    for (final (value, label) in kReportReasons)
                      RadioListTile<String>(
                        value: value,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppColors.ink,
                        title: Text(label,
                            style: const TextStyle(fontSize: 14)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                enabled: !_busy,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                    hintText: 'Add details (optional)'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.danger)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _reason == null || _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : const Text('Submit report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
