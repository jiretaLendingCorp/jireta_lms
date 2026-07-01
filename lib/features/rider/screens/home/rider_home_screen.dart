// lib/features/rider/screens/home/rider_home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/assignment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/rider_providers.dart';

class RiderHomeScreen extends ConsumerWidget {
  const RiderHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final statsAsync = ref.watch(riderStatsProvider);
    final assignmentsAsync = ref.watch(riderAssignmentsProvider('pending'));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(user: user),
            const SizedBox(height: 24),

            // Stats row
            statsAsync.when(
              loading: () => Row(
                children: List.generate(3, (_) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ShimmerCard(height: 90, isGlass: true),
                  ),
                )),
              ),
              error: (_, __) => const _StatsRow(pending: 0, completed: 0, collected: 0),
              data: (stats) => _StatsRow(
                pending: (stats['pending_count'] as num?)?.toInt() ?? 0,
                completed: (stats['completed_count'] as num?)?.toInt() ?? 0,
                collected: (stats['total_collected'] as num?)?.toDouble() ?? 0,
              ),
            ),
            const SizedBox(height: 28),

            // Today's assignments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Assignments",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go(RouteConstants.riderAssignments),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      color: AppColors.riderAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            assignmentsAsync.when(
              loading: () => Column(
                children: List.generate(3, (_) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ShimmerCard(height: 80, isGlass: true),
                )),
              ),
              error: (e, _) => GlassCard(
                child: Text(
                  'Unable to load assignments.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                ),
              ),
              data: (assignments) {
                final today = assignments
                    .where((a) => a.collectionDate.isToday)
                    .toList();
                if (today.isEmpty) {
                  return GlassCard(
                    borderColor: AppColors.riderAccent.withOpacity(0.2),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.riderAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            AppIcons.checkCircle,
                            color: AppColors.riderAccent,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'All clear for today!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No collection assignments today.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: today
                      .map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AssignmentTile(assignment: a),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),

            // View all button
            AppButton(
              label: 'View All Assignments',
              icon: AppIcons.assignments,
              width: double.infinity,
              size: AppButtonSize.lg,
              color: AppColors.riderAccent,
              textColor: Colors.black87,
              onPressed: () => context.go(RouteConstants.riderAssignments),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final dynamic user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppAvatar(
          imageUrl: user?.avatarUrl,
          name: user?.displayName ?? '',
          size: 46,
          backgroundColor: AppColors.riderAccent,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, ${user?.firstName ?? ''}! 👋',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                DateTime.now().toDisplayDate,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        // Notification icon
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(
              AppIcons.notifications,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int pending;
  final int completed;
  final double collected;
  const _StatsRow({
    required this.pending,
    required this.completed,
    required this.collected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Pending',
            value: '$pending',
            icon: AppIcons.clock,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Completed',
            value: '$completed',
            icon: AppIcons.checkCircle,
            color: AppColors.riderAccent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Collected',
            value: collected.toPesoCompact,
            icon: AppIcons.coins,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assignment Tile ───────────────────────────────────────────────────────────

class _AssignmentTile extends StatelessWidget {
  final AssignmentModel assignment;
  const _AssignmentTile({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/rider/assignments/${assignment.id}'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.riderAccent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              AppIcons.mapPin,
              color: AppColors.riderAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.lenderName ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  assignment.lenderAddress ?? 'No address',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                assignment.amountToCollect.toPeso,
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.riderAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              StatusChip.assignmentStatus(assignment.status.value, small: true),
            ],
          ),
        ],
      ),
    );
  }
}