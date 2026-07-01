// lib/features/lender/screens/loans/lender_loan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/lender_providers.dart';

class LenderLoanDetailScreen extends ConsumerWidget {
  final String id;
  const LenderLoanDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanAsync = ref.watch(lenderLoanDetailProvider(id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Loan Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: loanAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white70))),
        data: (loan) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            children: [
              _SummaryCard(loan: loan),
              const SizedBox(height: 16),
              _FinancialCard(loan: loan),
              const SizedBox(height: 16),
              _ScheduleSection(loanId: id),
              const SizedBox(height: 16),
              _PaymentHistorySection(loanId: id),
              if (loan.status == LoanStatus.active) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/lender/pay/$id'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lenderAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Make Payment',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final LoanModel loan;
  const _SummaryCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Outstanding Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              StatusChip.loanStatus(loan.status.value),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            loan.outstandingBalance.toPeso,
            style: GoogleFonts.jetBrainsMono(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700),
          ),
          if (loan.status == LoanStatus.active && loan.maturityDate != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: loan.progressPercentage,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                color: AppColors.lenderAccent,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(loan.progressPercentage * 100).toStringAsFixed(0)}% repaid',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
                Text('Due ${loan.maturityDate!.toDisplayDate}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          ],
          if (loan.hasPenalty && loan.penaltyAmount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Penalty: ${loan.penaltyAmount.toPeso} (${loan.daysOverdue ?? 0} days overdue)',
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final LoanModel loan;
  const _FinancialCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Loan Summary',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _Row('Principal', loan.principalAmount.toPeso),
          _Row('Interest (20%)', loan.interestAmount.toPeso),
          _Row('Total Payable', loan.totalPayable.toPeso, bold: true),
          if (loan.paymentFrequency != null) ...[
            const Divider(color: Colors.white12, height: 20),
            _Row('Payment Frequency', loan.paymentFrequency!.label),
            if (loan.termDays != null)
              _Row('Term', '${loan.termDays} days'),
            if (loan.installmentAmount != null)
              _Row('Installment', loan.installmentAmount!.toPeso),
          ],
          if (loan.purpose != null) ...[
            const Divider(color: Colors.white12, height: 20),
            _Row('Purpose', loan.purpose!),
          ],
          _Row('Applied', loan.createdAt.toDisplayDate),
          if (loan.disbursedAt != null)
            _Row('Disbursed', loan.disbursedAt!.toDisplayDate),
        ],
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
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

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
          const Text('Payment Schedule',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          schedAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white)),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: Colors.white70)),
            data: (schedule) {
              if (schedule.isEmpty) {
                return Text('No schedule available',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 13));
              }
              final upcoming = schedule.where((s) => !s.isPaid).take(5).toList();
              return Column(
                children: upcoming.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          s.isPaid
                              ? Icons.check_circle_rounded
                              : s.isOverdue
                                  ? Icons.warning_rounded
                                  : Icons.circle_outlined,
                          color: s.isPaid
                              ? AppColors.success
                              : s.isOverdue
                                  ? AppColors.error
                                  : Colors.white38,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '#${s.installmentNumber} · ${s.dueDate.toDisplayDate}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13),
                          ),
                        ),
                        Text(
                          s.amountDue.toPeso,
                          style: GoogleFonts.jetBrainsMono(
                            color: s.isOverdue
                                ? AppColors.error
                                : Colors.white,
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
          const Text('Payment History',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          histAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white)),
            error: (e, _) => Text('Error: $e',
                style: const TextStyle(color: Colors.white70)),
            data: (payments) {
              if (payments.isEmpty) {
                return Text('No payments yet',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 13));
              }
              return Column(
                children: payments.take(5).map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: p.status.value == 'verified'
                              ? AppColors.success
                              : Colors.white38,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${p.method.label} · ${p.createdAt.toDisplayDate}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13),
                          ),
                        ),
                        Text(
                          p.amount.toPeso,
                          style: GoogleFonts.jetBrainsMono(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
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