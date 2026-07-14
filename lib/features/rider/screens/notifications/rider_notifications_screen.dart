// lib/features/rider/screens/notifications/rider_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_icons.dart';
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.riderAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.riderAccent.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Icon(AppIcons.bell,
                      color: AppColors.riderAccent, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Notifications',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3)),
              ],
            ),
          ),
          // Mark-all-read action
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                notifsAsync.whenData((n) => n.any((x) => !x.isRead)).value ==
                        true
                    ? GestureDetector(
                        onTap: () async {
                          await RiderRepository().markAllNotificationsRead();
                          ref.invalidate(riderNotificationsProvider);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                AppColors.riderAccent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  AppColors.riderAccent.withValues(alpha: 0.30),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(AppIcons.checkCircle,
                                  color: AppColors.riderAccent, size: 14),
                              SizedBox(width: 6),
                              Text('Mark all read',
                                  style: TextStyle(
                                      color: AppColors.riderAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
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
                itemBuilder: (_, __) =>
                    const ShimmerCard(height: 76, isGlass: true),
              ),
              error: (e, _) => Center(
                  child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              )),
              data: (notifs) {
                if (notifs.isEmpty) {
                  return const EmptyState(
                    icon: AppIcons.bellOff,
                    title: "You're all caught up!",
                    subtitle: 'No new notifications',
                    isGlass: true,
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
    final accent = notif.isRead
        ? Colors.white.withValues(alpha: 0.55)
        : AppColors.riderAccent;
    return GlassCard(
      backgroundColor: notif.isRead
          ? Colors.white.withValues(alpha: 0.08)
          : AppColors.riderAccent.withValues(alpha: 0.10),
      borderColor: notif.isRead
          ? Colors.white.withValues(alpha: 0.14)
          : AppColors.riderAccent.withValues(alpha: 0.30),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              AppIcons.bell,
              size: 16,
              color: accent,
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
                    color: Colors.white,
                    fontWeight:
                        notif.isRead ? FontWeight.w500 : FontWeight.w700,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
                if (notif.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(AppIcons.clock,
                        size: 11, color: Colors.white.withValues(alpha: 0.40)),
                    const SizedBox(width: 4),
                    Text(
                      notif.createdAt.toRelative,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!notif.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4, left: 6),
              decoration: BoxDecoration(
                color: AppColors.riderAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.riderAccent.withValues(alpha: 0.40),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
