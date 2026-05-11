import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

/// Screen 3 — Search Items.
///
/// Full-text search across both purchases and sales tables.
/// Results are colour-coded and show relevant financial data.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Triggers a search using the current text field value.
  void _doSearch(AppProvider p) {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    p.search(q);
  }

  /// Clears text and resets search state.
  void _clear(AppProvider p) {
    _ctrl.clear();
    p.clearSearch();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header ───────────────────────────
          _SearchHeader(
            ctrl: _ctrl,
            onSearch: () => _doSearch(context.read<AppProvider>()),
            onClear: () => _clear(context.read<AppProvider>()),
            onChanged: () => setState(() {}),
          ),

          // ── Results ───────────────────────────────────
          Expanded(
            child: Consumer<AppProvider>(
              builder: (_, p, __) {
                if (p.searchLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!p.hasSearched) {
                  return const EmptyState(
                    message:
                        'Type an item name above and tap Search\nto find records across purchases and sales.',
                    icon: Icons.manage_search_outlined,
                  );
                }

                if (p.searchResults.isEmpty) {
                  return EmptyState(
                    message:
                        'No results found for "${_ctrl.text.trim()}".\nTry a different name.',
                    icon: Icons.search_off_outlined,
                  );
                }

                return _ResultsList(results: p.searchResults);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────

class _SearchHeader extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final VoidCallback onChanged;

  const _SearchHeader({
    required this.ctrl,
    required this.onSearch,
    required this.onClear,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Search Items',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text('Find any item across purchases & sales',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),

              // Search text field + button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => onSearch(),
                      onChanged: (_) => onChanged(),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Item name…',
                        hintStyle:
                            TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search,
                            color: AppTheme.accent),
                        suffixIcon: ctrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear,
                                    color: Colors.grey.shade400,
                                    size: 18),
                                onPressed: onClear,
                              )
                            : null,
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: onSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(56, 52),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.search, size: 22),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Results list ──────────────────────────────────────

class _ResultsList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  const _ResultsList({required this.results});

  @override
  Widget build(BuildContext context) {
    // Split by type for section headers
    final purchases =
        results.where((r) => r['record_type'] == 'purchase').toList();
    final sales =
        results.where((r) => r['record_type'] == 'sale').toList();

    return CustomScrollView(
      slivers: [
        // Result count header
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '${results.length} result(s) — '
              '${purchases.length} purchase · ${sales.length} sale',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        ),

        // Purchase results
        if (purchases.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SectionLabel('Purchases',
                  color: AppTheme.accent),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: purchases.length,
              itemBuilder: (_, i) =>
                  _ResultTile(row: purchases[i]),
            ),
          ),
        ],

        // Sale results
        if (sales.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SectionLabel('Sales', color: AppTheme.success),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: sales.length,
              itemBuilder: (_, i) => _ResultTile(row: sales[i]),
            ),
          ),
        ],

        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ResultTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final isPurchase = row['record_type'] == 'purchase';
    final color = isPurchase ? AppTheme.accent : AppTheme.success;
    final qty = (row['quantity'] as num?)?.toDouble() ?? 0;
    final value = isPurchase
        ? (row['total_cost'] as num?)?.toDouble() ?? 0
        : (row['total_revenue'] as num?)?.toDouble() ?? 0;
    final branch = row['branch_name']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPurchase
                  ? Icons.shopping_cart_outlined
                  : Icons.point_of_sale_outlined,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row['item_name']?.toString() ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  [
                    'Qty: ${fmtNum(qty)}',
                    if (branch != null && branch.isNotEmpty) branch,
                  ].join(' · '),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmtCurr(value)} EGP',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              Text(isPurchase ? 'Cost' : 'Revenue',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}
