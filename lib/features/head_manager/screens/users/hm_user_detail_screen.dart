// lib/features/head_manager/screens/users/hm_user_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/confirmation_dialog.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/hm_providers.dart';

class HmUserDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const HmUserDetailScreen({super.key, required this.id});

  @override
  ConsumerState<HmUserDetailScreen> createState() =>
      _HmUserDetailScreenState();
}

class _HmUserDetailScreenState extends ConsumerState<HmUserDetailScreen> {
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(hmUserDetailProvider(widget.id));

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (user) => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                    imageUrl: user.avatarUrl,
                    name: user.displayName,
                    size: 64),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: Theme.of(context).textTheme.displayMedium),
                      Text(user.email,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          StatusChip(
                            label: user.role.value.replaceAll('_', ' ').titleCase,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 8),
                          StatusChip(
                            label: user.isActive ? 'Active' : 'Inactive',
                            color: user.isActive ? AppColors.success : AppColors.error,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AppButton(
                  label: user.isActive ? 'Deactivate' : 'Reactivate',
                  isDanger: user.isActive,
                  isOutlined: true,
                  isLoading: _acting,
                  onPressed: () async {
                    final ok = await ConfirmationDialog.show(
                      context,
                      title: user.isActive ? 'Deactivate User' : 'Reactivate User',
                      message: 'Are you sure you want to ${user.isActive ? 'deactivate' : 'reactivate'} ${user.displayName}?',
                      isDanger: user.isActive,
                    );
                    if (ok != true) return;
                    setState(() => _acting = true);
                    final res = await ref.read(hmRepositoryProvider).updateUser(
                      user.id,
                      {'is_active': !user.isActive},
                    );
                    setState(() => _acting = false);
                    if (context.mounted) {
                      if (res.success) {
                        context.showSnack('User updated');
                        ref.invalidate(hmUserDetailProvider(widget.id));
                        ref.invalidate(hmUsersProvider('all'));
                      } else {
                        context.showSnack(res.error!, isError: true);
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profile Info',
                              style: Theme.of(context).textTheme.headlineLarge),
                          const SizedBox(height: 16),
                          _InfoRow('Phone', user.phone ?? '-'),
                          _InfoRow('Address', user.address ?? '-'),
                          _InfoRow('Employer', user.employer ?? '-'),
                          _InfoRow('Member Since',
                              user.createdAt.toDisplayDate),
                          if (user.creditScore != null)
                            _InfoRow('Credit Score',
                                user.creditScore!.toStringAsFixed(0)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }
}