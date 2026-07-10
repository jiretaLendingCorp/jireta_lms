// lib/features/rider/screens/history/rider_history_screen.dart
//
// FIX #4 + #6:
//  - Converted WhiteCard → GlassCard (glassmorphism) per design request.
//  - White text/icon colors so content is visible on dark gradient background.
//  - Summary card and list cards both use GlassCard.
//  - "BOTTOM OVERFLOWED BY 70px" was caused by the inner Column→Expanded chain
//    not propagating bounded height from asyncData.when. Wrapped in
//    LayoutBuilder to ensure the Column gets correct constraints.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text(
              'Collection History',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: asyncData.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => const ShimmerCard(height: 72),
              ),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.white70))),
              data: (assignments) {
                if (assignments.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'No completed collections',
                    isGlass: false,
                  );
                }
                final totalCollected = assignments.fold<double>(
                    0, (sum, a) => sum + (a.amountCollected ?? 0));

                // FIX: Use Column + Expanded properly with explicit flex.
                // The outer Expanded from asyncData.when gives bounded height
                // to this Column, so the inner Expanded(ListView) works.
                return Column(
                  children: [
                    // Summary glass card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Collected',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.6),
                                        fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  totalCollected.toPeso,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: AppColors.riderAccent,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Completed',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.6),
                                        fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  '${assignments.length}',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: assignments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final a = assignments[i];
                          return GlassCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.15),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.success,
                                      size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        a.lenderName ?? 'Unknown',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        a.completedAt?.toDisplayDate ??
                                            a.collectionDate.toDisplayDate,
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.55),
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  (a.amountCollected ?? a.amountToCollect)
                                      .toPeso,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: AppColors.riderAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
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