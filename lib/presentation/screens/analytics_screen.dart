import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../../domain/entities/item.dart';

/// Screen 2 — Analytics.
///
/// Three tabs: Top Sales (with bar chart), Deadstock, and Profit Report.
/// Data is loaded lazily on first visit and cached until invalidated.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl =
      TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    // Load analytics on first mount (provider caches results).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AppProvider>();
      if (p.counts['purchases']! > 0 || p.counts['sales']! > 0) {
        p.loadAnalytics();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── Gradient header with tabs ──────────────────
          _AnalyticsHeader(
            tabCtrl: _tabCtrl,
            onRefresh: () =>
                context.read<AppProvider>().forceReloadAnalytics(),
          ),

          // ── Tab content ───────────────────────────────
          Expanded(
            child: Consumer<AppProvider>(
              builder: (_, p, __) {
                if (p.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _TopSalesTab(items: p.topSales),
                    _DeadstockTab(items: p.deadstock),
                    _ProfitTab(
                      items: p.profitReport,
                      totalRevenue: p.totalRevenue,
                      totalCost: p.totalCost,
                      totalProfit: p.totalProfit,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────

class _AnalyticsHeader extends StatelessWidget {
  final TabController tabCtrl;
  final VoidCallback onRefresh;

  const _AnalyticsHeader(
      {required this.tabCtrl, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Analytics',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('Insights from your data',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: onRefresh,
                  ),
                ],
              ),
            ),
            TabBar(
              controller: tabCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: const [
                Tab(icon: Icon(Icons.bar_chart, size: 16), text: 'Top Sales'),
                Tab(
                    icon: Icon(Icons.warning_amber_rounded, size: 16),
                    text: 'Deadstock'),
                Tab(
                    icon: Icon(Icons.trending_up, size: 16),
                    text: 'Profit'),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Tab 1: Top Sales ──────────────────────────────────

class _TopSalesTab extends StatelessWidget {
  final List<ItemAnalysis> items;
  const _TopSalesTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(
        message:
            'No sales data found.\nUpload a sales CSV file to see top items.',
        icon: Icons.bar_chart_outlined,
      );
    }

    return CustomScrollView(
      slivers: [
        // Bar chart for top 5
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Top 5 by Revenue'),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: BarChart(_buildBarData(items.take(5).toList())),
                ),
                const SizedBox(height: 20),
                const SectionLabel('All Items Ranked'),
              ],
            ),
          ),
        ),

        // Ranked list
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => _SalesListTile(item: items[i], rank: i + 1),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }

  /// Builds [BarChartData] from the top items list.
  BarChartData _buildBarData(List<ItemAnalysis> top5) {
    final maxY = top5.isEmpty
        ? 1.0
        : top5.map((e) => e.totalRevenue).reduce((a, b) => a > b ? a : b);

    return BarChartData(
      maxY: maxY * 1.15,
      barGroups: top5.asMap().entries.map((e) {
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: e.value.totalRevenue,
            gradient: const LinearGradient(
              colors: [AppTheme.accent, AppTheme.primary],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: 26,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ]);
      }).toList(),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (val, _) {
              final i = val.toInt();
              if (i >= top5.length) return const SizedBox();
              final n = top5[i].itemName;
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  n.length > 8 ? '${n.substring(0, 8)}..' : n,
                  style: const TextStyle(fontSize: 9),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
        leftTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey.shade100, strokeWidth: 1),
      ),
    );
  }
}

