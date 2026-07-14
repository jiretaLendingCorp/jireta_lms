// lib/features/rider/screens/assignments/rider_assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/assignment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/rider_providers.dart';

class RiderAssignmentsScreen extends ConsumerStatefulWidget {
  const RiderAssignmentsScreen({super.key});

  @override
  ConsumerState<RiderAssignmentsScreen> createState() =>
      _RiderAssignmentsScreenState();
}

class _RiderAssignmentsScreenState extends ConsumerState<RiderAssignmentsScreen>
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.riderAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.riderAccent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(AppIcons.assignments,
                      color: AppColors.riderAccent, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Assignments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Glass pill-style TabBar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
              indicator: BoxDecoration(
                color: AppColors.riderAccent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.riderAccent.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: _labels.map((l) => Tab(text: l)).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: TabBarView(
                controller: _tabs,
                children:
                    _statuses.map((s) => _AssignmentList(status: s)).toList(),
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
        itemBuilder: (_, __) => const ShimmerCard(height: 86, isGlass: true),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $e',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
        ),
      ),
      data: (assignments) {
        if (assignments.isEmpty) {
          return EmptyState(
            icon: AppIcons.assignments,
            title: 'No assignments',
            subtitle: status == 'all'
                ? 'You have no assignments yet.'
                : 'No ${status.replaceAll('_', ' ')} assignments right now.',
            isGlass: true,
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
    final isCi = a.isCreditInvestigation;
    final accent = isCi ? AppColors.info : AppColors.riderAccent;
    return WhiteCard(
      isGlass: true,
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/rider/assignments/${a.id}'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(
              isCi ? Icons.person_search_rounded : AppIcons.mapPin,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.lenderName ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      a.collectionDate.toDisplayDate,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12),
                    ),
                  ],
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
              const SizedBox(height: 6),
              StatusChip.assignmentStatus(a.status.value, small: true),
            ],
          ),
          const SizedBox(width: 6),
          Icon(AppIcons.chevronRight,
              color: Colors.white.withValues(alpha: 0.35), size: 18),
        ],
      ),
    );
  }
}
