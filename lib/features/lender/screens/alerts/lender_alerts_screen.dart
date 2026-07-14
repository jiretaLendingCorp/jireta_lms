// lib/features/lender/screens/alerts/lender_alerts_screen.dart
//
// Premium Material 3 redesign with:
//  • Glass shimmer loading (isGlass: true) + glass empty state
//  • Category-tinted notification cards with leading colored icon tile
//  • Animated unread pill + "Mark all read" pill button
//  • Subtle accent line on unread cards
//
// Business logic (provider, mark-read calls) is unchanged.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../providers/lender_providers.dart';

const _accent = AppColors.lenderAccent;

class LenderAlertsScreen extends ConsumerWidget {
  const LenderAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(lenderNotificationsProvider);
    final hasUnread =
        notifsAsync.whenData((n) => n.any((x) => !x.isRead)).value == true;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasUnread
                            ? 'You have unread alerts'
                            : "You're all caught up",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: hasUnread
                      ? _MarkAllReadPill(
                          key: const ValueKey('mark-all'),
                          onTap: () async {
                            await ref
                                .read(lenderRepositoryProvider)
                                .markAllNotificationsRead();
                            ref.invalidate(lenderNotificationsProvider);
                          },
                        )
                      : const SizedBox.shrink(
                          key: ValueKey('mark-all-none'),
                        ),
                ),
              ],
            ),
          ),

          Expanded(
            child: notifsAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const ShimmerCard(
                  height: 80,
                  padding: EdgeInsets.all(14),
                  isGlass: true,
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.alertCircle,
                            color: AppColors.error, size: 32),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$e',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (notifs) {
                if (notifs.isEmpty) {
                  return const EmptyState(
                    icon: AppIcons.bell,
                    title: "You're all caught up!",
                    subtitle:
                        'Notifications about your loans, payments,\nand KYC status will show up here.',
                    isGlass: true,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _NotifCard(
                    notif: notifs[i],
                    onTap: () async {
                      if (!notifs[i].isRead) {
                        await ref
                            .read(lenderRepositoryProvider)
                            .markNotificationRead(notifs[i].id);
                        ref.invalidate(lenderNotificationsProvider);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mark All Read Pill ────────────────────────────────────────────────────────

class _MarkAllReadPill extends StatelessWidget {
  final VoidCallback onTap;
  const _MarkAllReadPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accent.withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.check, color: _accent, size: 14),
              SizedBox(width: 5),
              Text(
                'Mark all read',
                style: TextStyle(
                  color: _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Notification Card ─────────────────────────────────────────────────────────

class _NotifCard extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback? onTap;
  const _NotifCard({required this.notif, this.onTap});

  Color _color() {
    switch (notif.category) {
      case NotificationCategory.loanApproved:
      case NotificationCategory.loanDisbursed:
      case NotificationCategory.paymentConfirmed:
        return AppColors.success;
      case NotificationCategory.loanRejected:
      case NotificationCategory.penaltyApplied:
      case NotificationCategory.paymentOverdue:
        return AppColors.error;
      case NotificationCategory.paymentDue:
        return AppColors.warning;
      default:
        return _accent;
    }
  }

  IconData _icon() {
    switch (notif.category) {
      case NotificationCategory.loanApproved:
        return AppIcons.checkCircle;
      case NotificationCategory.loanRejected:
        return AppIcons.xCircle;
      case NotificationCategory.loanDisbursed:
        return AppIcons.send;
      case NotificationCategory.paymentConfirmed:
        return AppIcons.receipt;
      case NotificationCategory.paymentDue:
        return AppIcons.clock;
      case NotificationCategory.paymentOverdue:
        return AppIcons.warning;
      case NotificationCategory.penaltyApplied:
        return AppIcons.alertCircle;
      default:
        return AppIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      backgroundColor: notif.isRead
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.14),
      borderColor: notif.isRead
          ? Colors.white.withValues(alpha: 0.10)
          : color.withValues(alpha: 0.32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.32)),
            ),
            child: Icon(_icon(), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                              notif.isRead ? FontWeight.w500 : FontWeight.w700,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (!notif.isRead) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.5),
                              blurRadius: 6,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif.body,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      AppIcons.clock,
                      size: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notif.createdAt.toRelative,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
