// lib/features/lender/screens/profile/lender_profile_screen.dart
//
// REDESIGN (Task 7-A): Material 3 polish, per-section Form state with
// Validators on all fields, premium avatar with gradient ring + camera badge,
// consistent 14px radius, AppIcons for visual consistency. All business logic
// (avatar upload, profile update, password change, dialogs) preserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/lender_glass_helpers.dart';

class LenderProfileScreen extends ConsumerStatefulWidget {
  const LenderProfileScreen({super.key});
  @override
  ConsumerState<LenderProfileScreen> createState() =>
      _LenderProfileScreenState();
}

class _LenderProfileScreenState extends ConsumerState<LenderProfileScreen>
    with SingleTickerProviderStateMixin {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _profileFormKey = GlobalKey<FormState>();
  final _securityFormKey = GlobalKey<FormState>();

  bool _saving = false;
  bool _savingPass = false;
  bool _uploadingAvatar = false;
  bool _notifLoan = true;
  bool _notifPayment = true;
  bool _notifPromo = false;
  bool _editProfileExpanded = false;
  bool _securityExpanded = false;
  bool _notifExpanded = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  static const _accent = AppColors.lenderAccent;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    final user = ref.read(authProvider).user;
    _firstCtrl.text = user?.firstName ?? '';
    _lastCtrl.text = user?.lastName ?? '';
    _phoneCtrl.text = user?.phone ?? '';
    _addressCtrl.text = user?.address ?? '';
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource src) async {
    final file = await ImagePicker().pickImage(
        source: src, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    setState(() => _uploadingAvatar = true);
    final bytes = await file.readAsBytes();
    final name = file.name.isNotEmpty ? file.name : file.path;
    final ext = _sanitizeExt(name.split('.').last);
    final err =
        await ref.read(authRepositoryProvider).uploadAvatar(userId, bytes, ext);
    if (mounted) {
      setState(() => _uploadingAvatar = false);
      context.showSnack(err ?? 'Profile photo updated', isError: err != null);
      if (err == null) ref.read(authProvider.notifier).refreshProfile();
    }
  }

  String _sanitizeExt(String raw) {
    final e = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return ['jpg', 'jpeg', 'png', 'webp'].contains(e) ? e : 'jpg';
  }

  void _showAvatarPicker() {
    if (kIsWeb) {
      _pickAvatar(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF10173A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Change Profile Photo',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
          ListTile(
              leading: const Icon(AppIcons.camera, color: _accent),
              title: const Text('Take Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              }),
          ListTile(
              leading: const Icon(AppIcons.image, color: _accent),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) {
      context.showSnack('Please fix the errors before saving', isError: true);
      return;
    }
    setState(() => _saving = true);
    final err = await ref.read(authRepositoryProvider).updateProfile({
      'first_name': _firstCtrl.text.trim(),
      'last_name': _lastCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
    });
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(err ?? 'Profile updated', isError: err != null);
      if (err == null) {
        ref.read(authProvider.notifier).refreshProfile();
        setState(() => _editProfileExpanded = false);
      }
    }
  }

  Future<void> _changePass() async {
    if (!(_securityFormKey.currentState?.validate() ?? false)) {
      context.showSnack('Please fix the password fields', isError: true);
      return;
    }
    setState(() => _savingPass = true);
    final err = await ref
        .read(authProvider.notifier)
        .changePassword(_oldPassCtrl.text, _newPassCtrl.text);
    setState(() => _savingPass = false);
    if (mounted) {
      context.showSnack(err ?? 'Password changed', isError: err != null);
      if (err == null) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmCtrl.clear();
        setState(() => _securityExpanded = false);
      }
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: const SingleChildScrollView(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contact Us', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('📧  support@jireta.ph'),
            SizedBox(height: 4),
            Text('📞  +63 2 8888 0000'),
            SizedBox(height: 16),
            Text('Office Hours', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Monday – Friday\n8:00 AM – 5:00 PM (PST)'),
            SizedBox(height: 16),
            Text('FAQ', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text(
                '• Loan approval takes 1–3 business days after KYC is verified.\n'
                '• Payment can be made via rider collection or GCash/PayMongo.\n'
                '• For disputes, contact our support line within 24 hours.'),
          ],
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(
            child: Text(
          'By using Jireta LMS, you agree to our lending terms.\n\n'
          '1. Loan amounts range from ₱3,000 to ₱500,000.\n'
          '2. A 20% flat interest applies to all loans.\n'
          '3. Payment schedules are set at application (daily, weekly, or monthly).\n'
          '4. Late payments may incur penalties after 30 days.\n'
          '5. KYC verification is required before any loan application.\n'
          '6. Jireta reserves the right to reject applications without explanation.\n'
          '7. All transactions are governed by Philippine lending regulations.',
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
            child: Text(
          'Your privacy matters to us.\n\n'
          '• All personal data is encrypted using AES-256-GCM.\n'
          '• We do not sell your data to third parties.\n'
          '• Financial records are stored in a secured PostgreSQL database.\n'
          '• You may request data deletion by contacting support@jireta.ph.\n'
          '• KYC documents are stored encrypted and accessible only to authorized staff.',
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(authProvider).user;
    final isDark = ref.watch(themeModeProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;

    return SafeArea(
      bottom: false,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPad),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GlassCard(
                child: Row(children: [
                  GestureDetector(
                    onTap: _showAvatarPicker,
                    child: Stack(children: [
                      // Gradient ring around avatar
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              _accent,
                              _accent.withValues(alpha: 0.4),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: AppAvatar(
                          imageUrl: user?.avatarUrl,
                          name: user?.displayName ?? '',
                          size: 56,
                          backgroundColor: const Color(0xFF14183C),
                        ),
                      ),
                      Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                                color: _accent,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2)),
                            child: _uploadingAvatar
                                ? const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(AppIcons.camera,
                                    color: Colors.white, size: 12),
                          )),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(user?.fullName ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12)),
                        const SizedBox(height: 6),
                        const LGlassBadge(label: 'Lender', color: _accent),
                      ])),
                  LGlassStatusBadge(active: user?.isActive ?? true),
                ]),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LGlassHeader(
                          icon: AppIcons.profile,
                          title: 'Account Info',
                          accent: _accent),
                      const SizedBox(height: 12),
                      LGlassInfoRow(
                          label: 'Member Since',
                          value: user?.createdAt.toDisplayDate ?? '—'),
                      const SizedBox(height: 6),
                      LGlassInfoRow(
                          label: 'User ID',
                          value: user?.id.substring(0, 8).toUpperCase() ?? '—'),
                      const SizedBox(height: 6),
                      LGlassInfoRow(
                          label: 'Status',
                          value: user?.isActive == true ? 'Active' : 'Inactive',
                          valueColor: user?.isActive == true
                              ? AppColors.success
                              : AppColors.error),
                      if (user?.phone != null) ...[
                        const SizedBox(height: 6),
                        LGlassInfoRow(label: 'Phone', value: user!.phone!)
                      ],
                      if (user?.address != null) ...[
                        const SizedBox(height: 6),
                        LGlassInfoRow(label: 'Address', value: user!.address!)
                      ],
                    ]),
              ),
              const SizedBox(height: 12),
              LGlassCollapsibleSection(
                icon: AppIcons.profile,
                title: 'Edit Profile',
                expanded: _editProfileExpanded,
                accent: _accent,
                onToggle: () => setState(
                    () => _editProfileExpanded = !_editProfileExpanded),
                child: Form(
                  key: _profileFormKey,
                  child: Column(children: [
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: AppTextField(
                              label: 'First Name',
                              controller: _firstCtrl,
                              isGlass: true,
                              textCapitalization: TextCapitalization.words,
                              validator: Validators.firstName)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: AppTextField(
                              label: 'Last Name',
                              controller: _lastCtrl,
                              isGlass: true,
                              textCapitalization: TextCapitalization.words,
                              validator: Validators.lastName)),
                    ]),
                    const SizedBox(height: 12),
                    AppTextField(
                        label: 'Phone Number',
                        controller: _phoneCtrl,
                        isGlass: true,
                        keyboardType: TextInputType.phone,
                        hint: '09XXXXXXXXX',
                        prefixIcon: const Icon(AppIcons.phone,
                            size: 18, color: Colors.white54),
                        validator: Validators.phone),
                    const SizedBox(height: 12),
                    AppTextField(
                        label: 'Address',
                        controller: _addressCtrl,
                        isGlass: true,
                        hint: 'Street, City, Province',
                        maxLines: 2,
                        prefixIcon: const Icon(AppIcons.mapPin,
                            size: 18, color: Colors.white54),
                        validator: Validators.address),
                    const SizedBox(height: 16),
                    AppButton.gradient(
                        label: 'Save Changes',
                        icon: AppIcons.check,
                        color: _accent,
                        textColor: Colors.white,
                        isLoading: _saving,
                        onPressed: _save,
                        width: double.infinity,
                        size: AppButtonSize.lg),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              LGlassCollapsibleSection(
                icon: AppIcons.lock,
                title: 'Security',
                expanded: _securityExpanded,
                accent: _accent,
                onToggle: () =>
                    setState(() => _securityExpanded = !_securityExpanded),
                child: Form(
                  key: _securityFormKey,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        AppTextField(
                          label: 'Current Password',
                          controller: _oldPassCtrl,
                          isGlass: true,
                          obscureText: true,
                          validator: (v) => Validators.compose(v, [
                            (v) => Validators.required(v,
                                label: 'Current password'),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                            label: 'New Password',
                            controller: _newPassCtrl,
                            isGlass: true,
                            obscureText: true,
                            helperText:
                                'Minimum 8 characters, 1 letter + 1 number',
                            validator: Validators.strongPassword),
                        const SizedBox(height: 12),
                        AppTextField(
                            label: 'Confirm New Password',
                            controller: _confirmCtrl,
                            isGlass: true,
                            obscureText: true,
                            validator: (v) => Validators.confirmPassword(
                                v, _newPassCtrl.text)),
                        const SizedBox(height: 16),
                        AppButton.gradient(
                            label: 'Change Password',
                            icon: AppIcons.key,
                            color: _accent,
                            textColor: Colors.white,
                            isLoading: _savingPass,
                            onPressed: _changePass,
                            width: double.infinity,
                            size: AppButtonSize.lg),
                      ]),
                ),
              ),
              const SizedBox(height: 12),
              LGlassCollapsibleSection(
                icon: AppIcons.notifications,
                title: 'Notification Preferences',
                expanded: _notifExpanded,
                accent: _accent,
                onToggle: () =>
                    setState(() => _notifExpanded = !_notifExpanded),
                child: Column(children: [
                  const SizedBox(height: 8),
                  LGlassSwitchTile(
                      icon: AppIcons.loans,
                      label: 'Loan Updates',
                      subtitle: 'Application status changes',
                      value: _notifLoan,
                      accent: _accent,
                      onChanged: (v) => setState(() => _notifLoan = v)),
                  const LGlassDivider(),
                  LGlassSwitchTile(
                      icon: AppIcons.payments,
                      label: 'Payment Reminders',
                      subtitle: 'Upcoming due dates',
                      value: _notifPayment,
                      accent: _accent,
                      onChanged: (v) => setState(() => _notifPayment = v)),
                  const LGlassDivider(),
                  LGlassSwitchTile(
                      icon: AppIcons.bell,
                      label: 'Promotions',
                      subtitle: 'Special offers and news',
                      value: _notifPromo,
                      accent: _accent,
                      onChanged: (v) => setState(() => _notifPromo = v)),
                ]),
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LGlassHeader(
                          icon: AppIcons.settings,
                          title: 'Appearance',
                          accent: _accent),
                      const SizedBox(height: 8),
                      LGlassSwitchTile(
                          icon: isDark ? AppIcons.sun : AppIcons.moon,
                          label: 'Dark Mode',
                          subtitle: 'Toggle app theme',
                          value: isDark,
                          accent: _accent,
                          onChanged: (v) =>
                              ref.read(themeModeProvider.notifier).state = v),
                    ]),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  LGlassTapTile(
                    icon: Icons.verified_user_outlined,
                    label: 'KYC Verification',
                    subtitle: 'Submit identity documents',
                    onTap: () => context.go(RouteConstants.lenderKyc),
                  ),
                  const LGlassDivider(),
                  LGlassTapTile(
                    icon: AppIcons.headphones,
                    label: 'Help & Support',
                    subtitle: 'Get assistance',
                    onTap: _showHelpDialog,
                  ),
                  const LGlassDivider(),
                  LGlassTapTile(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    subtitle: 'View our terms of service',
                    onTap: _showTermsDialog,
                  ),
                  const LGlassDivider(),
                  LGlassTapTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    subtitle: 'How we handle your data',
                    onTap: _showPrivacyDialog,
                  ),
                  const LGlassDivider(),
                  LGlassTapTile(
                    icon: AppIcons.info,
                    label: 'App Version',
                    trailing: Text('v1.0.0',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13)),
                    onTap: () {},
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ref.read(authProvider.notifier).signOut(),
                  icon: const Icon(AppIcons.logout,
                      color: AppColors.error, size: 18),
                  label: const Text('Sign Out',
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
