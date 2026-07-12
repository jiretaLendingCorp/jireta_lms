// lib/features/head_manager/screens/payments/hm_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/hm_providers.dart';

class HmPaymentsScreen extends ConsumerStatefulWidget {
  const HmPaymentsScreen({super.key});

  @override
  ConsumerState<HmPaymentsScreen> createState() => _HmPaymentsScreenState();
}

class _HmPaymentsScreenState extends ConsumerState<HmPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _statuses = ['all', 'pending', 'verified', 'rejected'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.accent,
            unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
            indicatorColor: AppColors.accent,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: _statuses
                .map((s) => Tab(
                      text: s[0].toUpperCase() + s.substring(1),
                    ))
                .toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _statuses.map((s) => _PaymentList(status: s)).toList(),
          ),
        ),
      ],
    );
  }
}

class _PaymentList extends ConsumerWidget {
  final String status;
  const _PaymentList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(hmPaymentsProvider(status));

    return paymentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (payments) {
        if (payments.isEmpty) {
          return const EmptyState(
            icon: Icons.payment_outlined,
            title: 'No payments found',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: payments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _PaymentCard(payment: payments[i]),
        );
      },
    );
  }
}

class _PaymentCard extends ConsumerWidget {
  final PaymentModel payment;
  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = payment;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = isDark ? Colors.white54 : Colors.black54;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.payment_rounded,
                      size: 20, color: AppColors.success),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.lenderName ?? 'Unknown Borrower',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.method.label} · ${p.createdAt.toDisplayDate}',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.amount.toPeso,
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    StatusChip.paymentStatus(p.status.value, small: true),
                  ],
                ),
                if (p.status.value == 'pending') ...[
                  const SizedBox(width: 8),
                  _PaymentActions(paymentId: p.id),
                ],
              ],
            ),
            if (p.referenceNumber != null ||
                p.notes != null ||
                p.rejectionReason != null ||
                p.verifiedAt != null) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 24,
                runSpacing: 6,
                children: [
                  if (p.referenceNumber != null)
                    _Detail('Ref #', p.referenceNumber!, subColor),
                  if (p.notes != null) _Detail('Notes', p.notes!, subColor),
                  if (p.verifiedAt != null)
                    _Detail('Verified', p.verifiedAt!.toDisplayDate, subColor),
                  if (p.rejectionReason != null)
                    _Detail('Rejected', p.rejectionReason!, AppColors.error),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Detail(this.label, this.value, [this.color]);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 12),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _PaymentActions extends ConsumerStatefulWidget {
  final String paymentId;
  const _PaymentActions({required this.paymentId});

  @override
  ConsumerState<_PaymentActions> createState() => _PaymentActionsState();
}

class _PaymentActionsState extends ConsumerState<_PaymentActions> {
  bool _loading = false;

  Future<void> _verify() async {
    setState(() => _loading = true);
    final res =
        await ref.read(hmRepositoryProvider).verifyPayment(widget.paymentId);
    setState(() => _loading = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Payment verified');
        ref.invalidate(hmPaymentsProvider('pending'));
        ref.invalidate(hmPaymentsProvider('all'));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
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
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final res = await ref
        .read(hmRepositoryProvider)
        .rejectPayment(widget.paymentId, ctrl.text.trim());
    setState(() => _loading = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Payment rejected');
        ref.invalidate(hmPaymentsProvider('pending'));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon:
              const Icon(Icons.check_circle_outline, color: AppColors.success),
          onPressed: _verify,
          tooltip: 'Verify',
        ),
        IconButton(
          icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
          onPressed: _reject,
          tooltip: 'Reject',
        ),
      ],
    );
  }
}
