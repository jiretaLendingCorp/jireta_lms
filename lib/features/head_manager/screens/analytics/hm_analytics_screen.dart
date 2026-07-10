// lib/features/head_manager/screens/analytics/hm_analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../providers/hm_providers.dart';
import '../../widgets/kpi_card.dart';

class HmAnalyticsScreen extends ConsumerWidget {
  const HmAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpiAsync = ref.watch(hmAnalyticsKpiProvider);
    final chartsAsync = ref.watch(hmAnalyticsChartsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Portfolio Analytics', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 4),
          Text('Real-time business intelligence dashboard', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          kpiAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (kpi) => GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                KpiCard(label: 'Active Loans', value: '${kpi['active_loans'] ?? 0}', icon: Icons.description_rounded, iconColor: AppColors.accent),
                KpiCard(label: 'Portfolio Value', value: ((kpi['portfolio_value'] as num?)?.toDouble() ?? 0).toPesoCompact, icon: Icons.account_balance_wallet_rounded, iconColor: AppColors.info, isCurrency: true),
                KpiCard(label: 'Collection Rate', value: '${((kpi['collection_rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%', icon: Icons.trending_up_rounded, iconColor: AppColors.success),
                KpiCard(label: 'PAR-30', value: '${((kpi['par30'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%', icon: Icons.warning_amber_rounded, iconColor: AppColors.warning),
              ],
            ),
          ),
          const SizedBox(height: 24),
          chartsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (charts) => Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _ChartCard(title: 'Collection vs Expected', subtitle: 'Monthly performance', child: _CollectionBarChart(data: charts))),
                    const SizedBox(width: 16),
                    Expanded(child: _ChartCard(title: 'Revenue Breakdown', subtitle: 'Interest + Penalties', child: _RevenueChart(data: charts))),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _ChartCard(title: 'User Growth', subtitle: 'New members over time', child: _UserGrowthChart(data: charts))),
                    const SizedBox(width: 16),
                    Expanded(child: _ChartCard(title: 'Overdue Aging', subtitle: 'Days past due distribution', child: _AgingChart(data: charts))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _ChartCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            SizedBox(height: 200, child: child),
          ],
        ),
      ),
    );
  }
}

class _CollectionBarChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CollectionBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final raw = data['collection_performance'] as List? ?? [];
    if (raw.isEmpty) return const Center(child: Text('No data'));
    final groups = raw.asMap().entries.map((e) {
      final d = e.value as Map<String, dynamic>;
      return BarChartGroupData(x: e.key, barRods: [
        BarChartRodData(toY: (d['collected'] as num?)?.toDouble() ?? 0, color: AppColors.success, width: 10),
        BarChartRodData(toY: (d['expected'] as num?)?.toDouble() ?? 0, color: AppColors.accent.withOpacity(0.3), width: 10),
      ]);
    }).toList();
    return BarChart(BarChartData(
      barGroups: groups,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }
}

class _RevenueChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final interest = (data['total_interest'] as num?)?.toDouble() ?? 0;
    final penalty = (data['total_penalty'] as num?)?.toDouble() ?? 0;
    if (interest == 0 && penalty == 0) return const Center(child: Text('No data'));
    return PieChart(PieChartData(sections: [
      PieChartSectionData(value: interest, title: 'Interest', color: AppColors.accent, radius: 80, titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      PieChartSectionData(value: penalty, title: 'Penalty', color: AppColors.error, radius: 80, titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ], sectionsSpace: 3));
  }
}

class _UserGrowthChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _UserGrowthChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final raw = data['user_growth'] as List? ?? [];
    if (raw.isEmpty) return const Center(child: Text('No data'));
    final spots = raw.asMap().entries.map((e) {
      final d = e.value as Map<String, dynamic>;
      return FlSpot(e.key.toDouble(), (d['count'] as num?)?.toDouble() ?? 0);
    }).toList();
    return LineChart(LineChartData(
      lineBarsData: [LineChartBarData(spots: spots, isCurved: true, color: AppColors.info, barWidth: 2.5, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppColors.info.withOpacity(0.08)))],
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }
}

class _AgingChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AgingChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final aging = data['overdue_aging'] as Map<String, dynamic>? ?? {};
    if (aging.isEmpty) return const Center(child: Text('No data'));
    final labels = ['1-30d', '31-60d', '61-90d', '90d+'];
    final keys = ['bucket_30', 'bucket_60', 'bucket_90', 'bucket_over_90'];
    final groups = keys.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
      BarChartRodData(toY: (aging[e.value] as num?)?.toDouble() ?? 0, color: [AppColors.warning, AppColors.warning.withOpacity(0.7), AppColors.error.withOpacity(0.7), AppColors.error][e.key], width: 28, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
    ])).toList();
    return BarChart(BarChartData(
      barGroups: groups,
      borderData: FlBorderData(show: false),
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Text(labels[v.toInt().clamp(0, 3)], style: const TextStyle(fontSize: 10)))),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
    ));
  }
}