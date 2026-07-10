// lib/features/employee/screens/payments/emp_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/emp_providers.dart';

class EmpPaymentsScreen extends ConsumerStatefulWidget {
  const EmpPaymentsScreen({super.key});

  @override
  ConsumerState<EmpPaymentsScreen> createState() => _EmpPaymentsScreenState();
}

class _EmpPaymentsScreenState extends ConsumerState<EmpPaymentsScreen>
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
            tabs: _statuses.map((s) => Tab(text: s[0].toUpperCase() + s.substring(1))).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _statuses.map((s) => _PayList(status: s)).toList(),
          ),
        ),
      ],
    );
  }
}

class _PayList extends ConsumerWidget {
  final String status;
  const _PayList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pAsync = ref.watch(empPaymentsProvider(status));
    return pAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (payments) {
        if (payments.isEmpty) return const EmptyState(icon: Icons.payment_outlined, title: 'No payments');
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: payments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final p = payments[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.payment_rounded, size: 20, color: AppColors.success)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.lenderName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text('${p.method.label} · ${p.createdAt.toDisplayDate}', style: Theme.of(context).textTheme.bodyMedium),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(p.amount.toPeso, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 4),
                      StatusChip.paymentStatus(p.status.value, small: true),
                    ]),
                    if (p.status.value == 'pending') ...[
                      const SizedBox(width: 8),
                      _QuickVerify(paymentId: p.id),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _QuickVerify extends ConsumerStatefulWidget {
  final String paymentId;
  const _QuickVerify({required this.paymentId});
  @override
  ConsumerState<_QuickVerify> createState() => _QuickVerifyState();
}

class _QuickVerifyState extends ConsumerState<_QuickVerify> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
        onPressed: () async {
          setState(() => _loading = true);
          final res = await ref.read(empRepositoryProvider).verifyPayment(widget.paymentId);
          setState(() => _loading = false);
          if (context.mounted) {
            if (res.success) { ref.invalidate(empPaymentsProvider('pending')); ref.invalidate(empPaymentsProvider('all')); }
          }
        },
        tooltip: 'Verify',
      ),
    ]);
  }
}