// lib/features/employee/screens/loans/emp_loans_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/models/loan_model.dart';
import '../../providers/emp_providers.dart';

class EmpLoansScreen extends ConsumerStatefulWidget {
  const EmpLoansScreen({super.key});

  @override
  ConsumerState<EmpLoansScreen> createState() => _EmpLoansScreenState();
}

class _EmpLoansScreenState extends ConsumerState<EmpLoansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _statuses = ['all', 'pending', 'under_review', 'approved', 'active', 'completed', 'rejected'];

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
            tabs: _statuses.map((s) => Tab(text: s == 'all' ? 'All' : s.replaceAll('_', ' ').titleCase)).toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _statuses.map((s) => _EmpLoanList(status: s)).toList(),
          ),
        ),
      ],
    );
  }
}

class _EmpLoanList extends ConsumerWidget {
  final String status;
  const _EmpLoanList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(empLoansProvider(status));
    return loansAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (loans) {
        if (loans.isEmpty) return const EmptyState(icon: Icons.description_outlined, title: 'No loans found');
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: loans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final loan = loans[i];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go('/emp/loans/${loan.id}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.description_outlined, size: 20, color: AppColors.accent),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loan.lenderName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(loan.createdAt.toDisplayDate, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(loan.principalAmount.toPeso, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 4),
                          StatusChip.loanStatus(loan.status.value, small: true),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondaryLight),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}