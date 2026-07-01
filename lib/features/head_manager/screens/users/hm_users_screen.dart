// lib/features/head_manager/screens/users/hm_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../providers/hm_providers.dart';

class HmUsersScreen extends ConsumerStatefulWidget {
  const HmUsersScreen({super.key});

  @override
  ConsumerState<HmUsersScreen> createState() => _HmUsersScreenState();
}

class _HmUsersScreenState extends ConsumerState<HmUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _roles = ['all', 'head_manager', 'employee', 'rider', 'lender'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _roles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    // Null default forces the head manager to explicitly pick a role --
    // no silently-created accounts because a default was left in place.
    final roleNotifier = ValueNotifier<String?>(null);
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(AppIcons.userPlus, color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Create New User',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(AppIcons.close, size: 18),
                          onPressed: () => Navigator.pop(ctx, false),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Role selector
                    ValueListenableBuilder<String?>(
                      valueListenable: roleNotifier,
                      builder: (_, role, __) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Role',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: context.isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 7),
                          DropdownButtonFormField<String>(
                            initialValue: role,
                            decoration: const InputDecoration(
                              hintText: 'Select a role',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'head_manager', child: Text('Head Manager')),
                              DropdownMenuItem(value: 'employee', child: Text('Employee')),
                              DropdownMenuItem(value: 'rider', child: Text('Rider')),
                              DropdownMenuItem(value: 'lender', child: Text('Lender')),
                            ],
                            validator: (v) => v == null ? 'Please select a role' : null,
                            onChanged: (v) => roleNotifier.value = v,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Name row
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            label: 'First Name',
                            hint: 'Juan',
                            controller: firstCtrl,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            prefixIcon: const Icon(AppIcons.user, size: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            label: 'Last Name',
                            hint: 'Dela Cruz',
                            controller: lastCtrl,
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      label: 'Email Address',
                      hint: 'user@jiretaloans.com',
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(AppIcons.email, size: 16),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (!v.isValidEmail) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    AppTextField(
                      label: 'Phone Number',
                      hint: '09XXXXXXXXX',
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon: const Icon(AppIcons.phone, size: 16),
                      validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        if (!v.isValidPhone) return 'Invalid PH number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: 'Create User',
                          icon: AppIcons.userPlus,
                          isLoading: loading,
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            // formKey.validate() above enforces role != null
                            // via the dropdown's validator.
                            final selectedRole = roleNotifier.value!;
                            setSt(() => loading = true);
                            final err = await ref.read(hmUsersNotifierProvider.notifier).createUser(
                              role: selectedRole,
                              firstName: firstCtrl.text.trim(),
                              lastName: lastCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            );
                            setSt(() => loading = false);
                            if (err != null && ctx.mounted) {
                              context.showSnack(err, isError: true);
                            } else if (ctx.mounted) {
                              Navigator.pop(ctx, true);
                            }
                          },
                          size: AppButtonSize.md,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      context.showSnack('User created successfully!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surfaceColor = isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight;
    final borderColor = isDark ? AppColors.webBorderDark : AppColors.webBorderLight;

    return Column(
      children: [
        Container(
          color: surfaceColor,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w400),
                  tabs: _roles.map((r) => Tab(
                    text: r == 'all' ? 'All Users' : r.snakeToLabel,
                  )).toList(),
                ),
              ),
              const SizedBox(width: 12),
              AppButton(
                label: 'Create User',
                icon: AppIcons.userPlus,
                size: AppButtonSize.sm,
                onPressed: _createUser,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _roles.map((r) => _UserList(role: r)).toList(),
          ),
        ),
      ],
    );
  }
}

class _UserList extends ConsumerWidget {
  final String role;
  const _UserList({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(hmUsersProvider(role));
    final isDark = context.isDark;

    return usersAsync.when(
      loading: () => const _LoadingUsers(),
      error: (e, _) => ErrorState(message: e.toString()),
      data: (users) {
        if (users.isEmpty) {
          return EmptyState(
            icon: AppIcons.users,
            title: 'No users found',
            subtitle: role == 'all'
                ? 'No users in the system yet.'
                : 'No ${role.snakeToLabel.toLowerCase()}s found.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _UserCard(user: users[i], isDark: isDark),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isDark;
  const _UserCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role.value);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.webBorderDark : AppColors.webBorderLight,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/hm/users/${user.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              AppAvatar(
                imageUrl: user.avatarUrl,
                name: user.displayName,
                size: 40,
                backgroundColor: roleColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isNotEmpty ? user.email : (user.phone ?? '—'),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.role.value.snakeToLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: roleColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                AppIcons.chevronRight,
                size: 16,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'head_manager': return AppColors.accent;
      case 'employee': return AppColors.info;
      case 'rider': return AppColors.riderAccent;
      case 'lender': return AppColors.lenderAccent;
      default: return AppColors.textSecondaryLight;
    }
  }
}

class _LoadingUsers extends StatelessWidget {
  const _LoadingUsers();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        height: 70,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ShimmerBox(width: 40, height: 40, radius: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBox(width: 160, height: 13, radius: 4),
                  const SizedBox(height: 7),
                  ShimmerBox(width: 220, height: 11, radius: 4),
                ],
              ),
            ),
            ShimmerBox(width: 70, height: 24, radius: 12),
          ],
        ),
      ),
    );
  }
}