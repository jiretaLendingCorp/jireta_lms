// lib/features/rider/screens/profile/rider_profile_screen.dart
// Fixed: collapsible sections, working avatar upload, white card design on gradient bg.
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/data/auth_repository.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RiderProfileScreen extends ConsumerStatefulWidget {
  const RiderProfileScreen({super.key});
  @override
  ConsumerState<RiderProfileScreen> createState() => _RiderProfileScreenState();
}

class _RiderProfileScreenState extends ConsumerState<RiderProfileScreen>
    with SingleTickerProviderStateMixin {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _showEditProfile = false;
  bool _showChangePassword = false;

  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _animCtrl.forward();
    final user = ref.read(authProvider).user;
    _firstCtrl.text = user?.firstName ?? '';
    _lastCtrl.text = user?.lastName ?? '';
    _phoneCtrl.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource src) async {
    final file = await ImagePicker().pickImage(
        source: src, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null) return;
    setState(() => _uploadingAvatar = true);
    final bytes = await file.readAsBytes();
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) {
      setState(() => _uploadingAvatar = false);
      return;
    }
    final err = await AuthRepository()
        .uploadAvatar(userId, bytes, file.path.split('.').last);
    setState(() => _uploadingAvatar = false);
    if (mounted) {
      context.showSnack(err ?? 'Profile photo updated', isError: err != null);
      if (err == null) ref.read(authProvider.notifier).refreshProfile();
    }
  }

  void _showAvatarPicker() {
    if (kIsWeb) {
      _pickAvatar(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take Photo'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _pickAvatar(ImageSource.camera);
            }),
        ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(sheetCtx);
              _pickAvatar(ImageSource.gallery);
            }),
        const SizedBox(height: 8),
      ])),
    );
  }

  Future<void> _saveProfile() async {
    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) {
      context.showSnack('First and last name are required', isError: true);
      return;
    }
    setState(() => _saving = true);
    final err = await AuthRepository().updateProfile({
      'first_name': _firstCtrl.text.trim(),
      'last_name': _lastCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    });
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(err ?? 'Profile updated', isError: err != null);
      if (err == null) {
        ref.read(authProvider.notifier).refreshProfile();
        setState(() => _showEditProfile = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (_newPassCtrl.text.length < 8) {
      context.showSnack('Password must be at least 8 characters',
          isError: true);
      return;
    }
    if (_newPassCtrl.text != _confirmCtrl.text) {
      context.showSnack('Passwords do not match', isError: true);
      return;
    }
    setState(() => _saving = true);
    final err = await AuthRepository()
        .changePassword(_oldPassCtrl.text, _newPassCtrl.text);
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(err ?? 'Password changed', isError: err != null);
      if (err == null) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmCtrl.clear();
        setState(() => _showChangePassword = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 24, 20, MediaQuery.of(context).padding.bottom + 100),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(children: [
                  AppAvatar(
                      imageUrl: user?.avatarUrl,
                      name: user?.displayName ?? '',
                      size: 80,
                      backgroundColor: AppColors.riderAccent),
                  Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                            color: AppColors.riderAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: _uploadingAvatar
                            ? const Padding(
                                padding: EdgeInsets.all(6),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt_rounded,
                                size: 14, color: Colors.white),
                      )),
                ]),
              ),
              const SizedBox(height: 8),
              Text(user?.displayName ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(user?.email ?? '',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Badge('Rider', AppColors.riderAccent),
                const SizedBox(width: 8),
                _Badge(user?.isActive == true ? 'Active' : 'Inactive',
                    user?.isActive == true ? Colors.green : Colors.red),
              ]),
              const SizedBox(height: 24),

              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.20))),
                child: Column(children: [
                  _InfoRow('Account ID',
                      user?.id.substring(0, 8).toUpperCase() ?? '—'),
                  const Divider(height: 16),
                  _InfoRow('Joined', user?.createdAt.toDisplayDate ?? '—'),
                  if (user?.phone != null) ...[
                    const Divider(height: 16),
                    _InfoRow('Phone', user!.phone!)
                  ],
                  if (user?.address != null) ...[
                    const Divider(height: 16),
                    _InfoRow('Address', user!.address!)
                  ],
                ]),
              ),
              const SizedBox(height: 12),

              // Collapsible: Edit Profile
              _CollapsibleCard(
                icon: Icons.edit_outlined,
                title: 'Edit Profile',
                accentColor: AppColors.riderAccent,
                isOpen: _showEditProfile,
                onToggle: () =>
                    setState(() => _showEditProfile = !_showEditProfile),
                child: Column(children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: AppTextField(
                            label: 'First Name',
                            controller: _firstCtrl,
                            maxLength: 50,
                            textCapitalization: TextCapitalization.words)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: AppTextField(
                            label: 'Last Name',
                            controller: _lastCtrl,
                            maxLength: 50,
                            textCapitalization: TextCapitalization.words)),
                  ]),
                  const SizedBox(height: 12),
                  AppTextField(
                      label: 'Phone',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      hint: '09XXXXXXXXX'),
                  const SizedBox(height: 14),
                  AppButton(
                      label: 'Save Changes',
                      isLoading: _saving,
                      onPressed: _saveProfile,
                      width: double.infinity),
                ]),
              ),
              const SizedBox(height: 10),

              // Collapsible: Change Password
              _CollapsibleCard(
                icon: Icons.lock_outline_rounded,
                title: 'Change Password',
                accentColor: AppColors.riderAccent,
                isOpen: _showChangePassword,
                onToggle: () =>
                    setState(() => _showChangePassword = !_showChangePassword),
                child: Column(children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  AppTextField(
                      label: 'Current Password',
                      controller: _oldPassCtrl,
                      obscureText: true,
                      maxLength: 64),
                  const SizedBox(height: 12),
                  AppTextField(
                      label: 'New Password',
                      controller: _newPassCtrl,
                      obscureText: true,
                      maxLength: 64,
                      helperText: 'Minimum 8 characters'),
                  const SizedBox(height: 12),
                  AppTextField(
                      label: 'Confirm Password',
                      controller: _confirmCtrl,
                      obscureText: true,
                      maxLength: 64),
                  const SizedBox(height: 14),
                  AppButton(
                      label: 'Change Password',
                      isLoading: _saving,
                      onPressed: _changePassword,
                      width: double.infinity),
                ]),
              ),
              const SizedBox(height: 10),

              // Terms
              _WhiteTile(
                  icon: Icons.gavel_rounded,
                  title: 'Terms & Conditions',
                  subtitle: 'View our terms of service',
                  accentColor: AppColors.riderAccent,
                  onTap: () => showDialog(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                            title: const Text('Terms & Conditions'),
                            content: const SingleChildScrollView(
                                child: Text(
                                    'By using Jireta LMS, you agree to our lending terms. Loan amounts, interest rates, and payment schedules are set by the head manager and visible before application. Late payments may incur penalties.')),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dlgCtx),
                                  child: const Text('Close'))
                            ],
                          ))),
              const SizedBox(height: 10),
              _WhiteTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  accentColor: AppColors.riderAccent,
                  onTap: () => showDialog(
                      context: context,
                      builder: (dlgCtx) => AlertDialog(
                            title: const Text('Privacy Policy'),
                            content: const SingleChildScrollView(
                                child: Text(
                                    'Your personal and financial data is encrypted and stored securely. We do not share your information with third parties without consent.')),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dlgCtx),
                                  child: const Text('Close'))
                            ],
                          ))),
              const SizedBox(height: 24),

              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color == Colors.green
                    ? Colors.greenAccent
                    : color == Colors.red
                        ? Colors.redAccent
                        : color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: Colors.black54)),
        Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
                textAlign: TextAlign.end)),
      ]);
}

class _CollapsibleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final bool isOpen;
  final VoidCallback onToggle;
  final Widget child;
  const _CollapsibleCard(
      {required this.icon,
      required this.title,
      required this.accentColor,
      required this.isOpen,
      required this.onToggle,
      required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.20))),
            child: Column(children: [
              InkWell(
                onTap: onToggle,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(icon, size: 18, color: accentColor)),
                      const SizedBox(width: 12),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const Spacer(),
                      AnimatedRotation(
                          turns: isOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(Icons.expand_more_rounded,
                              color: Colors.black38)),
                    ])),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOut,
                child: isOpen
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: child)
                    : const SizedBox.shrink(),
              ),
            ]),
          )));
}

class _WhiteTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  const _WhiteTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.accentColor,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20))),
        child: ListTile(
          leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: accentColor)),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          subtitle: Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
          trailing:
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          onTap: onTap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}
