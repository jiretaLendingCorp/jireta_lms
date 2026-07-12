// lib/features/head_manager/screens/dashboard/hm_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/hm_providers.dart';
import '../../widgets/kpi_card.dart';

class HmDashboardScreen extends ConsumerWidget {
  const HmDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final kpiAsync = ref.watch(hmAnalyticsKpiProvider);

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Page header ─────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${_greeting()}, ${user?.firstName ?? '—'}',
                      style: context.textTheme.displayMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateTime.now().toDisplayDate,
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              AppButton(
                label: 'New Loan',
                icon: AppIcons.plusCircle,
                onPressed: () => context.go(RouteConstants.hmLoans),
                size: AppButtonSize.md,
                useGradient: true,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── KPI cards ────────────────────────────────────────────────────────
          kpiAsync.when(
            loading: () => _KpiShimmer(),
            error: (_, __) => const _KpiCards(kpi: {}),
            data: (kpi) => _KpiCards(kpi: kpi),
          ),
          const SizedBox(height: 16),

          // ── Lifetime metrics bar ─────────────────────────────────────────────
          _LifetimeMetricsBar(),
          const SizedBox(height: 24),

          // ── Charts row ──────────────────────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _LoanVolumeCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _StatusDistCard()),
                ],
              );
            }
            return Column(
              children: [
                _LoanVolumeCard(),
                const SizedBox(height: 16),
                _StatusDistCard(),
              ],
            );
          }),
          const SizedBox(height: 24),

          // ── Recent & Quick actions row ───────────────────────────────────────
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _RecentLoansCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _QuickActionsCard()),
                ],
              );
            }
            return Column(
              children: [
                _RecentLoansCard(),
                const SizedBox(height: 16),
                _QuickActionsCard(),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

// ── KPI Cards ─────────────────────────────────────────────────────────────────

class _KpiCards extends StatelessWidget {
  final Map<String, dynamic> kpi;
  const _KpiCards({required this.kpi});

  @override
  Widget build(BuildContext context) {
    double v(String key) => (kpi[key] as num?)?.toDouble() ?? 0;

    return KpiGrid(
      cards: [
        KpiCard(
          label: 'Active Loans',
          value: '${kpi['active_loans'] ?? 0}',
          icon: AppIcons.loans,
          iconColor: AppColors.accent,
          change: v('active_loans_change'),
        ),
        KpiCard(
          label: 'Portfolio Value',
          value: v('portfolio_value').toPesoCompact,
          icon: AppIcons.wallet,
          iconColor: AppColors.info,
          change: v('portfolio_change'),
          isCurrency: true,
        ),
        KpiCard(
          label: 'Collection Rate (MTD)',
          value: '${v('collection_rate').toStringAsFixed(1)}%',
          icon: AppIcons.trendUp,
          iconColor: AppColors.success,
          change: v('collection_rate_change'),
        ),
        KpiCard(
          label: 'PAR-30',
          value: '${v('par30').toStringAsFixed(1)}%',
          icon: AppIcons.warning,
          iconColor: AppColors.warning,
          change: v('par30_change'),
        ),
        KpiCard(
          label: 'New Loans (MTD)',
          value: '${kpi['new_loans_mtd'] ?? 0}',
          icon: AppIcons.plusCircle,
          iconColor: AppColors.lenderAccent,
          change: v('new_loans_change'),
        ),
        KpiCard(
          label: 'Revenue (MTD)',
          value: v('revenue_mtd').toPesoCompact,
          icon: AppIcons.banknote,
          iconColor: AppColors.success,
          change: v('revenue_change'),
          isCurrency: true,
        ),
      ],
    );
  }
}

class _KpiShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;
    return LayoutBuilder(
      builder: (_, constraints) {
        final cols = constraints.maxWidth >= 1100
            ? 4
            : constraints.maxWidth >= 800
                ? 3
                : constraints.maxWidth >= 520
                    ? 2
                    : 1;
        final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(
            6,
            (_) => SizedBox(width: itemWidth, child: const ShimmerCard()),
          ),
        );
      },
    );
  }
}

// ── Lifetime Metrics Bar ─────────────────────────────────────────────────────

class _LifetimeMetricsBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(hmLifetimeMetricsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (m) {
        double v(String k) => (m[k] as num?)?.toDouble() ?? 0;
        int i(String k) => (m[k] as num?)?.toInt() ?? 0;
        return AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded,
                      color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Text('All-Time Totals',
                      style: context.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (_, c) {
                final wrap = c.maxWidth < 600;
                final items = [
                  _LM('Total Loans', '${i('total_loans_ever')}',
                      AppIcons.loans),
                  _LM('Lenders', '${i('total_lenders')}', AppIcons.users),
                  _LM('Riders', '${i('total_riders')}',
                      Icons.two_wheeler_rounded),
                  _LM('Employees', '${i('total_employees')}', AppIcons.profile),
                  _LM('Disbursed', v('total_disbursed').toPesoCompact,
                      AppIcons.banknote),
                  _LM('Collected', v('total_collected').toPesoCompact,
                      AppIcons.coins),
                ];
                if (wrap) {
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: items
                        .map((e) =>
                            SizedBox(width: (c.maxWidth - 12) / 2, child: e))
                        .toList(),
                  );
                }
                return Row(
                  children: items.map((e) => Expanded(child: e)).toList(),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _LM extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _LM(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13, color: AppColors.accent.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondaryLight),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3)),
      ],
    );
  }
}

// ── Loan Volume Chart ─────────────────────────────────────────────────────────

