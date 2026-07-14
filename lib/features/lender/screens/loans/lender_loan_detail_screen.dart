// lib/features/lender/screens/loans/lender_loan_detail_screen.dart
//
// Premium Material 3 redesign with:
//  • Hero animation matching the home/loans list cards (tag: loan_<id>)
//  • Gradient-accented summary card with progress + penalty alert
//  • Clean financial breakdown with dividers and JetBrains Mono figures
//  • Status-tinted payment schedule & history rows
//  • AppButton gradient for "Make Payment" CTA
//
// Business logic (providers, navigation) is unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/lender_providers.dart';

const _accent = AppColors.lenderAccent;

class LenderLoanDetailScreen extends ConsumerWidget {
  final String id;
  const LenderLoanDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanAsync = ref.watch(lenderLoanDetailProvider(id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Loan Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: loanAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: _accent,
            strokeWidth: 2.5,
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.alertCircle,
                      color: AppColors.error, size: 32),
                  const SizedBox(height: 12),
                  const Text(
                    'Could not load loan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$e',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (loan) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'loan_$id',
                child: Material(
                  type: MaterialType.transparency,
                  child: _SummaryCard(loan: loan),
                ),
              ),
              const SizedBox(height: 14),
              _FinancialCard(loan: loan),
              const SizedBox(height: 14),
              _ScheduleSection(loanId: id),
              const SizedBox(height: 14),
              _PaymentHistorySection(loanId: id),
              if (loan.status == LoanStatus.active) ...[
                const SizedBox(height: 22),
                AppButton.gradient(
                  label: 'Make Payment',
                  icon: AppIcons.banknote,
                  width: double.infinity,
                  size: AppButtonSize.lg,
                  gradientColors: const [
                    AppColors.lenderAccent,
                    Color(0xFF5B5FE6),
                  ],
                  onPressed: () => context.go('/lender/pay/$id'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final LoanModel loan;
  const _SummaryCard({required this.loan});

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
                        'Outstanding Balance',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  StatusChip.loanStatus(loan.status.value),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                loan.outstandingBalance.toPeso,
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              if (loan.status == LoanStatus.active &&
                  loan.maturityDate != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: loan.progressPercentage,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    color: _accent,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(loan.progressPercentage * 100).toStringAsFixed(0)}% repaid',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Due ${loan.maturityDate!.toDisplayDate}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
              if (loan.hasPenalty && loan.penaltyAmount > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(AppIcons.warning,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Penalty: ${loan.penaltyAmount.toPeso} (${loan.daysOverdue ?? 0} days overdue)',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Financial Card ────────────────────────────────────────────────────────────

class _FinancialCard extends StatelessWidget {
  final LoanModel loan;
  const _FinancialCard({required this.loan});

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(AppIcons.banknote, color: _accent, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Loan Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Row('Principal', loan.principalAmount.toPeso),
          _Row('Interest (20%)', loan.interestAmount.toPeso),
          _Row('Total Payable', loan.totalPayable.toPeso, bold: true),
          if (loan.paymentFrequency != null) ...[
            const _Divider(),
            _Row('Payment Frequency', loan.paymentFrequency!.label),
            if (loan.termDays != null) _Row('Term', '${loan.termDays} days'),
            if (loan.installmentAmount != null)
              _Row('Installment', loan.installmentAmount!.toPeso),
          ],
          if (loan.purpose != null && loan.purpose!.isNotEmpty) ...[
            const _Divider(),
            _Row('Purpose', loan.purpose!),
          ],
          const _Divider(),
          _Row('Applied', loan.createdAt.toDisplayDate),
          if (loan.disbursedAt != null)
            _Row('Disbursed', loan.disbursedAt!.toDisplayDate),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        height: 1,
        color: Colors.white.withValues(alpha: 0.10),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Schedule Section ──────────────────────────────────────────────────────────

class _ScheduleSection extends ConsumerWidget {
  final String loanId;
  const _ScheduleSection({required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedAsync = ref.watch(lenderScheduleProvider(loanId));
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
                child: const Icon(AppIcons.calendar, color: _accent, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Payment Schedule',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          schedAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2.2,
                  ),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            data: (schedule) {
              if (schedule.isEmpty) {
                return const _EmptyInline(
                  icon: AppIcons.calendar,
                  text: 'No schedule available',
                );
              }
              final upcoming =
                  schedule.where((s) => !s.isPaid).take(5).toList();
              if (upcoming.isEmpty) {
                return const _EmptyInline(
                  icon: AppIcons.checkCircle,
                  text: 'All installments paid 🎉',
                  tone: AppColors.success,
                );
              }
              return Column(
                children: upcoming.map((s) {
                  final tone = s.isPaid
                      ? AppColors.success
                      : s.isOverdue
                          ? AppColors.error
                          : Colors.white.withValues(alpha: 0.4);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          s.isPaid
                              ? AppIcons.checkCircle
                              : s.isOverdue
                                  ? AppIcons.warning
                                  : Icons.radio_button_unchecked_rounded,
                          color: tone,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '#${s.installmentNumber} · ${s.dueDate.toDisplayDate}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          s.amountDue.toPeso,
                          style: GoogleFonts.jetBrainsMono(
                            color: s.isOverdue ? AppColors.error : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Payment History Section ───────────────────────────────────────────────────

class _PaymentHistorySection extends ConsumerWidget {
  final String loanId;
  const _PaymentHistorySection({required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(lenderPaymentHistoryProvider(loanId));
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
                child: const Icon(AppIcons.receipt, color: _accent, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'Payment History',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          histAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2.2,
                  ),
                ),
              ),
            ),
            error: (e, _) => Text(
              'Error: $e',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            data: (payments) {
              if (payments.isEmpty) {
                return const _EmptyInline(
                  icon: AppIcons.receipt,
                  text: 'No payments yet',
                );
              }
              return Column(
                children: payments.take(5).map((p) {
                  final isVerified = p.status.value == 'verified';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          isVerified ? AppIcons.checkCircle : AppIcons.clock,
                          color: isVerified
                              ? AppColors.success
                              : AppColors.warning,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                p.method.label,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                p.createdAt.toDisplayDate,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          p.amount.toPeso,
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyInline extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? tone;
  const _EmptyInline({required this.icon, required this.text, this.tone});

  @override
  Widget build(BuildContext context) {
    final t = tone ?? Colors.white.withValues(alpha: 0.4);
    return Row(
      children: [
        Icon(icon, color: t, size: 16),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
