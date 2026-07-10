// lib/features/head_manager/screens/loans/hm_loans_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/hm_providers.dart';

class HmLoansScreen extends ConsumerStatefulWidget {
  const HmLoansScreen({super.key});

  @override
  ConsumerState<HmLoansScreen> createState() => _HmLoansScreenState();
}

class _HmLoansScreenState extends ConsumerState<HmLoansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _statuses = [
    'all', 'pending', 'under_review', 'approved', 'active', 'completed', 'rejected'
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surfaceColor = isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight;
    final borderColor = isDark ? AppColors.webBorderDark : AppColors.webBorderLight;

    return Column(
      children: [
        // Tab bar
        Container(
          color: surfaceColor,
          child: Column(
            children: [
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.accent,
                unselectedLabelColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
                tabs: _statuses.map((s) => Tab(
                  text: s == 'all' ? 'All Loans' : s.snakeToLabel,
                )).toList(),
              ),
              Divider(height: 1, color: borderColor),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _statuses.map((s) => _LoanList(status: s)).toList(),
          ),
        ),
      ],
    );
  }
}

class _LoanList extends ConsumerWidget {
  final String status;
  const _LoanList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(hmLoansProvider(status));
    final isDark = context.isDark;

    return loansAsync.when(
      loading: () => const _LoadingList(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (loans) {
        if (loans.isEmpty) {
          return EmptyState(
            icon: AppIcons.loans,
            title: 'No loans found',
            subtitle: status == 'all'
                ? 'No loan applications yet.'
                : 'No ${status.snakeToLabel.toLowerCase()} loan applications.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: loans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _LoanCard(loan: loans[i], isDark: isDark),
        );
      },
    );
  }
}

class _LoanCard extends StatelessWidget {
  final LoanModel loan;
  final bool isDark;
  const _LoanCard({required this.loan, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.webBorderDark : AppColors.webBorderLight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/hm/loans/${loan.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(AppIcons.loans, size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 14),
              // Name & date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.lenderName ?? 'Unknown Borrower',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Applied ${loan.createdAt.toDisplayDate}',
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
              // Amount & Status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    loan.principalAmount.toPeso,
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  StatusChip.loanStatus(loan.status.value, small: true),
                ],
              ),
              const SizedBox(width: 8),
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
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        height: 74,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            ShimmerBox(width: 40, height: 40, radius: 10),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBox(width: double.infinity, height: 13, radius: 4),
                  SizedBox(height: 7),
                  ShimmerBox(width: 120, height: 11, radius: 4),
                ],
              ),
            ),
            SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerBox(width: 80, height: 14, radius: 4),
                SizedBox(height: 7),
                ShimmerBox(width: 60, height: 20, radius: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}