// lib/features/lender/screens/alerts/lender_alerts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/lender_providers.dart';

class LenderAlertsScreen extends ConsumerWidget {
  const LenderAlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(lenderNotificationsProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Text('Notifications',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: notifsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.white70))),
              data: (notifs) {
                if (notifs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: "You're all caught up!",
                    isGlass: true,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _NotifCard(notif: notifs[i]),
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
  const _NotifCard({required this.notif});

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
      case NotificationCategory.loanApproved: return Icons.check_circle_outline;
      case NotificationCategory.loanRejected: return Icons.cancel_outlined;
      case NotificationCategory.loanDisbursed: return Icons.send_rounded;
      case NotificationCategory.paymentConfirmed: return Icons.payment_rounded;
      case NotificationCategory.paymentDue: return Icons.schedule_rounded;
      case NotificationCategory.paymentOverdue: return Icons.warning_amber_rounded;
      case NotificationCategory.penaltyApplied: return Icons.report_problem_outlined;
      default: return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return GlassCard(
      borderColor: notif.isRead ? null : color.withOpacity(0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon(), size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(notif.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14))),
                    if (!notif.isRead)
                      Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.lenderAccent,
                              shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(notif.body,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 13)),
                const SizedBox(height: 6),
                Text(notif.createdAt.toRelative,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}