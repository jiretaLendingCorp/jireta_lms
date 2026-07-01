// lib/features/lender/screens/profile/lender_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/data/auth_repository.dart';

class LenderProfileScreen extends ConsumerStatefulWidget {
  const LenderProfileScreen({super.key});

  @override
  ConsumerState<LenderProfileScreen> createState() =>
      _LenderProfileScreenState();
}

class _LenderProfileScreenState extends ConsumerState<LenderProfileScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _firstCtrl.text = user?.firstName ?? '';
    _lastCtrl.text = user?.lastName ?? '';
    _phoneCtrl.text = user?.phone ?? '';
    _addressCtrl.text = user?.address ?? '';
  }

  @override
  void dispose() {
    _firstCtrl.dispose(); _lastCtrl.dispose(); _phoneCtrl.dispose();
    _addressCtrl.dispose(); _oldPassCtrl.dispose(); _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource src) async {
    final file = await ImagePicker()
        .pickImage(source: src, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    final bytes = await file.readAsBytes();
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    final err = await AuthRepository()
        .uploadAvatar(userId, bytes, file.path.split('.').last);
    setState(() => _uploadingAvatar = false);
    if (mounted) {
      context.showSnack(err ?? 'Photo updated', isError: err != null);
      if (err == null) ref.read(authProvider.notifier).refreshProfile();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await AuthRepository().updateProfile({
      'first_name': _firstCtrl.text.trim(),
      'last_name': _lastCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
    });
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(err ?? 'Profile updated', isError: err != null);
      if (err == null) ref.read(authProvider.notifier).refreshProfile();
    }
  }

  Future<void> _changePass() async {
    if (_newPassCtrl.text != _confirmCtrl.text) {
      context.showSnack('Passwords do not match', isError: true); return;
    }
    setState(() => _saving = true);
    final err = await ref.read(authProvider.notifier)
        .changePassword(_oldPassCtrl.text, _newPassCtrl.text);
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(err ?? 'Password changed', isError: err != null);
      if (err == null) { _oldPassCtrl.clear(); _newPassCtrl.clear(); _confirmCtrl.clear(); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GlassCard(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      AppAvatar(imageUrl: user?.avatarUrl, name: user?.displayName ?? '', size: 80, backgroundColor: AppColors.lenderAccent),
                      GestureDetector(
                        onTap: () => _showOptions(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: AppColors.lenderAccent, shape: BoxShape.circle, border: Border.all(color: Colors.black26, width: 2)),
                          child: _uploadingAvatar
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                              : const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(user?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  Text(user?.email ?? '', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.lenderAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                        child: const Text('Lender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.lenderAccent)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => context.go(RouteConstants.lenderKyc),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero),
                        child: const Text('KYC Status', style: TextStyle(fontSize: 12, color: AppColors.lenderAccent)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: AppTextField(label: 'First Name', controller: _firstCtrl, isGlass: true, textCapitalization: TextCapitalization.words)),
                    const SizedBox(width: 10),
                    Expanded(child: AppTextField(label: 'Last Name', controller: _lastCtrl, isGlass: true, textCapitalization: TextCapitalization.words)),
                  ]),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Phone', controller: _phoneCtrl, isGlass: true, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Address', controller: _addressCtrl, isGlass: true, maxLines: 2, textCapitalization: TextCapitalization.sentences),
                  const SizedBox(height: 16),
                  AppButton(label: 'Save Changes', color: AppColors.lenderAccent, isLoading: _saving, onPressed: _save, width: double.infinity),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  AppTextField(label: 'Current Password', controller: _oldPassCtrl, isGlass: true, obscureText: true),
                  const SizedBox(height: 12),
                  AppTextField(label: 'New Password', controller: _newPassCtrl, isGlass: true, obscureText: true),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Confirm Password', controller: _confirmCtrl, isGlass: true, obscureText: true),
                  const SizedBox(height: 16),
                  AppButton(label: 'Change Password', color: AppColors.lenderAccent, isLoading: _saving, onPressed: _changePass, width: double.infinity),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                icon: const Icon(Icons.logout, color: AppColors.error, size: 18),
                label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ListTile(leading: const Icon(Icons.camera_alt_outlined, color: Colors.white), title: const Text('Camera', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _pickAvatar(ImageSource.camera); }),
            ListTile(leading: const Icon(Icons.photo_library_outlined, color: Colors.white), title: const Text('Gallery', style: TextStyle(color: Colors.white)), onTap: () { Navigator.pop(context); _pickAvatar(ImageSource.gallery); }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}