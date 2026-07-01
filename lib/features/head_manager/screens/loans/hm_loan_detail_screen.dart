// lib/features/head_manager/screens/loans/hm_loan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/hm_providers.dart';

class HmLoanDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const HmLoanDetailScreen({super.key, required this.id});

  @override
  ConsumerState<HmLoanDetailScreen> createState() =>
      _HmLoanDetailScreenState();
}

class _HmLoanDetailScreenState extends ConsumerState<HmLoanDetailScreen> {
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final loanAsync = ref.watch(hmLoanDetailProvider(widget.id));

    return loanAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (loan) => _LoanDetail(
        loan: loan,
        acting: _acting,
        onApprove: () => _approve(loan),
        onReject: () => _reject(loan),
        onDisburse: () => _disburse(loan),
        onClose: () => _close(loan),
        onWaivePenalty: () => _waivePenalty(loan),
      ),
    );
  }

  Future<void> _approve(LoanModel loan) async {
    final termCtrl = TextEditingController(text: '30');
    String freq = 'monthly';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Approve Loan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: termCtrl,
                decoration: const InputDecoration(
                  labelText: 'Term (days)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: freq,
                decoration: const InputDecoration(
                  labelText: 'Payment Frequency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                ],
                onChanged: (v) => setSt(() => freq = v ?? freq),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    setState(() => _acting = true);
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.approveLoan(
        loan.id, int.tryParse(termCtrl.text) ?? 30, freq);
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Loan approved');
        ref.invalidate(hmLoanDetailProvider(widget.id));
        ref.invalidate(hmLoansProvider('pending'));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _reject(LoanModel loan) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Loan'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || reasonCtrl.text.trim().isEmpty) return;
    setState(() => _acting = true);
    final res = await ref
        .read(hmRepositoryProvider)
        .rejectLoan(loan.id, reasonCtrl.text.trim());
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Loan rejected');
        ref.invalidate(hmLoanDetailProvider(widget.id));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _disburse(LoanModel loan) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Disburse Loan',
      message: 'Disburse ${loan.principalAmount.toPeso} to ${loan.lenderName}? This will initiate a Xendit disbursement.',
      confirmLabel: 'Disburse',
    );
    if (ok != true) return;
    setState(() => _acting = true);
    final res = await ref.read(hmRepositoryProvider).disburseLoan(loan.id);
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Loan disbursed');
        ref.invalidate(hmLoanDetailProvider(widget.id));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _close(LoanModel loan) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Close Loan',
      message: 'Mark this loan as completed?',
      confirmLabel: 'Close Loan',
    );
    if (ok != true) return;
    setState(() => _acting = true);
    final res = await ref.read(hmRepositoryProvider).closeLoan(loan.id);
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Loan closed');
        ref.invalidate(hmLoanDetailProvider(widget.id));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _waivePenalty(LoanModel loan) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Waive Penalty'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Waive')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _acting = true);
    final res = await ref
        .read(hmRepositoryProvider)
        .waivePenalty(loan.id, reasonCtrl.text.trim());
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Penalty waived');
        ref.invalidate(hmLoanDetailProvider(widget.id));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }
}

class _LoanDetail extends StatelessWidget {
  final LoanModel loan;
  final bool acting;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onDisburse;
  final VoidCallback onClose;
  final VoidCallback onWaivePenalty;

