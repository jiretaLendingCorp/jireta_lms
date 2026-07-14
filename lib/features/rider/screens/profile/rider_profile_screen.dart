// lib/features/rider/screens/profile/rider_profile_screen.dart
//
// Redesigned (Task 8-A): Premium Material 3 glassmorphism UI on rider navy
// gradient. All form fields wired to `Validators` with inline error feedback.
// Business logic, controllers, providers, avatar upload, password change —
// all preserved.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/constants/app_icons.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/data/auth_repository.dart';

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

  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

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
    final err =
        await AuthRepository().uploadAvatar(userId, bytes, _resolveExt(file));
    setState(() => _uploadingAvatar = false);
    if (mounted) {
      context.showSnack(err ?? 'Profile photo updated', isError: err != null);
      if (err == null) ref.read(authProvider.notifier).refreshProfile();
    }
  }

  String _resolveExt(XFile file) {
    final name = file.name.isNotEmpty ? file.name : file.path;
    final raw = name.split('.').last.toLowerCase();
    return <String, String>{
          'jpg': 'jpg',
          'jpeg': 'jpg',
          'png': 'png',
          'webp': 'webp'
        }[raw] ??
        'jpg';
  }

  void _showAvatarPicker() {
    if (kIsWeb) {
      _pickAvatar(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D2060),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        _SheetOption(
          icon: AppIcons.camera,
          label: 'Take Photo',
          onTap: () {
            Navigator.pop(sheetCtx);
            _pickAvatar(ImageSource.camera);
          },
        ),
        _SheetOption(
          icon: AppIcons.image,
          label: 'Choose from Gallery',
          onTap: () {
            Navigator.pop(sheetCtx);
            _pickAvatar(ImageSource.gallery);
          },
        ),
        const SizedBox(height: 12),
      ])),
    );
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;
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
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;
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
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.riderAccent.withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: AppAvatar(
                        imageUrl: user?.avatarUrl,
                        name: user?.displayName ?? '',
                        size: 88,
                        backgroundColor: AppColors.riderAccent),
                  ),
                  Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            color: AppColors.riderAccent,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2.5)),
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
              const SizedBox(height: 12),
              Text(user?.displayName ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2)),
              const SizedBox(height: 4),
              Text(user?.email ?? '',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 13)),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const _Badge('Rider', AppColors.riderAccent),
                const SizedBox(width: 8),
                _Badge(
                    user?.isActive == true ? 'Active' : 'Inactive',
                    user?.isActive == true
                        ? AppColors.success
                        : AppColors.error),
              ]),
              const SizedBox(height: 24),

              // Info card
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  _InfoRow('Account ID',
                      user?.id.substring(0, 8).toUpperCase() ?? '—'),
                  const _GlassDivider(),
                  _InfoRow('Joined', user?.createdAt.toDisplayDate ?? '—'),
                  if (user?.phone != null) ...[
                    const _GlassDivider(),
                    _InfoRow('Phone', user!.phone!),
                  ],
                  if (user?.address != null &&
                      user!.address!.trim().isNotEmpty) ...[
                    const _GlassDivider(),
                    _InfoRow('Address', user.address!),
                  ],
                ]),
              ),
              const SizedBox(height: 14),

              // Collapsible: Edit Profile
              _CollapsibleCard(
                icon: AppIcons.edit,
                title: 'Edit Profile',
                accentColor: AppColors.riderAccent,
                isOpen: _showEditProfile,
                onToggle: () =>
                    setState(() => _showEditProfile = !_showEditProfile),
                child: Form(
                  key: _profileFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                            child: AppTextField(
                                label: 'First Name',
                                controller: _firstCtrl,
                                isGlass: true,
                                maxLength: 50,
                                textCapitalization: TextCapitalization.words,
                                validator: Validators.firstName)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: AppTextField(
                                label: 'Last Name',
                                controller: _lastCtrl,
                                isGlass: true,
                                maxLength: 50,
                                textCapitalization: TextCapitalization.words,
                                validator: Validators.lastName)),
                      ]),
                      const SizedBox(height: 14),
                      AppTextField(
                          label: 'Phone',
                          controller: _phoneCtrl,
                          isGlass: true,
                          keyboardType: TextInputType.phone,
                          maxLength: 13,
                          hint: '09XXXXXXXXX',
                          validator: Validators.optionalPhone),
                      const SizedBox(height: 16),
                      AppButton(
                          label: 'Save Changes',
                          isLoading: _saving,
                          color: AppColors.riderAccent,
                          textColor: Colors.black87,
                          size: AppButtonSize.lg,
                          onPressed: _saveProfile,
                          width: double.infinity),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Collapsible: Change Password
              _CollapsibleCard(
                icon: AppIcons.lock,
                title: 'Change Password',
                accentColor: AppColors.riderAccent,
                isOpen: _showChangePassword,
                onToggle: () =>
                    setState(() => _showChangePassword = !_showChangePassword),
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      AppTextField(
                          label: 'Current Password',
                          controller: _oldPassCtrl,
                          isGlass: true,
                          obscureText: true,
                          maxLength: 64,
                          validator: (v) => Validators.required(v,
                              label: 'Current password')),
                      const SizedBox(height: 14),
                      AppTextField(
                          label: 'New Password',
                          controller: _newPassCtrl,
                          isGlass: true,
                          obscureText: true,
                          maxLength: 64,
                          helperText: 'Min 8 chars, 1 letter & 1 number',
                          validator: Validators.strongPassword),
                      const SizedBox(height: 14),
                      AppTextField(
                          label: 'Confirm Password',
                          controller: _confirmCtrl,
                          isGlass: true,
                          obscureText: true,
                          maxLength: 64,
                          validator: (v) =>
                              Validators.confirmPassword(v, _newPassCtrl.text)),
                      const SizedBox(height: 16),
                      AppButton(
                          label: 'Change Password',
                          isLoading: _saving,
                          color: AppColors.riderAccent,
                          textColor: Colors.black87,
                          size: AppButtonSize.lg,
                          onPressed: _changePassword,
                          width: double.infinity),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
                    icon: const Icon(AppIcons.logout,
                        size: 18, color: AppColors.error),
                    label: const Text('Sign Out',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600)),
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
            color: color.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55), fontSize: 13)),
        Flexible(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
                textAlign: TextAlign.end)),
      ]);
}

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, indent: 0, color: Colors.white.withValues(alpha: 0.08));
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
                              color: accentColor.withValues(alpha: 0.18),
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
                          child: Icon(Icons.expand_more_rounded,
                              color: Colors.white.withValues(alpha: 0.55))),
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
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 18, color: accentColor)),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          subtitle: Text(subtitle,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.4)),
          onTap: onTap,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

// ── Bottom sheet option ───────────────────────────────────────────────────
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.riderAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.riderAccent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
              Icon(AppIcons.chevronRight,
                  color: Colors.white.withValues(alpha: 0.4), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
