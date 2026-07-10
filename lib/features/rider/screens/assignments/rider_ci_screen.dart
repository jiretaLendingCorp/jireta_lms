// lib/features/rider/screens/assignments/rider_ci_screen.dart
// Credit Investigation screen for riders — shows only CI assignments.
// Separate from the Collection screen per item #13.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/assignment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
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
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
        data: (allAssignments) {
          final ciAssignments = allAssignments
              .where((a) => a.isCreditInvestigation)
              .toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.search_rounded, color: AppColors.info, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Credit Investigation', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text('${ciAssignments.length} assignment${ciAssignments.length != 1 ? 's' : ''}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13)),
              ),
              Expanded(
                child: ciAssignments.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No CI Assignments',
                        subtitle: 'Your credit investigation tasks will appear here',
                        isGlass: true,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                        itemCount: ciAssignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _CiCard(assignment: ciAssignments[i]),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_search_rounded, color: AppColors.info, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(assignment.lenderName ?? 'Unknown Lender', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(assignment.collectionDate.toDisplayDate, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
              ])),
              StatusChip.assignmentStatus(assignment.status.value, small: true),
            ]),
            if (assignment.lenderAddress != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(assignment.lenderAddress!, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ],
            if (assignment.notes != null) ...[
              const SizedBox(height: 8),
              Text('Notes: ${assignment.notes}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12, fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.info),
              const SizedBox(width: 6),
              Text('Loan Amount:', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
              const SizedBox(width: 4),
              Text(assignment.amountToCollect.toPeso, style: GoogleFonts.jetBrainsMono(color: AppColors.info, fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 18),
            ]),
          ],
        ),
      ),
    );
  }
}