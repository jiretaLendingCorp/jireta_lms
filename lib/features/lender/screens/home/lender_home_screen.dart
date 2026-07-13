// lib/features/lender/screens/home/lender_home_screen.dart
// Fixed: glassmorphism design; removed Settings from Quick Actions per spec.

import 'dart:ui';
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

const _accent = AppColors.lenderAccent;

class LenderHomeScreen extends ConsumerWidget {
  const LenderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final loansAsync = ref.watch(lenderMyLoansProvider);
    final kycAsync = ref.watch(lenderMyKycProvider);

    final bottomPad = MediaQuery.of(context).padding.bottom + 100;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(user: user),
            const SizedBox(height: 20),

            // KYC banner
            kycAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (kyc) {
                if (kyc == null || kyc.status.value != 'approved') {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _KycBanner(status: kyc?.status.value),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Loan area
            loansAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
              error: (e, _) => GlassCard(
                child: Text(
                  'Unable to load loans: $e',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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
                      const SizedBox(height: 14),
                    ],
                    if (pending.isNotEmpty) ...[
                      _PendingCard(count: pending.length),
                      const SizedBox(height: 14),
                    ],
                    if (active.isEmpty && pending.isEmpty) ...[
                      _NoLoanCard(),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),

            _QuickActions(),
            const SizedBox(height: 16),
            _LifetimeStats(),
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
          backgroundColor: _accent,
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
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.go(RouteConstants.lenderAlerts),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.25)),
                ),
                child: const Icon(AppIcons.notifications,
                    color: Colors.white, size: 20),
              ),
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
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
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
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
          if (!isPending)
            TextButton(
              onPressed: () => context.go(RouteConstants.lenderKyc),
              child: const Text('Submit',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
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
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(AppIcons.wallet, color: _accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text('Active Loan',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
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
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text('Outstanding balance',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: loan.progressPercentage,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(_accent),
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
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 11),
              ),
              if (loan.maturityDate != null)
                Text(
                  'Due ${loan.maturityDate!.toDisplayDate}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Make Payment',
            icon: AppIcons.banknote,
            width: double.infinity,
            size: AppButtonSize.lg,
            color: _accent,
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
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(AppIcons.clock, color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Application Pending',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                Text(
                  '$count application${count > 1 ? 's' : ''} under review',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight,
              color: Colors.white.withValues(alpha: 0.4), size: 18),
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
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(AppIcons.wallet, color: _accent, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text('Outstanding Balance',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('No Active Loan',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '₱0.00',
            style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1),
          ),
          const SizedBox(height: 4),
          Text('Apply for a loan from ₱3,000 to ₱500,000',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: 0,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(_accent),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Apply for a Loan',
            icon: AppIcons.plusCircle,
            width: double.infinity,
            size: AppButtonSize.lg,
            color: _accent,
            onPressed: () => context.go(RouteConstants.lenderApply),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions — Settings REMOVED per spec ─────────────────────────────────

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2)),
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
            // FIX: Settings removed from Quick Actions per spec (item 7)
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _accent, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Lifetime Stats ────────────────────────────────────────────────────────────

class _LifetimeStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(lenderLifetimeStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        if ((stats['total_loans'] as int? ?? 0) == 0) {
          return const SizedBox.shrink();
        }
        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: _accent, size: 18),
                  SizedBox(width: 8),
                  Text('Lifetime Summary',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              _SRow('Total Loan Applications', '${stats['total_loans']}'),
              _SRow('Active Loans', '${stats['active_loans']}'),
              _SRow('Completed Loans', '${stats['completed_loans']}'),
              _SRow('Total Borrowed',
                  '₱${((stats['total_borrowed'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
              _SRow('Outstanding Balance',
                  '₱${((stats['outstanding_balance'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
            ],
          ),
        );
      },
    );
  }
}

class _SRow extends StatelessWidget {
  final String label;
  final String value;
  const _SRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65), fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
