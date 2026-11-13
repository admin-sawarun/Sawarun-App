import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/data/admin_service.dart'
    show adminFitWeightsProvider;
import '../data/admin_web_api.dart';
import '../widgets/common.dart';

const _factors = [
  ('trendMatch', 'Trend Match', 'How closely the outfit follows current trends.'),
  ('colorHarmony', 'Color Harmony', 'How well the colours work together.'),
  ('styleConsistency', 'Style Consistency',
      'Whether the pieces share one coherent style.'),
  ('silhouetteBalance', 'Silhouette Balance',
      'Proportions and fit of the overall shape.'),
  ('accessories', 'Accessories', 'How accessories complete the look.'),
];

/// Defaults from the backend's fitScore.service (percent).
const _defaults = {
  'trendMatch': 30.0,
  'colorHarmony': 20.0,
  'styleConsistency': 20.0,
  'silhouetteBalance': 15.0,
  'accessories': 15.0,
};

class TuningPage extends ConsumerWidget {
  const TuningPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScroll(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: AsyncBody<Map<String, num>>(
              value: ref.watch(adminFitWeightsProvider),
              onRetry: () => ref.invalidate(adminFitWeightsProvider),
              loading: const PanelCard(child: TableSkeleton(rows: 5)),
              builder: (w) => _Editor(
                // Key on the loaded values so a refresh resets the sliders.
                key: ValueKey(w.toString()),
                initial: w,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({super.key, required this.initial});
  final Map<String, num> initial;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late Map<String, double> _values = _fromServer();
  bool _saving = false;

  /// Stored as fractions (0.30); edited as percentages.
  Map<String, double> _fromServer() => {
        for (final (k, _, _) in _factors)
          k: ((widget.initial[k] ?? (_defaults[k]! / 100)).toDouble() * 100)
              .roundToDouble(),
      };

  double get _total => _values.values.fold(0.0, (a, b) => a + b);

  bool get _dirty {
    final s = _fromServer();
    return _values.entries.any((e) => (s[e.key]! - e.value).abs() > 0.01);
  }

  Future<void> _save() async {
    if (_total <= 0) {
      showToast(context, 'At least one factor needs a weight above 0',
          error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      // Send fractions; the backend re-normalises to sum 1.0 anyway.
      await ref.read(adminWebRepoProvider).saveFitWeights(
          _values.map((k, v) => MapEntry(k, v / _total)));
      ref.invalidate(adminFitWeightsProvider);
      if (mounted) showToast(context, 'Fit Score weights saved');
    } catch (e) {
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final balanced = (total - 100).abs() < 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          title: 'Fit Score weights',
          subtitle:
              'Each outfit analysis scores five factors from 0–100. The Fit '
              'Score is their weighted average, so these weights decide how '
              'much each factor counts. Changes apply to new analyses only.',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (balanced ? AdminPalette.success : AdminPalette.warning)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('Total ${total.round()}%',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: balanced
                        ? AdminPalette.success
                        : AdminPalette.warning)),
          ),
          child: Column(
            children: [
              for (final (key, label, help) in _factors)
                _Row(
                  label: label,
                  help: help,
                  value: _values[key]!,
                  share: total == 0 ? 0 : _values[key]! / total,
                  onChanged: (v) => setState(() => _values[key] = v),
                ),
              if (!balanced)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'The total isn\'t 100%. Weights are scaled proportionally '
                    'on save (the "share" column shows the effective weight).',
                    style: TextStyle(fontSize: 12.5, color: AdminPalette.muted),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: _saving
                  ? null
                  : () => setState(() => _values = Map.of(_defaults)),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset to defaults (30/20/20/15/15)'),
            ),
            FilledButton.icon(
              onPressed: _saving || !_dirty ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.help,
    required this.value,
    required this.share,
    required this.onChanged,
  });
  final String label;
  final String help;
  final double value;
  final double share;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(help,
                    style: const TextStyle(
                        fontSize: 12, color: AdminPalette.muted)),
              ],
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0, 100),
              min: 0,
              max: 100,
              divisions: 100,
              label: '${value.round()}',
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${value.round()}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                Text('share ${(share * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 11.5, color: AdminPalette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
