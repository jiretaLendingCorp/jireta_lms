// lib/features/lender/screens/alerts/lender_alerts_screen.dart
//
// FIX #4 + #6:
//  - Converted WhiteCard → GlassCard (glassmorphism).
//  - All text colors changed to white/light so content is visible on dark bg.
//  - "BOTTOM OVERFLOWED BY 70px" was caused by _NotifCard's Row not having
//    mainAxisSize: MainAxisSize.min on its inner Column — the Column was
//    trying to expand infinitely inside the Row. Fixed with mainAxisSize.min.
//  - Added extra bottom padding on the ListView to clear the nav bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../data/lender_repository.dart';
import '../../providers/lender_providers.dart';

class LenderAlertsScreen extends ConsumerWidget {
  const LenderAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(lenderNotificationsProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Notifications',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                notifsAsync.whenData((n) => n.any((x) => !x.isRead)).value ==
                        true
                    ? TextButton(
                        onPressed: () async {
                          await LenderRepository()
                              .markAllNotificationsRead();
                          ref.invalidate(lenderNotificationsProvider);
                        },
                        child: const Text('Mark all read',
                            style: TextStyle(
                                color: AppColors.lenderAccent,
                                fontSize: 13)),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
          Expanded(
            child: notifsAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, __) => const ShimmerCard(height: 72),
              ),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.white70))),
              data: (notifs) {
                if (notifs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: "You're all caught up!",
                    isGlass: false,
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
                        await LenderRepository()
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
        return AppColors.lenderAccent;
    }
  }

  IconData _icon() {
    switch (notif.category) {
      case NotificationCategory.loanApproved:
        return Icons.check_circle_outline;
      case NotificationCategory.loanRejected:
        return Icons.cancel_outlined;
      case NotificationCategory.loanDisbursed:
        return Icons.send_rounded;
      case NotificationCategory.paymentConfirmed:
        return Icons.payment_rounded;
      case NotificationCategory.paymentDue:
        return Icons.schedule_rounded;
      case NotificationCategory.paymentOverdue:
        return Icons.warning_amber_rounded;
      case NotificationCategory.penaltyApplied:
        return Icons.report_problem_outlined;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      // FIX: Reduced backgroundColor opacity to show unread indicator
      backgroundColor: notif.isRead
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.13),
      child: Row(
        // FIX: crossAxisAlignment.start so long body text doesn't force
        // the icon container to stretch and overflow
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          // FIX: Expanded wraps the Column so it doesn't overflow the Row.
          // The Column itself uses mainAxisSize.min so it only takes the
          // height it needs — this prevents the 70px overflow.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(
                      notif.title,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: notif.isRead
                              ? FontWeight.w400
                              : FontWeight.w600,
                          fontSize: 14),
                    )),
                    if (!notif.isRead)
                      Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: const BoxDecoration(
                              color: AppColors.lenderAccent,
                              shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif.body,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  notif.createdAt.toRelative,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}