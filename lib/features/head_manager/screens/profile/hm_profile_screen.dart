// lib/features/head_manager/screens/profile/hm_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../features/auth/data/auth_repository.dart';

class HmProfileScreen extends ConsumerStatefulWidget {
  const HmProfileScreen({super.key});

  @override
  ConsumerState<HmProfileScreen> createState() => _HmProfileScreenState();
}

class _HmProfileScreenState extends ConsumerState<HmProfileScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _firstCtrl.text = user?.firstName ?? '';
    _lastCtrl.text = user?.lastName ?? '';
    _phoneCtrl.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    final err = await AuthRepository().uploadAvatar(userId, bytes, ext);
    setState(() => _uploadingAvatar = false);
    if (mounted) {
      if (err == null) {
        context.showSnack('Avatar updated');
        ref.read(authProvider.notifier).refreshProfile();
      } else {
        context.showSnack(err, isError: true);
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final err = await AuthRepository().updateProfile({
      'first_name': _firstCtrl.text.trim(),
      'last_name': _lastCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    });
    setState(() => _saving = false);
    if (mounted) {
      if (err == null) {
        context.showSnack('Profile updated');
        ref.read(authProvider.notifier).refreshProfile();
      } else {
        context.showSnack(err, isError: true);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      context.showSnack('Passwords do not match', isError: true);
      return;
    }
    if (_newPassCtrl.text.length < 8) {
      context.showSnack('Password must be at least 8 characters', isError: true);
      return;
    }
    setState(() => _saving = true);
    final err = await ref.read(authProvider.notifier).changePassword(
          _oldPassCtrl.text,
          _newPassCtrl.text,
        );
    setState(() => _saving = false);
    if (mounted) {
      if (err == null) {
        context.showSnack('Password changed successfully');
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      } else {
        context.showSnack(err, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 280,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AppAvatar(
                          imageUrl: user?.avatarUrl,
                          name: user?.displayName ?? '',
                          size: 96,
                        ),
                        GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: _uploadingAvatar
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white)),
                                  )
                                : const Icon(Icons.camera_alt,
                                    size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(user?.fullName ?? '', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        user?.role.value.replaceAll('_', ' ').titleCase ?? '',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _InfoRow('Member Since', user?.createdAt.toDisplayDate ?? '-'),
                    _InfoRow('Status', user?.isActive == true ? 'Active' : 'Inactive'),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Profile', style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: AppTextField(label: 'First Name', controller: _firstCtrl, textCapitalization: TextCapitalization.words)),
                            const SizedBox(width: 12),
                            Expanded(child: AppTextField(label: 'Last Name', controller: _lastCtrl, textCapitalization: TextCapitalization.words)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        AppTextField(label: 'Phone', controller: _phoneCtrl, keyboardType: TextInputType.phone),
                        const SizedBox(height: 20),
                        AppButton(label: 'Save Profile', isLoading: _saving, onPressed: _saveProfile, width: double.infinity),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change Password', style: Theme.of(context).textTheme.headlineLarge),
                        const SizedBox(height: 20),
                        AppTextField(label: 'Current Password', controller: _oldPassCtrl, obscureText: true),
                        const SizedBox(height: 12),
                        AppTextField(label: 'New Password', controller: _newPassCtrl, obscureText: true),
                        const SizedBox(height: 12),
                        AppTextField(label: 'Confirm New Password', controller: _confirmPassCtrl, obscureText: true),
                        const SizedBox(height: 20),
                        AppButton(label: 'Change Password', isLoading: _saving, onPressed: _changePassword, width: double.infinity),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}