  const _LoanDetail({
    required this.loan,
    required this.acting,
    required this.onApprove,
    required this.onReject,
    required this.onDisburse,
    required this.onClose,
    required this.onWaivePenalty,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.lenderName ?? 'Loan #${loan.id.substring(0, 8)}',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 4),
                    StatusChip.loanStatus(loan.status.value),
                  ],
                ),
              ),
              _ActionButtons(
                loan: loan,
                acting: acting,
                onApprove: onApprove,
                onReject: onReject,
                onDisburse: onDisburse,
                onClose: onClose,
                onWaivePenalty: onWaivePenalty,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _FinancialCard(loan: loan)),
              const SizedBox(width: 16),
              Expanded(child: _DetailsCard(loan: loan)),
            ],
          ),
          if (loan.comaker != null) ...[
            const SizedBox(height: 16),
            _ComakerCard(loan: loan),
          ],
          if (loan.hasPenalty) ...[
            const SizedBox(height: 16),
            _PenaltyCard(loan: loan, onWaive: onWaivePenalty),
          ],
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final LoanModel loan;
  final bool acting;
  final VoidCallback onApprove, onReject, onDisburse, onClose, onWaivePenalty;

  const _ActionButtons({
    required this.loan,
    required this.acting,
    required this.onApprove,
    required this.onReject,
    required this.onDisburse,
    required this.onClose,
    required this.onWaivePenalty,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (loan.status == LoanStatus.pending ||
            loan.status == LoanStatus.underReview) ...[
          AppButton(
            label: 'Approve',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            isLoading: acting,
            onPressed: onApprove,
          ),
          const SizedBox(width: 8),
          AppButton(
            label: 'Reject',
            isDanger: true,
            isOutlined: true,
            isLoading: acting,
            onPressed: onReject,
          ),
        ],
        if (loan.status == LoanStatus.approved) ...[
          AppButton(
            label: 'Disburse',
            icon: Icons.send_rounded,
            color: AppColors.accent,
            isLoading: acting,
            onPressed: onDisburse,
          ),
        ],
        if (loan.status == LoanStatus.active) ...[
          AppButton(
            label: 'Close Loan',
            isOutlined: true,
            isLoading: acting,
            onPressed: onClose,
          ),
        ],
      ],
    );
  }
}

class _FinancialCard extends StatelessWidget {
  final LoanModel loan;
  const _FinancialCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Financial Summary',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 20),
            _Row('Principal', loan.principalAmount.toPeso),
            _Row('Interest (20%)', loan.interestAmount.toPeso),
            _Row('Total Payable', loan.totalPayable.toPeso, bold: true),
            const Divider(height: 24),
            _Row('Outstanding Balance', loan.outstandingBalance.toPeso,
                bold: true, valueColor: AppColors.accent),
            if (loan.penaltyAmount > 0)
              _Row('Penalty', loan.penaltyAmount.toPeso,
                  valueColor: AppColors.error),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: loan.progressPercentage,
              color: AppColors.success,
              backgroundColor: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              minHeight: 8,
            ),
            const SizedBox(height: 6),
            Text(
              '${(loan.progressPercentage * 100).toStringAsFixed(0)}% repaid',
              style: const TextStyle(fontSize: 12, color: AppColors.success),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final LoanModel loan;
  const _DetailsCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loan Details',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 20),
            _Row('Applied', loan.createdAt.toDisplayDate),
            if (loan.approvedAt != null)
              _Row('Approved', loan.approvedAt!.toDisplayDate),
            if (loan.disbursedAt != null)
              _Row('Disbursed', loan.disbursedAt!.toDisplayDate),
            if (loan.maturityDate != null)
              _Row('Maturity', loan.maturityDate!.toDisplayDate),
            if (loan.paymentFrequency != null)
              _Row('Frequency', loan.paymentFrequency!.label),
            if (loan.termDays != null)
              _Row('Term', '${loan.termDays} days'),
            if (loan.installmentAmount != null)
              _Row('Installment', loan.installmentAmount!.toPeso),
            if (loan.purpose != null)
              _Row('Purpose', loan.purpose!),
            if (loan.rejectionReason != null) ...[
              const Divider(height: 24),
              const Text('Rejection Reason',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.error)),
              const SizedBox(height: 4),
              Text(loan.rejectionReason!,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComakerCard extends StatelessWidget {
  final LoanModel loan;
  const _ComakerCard({required this.loan});

  @override
  Widget build(BuildContext context) {
    final c = loan.comaker!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people_outline, size: 18),
                const SizedBox(width: 8),
                Text('Co-maker Information',
                    style: Theme.of(context).textTheme.headlineLarge),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Row('Full Name', c.fullName)),
                Expanded(child: _Row('Relationship', c.relationship)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PenaltyCard extends StatelessWidget {
  final LoanModel loan;
  final VoidCallback onWaive;
  const _PenaltyCard({required this.loan, required this.onWaive});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Penalty Applied',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.error)),
                  Text('Overdue ${loan.daysOverdue ?? 0} days',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            Text(
              loan.penaltyAmount.toPeso,
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 12),
            AppButton(
              label: 'Waive',
              isOutlined: true,
              isDanger: true,
              onPressed: onWaive,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _Row(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              fontSize: 13,
              color: valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}