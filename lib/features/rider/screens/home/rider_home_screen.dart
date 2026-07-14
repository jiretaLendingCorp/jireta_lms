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

    final bottomPad = MediaQuery.of(context).padding.bottom + 100;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(user: user),
            const SizedBox(height: 22),

            // Stats row
            statsAsync.when(
              loading: () => Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                      child: const ShimmerCard(height: 104, isGlass: true),
                    ),
                  ),
                ),
              ),
              error: (_, __) =>
                  const _StatsRow(pending: 0, completed: 0, collected: 0),
              data: (stats) => _StatsRow(
                pending: (stats['pending_count'] as num?)?.toInt() ?? 0,
                completed: (stats['completed_count'] as num?)?.toInt() ?? 0,
                collected: (stats['total_collected'] as num?)?.toDouble() ?? 0,
              ),
            ),
            const SizedBox(height: 28),

            // Today's assignments section header
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.riderAccent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.riderAccent.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'View all',
                          style: TextStyle(
                            color: AppColors.riderAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          AppIcons.chevronRight,
                          color: AppColors.riderAccent,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            assignmentsAsync.when(
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ShimmerCard(height: 86, isGlass: true),
                  ),
                ),
              ),
              error: (e, _) => WhiteCard(
                isGlass: true,
                child: Text(
                  'Unable to load assignments.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
              data: (assignments) {
                final today =
                    assignments.where((a) => a.collectionDate.isToday).toList();
                if (today.isEmpty) {
                  return _EmptyTodayCard(
                    onCTA: () => context.go(RouteConstants.riderAssignments),
                  );
                }
                return AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: Column(
                    children: today
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _AssignmentTile(assignment: a),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),

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
            const SizedBox(height: 24),
            _LifetimeStats(),
          ],
        ),
      ),
    );
  }
}

// ── Empty Today Card ───────────────────────────────────────────────────────────

class _EmptyTodayCard extends StatelessWidget {
  final VoidCallback onCTA;
  const _EmptyTodayCard({required this.onCTA});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      isGlass: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.riderAccent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.riderAccent.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              AppIcons.checkCircle,
              color: AppColors.riderAccent,
              size: 30,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'All clear for today!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No collection assignments scheduled today.\nEnjoy your downtime or check all assignments.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          AppTextButton(
            label: 'Browse all assignments',
            icon: AppIcons.arrowRight,
            color: AppColors.riderAccent,
            onPressed: onCTA,
          ),
        ],
      ),
    );
  }
}

// ── Lifetime Stats ─────────────────────────────────────────────────────────────

class _LifetimeStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(riderLifetimeStatsProvider);
    return statsAsync.when(
      loading: () => const ShimmerCard(height: 240, isGlass: true),
      error: (_, __) => const SizedBox.shrink(),
      data: (s) {
        if ((s['total_assignments'] as int? ?? 0) == 0) {
          return const SizedBox.shrink();
        }
        final completionRate =
            ((s['completion_rate'] as num?)?.toDouble() ?? 0);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          child: WhiteCard(
            key: const ValueKey('lifetime-stats'),
            isGlass: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.riderAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bar_chart_rounded,
                          color: AppColors.riderAccent, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('Lifetime Summary',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),
                _SRow('Total Assignments', '${s['total_assignments']}'),
                _SRow('Completed', '${s['completed']}'),
                _SRow('Credit Investigations', '${s['credit_investigations']}'),
                _SRow('Collections Done', '${s['collections']}'),
                _SRow('Failed', '${s['failed']}'),
                _SRow(
                    'Completion Rate', '${completionRate.toStringAsFixed(1)}%'),
                _SRow(
                  'Total Collected',
                  '₱${((s['total_collected'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                  isLast: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _SRow(this.label, this.value, {this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                  fontWeight: FontWeight.w400)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
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
              const SizedBox(height: 2),
              Text(
                DateTime.now().toDisplayDate,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.go(RouteConstants.riderNotifications),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(AppIcons.notifications,
                color: Colors.white, size: 20),
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
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Done',
            value: '$completed',
            icon: AppIcons.checkCircle,
            color: AppColors.riderAccent,
          ),
        ),
        const SizedBox(width: 12),
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

class _StatCard extends StatefulWidget {
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
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: WhiteCard(
          isGlass: true,
          borderRadius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: widget.color, size: 16),
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(widget.value,
                    style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 3),
              Text(widget.label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 11,
                      fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
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
    return WhiteCard(
      isGlass: true,
      padding: const EdgeInsets.all(14),
      onTap: () => context.go('/rider/assignments/${assignment.id}'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.riderAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.riderAccent.withValues(alpha: 0.22),
              ),
            ),
            child: const Icon(AppIcons.mapPin,
                color: AppColors.riderAccent, size: 18),
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
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      AppIcons.mapPin,
                      size: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        assignment.lenderAddress ?? 'No address',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.60),
                            fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
                    fontWeight: FontWeight.w700),
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
