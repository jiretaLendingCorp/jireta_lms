// lib/features/employee/screens/dashboard/emp_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../head_manager/widgets/kpi_card.dart';
import '../../providers/emp_providers.dart';

class EmpDashboardScreen extends ConsumerWidget {
  const EmpDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final pendingAsync = ref.watch(empLoansProvider('pending'));
    final paymentsAsync = ref.watch(empPaymentsProvider('pending'));
    final activeAsync = ref.watch(empLoansProvider('active'));

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, ${user?.firstName ?? '—'}',
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
                label: 'Loans',
                icon: AppIcons.loans,
                onPressed: () => context.go(RouteConstants.empLoans),
                size: AppButtonSize.sm,
                isOutlined: true,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // KPI Grid — responsive
          KpiGrid(
            cards: [
              KpiCard(
                label: 'Pending Review',
                value: pendingAsync.when(
                  data: (l) => '${l.length}',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
                icon: AppIcons.clock,
                iconColor: AppColors.warning,
              ),
              KpiCard(
                label: "Today's Collections",
                value: paymentsAsync.when(
                  data: (p) => '${p.length}',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
                icon: AppIcons.banknote,
                iconColor: AppColors.success,
              ),
              KpiCard(
                label: 'Active Loans',
                value: activeAsync.when(
                  data: (l) => '${l.length}',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
                icon: AppIcons.loans,
                iconColor: AppColors.accent,
              ),
              KpiCard(
                label: 'Cash Queue',
                value: paymentsAsync.when(
                  data: (p) =>
                      '${p.where((x) => x.method.value == 'cash').length}',
                  loading: () => '—',
                  error: (_, __) => '—',
                ),
                icon: AppIcons.truck,
                iconColor: AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Fix: give unique keys to prevent GlobalKey ink-renderer collision
          // when LayoutBuilder switches between wide/narrow layout trees.
          LayoutBuilder(builder: (context, c) {
            final isWide = c.maxWidth >= 860;
            if (isWide) {
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _PendingLoansCard()),
                  SizedBox(width: 16),
                  Expanded(child: _PendingPaymentsCard()),
                ],
              );
            }
            return const Column(
              children: [
                _PendingLoansCard(),
                SizedBox(height: 16),
                _PendingPaymentsCard(),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Pending Loans ─────────────────────────────────────────────────────────────

class _PendingLoansCard extends ConsumerWidget {
  const _PendingLoansCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(empLoansProvider('pending'));
    final isDark = context.isDark;

    return AppCard(
      header: AppSectionHeader(
        title: 'Pending Review',
        subtitle: 'Loans awaiting action',
        action: TextButton(
          onPressed: () => context.go(RouteConstants.empLoans),
          child: const Text('View all'),
        ),
      ),
      noPadding: true,
      child: loansAsync.when(
        loading: () => const ShimmerRow(count: 4),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $e', style: context.textTheme.bodyMedium),
        ),
        data: (loans) {
          if (loans.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No pending loans', style: TextStyle(fontSize: 14)),
              ),
            );
          }
          return Column(
            children: loans.take(5).map((loan) {
              return Column(
                children: [
                  InkWell(
                    onTap: () => context.go('/emp/loans/${loan.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(AppIcons.loans,
                                size: 17, color: AppColors.warning),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loan.lenderName ?? 'Unknown',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
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
                          Text(
                            loan.principalAmount.toPeso,
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: isDark
                        ? AppColors.webBorderDark
                        : AppColors.webBorderLight,
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ── Pending Payments ──────────────────────────────────────────────────────────

class _PendingPaymentsCard extends ConsumerWidget {
  const _PendingPaymentsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(empPaymentsProvider('pending'));
    final isDark = context.isDark;

    return AppCard(
      header: AppSectionHeader(
        title: 'Pending Payments',
        subtitle: 'Require verification',
        action: TextButton(
          onPressed: () => context.go(RouteConstants.empPayments),
          child: const Text('View all'),
        ),
      ),
      noPadding: true,
      child: paymentsAsync.when(
        loading: () => const ShimmerRow(count: 4),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $e', style: context.textTheme.bodyMedium),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child:
                    Text('No pending payments', style: TextStyle(fontSize: 14)),
              ),
            );
          }
          return Column(
            children: payments.take(5).map((pmt) {
              final isCash = pmt.method.value == 'cash';
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (isCash ? AppColors.success : AppColors.info)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isCash ? AppIcons.banknote : AppIcons.payments,
                            size: 17,
                            color: isCash ? AppColors.success : AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pmt.lenderName ?? 'Unknown',
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                pmt.method.value.snakeToLabel,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              pmt.amount.toPeso,
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            StatusChip.paymentStatus(pmt.status.value,
                                small: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: isDark
                        ? AppColors.webBorderDark
                        : AppColors.webBorderLight,
                  ),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
