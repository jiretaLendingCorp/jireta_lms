// lib/features/rider/screens/assignments/rider_assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/models/assignment_model.dart';
import '../../providers/rider_providers.dart';

class RiderAssignmentsScreen extends ConsumerStatefulWidget {
  const RiderAssignmentsScreen({super.key});

  @override
  ConsumerState<RiderAssignmentsScreen> createState() =>
      _RiderAssignmentsScreenState();
}

class _RiderAssignmentsScreenState
    extends ConsumerState<RiderAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _statuses = ['all', 'pending', 'in_progress', 'completed', 'failed'];
  final _labels = ['All', 'Pending', 'In Progress', 'Completed', 'Failed'];

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
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'My Assignments',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.riderAccent,
            unselectedLabelColor: Colors.white54,
            indicatorColor: AppColors.riderAccent,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: _labels.map((l) => Tab(text: l)).toList(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: TabBarView(
                controller: _tabs,
                children: _statuses
                    .map((s) => _AssignmentList(status: s))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentList extends ConsumerWidget {
  final String status;
  const _AssignmentList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(riderAssignmentsProvider(status));
    return asyncData.when(
      loading: () => ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const ShimmerCard(height: 80),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $e',
              style: const TextStyle(color: Colors.white70)),
        ),
      ),
      data: (assignments) {
        if (assignments.isEmpty) {
          return const EmptyState(
            icon: Icons.assignment_outlined,
            title: 'No assignments',
            isGlass: false,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: assignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            final a = assignments[i];
            return _AssignmentTile(a: a);
          },
        );
      },
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final AssignmentModel a;
  const _AssignmentTile({required this.a});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/rider/assignments/${a.id}'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.riderAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_ind_rounded,
                color: AppColors.riderAccent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.lenderName ?? 'Unknown',
                  style: const TextStyle(
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  a.collectionDate.toDisplayDate,
                  style: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                a.amountToCollect.toPeso,
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.riderAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              StatusChip.assignmentStatus(a.status.value, small: true),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFD1D5DB)),
        ],
      ),
    );
  }
}