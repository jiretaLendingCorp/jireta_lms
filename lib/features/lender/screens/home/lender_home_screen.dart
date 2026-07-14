// lib/features/lender/screens/home/lender_home_screen.dart
//
// Premium Material 3 redesign with:
//  • Animated state transitions (loading → data) via AnimatedSwitcher
//  • Hero animation bridging active-loan card → loan detail screen
//  • Gradient-accented stat cards in a 2-col grid for lifetime summary
//  • Glassmorphism on deep midnight gradient (lenderAccent #818CF8)
//  • Consistent 14–16px corner radius, 200–280ms ease-out animations
//
// Business logic (providers, navigation, state) is unchanged.

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
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
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

            // Loan area — animated loading → data transition
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: loansAsync.when(
                loading: () =>
                    const _LoadingCard(key: ValueKey('loan-loading')),
                error: (e, _) => GlassCard(
                  key: const ValueKey('loan-error'),
                  child: Row(
                    children: [
                      const Icon(AppIcons.alertCircle,
                          color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Unable to load loans. Pull down to refresh.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (loans) {
                  final active = loans
                      .where((l) => l.status == LoanStatus.active)
                      .toList();
                  final pending = loans
                      .where((l) =>
                          l.status == LoanStatus.pending ||
                          l.status == LoanStatus.underReview)
                      .toList();
                  return Column(
                    key: ValueKey('loan-${active.length}-${pending.length}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (active.isNotEmpty) ...[
                        Hero(
                          tag: 'loan_${active.first.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: _ActiveLoanCard(loan: active.first),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (pending.isNotEmpty) ...[
                        _PendingCard(count: pending.length),
                        const SizedBox(height: 14),
                      ],
                      if (active.isEmpty && pending.isEmpty) ...[
                        const _NoLoanCard(),
                        const SizedBox(height: 14),
                      ],
                    ],
                  );
                },
              ),
            ),

            const _QuickActions(),
            const SizedBox(height: 18),
            const _LifetimeStats(),
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
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _accent.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppAvatar(
            imageUrl: user?.avatarUrl,
            name: user?.displayName ?? '',
            size: 46,
            backgroundColor: _accent,
          ),
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
              const SizedBox(height: 2),
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
        _HeaderIconButton(
          icon: AppIcons.notifications,
          onTap: () => context.go(RouteConstants.lenderAlerts),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _pressed ? 0.28 : 0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Icon(widget.icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Loading Card ──────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 90,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Center(
            child: SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                color: _accent,
                strokeWidth: 2.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
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
    final tone = isPending ? AppColors.warning : _accent;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tone.withValues(alpha: 0.35)),
            ),
            child: Icon(
              isPending ? AppIcons.clock : AppIcons.shieldOk,
              color: tone,
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
                const SizedBox(height: 2),
                Text(
                  isPending
                      ? 'Your documents are being reviewed.'
                      : 'Submit your ID to apply for a loan.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isPending)
            GestureDetector(
              onTap: () => context.go(RouteConstants.lenderKyc),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Submit',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
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
      child: Stack(
        children: [
          // Top accent gradient line
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accent.withValues(alpha: 0.0),
                    _accent.withValues(alpha: 0.85),
                    _accent.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Column(
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
                          border:
                              Border.all(color: _accent.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(AppIcons.wallet,
                            color: _accent, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Active Loan',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
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
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Outstanding balance',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: loan.progressPercentage,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(_accent),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(loan.progressPercentage * 100).toStringAsFixed(0)}% repaid',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                  if (loan.maturityDate != null)
                    Text(
                      'Due ${loan.maturityDate!.toDisplayDate}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
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
                color: _accent,
                onPressed: () => context.go('/lender/pay/${loan.id}'),
              ),
            ],
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
              color: AppColors.warning.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.32)),
            ),
            child:
                const Icon(AppIcons.clock, color: AppColors.warning, size: 22),
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
                const SizedBox(height: 2),
                Text(
                  '$count application${count > 1 ? 's' : ''} under review',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
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

// ── No Loan Card ──────────────────────────────────────────────────────────────

class _NoLoanCard extends StatelessWidget {
  const _NoLoanCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 20,
            right: 20,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _accent.withValues(alpha: 0.0),
                    _accent.withValues(alpha: 0.85),
                    _accent.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Column(
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
                          border:
                              Border.all(color: _accent.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(AppIcons.wallet,
                            color: _accent, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Outstanding Balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Text(
                      'No Active Loan',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Apply for a loan from ₱3,000 to ₱500,000',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: 0,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
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
        ],
      ),
    );
  }
}

// ── Quick Actions — Settings REMOVED per spec ─────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Tap to open',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ],
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
            const SizedBox(width: 12),
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
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      backgroundColor: Colors.white.withValues(alpha: 0.10),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accent.withValues(alpha: 0.32)),
            ),
            child: Icon(icon, color: _accent, size: 20),
          ),
          const SizedBox(height: 9),
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

// ── Lifetime Stats ────────────────────────────────────────────────────────────

class _LifetimeStats extends ConsumerWidget {
  const _LifetimeStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(lenderLifetimeStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (stats) {
        final totalLoans = stats['total_loans'] as int? ?? 0;
        if (totalLoans == 0) return const SizedBox.shrink();

        final totalBorrowed =
            (stats['total_borrowed'] as num?)?.toDouble() ?? 0;
        final outstanding =
            (stats['outstanding_balance'] as num?)?.toDouble() ?? 0;
        final activeCount = stats['active_loans'] as int? ?? 0;
        final completedCount = stats['completed_loans'] as int? ?? 0;

        return GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _accent.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(AppIcons.analytics,
                        color: _accent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Lifetime Summary',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _accent.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      '$totalLoans total',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatMini(
                      label: 'Total Borrowed',
                      value: totalBorrowed.toPesoCompact,
                      icon: AppIcons.coins,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatMini(
                      label: 'Outstanding',
                      value: outstanding.toPesoCompact,
                      icon: AppIcons.wallet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _StatMini(
                      label: 'Active Loans',
                      value: '$activeCount',
                      icon: AppIcons.trendUp,
                      tone: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatMini(
                      label: 'Completed',
                      value: '$completedCount',
                      icon: AppIcons.checkCircle,
                      tone: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatMini extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? tone;
  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final t = tone ?? _accent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: t, size: 14),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
