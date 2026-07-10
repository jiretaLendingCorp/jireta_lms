// lib/features/head_manager/screens/users/hm_user_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
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
  bool _editing = false;

  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _startEditing(AppUser user) {
    _firstCtrl.text = user.firstName;
    _lastCtrl.text = user.lastName;
    _phoneCtrl.text = user.phone ?? '';
    _addressCtrl.text = user.address ?? '';
    setState(() => _editing = true);
  }

  Future<void> _saveEdits() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _acting = true);
    final err = await ref.read(hmUsersNotifierProvider.notifier).updateUser(
      widget.id,
      {
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      },
    );
    setState(() { _acting = false; _editing = false; });
    if (mounted) {
      context.showSnack(err ?? 'User updated', isError: err != null);
    }
  }

  Future<void> _resetPassword() async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Reset Password',
      message: 'Reset this user\'s password to the default "12345678"? They will be required to change it on next login.',
      isDanger: true,
      confirmLabel: 'Reset',
    );
    if (ok != true || !mounted) return;
    setState(() => _acting = true);
    final err = await ref.read(hmUsersNotifierProvider.notifier).resetPassword(widget.id);
    setState(() => _acting = false);
    if (mounted) {
      context.showSnack(err ?? 'Password reset to 12345678', isError: err != null);
    }
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(hmUserDetailProvider(widget.id));
    final isDark = context.isDark;
    final border = isDark ? AppColors.webBorderDark : AppColors.webBorderLight;
    final surface = isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight;

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (user) => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header card ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppAvatar(imageUrl: user.avatarUrl, name: user.displayName, size: 72),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.fullName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(user.email, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 14)),
                            if (user.phone != null) ...[
                              const SizedBox(height: 2),
                              Text(user.phone!, style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 14)),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                StatusChip(label: user.role.value.snakeToLabel, color: _roleColor(user.role.value)),
                                const SizedBox(width: 8),
                                StatusChip(
                                  label: user.isActive ? 'Active' : 'Inactive',
                                  color: user.isActive ? AppColors.success : AppColors.error,
                                ),
                                if (user.forcePasswordChange) ...[
                                  const SizedBox(width: 8),
                                  const StatusChip(label: 'Must Change Password', color: AppColors.warning),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Edit Form ─────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('User Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (!_editing)
                              TextButton.icon(
                                icon: const Icon(AppIcons.edit, size: 15),
                                label: const Text('Edit'),
                                onPressed: () => _startEditing(user),
                              )
                            else
                              TextButton(
                                onPressed: () => setState(() => _editing = false),
                                child: const Text('Cancel'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'First Name',
                                controller: _editing ? _firstCtrl : (TextEditingController(text: user.firstName)),
                                enabled: _editing,
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppTextField(
                                label: 'Last Name',
                                controller: _editing ? _lastCtrl : (TextEditingController(text: user.lastName)),
                                enabled: _editing,
                                textCapitalization: TextCapitalization.words,
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'Phone',
                                controller: _editing ? _phoneCtrl : (TextEditingController(text: user.phone ?? '')),
                                enabled: _editing,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (v == null || v.isEmpty) return null;
                                  if (!v.isValidPhone) return 'Invalid PH number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: AppTextField(
                                label: 'Address',
                                controller: _editing ? _addressCtrl : (TextEditingController(text: user.address ?? '')),
                                enabled: _editing,
                                textCapitalization: TextCapitalization.sentences,
                              ),
                            ),
                          ],
                        ),
                        if (_editing) ...[
                          const SizedBox(height: 20),
                          AppButton(
                            label: 'Save Changes',
                            icon: AppIcons.checkCircle,
                            isLoading: _acting,
                            onPressed: _saveEdits,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Actions card ──────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Account Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          AppButton(
                            label: 'Reset Password',
                            icon: AppIcons.key,
                            isOutlined: true,
                            isLoading: _acting,
                            onPressed: _resetPassword,
                          ),
                          const SizedBox(width: 12),
                          AppButton(
                            label: user.isActive ? 'Deactivate Account' : 'Reactivate Account',
                            isDanger: user.isActive,
                            isOutlined: true,
                            isLoading: _acting,
                            onPressed: () async {
                              final scaffoldCtx = context;
                              final ok = await ConfirmationDialog.show(
                                scaffoldCtx,
                                title: user.isActive ? 'Deactivate User' : 'Reactivate User',
                                message: 'Are you sure you want to ${user.isActive ? 'deactivate' : 'reactivate'} ${user.displayName}?',
                                isDanger: user.isActive,
                              );
                              if (ok != true || !mounted) return;
                              setState(() => _acting = true);
                              final repo = ref.read(hmRepositoryProvider);
                              final res = await repo.deactivateUser(user.id);
                              if (!mounted) return;
                              setState(() => _acting = false);
                              if (!scaffoldCtx.mounted) return;
                              scaffoldCtx.showSnack(
                                res.success ? 'User ${user.isActive ? 'deactivated' : 'reactivated'}' : (res.error ?? 'Failed'),
                                isError: !res.success,
                              );
                              if (res.success) ref.invalidate(hmUserDetailProvider(widget.id));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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