// lib/features/head_manager/screens/loans/hm_loan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/app_user.dart';
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
  ConsumerState<HmLoanDetailScreen> createState() => _HmLoanDetailScreenState();
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
        onAssignRider: () => _assignRider(loan),
        onDisburse: () => _disburse(loan),
        onClose: () => _close(loan),
        onWaivePenalty: () => _waivePenalty(loan),
      ),
    );
  }

  Future<void> _approve(LoanModel loan) async {
    final freq = loan.preferredFrequency?.value ??
        loan.paymentFrequency?.value ??
        'monthly';
    final termDays = loan.termDays ?? 30;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Loan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve ${loan.principalAmount.toPeso} loan for ${loan.lenderName}?',
            ),
            const SizedBox(height: 16),
            _InfoRow('Term', '$termDays days'),
            _InfoRow(
              'Payment Frequency',
              freq[0].toUpperCase() + freq.substring(1),
            ),
            if (loan.tierLabel != null) _InfoRow('Tier', loan.tierDisplayLabel),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _acting = true);
    final res = await ref
        .read(hmRepositoryProvider)
        .approveLoan(loan.id, termDays, freq);
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
            child: const Text('Cancel'),
          ),
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
        ref.invalidate(hmLoansProvider('pending'));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _assignRider(LoanModel loan) async {
    final ridersAsync = ref.read(hmRidersProvider);
    final riders = ridersAsync.valueOrNull ?? [];

    AppUser? selectedRider;
    DateTime collectionDate = DateTime.now().add(const Duration(days: 1));
    String assignmentType = 'collection';
    final notesCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Assign Rider'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<AppUser>(
                  value: selectedRider,
                  decoration: const InputDecoration(
                    labelText: 'Select Rider',
                    border: OutlineInputBorder(),
                  ),
                  items: riders
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.fullName),
                          ))
                      .toList(),
                  onChanged: (v) => setSt(() => selectedRider = v),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: assignmentType,
                  decoration: const InputDecoration(
                    labelText: 'Assignment Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'collection',
                      child: Text('Collection'),
                    ),
                    DropdownMenuItem(
                      value: 'credit_investigation',
                      child: Text('Credit Investigation'),
                    ),
                  ],
                  onChanged: (v) =>
                      setSt(() => assignmentType = v ?? 'collection'),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(collectionDate.toDisplayDate),
                  subtitle: const Text('Collection Date'),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: collectionDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setSt(() => collectionDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  selectedRider == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selectedRider == null) return;
    setState(() => _acting = true);
    final res = await ref.read(hmRepositoryProvider).createAssignment({
      'loan_id': loan.id,
      'rider_id': selectedRider!.id,
      'lender_id': loan.lenderId,
      'amount_to_collect': loan.outstandingBalance,
      'collection_date':
          '${collectionDate.year}-${collectionDate.month.toString().padLeft(2, '0')}-${collectionDate.day.toString().padLeft(2, '0')}',
      'assignment_type': assignmentType,
      if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
    });
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Rider assigned successfully');
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
      message:
          'Disburse ${loan.principalAmount.toPeso} to ${loan.lenderName}? This will initiate a Xendit disbursement.',
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
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Waive'),
          ),
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
  final VoidCallback onAssignRider;
  final VoidCallback onDisburse;
  final VoidCallback onClose;
  final VoidCallback onWaivePenalty;

  const _LoanDetail({
    required this.loan,
    required this.acting,
    required this.onApprove,
    required this.onReject,
    required this.onAssignRider,
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
                onAssignRider: onAssignRider,
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
  final VoidCallback onApprove,
      onReject,
      onAssignRider,
      onDisburse,
      onClose,
      onWaivePenalty;

  const _ActionButtons({
    required this.loan,
    required this.acting,
    required this.onApprove,
    required this.onReject,
    required this.onAssignRider,
    required this.onDisburse,
    required this.onClose,
    required this.onWaivePenalty,
  });

  @override
  Widget build(BuildContext context) {
    final canAct = loan.status == LoanStatus.pending ||
        loan.status == LoanStatus.underReview;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        if (canAct) ...[
          AppButton(
            label: 'Approve',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            isLoading: acting,
            onPressed: onApprove,
          ),
          AppButton(
            label: 'Reject',
            isDanger: true,
            isOutlined: true,
            isLoading: acting,
            onPressed: onReject,
          ),
          AppButton(
            label: 'Assign Rider',
            icon: Icons.person_pin_circle_outlined,
            isOutlined: true,
            isLoading: acting,
            onPressed: onAssignRider,
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
          AppButton(
            label: 'Assign Rider',
            icon: Icons.person_pin_circle_outlined,
            isOutlined: true,
            isLoading: acting,
            onPressed: onAssignRider,
          ),
        ],
        if (loan.status == LoanStatus.active) ...[
          AppButton(
            label: 'Close Loan',
            isOutlined: true,
            isLoading: acting,
            onPressed: onClose,
          ),
          AppButton(
            label: 'Assign Rider',
            icon: Icons.person_pin_circle_outlined,
            isOutlined: true,
            isLoading: acting,
            onPressed: onAssignRider,
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
            if (loan.preferredFrequency != null)
              _Row('Preferred Frequency', loan.preferredFrequency!.label),
            if (loan.approvedAt != null)
              _Row('Approved', loan.approvedAt!.toDisplayDate),
            if (loan.disbursedAt != null)
              _Row('Disbursed', loan.disbursedAt!.toDisplayDate),
            if (loan.maturityDate != null)
              _Row('Maturity', loan.maturityDate!.toDisplayDate),
            if (loan.paymentFrequency != null)
              _Row('Payment Frequency', loan.paymentFrequency!.label),
            if (loan.termDays != null) _Row('Term', '${loan.termDays} days'),
            if (loan.installmentAmount != null)
              _Row('Installment', loan.installmentAmount!.toPeso),
            if (loan.tierLabel != null) _Row('Tier', loan.tierDisplayLabel),
            if (loan.purpose != null) _Row('Purpose', loan.purpose!),
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
                          fontWeight: FontWeight.w700, color: AppColors.error)),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
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
