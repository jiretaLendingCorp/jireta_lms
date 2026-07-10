// lib/features/rider/screens/notifications/rider_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../data/rider_repository.dart';
import '../../providers/rider_providers.dart';

class RiderNotificationsScreen extends ConsumerWidget {
  const RiderNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(riderNotificationsProvider);

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
                          await RiderRepository().markAllNotificationsRead();
                          ref.invalidate(riderNotificationsProvider);
                        },
                        child: const Text('Mark all read',
                            style: TextStyle(
                                color: AppColors.riderAccent, fontSize: 13)),
                      )
                    : const SizedBox.shrink(),
              ],
            ),
          ),
          Expanded(
            child: notifsAsync.when(
              loading: () => ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
                    subtitle: 'No new notifications',
                    isGlass: false,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final n = notifs[i];
                    return _NotifTile(
                      notif: n,
                      onTap: () async {
                        if (!n.isRead) {
                          await RiderRepository().markNotificationRead(n.id);
                          ref.invalidate(riderNotificationsProvider);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (notif.isRead
                      ? const Color(0xFF9CA3AF)
                      : AppColors.riderAccent)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.notifications_rounded,
              size: 18,
              color: notif.isRead
                  ? const Color(0xFF9CA3AF)
                  : AppColors.riderAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: TextStyle(
                    color: const Color(0xFF1F2937),
                    fontWeight:
                        notif.isRead ? FontWeight.w400 : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (notif.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(notif.body,
                      style: const TextStyle(
                          color: Color(0xFF6B7280), fontSize: 12)),
                ],
                const SizedBox(height: 4),
                Text(notif.createdAt.toDisplayDate,
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 11)),
              ],
            ),
          ),
          if (!notif.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: AppColors.riderAccent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}