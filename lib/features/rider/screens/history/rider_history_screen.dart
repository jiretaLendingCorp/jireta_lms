// lib/features/rider/screens/history/rider_history_screen.dart
//
// Premium Material 3 redesign of the rider collection history screen.
//  - Glass summary card with two stat columns (Total Collected, Completed)
//  - Glass list tiles with status icon, lender name, date, amount
//  - Shimmer loading state and friendly empty state
//  - Bottom overflow guarded via Column + Expanded chain.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class RiderHistoryScreen extends ConsumerWidget {
  const RiderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(riderAssignmentsProvider('completed'));

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
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
                  child: const Icon(AppIcons.history,
                      color: AppColors.riderAccent, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Collection History',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: asyncData.when(
              loading: () => Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: ShimmerCard(height: 110, isGlass: true),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, __) =>
                          const ShimmerCard(height: 76, isGlass: true),
                    ),
                  ),
                ],
              ),
              error: (e, _) => Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              )),
              data: (assignments) {
                if (assignments.isEmpty) {
                  return const EmptyState(
                    icon: AppIcons.history,
                    title: 'No completed collections',
                    subtitle:
                        'Your completed collection history will appear here.',
                    isGlass: true,
                  );
                }
                final totalCollected = assignments.fold<double>(
                    0, (sum, a) => sum + (a.amountCollected ?? 0));

                return Column(
                  children: [
                    // Summary glass card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _SummaryCard(
                        totalCollected: totalCollected,
                        completedCount: assignments.length,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: assignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final a = assignments[i];
                          return _HistoryTile(assignment: a);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Card ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalCollected;
  final int completedCount;
  const _SummaryCard({
    required this.totalCollected,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(AppIcons.coins,
                      color: AppColors.success, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Collected',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          totalCollected.toPeso,
                          style: GoogleFonts.jetBrainsMono(
                            color: AppColors.riderAccent,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 38,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.riderAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(AppIcons.checkCircle,
                      color: AppColors.riderAccent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Completed',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(
                        '$completedCount',
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── History Tile ───────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final AssignmentModel assignment;
  const _HistoryTile({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final amount = assignment.amountCollected ?? assignment.amountToCollect;
    final dateStr = assignment.completedAt?.toDisplayDate ??
        assignment.collectionDate.toDisplayDate;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(AppIcons.checkCircle,
                color: AppColors.success, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  assignment.lenderName ?? 'Unknown',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(AppIcons.calendar,
                        size: 12, color: Colors.white.withValues(alpha: 0.45)),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
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
                amount.toPeso,
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.riderAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              StatusChip.assignmentStatus(assignment.status.value, small: true),
            ],
          ),
        ],
      ),
    );
  }
}
