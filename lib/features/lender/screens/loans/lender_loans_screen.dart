// lib/features/lender/screens/loans/lender_loans_screen.dart
//
// Premium Material 3 redesign with glassmorphism, shimmer loading,
// animated state transitions, Hero animation bridging list → detail,
// and consistent indigo accent (#818CF8).
//
// Business logic (provider, navigation) is unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/lender_providers.dart';

const _accent = AppColors.lenderAccent;

class LenderLoansScreen extends ConsumerWidget {
  const LenderLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(lenderMyLoansProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Loans',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Track applications, active loans & history',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: 'Apply',
                  icon: AppIcons.add,
                  size: AppButtonSize.sm,
                  color: _accent,
                  onPressed: () => context.go(RouteConstants.lenderApply),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: loansAsync.when(
                loading: () =>
                    const _LoansShimmer(key: ValueKey('loans-loading')),
                error: (e, _) => _ErrorState(
                  key: const ValueKey('loans-error'),
                  message: '$e',
                ),
                data: (loans) {
                  if (loans.isEmpty) {
                    return EmptyState(
                      key: const ValueKey('loans-empty'),
                      icon: AppIcons.loans,
                      title: 'No loans yet',
                      subtitle:
                          'Apply for your first loan and get funds\nwithin minutes after approval.',
                      isGlass: true,
                      action: AppButton(
                        label: 'Apply Now',
                        icon: AppIcons.plusCircle,
                        color: _accent,
                        size: AppButtonSize.lg,
                        onPressed: () => context.go(RouteConstants.lenderApply),
                      ),
                    );
                  }
                  return ListView.separated(
                    key: ValueKey('loans-${loans.length}'),
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                    itemCount: loans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final loan = loans[i];
                      return Hero(
                        tag: 'loan_${loan.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: _LoanCard(loan: loan),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Loan Card ─────────────────────────────────────────────────────────────────

class _LoanCard extends StatelessWidget {
  final LoanModel loan;
  const _LoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final isActive = loan.status == LoanStatus.active;
    final isPending = loan.status == LoanStatus.pending ||
        loan.status == LoanStatus.underReview;

    return GlassCard(
      onTap: () => context.go('/lender/loans/${loan.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status-tinted icon tile
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: (isActive
                      ? AppColors.success
                      : isPending
                          ? AppColors.warning
                          : _accent)
                  .withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (isActive
                        ? AppColors.success
                        : isPending
                            ? AppColors.warning
                            : _accent)
                    .withValues(alpha: 0.28),
              ),
            ),
            child: Icon(
              isActive
                  ? AppIcons.wallet
                  : isPending
                      ? AppIcons.clock
                      : AppIcons.loans,
              color: isActive
                  ? AppColors.success
                  : isPending
                      ? AppColors.warning
                      : _accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan.principalAmount.toPeso,
                  style: GoogleFonts.jetBrainsMono(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        loan.createdAt.toDisplayDate,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: loan.progressPercentage,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation(_accent),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Right column: status + outstanding
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip.loanStatus(loan.status.value, small: true),
              if (isActive) ...[
                const SizedBox(height: 6),
                Text(
                  loan.outstandingBalance.toPeso,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 6),
          Icon(
            AppIcons.chevronRight,
            color: Colors.white.withValues(alpha: 0.4),
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ── Loading Shimmer ───────────────────────────────────────────────────────────

class _LoansShimmer extends StatelessWidget {
  const _LoansShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const ShimmerCard(
        height: 78,
        padding: EdgeInsets.all(14),
        isGlass: true,
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35)),
                ),
                child: const Icon(AppIcons.alertCircle,
                    color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Could not load loans',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
