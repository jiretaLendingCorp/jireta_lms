// lib/features/lender/screens/home/lender_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/kyc_model.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/lender_providers.dart';

class LenderHomeScreen extends ConsumerWidget {
  const LenderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final loansAsync = ref.watch(lenderMyLoansProvider);
    final kycAsync = ref.watch(lenderMyKycProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(user: user),
            const SizedBox(height: 24),

            // KYC banner
            kycAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (kyc) {
                if (kyc == null || kyc.status.value != 'approved') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _KycBanner(status: kyc?.status.value),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Main loan area
            loansAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(
                    color: AppColors.lenderAccent,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
              error: (e, _) => GlassCard(
                child: Text(
                  'Unable to load loans.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
              data: (loans) {
                final active =
                    loans.where((l) => l.status == LoanStatus.active).toList();
                final pending = loans
                    .where((l) =>
                        l.status == LoanStatus.pending ||
                        l.status == LoanStatus.underReview)
                    .toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (active.isNotEmpty) ...[
                      _ActiveLoanCard(loan: active.first),
                      const SizedBox(height: 16),
                    ],
                    if (pending.isNotEmpty) ...[
                      _PendingCard(count: pending.length),
                      const SizedBox(height: 16),
                    ],
                    if (active.isEmpty && pending.isEmpty) ...[
                      _NoLoanCard(),
                      const SizedBox(height: 20),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 8),
            _QuickActions(),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final dynamic user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(
          imageUrl: user?.avatarUrl,
          name: user?.displayName ?? '',
          size: 46,
          backgroundColor: AppColors.lenderAccent,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${user?.firstName ?? ''}! 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                DateTime.now().toDisplayDate,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Notification button
        GestureDetector(
          onTap: () => context.go(RouteConstants.lenderAlerts),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(
              AppIcons.notifications,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

// ── KYC Banner ────────────────────────────────────────────────────────────────

class _KycBanner extends StatelessWidget {
  final String? status;
  const _KycBanner({this.status});

  @override
  Widget build(BuildContext context) {
    final isPending = status == 'pending' || status == 'under_review';
    return GlassCard(
      borderColor: AppColors.warning.withOpacity(0.35),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPending ? AppIcons.clock : AppIcons.shieldOk,
              color: AppColors.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPending ? 'KYC Under Review' : 'KYC Required',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  isPending
                      ? 'Your documents are being reviewed.'
                      : 'Submit your ID to apply for a loan.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isPending)
            TextButton(
              onPressed: () => context.go(RouteConstants.lenderKyc),
              child: const Text(
                'Submit',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Active Loan Card ──────────────────────────────────────────────────────────

class _ActiveLoanCard extends StatelessWidget {
  final LoanModel loan;
  const _ActiveLoanCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppColors.lenderAccent.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.lenderAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      AppIcons.wallet,
                      color: AppColors.lenderAccent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active Loan',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              StatusChip.loanStatus(loan.status.value, small: true),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            loan.outstandingBalance.toPeso,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Outstanding balance',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: loan.progressPercentage,
              backgroundColor: Colors.white.withOpacity(0.10),
              valueColor: const AlwaysStoppedAnimation(AppColors.lenderAccent),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(loan.progressPercentage * 100).toStringAsFixed(0)}% repaid',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 11,
                ),
              ),
              if (loan.maturityDate != null)
                Text(
                  'Due ${loan.maturityDate!.toDisplayDate}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Make Payment',
            icon: AppIcons.banknote,
            width: double.infinity,
            size: AppButtonSize.lg,
            color: AppColors.lenderAccent,
            onPressed: () => context.go('/lender/pay/${loan.id}'),
          ),
        ],
      ),
    );
  }
}

// ── Pending Card ──────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final int count;
  const _PendingCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.go(RouteConstants.lenderLoans),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              AppIcons.clock,
              color: AppColors.warning,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Application Pending',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '$count application${count > 1 ? 's' : ''} under review',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            AppIcons.chevronRight,
            color: Colors.white.withOpacity(0.35),
            size: 18,
          ),
        ],
      ),
    );
  }
}

// ── No Loan Card ──────────────────────────────────────────────────────────────

class _NoLoanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: AppColors.lenderAccent.withOpacity(0.2),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.lenderAccent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              AppIcons.banknote,
              color: AppColors.lenderAccent,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active Loans',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Apply for a loan from ₱3,000 to ₱500,000\nwith flexible payment terms.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Apply for a Loan',
            icon: AppIcons.plusCircle,
            width: double.infinity,
            size: AppButtonSize.lg,
            color: AppColors.lenderAccent,
            onPressed: () => context.go(RouteConstants.lenderApply),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: AppIcons.loans,
                label: 'My Loans',
                onTap: () => context.go(RouteConstants.lenderLoans),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: AppIcons.kyc,
                label: 'KYC Status',
                onTap: () => context.go(RouteConstants.lenderKyc),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionTile(
                icon: AppIcons.settings,
                label: 'Settings',
                onTap: () => context.go(RouteConstants.lenderSettings),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lenderAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.lenderAccent, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}