class _LoanVolumeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartsAsync = ref.watch(hmAnalyticsChartsProvider);
    return AppCard(
      header: const AppSectionHeader(
        title: 'Loan Volume Trend',
        subtitle: 'Last 12 months',
      ),
      child: SizedBox(
        height: 220,
        child: chartsAsync.when(
          loading: () => const ShimmerBox(height: 220),
          error: (_, __) => _ChartEmpty(),
          data: (d) {
            final raw = (d['loan_volume'] as List?) ?? [];
            final spots = raw.isEmpty
                ? [for (var i = 1; i <= 12; i++) FlSpot(i.toDouble(), 0)]
                : raw
                    .map((e) => FlSpot(
                          (e['month'] as num).toDouble(),
                          (e['count'] as num).toDouble(),
                        ))
                    .toList();
            return _LoanVolumeChart(data: spots);
          },
        ),
      ),
    );
  }
}

class _LoanVolumeChart extends StatelessWidget {
  final List<FlSpot> data;
  const _LoanVolumeChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);
    final labelColor =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return RepaintBoundary(
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: gridColor,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: TextStyle(fontSize: 11, color: labelColor),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) {
                  const months = [
                    '',
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec'
                  ];
                  final i = v.toInt().clamp(0, 12);
                  return Text(
                    months[i],
                    style: TextStyle(fontSize: 11, color: labelColor),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: data,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.accent,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accent.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) =>
                  isDark ? AppColors.webSurfaceLight : AppColors.webSurfaceDark,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                  return LineTooltipItem(
                    s.y.toInt().toString(),
                    TextStyle(
                      color: isDark
                          ? AppColors.textPrimaryLight
                          : AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status Distribution Pie ────────────────────────────────────────────────────

class _StatusDistCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartsAsync = ref.watch(hmAnalyticsChartsProvider);
    return AppCard(
      header: const AppSectionHeader(
        title: 'Loan Status',
        subtitle: 'Distribution',
      ),
      child: SizedBox(
        height: 220,
        child: chartsAsync.when(
          loading: () => const ShimmerBox(height: 220),
          error: (_, __) => _ChartEmpty(),
          data: (d) => _StatusPieChart(
            data: d['status_distribution'] as Map<String, dynamic>? ?? {},
          ),
        ),
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatusPieChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorMap = {
      'active': AppColors.success,
      'pending': AppColors.warning,
      'under_review': AppColors.info,
      'approved': AppColors.statusApproved,
      'completed': AppColors.textSecondaryLight,
      'defaulted': AppColors.error,
      'rejected': AppColors.statusRejected,
    };

    if (data.isEmpty) return _ChartEmpty();

    final sections = data.entries.map((e) {
      final pct = (e.value as num?)?.toDouble() ?? 0;
      return PieChartSectionData(
        value: pct,
        title: pct > 6 ? '${pct.toStringAsFixed(0)}%' : '',
        color: colorMap[e.key] ?? AppColors.accent,
        radius: 72,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          child: RepaintBoundary(
            child: PieChart(
              PieChartData(sections: sections, sectionsSpace: 2),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Legend
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries.map((e) {
            final color = colorMap[e.key] ?? AppColors.accent;
            final label = e.key.replaceAll('_', ' ');
            final pct = (e.value as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${label[0].toUpperCase()}${label.substring(1)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No data available',
        style: context.textTheme.bodyMedium,
      ),
    );
  }
}

// ── Recent Loans ──────────────────────────────────────────────────────────────

class _RecentLoansCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(hmLoansProvider('pending'));
    final isDark = context.isDark;

    return AppCard(
      header: AppSectionHeader(
        title: 'Pending Applications',
        action: TextButton(
          onPressed: () => context.go(RouteConstants.hmLoans),
          child: const Text('View all'),
        ),
      ),
      noPadding: true,
      child: loansAsync.when(
        loading: () => const ShimmerRow(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $e', style: context.textTheme.bodyMedium),
        ),
        data: (loans) {
          if (loans.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No pending applications',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            );
          }
          return Column(
            children: loans.take(5).map((loan) {
              return _LoanRow(
                loan: loan,
                isDark: isDark,
                onTap: () => context.go('/hm/loans/${loan.id}'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _LoanRow extends StatelessWidget {
  final LoanModel loan;
  final bool isDark;
  final VoidCallback onTap;
  const _LoanRow({
    required this.loan,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                AppIcons.loans,
                size: 17,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            // Name & date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.lenderName ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    loan.createdAt.toDisplayDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  loan.principalAmount.toPeso,
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                StatusChip.loanStatus('pending', small: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      header: const AppSectionHeader(title: 'Quick Actions'),
      noPadding: true,
      child: Column(
        children: [
          _ActionTile(
            icon: AppIcons.users,
            label: 'Manage Users',
            iconColor: AppColors.accent,
            onTap: () => context.go(RouteConstants.hmUsers),
          ),
          _ActionTile(
            icon: AppIcons.kyc,
            label: 'Review KYC',
            iconColor: AppColors.info,
            onTap: () => context.go(RouteConstants.hmKyc),
          ),
          _ActionTile(
            icon: AppIcons.analytics,
            label: 'View Analytics',
            iconColor: AppColors.success,
            onTap: () => context.go(RouteConstants.hmAnalytics),
          ),
          _ActionTile(
            icon: AppIcons.settings,
            label: 'System Settings',
            iconColor: AppColors.warning,
            onTap: () => context.go(RouteConstants.hmSettings),
          ),
          _ActionTile(
            icon: AppIcons.audit,
            label: 'Audit Log',
            iconColor: AppColors.textSecondaryLight,
            onTap: () => context.go(RouteConstants.hmAudit),
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLast;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  AppIcons.chevronRight,
                  size: 16,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: isDark ? AppColors.webBorderDark : AppColors.webBorderLight,
          ),
      ],
    );
  }
}
