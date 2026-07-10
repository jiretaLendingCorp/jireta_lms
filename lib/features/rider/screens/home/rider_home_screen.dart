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

    final bottomPad = MediaQuery.of(context).padding.bottom + 100;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(user: user),
            const SizedBox(height: 20),

            // Stats row
            statsAsync.when(
              loading: () => Row(
                children: List.generate(3, (i) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                    child: const ShimmerCard(height: 90),
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
            const SizedBox(height: 24),

            // Today's assignments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Assignments",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go(RouteConstants.riderAssignments),
                  child: const Text(
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
                children: List.generate(3, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: ShimmerCard(height: 80),
                )),
              ),
              error: (e, _) => _WhiteCard(
                child: Text(
                  'Unable to load assignments.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              data: (assignments) {
                final today = assignments
                    .where((a) => a.collectionDate.isToday)
                    .toList();
                if (today.isEmpty) {
                  return _WhiteCard(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.riderAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            AppIcons.checkCircle,
                            color: AppColors.riderAccent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'All clear for today!',
                          style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No collection assignments today.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
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
            const SizedBox(height: 16),

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
            const SizedBox(height: 20),
            _LifetimeStats(),
          ],
        ),
      ),
    );
  }
}

// ── White Card (replaces GlassCard for rider/lender) ──────────────────────────

class _WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  const _WhiteCard({required this.child, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}

// ── Lifetime Stats ─────────────────────────────────────────────────────────────

class _LifetimeStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(riderLifetimeStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if ((s['total_assignments'] as int? ?? 0) == 0) return const SizedBox.shrink();
        return _WhiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: AppColors.riderAccent, size: 18),
                  SizedBox(width: 8),
                  Text('Lifetime Summary',
                      style: TextStyle(color: Color(0xFF1F2937), fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 14),
              _SRow('Total Assignments', '${s['total_assignments']}'),
              _SRow('Completed', '${s['completed']}'),
              _SRow('Credit Investigations', '${s['credit_investigations']}'),
              _SRow('Collections Done', '${s['collections']}'),
              _SRow('Failed', '${s['failed']}'),
              _SRow('Completion Rate',
                  '${((s['completion_rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%'),
              _SRow('Total Collected',
                  '₱${((s['total_collected'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
            ],
          ),
        );
      },
    );
  }
}

class _SRow extends StatelessWidget {
  final String label;
  final String value;
  const _SRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Text(value,
              style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

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
                style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.go(RouteConstants.riderNotifications),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(AppIcons.notifications, color: Colors.white, size: 20),
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
  const _StatsRow({required this.pending, required this.completed, required this.collected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Pending', value: '$pending', icon: AppIcons.clock, color: AppColors.warning)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Done', value: '$completed', icon: AppIcons.checkCircle, color: AppColors.riderAccent)),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Collected', value: collected.toPesoCompact, icon: AppIcons.coins, color: AppColors.success)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: GoogleFonts.jetBrainsMono(color: const Color(0xFF1F2937), fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Assignment Tile ────────────────────────────────────────────────────────────

class _AssignmentTile extends StatelessWidget {
  final AssignmentModel assignment;
  const _AssignmentTile({required this.assignment});

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/rider/assignments/${assignment.id}'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.riderAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(AppIcons.mapPin, color: AppColors.riderAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment.lenderName ?? 'Unknown',
                  style: const TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  assignment.lenderAddress ?? 'No address',
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
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
                style: GoogleFonts.jetBrainsMono(color: AppColors.riderAccent, fontSize: 13, fontWeight: FontWeight.w700),
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