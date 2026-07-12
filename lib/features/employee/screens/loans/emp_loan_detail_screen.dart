// lib/features/employee/screens/loans/emp_loan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/emp_providers.dart';

class EmpLoanDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const EmpLoanDetailScreen({super.key, required this.id});

  @override
  ConsumerState<EmpLoanDetailScreen> createState() =>
      _EmpLoanDetailScreenState();
}

class _EmpLoanDetailScreenState extends ConsumerState<EmpLoanDetailScreen> {
  bool _acting = false;

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
        .read(empRepositoryProvider)
        .approveLoan(loan.id, termDays, freq);
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Loan approved');
        ref.invalidate(empLoanDetailProvider(widget.id));
        ref.invalidate(empLoansProvider('pending'));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _reject(LoanModel loan) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Loan'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason',
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
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _acting = true);
    final res = await ref
        .read(empRepositoryProvider)
        .rejectLoan(loan.id, ctrl.text.trim());
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Loan rejected');
        ref.invalidate(empLoanDetailProvider(widget.id));
        ref.invalidate(empLoansProvider('pending'));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _assignRider(LoanModel loan) async {
    final ridersAsync = ref.read(empRidersProvider);
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
    final res = await ref.read(empRepositoryProvider).createAssignment({
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
        ref.invalidate(empLoanDetailProvider(widget.id));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loanAsync = ref.watch(empLoanDetailProvider(widget.id));
    return loanAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (loan) => SingleChildScrollView(
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
                        loan.lenderName ?? 'Loan',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 4),
                      StatusChip.loanStatus(loan.status.value),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (loan.status == LoanStatus.pending ||
                        loan.status == LoanStatus.underReview) ...[
                      AppButton(
                        label: 'Approve',
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                        isLoading: _acting,
                        onPressed: () => _approve(loan),
                      ),
                      AppButton(
                        label: 'Reject',
                        isDanger: true,
                        isOutlined: true,
                        isLoading: _acting,
                        onPressed: () => _reject(loan),
                      ),
                    ],
                    if (loan.status == LoanStatus.pending ||
                        loan.status == LoanStatus.underReview ||
                        loan.status == LoanStatus.approved ||
                        loan.status == LoanStatus.active)
                      AppButton(
                        label: 'Assign Rider',
                        icon: Icons.person_pin_circle_outlined,
                        isOutlined: true,
                        isLoading: _acting,
                        onPressed: () => _assignRider(loan),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _FinCard(loan: loan)),
                const SizedBox(width: 16),
                Expanded(child: _InfoCard(loan: loan)),
              ],
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

class _FinCard extends StatelessWidget {
  final LoanModel loan;
  const _FinCard({required this.loan});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Financial Summary',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),
              _R('Principal', loan.principalAmount.toPeso),
              _R('Interest (20%)', loan.interestAmount.toPeso),
              _R('Total Payable', loan.totalPayable.toPeso, bold: true),
              const Divider(height: 24),
              _R('Outstanding', loan.outstandingBalance.toPeso,
                  bold: true, color: AppColors.accent),
            ],
          ),
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final LoanModel loan;
  const _InfoCard({required this.loan});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Details', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),
              _R('Applied', loan.createdAt.toDisplayDate),
              if (loan.preferredFrequency != null)
                _R('Preferred Frequency', loan.preferredFrequency!.label),
              if (loan.termDays != null) _R('Term', '${loan.termDays} days'),
              if (loan.paymentFrequency != null)
                _R('Payment Frequency', loan.paymentFrequency!.label),
              if (loan.tierLabel != null) _R('Tier', loan.tierDisplayLabel),
              if (loan.purpose != null) _R('Purpose', loan.purpose!),
              if (loan.comaker != null) ...[
                const Divider(height: 20),
                _R('Co-maker', loan.comaker!.fullName),
                _R('Relationship', loan.comaker!.relationship),
              ],
            ],
          ),
        ),
      );
}

class _R extends StatelessWidget {
  final String l, v;
  final bool bold;
  final Color? color;
  const _R(this.l, this.v, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              v,
              style: GoogleFonts.jetBrainsMono(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                fontSize: 13,
                color: color ?? Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      );
}
