// lib/features/head_manager/screens/notifications/hm_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../providers/hm_providers.dart';

class HmNotificationsScreen extends ConsumerWidget {
  const HmNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(hmNotificationsProvider);

    return notifsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (notifs) {
        if (notifs.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications',
            subtitle: 'You\'re all caught up!',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: notifs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _NotifCard(notif: notifs[i]),
        );
      },
    );
  }
}

class _NotifCard extends StatelessWidget {
  final NotificationModel notif;
  const _NotifCard({required this.notif});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(notif.category);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconFor(notif.category), size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: notif.isRead ? null : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif.body, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(notif.createdAt.toRelative, style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.loanApproved:
      case NotificationCategory.paymentConfirmed:
        return AppColors.success;
      case NotificationCategory.loanRejected:
      case NotificationCategory.penaltyApplied:
      case NotificationCategory.paymentOverdue:
        return AppColors.error;
      case NotificationCategory.paymentDue:
      case NotificationCategory.assignmentNew:
        return AppColors.warning;
      default:
        return AppColors.accent;
    }
  }

  IconData _iconFor(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.loanApproved:
        return Icons.check_circle_outline;
      case NotificationCategory.loanRejected:
        return Icons.cancel_outlined;
      case NotificationCategory.loanDisbursed:
        return Icons.send_rounded;
      case NotificationCategory.paymentConfirmed:
        return Icons.payment_rounded;
      case NotificationCategory.paymentDue:
      case NotificationCategory.paymentOverdue:
        return Icons.schedule_rounded;
      case NotificationCategory.penaltyApplied:
        return Icons.warning_amber_rounded;
      case NotificationCategory.assignmentNew:
        return Icons.assignment_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}