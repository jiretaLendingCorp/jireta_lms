// lib/features/employee/screens/notifications/emp_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../providers/emp_providers.dart';

class EmpNotificationsScreen extends ConsumerWidget {
  const EmpNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(empNotificationsProvider);
    return notifsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (notifs) {
        if (notifs.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications',
            subtitle: "You're all caught up!",
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: notifs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _NotifTile(notif: notifs[i]),
        );
      },
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  const _NotifTile({required this.notif});

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
                color: color.withOpacity(0.1),
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
                        child: Text(notif.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      if (!notif.isRead)
                        Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif.body,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Text(notif.createdAt.toRelative,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondaryLight)),
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
      case NotificationCategory.paymentConfirmed:
        return Icons.payment_rounded;
      case NotificationCategory.assignmentNew:
        return Icons.assignment_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }
}