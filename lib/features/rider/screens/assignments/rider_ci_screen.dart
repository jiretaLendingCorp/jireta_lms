// lib/features/rider/screens/assignments/rider_ci_screen.dart
// Credit Investigation screen for riders — shows only CI assignments.
// Separate from the Collection screen per item #13.
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

class RiderCiScreen extends ConsumerWidget {
  const RiderCiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(riderAssignmentsProvider('all'));

    return SafeArea(
      bottom: false,
      child: asyncData.when(
        loading: () => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, __) => const ShimmerCard(height: 140, isGlass: true),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
        ),
        data: (allAssignments) {
          final ciAssignments =
              allAssignments.where((a) => a.isCreditInvestigation).toList();

          return Column(
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
                        color: AppColors.info.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Icon(Icons.person_search_rounded,
                          color: AppColors.info, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Credit Investigation',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3)),
                          const SizedBox(height: 2),
                          Text(
                            '${ciAssignments.length} assignment${ciAssignments.length != 1 ? 's' : ''} pending review',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ciAssignments.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No CI Assignments',
                        subtitle:
                            'Your credit investigation tasks will appear here',
                        isGlass: true,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: ciAssignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            _CiCard(assignment: ciAssignments[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CiCard extends StatelessWidget {
  final AssignmentModel assignment;
  const _CiCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => context.go('/rider/assignments/${assignment.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(Icons.person_search_rounded,
                    color: AppColors.info, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(assignment.lenderName ?? 'Unknown Lender',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(AppIcons.calendar,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.45)),
                        const SizedBox(width: 4),
                        Text(
                          assignment.collectionDate.toDisplayDate,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusChip.assignmentStatus(assignment.status.value, small: true),
            ],
          ),
          if (assignment.lenderAddress != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.mapPin,
                      size: 14, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(assignment.lenderAddress!,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
          if (assignment.notes != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.message,
                      size: 13, color: AppColors.info.withValues(alpha: 0.8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(assignment.notes!,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(AppIcons.wallet, size: 14, color: AppColors.info),
              const SizedBox(width: 6),
              Text('Loan Amount:',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12)),
              const SizedBox(width: 4),
              Text(assignment.amountToCollect.toPeso,
                  style: GoogleFonts.jetBrainsMono(
                      color: AppColors.info,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.riderAccent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.riderAccent.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Open',
                      style: TextStyle(
                        color: AppColors.riderAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(AppIcons.chevronRight,
                        color: AppColors.riderAccent, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
