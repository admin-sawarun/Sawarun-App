import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../wardrobe/data/wardrobe_models.dart';
import '../../wardrobe/data/wardrobe_providers.dart';
import '../models/outfit_analysis.dart';
import 'inspiration_grid.dart';

/// "Complete the Look" — the fourth result page (CR-2). It turns the AI's
/// alternative-outfit ideas into visual combination cards, pulling the real
/// item photos from the user's own Digital Wardrobe where they have a match,
/// and falls back to a colour swatch + category chip otherwise. Below the
/// combinations it shows the community Inspiration Grid for the dominant style.
class CombinationsView extends ConsumerWidget {
  const CombinationsView({super.key, required this.analysis});

  final OutfitAnalysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobe = ref.watch(wardrobeProvider).value ?? const <WardrobeItem>[];
    final dominant =
        analysis.styleDna.isNotEmpty ? analysis.styleDna.first.style : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      children: [
        Center(
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_mosaic_rounded,
                        size: 14, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'STYLE IT NEXT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete the Look',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Other combinations you can try — matched to your wardrobe',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (analysis.combinations.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'No combination ideas for this photo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: AppColors.inkMuted),
            ),
          )
        else
          for (final combo in analysis.combinations)
            _CombinationCard(combo: combo, wardrobe: wardrobe),

        if (dominant != null) ...[
          const SizedBox(height: 24),
          InspirationGrid(style: dominant),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// One alternative-outfit card: a title and a row of piece tiles.
class _CombinationCard extends StatelessWidget {
  const _CombinationCard({required this.combo, required this.wardrobe});

  final OutfitCombination combo;
  final List<WardrobeItem> wardrobe;

  @override
  Widget build(BuildContext context) {
    if (combo.pieces.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (combo.title.isNotEmpty)
            Text(
              combo.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: combo.pieces.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _PieceTile(
                piece: combo.pieces[i],
                match: _matchWardrobe(combo.pieces[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Find the user's wardrobe item that best fits this piece: same category,
  /// then the nearest colour. Returns null when they own nothing in that
  /// category (so the app suggests it as something to add).
  WardrobeItem? _matchWardrobe(CombinationPiece piece) {
    final cat = piece.category.trim().toLowerCase();
    final sameCat =
        wardrobe.where((w) => w.category.toLowerCase() == cat).toList();
    if (sameCat.isEmpty) return null;

    final target = _colorForName(piece.color);
    sameCat.sort((a, b) =>
        _colorDistance(a.color, target).compareTo(_colorDistance(b.color, target)));
    return sameCat.first;
  }
}

/// A single tile — either the matched wardrobe photo or a colour-swatch idea.
class _PieceTile extends StatelessWidget {
  const _PieceTile({required this.piece, required this.match});

  final CombinationPiece piece;
  final WardrobeItem? match;

  @override
  Widget build(BuildContext context) {
    final owned = match != null;
    final label = owned ? (match!.name) : _titleCase(piece.category);
    final swatch = _colorForName(piece.color);

    return GestureDetector(
      onTap: owned
          ? () => context.push(Routes.itemDetails, extra: match)
          : () => context.push(Routes.addItem),
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 104,
                height: 104,
                child: _tileArt(owned: owned, swatch: swatch),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            Text(
              owned ? 'From your wardrobe' : 'Add to wardrobe',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: owned ? AppColors.primary : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tileArt({required bool owned, required Color swatch}) {
    if (owned && (match!.photoURL ?? '').isNotEmpty) {
      return Image.network(
        match!.photoURL!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _swatchArt(swatch),
      );
    }
    return _swatchArt(swatch);
  }

  // A soft colour panel with a category glyph — the "idea" state.
  Widget _swatchArt(Color swatch) {
    return Container(
      color: swatch.withValues(alpha: 0.18),
      child: Stack(
        children: [
          Center(
            child: Icon(_iconForCategory(piece.category),
                size: 34, color: swatch),
          ),
          if (match == null)
            const Positioned(
              right: 6,
              top: 6,
              child: Icon(Icons.add_circle_rounded,
                  size: 18, color: AppColors.inkMuted),
            ),
        ],
      ),
    );
  }
}

/* ─────────────── shared helpers ─────────────── */

String _titleCase(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

IconData _iconForCategory(String category) {
  switch (category.trim().toLowerCase()) {
    case 'tops':
      return Icons.checkroom_rounded;
    case 'bottoms':
      return Icons.dry_cleaning_rounded;
    case 'footwear':
      return Icons.ice_skating_rounded;
    case 'outerwear':
      return Icons.dry_cleaning_outlined;
    case 'accessories':
      return Icons.watch_rounded;
    default:
      return Icons.style_rounded;
  }
}

/// Map a colour name (as the AI returns it) to a Color using the wardrobe's
/// known swatch names; falls back to a neutral grey.
Color _colorForName(String name) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return const Color(0xFF9E9E9E);
  for (final c in WardrobeOptions.colors) {
    if (c.name.toLowerCase() == n) return _hexToColor(c.hex);
  }
  // Loose contains match (e.g. "light blue" → "Blue").
  for (final c in WardrobeOptions.colors) {
    if (n.contains(c.name.toLowerCase())) return _hexToColor(c.hex);
  }
  return const Color(0xFF9E9E9E);
}

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF9E9E9E);
}

/// Squared RGB distance between two colours (for nearest-colour matching).
int _colorDistance(Color a, Color b) {
  final dr = _c(a.r) - _c(b.r);
  final dg = _c(a.g) - _c(b.g);
  final db = _c(a.b) - _c(b.b);
  return dr * dr + dg * dg + db * db;
}

int _c(double channel) => (channel * 255).round();
