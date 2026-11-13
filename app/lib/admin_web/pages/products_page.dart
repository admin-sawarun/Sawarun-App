import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_web_api.dart';
import '../widgets/common.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  String _q = '';
  String? _brand;
  String? _category;
  final Set<String> _busy = {};

  Future<void> _toggle(ProductRow p, {bool? approved, bool? hidden}) async {
    final repo = ref.read(adminWebRepoProvider);
    final prevApproved = p.approved;
    final prevHidden = p.hidden;
    setState(() {
      _busy.add(p.id);
      if (approved != null) p.approved = approved;
      if (hidden != null) p.hidden = hidden;
    });
    try {
      if (approved != null) await repo.setProductApproval(p.id, approved);
      if (hidden != null) await repo.setProductHidden(p.id, hidden);
    } catch (e) {
      // Roll back the optimistic change.
      setState(() {
        p.approved = prevApproved;
        p.hidden = prevHidden;
      });
      if (mounted) showToast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final all = products.value ?? const <ProductRow>[];
    final brands = {for (final p in all) p.brandName}.toList()..sort();
    final categories = {
      for (final p in all)
        if (p.category != null) p.category!.toLowerCase()
    }.toList()
      ..sort();

    return PageScroll(
      children: [
        PanelCard(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                    hintText: 'Search products',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
              _dropdown('All brands', _brand, brands,
                  (v) => setState(() => _brand = v)),
              _dropdown('All categories', _category, categories,
                  (v) => setState(() => _category = v)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PanelCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: AsyncBody<List<ProductRow>>(
            value: products,
            onRetry: () => ref.invalidate(productsProvider),
            loading: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: TableSkeleton(),
            ),
            builder: (list) {
              final rows = list.where((p) {
                if (_brand != null && p.brandName != _brand) return false;
                if (_category != null &&
                    p.category?.toLowerCase() != _category) {
                  return false;
                }
                if (_q.isEmpty) return true;
                return p.name.toLowerCase().contains(_q) ||
                    p.brandName.toLowerCase().contains(_q);
              }).toList();
              if (rows.isEmpty) {
                return EmptyState(
                  title: list.isEmpty ? 'No products yet' : 'No matches',
                  subtitle: list.isEmpty
                      ? 'Products added by approved brands appear here.'
                      : 'Try clearing a filter.',
                  icon: Icons.shopping_bag_outlined,
                );
              }
              return _table(rows);
            },
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String hint, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String?>(
        initialValue: items.contains(value) ? value : null,
        isExpanded: true,
        items: [
          DropdownMenuItem(value: null, child: Text(hint)),
          for (final i in items)
            DropdownMenuItem(
                value: i,
                child: Text(capitalize(i), overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _table(List<ProductRow> rows) {
    return WideTable(
      child: DataTable(
        dataRowMinHeight: 64,
        dataRowMaxHeight: 68,
        columns: const [
          DataColumn(label: Text('PRODUCT')),
          DataColumn(label: Text('BRAND')),
          DataColumn(label: Text('PRICE'), numeric: true),
          DataColumn(label: Text('CATEGORY')),
          DataColumn(label: Text('CLICKS'), numeric: true),
          DataColumn(label: Text('APPROVED')),
          DataColumn(label: Text('VISIBLE')),
        ],
        rows: [
          for (final p in rows)
            DataRow(cells: [
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NetImage(p.imageUrl, width: 44, height: 44),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              )),
              DataCell(Text(p.brandName)),
              DataCell(Text(_price(p))),
              DataCell(Text(p.category == null ? '—' : capitalize(p.category!))),
              DataCell(Text(formatCount(p.clicks))),
              DataCell(Switch(
                value: p.approved,
                onChanged: _busy.contains(p.id)
                    ? null
                    : (v) => _toggle(p, approved: v),
              )),
              DataCell(Switch(
                value: !p.hidden,
                onChanged: _busy.contains(p.id)
                    ? null
                    : (v) => _toggle(p, hidden: !v),
              )),
            ]),
        ],
      ),
    );
  }

  String _price(ProductRow p) {
    final cur = (p.currency ?? 'INR').toUpperCase();
    final symbol = switch (cur) {
      'INR' => '₹',
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      _ => '$cur ',
    };
    final v = p.price % 1 == 0
        ? formatCount(p.price)
        : p.price.toStringAsFixed(2);
    return '$symbol$v';
  }
}
