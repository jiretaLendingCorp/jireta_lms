// lib/features/head_manager/screens/assignments/hm_assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/models/assignment_model.dart';
import '../../providers/hm_providers.dart';

class HmAssignmentsScreen extends ConsumerStatefulWidget {
  const HmAssignmentsScreen({super.key});

  @override
  ConsumerState<HmAssignmentsScreen> createState() =>
      _HmAssignmentsScreenState();
}

class _HmAssignmentsScreenState extends ConsumerState<HmAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _statuses = ['all', 'pending', 'in_progress', 'completed', 'failed', 'cancelled'];

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
                .map((s) => Tab(text: s == 'all' ? 'All' : s.replaceAll('_', ' ').titleCase))
                .toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _statuses.map((s) => _AssignmentList(status: s)).toList(),
          ),
        ),
      ],
    );
  }
}

class _AssignmentList extends ConsumerWidget {
  final String status;
  const _AssignmentList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(hmAssignmentsProvider(status));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assignments) {
        if (assignments.isEmpty) {
          return const EmptyState(icon: Icons.assignment_outlined, title: 'No assignments found');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: assignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final a = assignments[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.riderAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_ind_rounded, color: AppColors.riderAccent, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.lenderName ?? 'Unknown Lender', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('Rider: ${a.riderName ?? 'Unassigned'} · ${a.collectionDate.toDisplayDate}', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(a.amountToCollect.toPeso, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        StatusChip.assignmentStatus(a.status.value, small: true),
                      ],
                    ),
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