class _SalesListTile extends StatelessWidget {
  final ItemAnalysis item;
  final int rank;
  const _SalesListTile({required this.item, required this.rank});

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final medalColors = [
      const Color(0xFFFFD700), // gold
      const Color(0xFFC0C0C0), // silver
      const Color(0xFFCD7F32), // bronze
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isTop3
                ? medalColors[rank - 1].withOpacity(0.4)
                : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop3
                  ? medalColors[rank - 1].withOpacity(0.15)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isTop3
                      ? medalColors[rank - 1]
                      : Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Qty sold: ${fmtNum(item.soldQty)}',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmtCurr(item.totalRevenue)} EGP',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                      fontSize: 13)),
              if (item.profit != 0)
                Text(
                  '${item.profit >= 0 ? '+' : ''}${fmtCurr(item.profit)} profit',
                  style: TextStyle(
                      fontSize: 10,
                      color: item.profit >= 0
                          ? AppTheme.success
                          : AppTheme.danger),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Deadstock ──────────────────────────────────

class _DeadstockTab extends StatelessWidget {
  final List<ItemAnalysis> items;
  const _DeadstockTab({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        message: '🎉 No deadstock!\nAll purchased items have sales records.',
        icon: Icons.check_circle_outline,
      );
    }

    final totalLocked =
        items.fold<double>(0, (s, e) => s + e.totalCost);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Summary banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.warning.withOpacity(0.15),
                        AppTheme.warning.withOpacity(0.05)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warning, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${items.length} Deadstock Items',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            Text(
                                '${fmtCurr(totalLocked)} EGP capital locked',
                                style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const SectionLabel('Items with No Sales'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => _DeadstockCard(item: items[i]),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }
}

class _DeadstockCard extends StatelessWidget {
  final ItemAnalysis item;
  const _DeadstockCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.danger.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.danger.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.block_outlined,
                color: AppTheme.danger, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Stock: ${fmtNum(item.purchasedQty)} units',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${fmtCurr(item.totalCost)} EGP',
                  style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              Text('Capital locked',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 3: Profit Report ──────────────────────────────

class _ProfitTab extends StatelessWidget {
  final List<ItemAnalysis> items;
  final double totalRevenue, totalCost, totalProfit;

  const _ProfitTab({
    required this.items,
    required this.totalRevenue,
    required this.totalCost,
    required this.totalProfit,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        message: 'No data found.\nUpload both purchases and sales files.',
        icon: Icons.trending_up_outlined,
      );
    }

    return CustomScrollView(
      slivers: [
        // Summary KPIs
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        label: 'Total Revenue',
                        value: fmtCurr(totalRevenue),
                        subtitle: 'EGP',
                        color: AppTheme.accent,
                        icon: Icons.arrow_upward,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KpiCard(
                        label: 'Total Cost',
                        value: fmtCurr(totalCost),
                        subtitle: 'EGP',
                        color: AppTheme.warning,
                        icon: Icons.arrow_downward,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                KpiCard(
                  label: 'Net Profit',
                  value: '${fmtCurr(totalProfit)} EGP',
                  subtitle:
                      totalRevenue > 0
                          ? '${((totalProfit / totalRevenue) * 100).toStringAsFixed(1)}% margin'
                          : null,
                  color: totalProfit >= 0 ? AppTheme.success : AppTheme.danger,
                  icon: totalProfit >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                ),
                const SizedBox(height: 16),
                const SectionLabel('Per Item Breakdown'),
              ],
            ),
          ),
        ),

        // Item list
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => _ProfitCard(item: items[i]),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
      ],
    );
  }
}

class _ProfitCard extends StatelessWidget {
  final ItemAnalysis item;
  const _ProfitCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final profitColor =
        item.profit >= 0 ? AppTheme.success : AppTheme.danger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + profit badge
          Row(
            children: [
              Expanded(
                child: Text(item.itemName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: profitColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${item.profit >= 0 ? '+' : ''}${fmtCurr(item.profit)} EGP',
                  style: TextStyle(
                      color: profitColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Cost / Revenue / Margin row
          Row(
            children: [
              _Chip('Cost', '${fmtCurr(item.totalCost)}', AppTheme.warning),
              const SizedBox(width: 8),
              _Chip('Revenue', '${fmtCurr(item.totalRevenue)}', AppTheme.accent),
              const SizedBox(width: 8),
              _Chip(
                'Margin',
                '${item.profitMarginPct.toStringAsFixed(1)}%',
                profitColor,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ProfitProgressRow(
              cost: item.totalCost, revenue: item.totalRevenue),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color.withOpacity(0.8))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}
