// lib/features/employee/screens/loans/emp_loan_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/emp_providers.dart';

class EmpLoanDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const EmpLoanDetailScreen({super.key, required this.id});

  @override
  ConsumerState<EmpLoanDetailScreen> createState() => _EmpLoanDetailScreenState();
}

class _EmpLoanDetailScreenState extends ConsumerState<EmpLoanDetailScreen> {
  bool _acting = false;

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
              TextField(controller: termCtrl, decoration: const InputDecoration(labelText: 'Term (days)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: freq,
                decoration: const InputDecoration(labelText: 'Payment Frequency', border: OutlineInputBorder()),
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    setState(() => _acting = true);
    final res = await ref.read(empRepositoryProvider).approveLoan(loan.id, int.tryParse(termCtrl.text) ?? 30, freq);
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) { context.showSnack('Loan approved'); ref.invalidate(empLoanDetailProvider(widget.id)); }
      else {
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
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogCtx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Reject')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _acting = true);
    final res = await ref.read(empRepositoryProvider).rejectLoan(loan.id, ctrl.text.trim());
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) { context.showSnack('Loan rejected'); ref.invalidate(empLoanDetailProvider(widget.id)); }
      else {
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
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(loan.lenderName ?? 'Loan', style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: 4),
                  StatusChip.loanStatus(loan.status.value),
                ])),
                if (loan.status == LoanStatus.pending || loan.status == LoanStatus.underReview) ...[
                  AppButton(label: 'Approve', icon: Icons.check_circle_outline, color: AppColors.success, isLoading: _acting, onPressed: () => _approve(loan)),
                  const SizedBox(width: 8),
                  AppButton(label: 'Reject', isDanger: true, isOutlined: true, isLoading: _acting, onPressed: () => _reject(loan)),
                ],
              ],
            ),
            const SizedBox(height: 24),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _FinCard(loan: loan)),
              const SizedBox(width: 16),
              Expanded(child: _InfoCard(loan: loan)),
            ]),
          ],
        ),
      ),
    );
  }
}

class _FinCard extends StatelessWidget {
  final LoanModel loan;
  const _FinCard({required this.loan});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Financial Summary', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 16),
      _R('Principal', loan.principalAmount.toPeso),
      _R('Interest (20%)', loan.interestAmount.toPeso),
      _R('Total Payable', loan.totalPayable.toPeso, bold: true),
      const Divider(height: 24),
      _R('Outstanding', loan.outstandingBalance.toPeso, bold: true, color: AppColors.accent),
    ])),
  );
}

class _InfoCard extends StatelessWidget {
  final LoanModel loan;
  const _InfoCard({required this.loan});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Details', style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 16),
      _R('Applied', loan.createdAt.toDisplayDate),
      if (loan.termDays != null) _R('Term', '${loan.termDays} days'),
      if (loan.paymentFrequency != null) _R('Frequency', loan.paymentFrequency!.label),
      if (loan.purpose != null) _R('Purpose', loan.purpose!),
      if (loan.comaker != null) ...[const Divider(height: 20), _R('Co-maker', loan.comaker!.fullName), _R('Relationship', loan.comaker!.relationship)],
    ])),
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
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: Theme.of(context).textTheme.bodyMedium),
      Text(v, style: GoogleFonts.jetBrainsMono(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: 13, color: color ?? Theme.of(context).textTheme.bodyLarge?.color)),
    ]),
  );
}