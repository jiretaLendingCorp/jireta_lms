// lib/features/lender/screens/profile/lender_profile_screen.dart
//
// FIX #1: Merged Settings into Profile (single screen).
//         - Profile is now the full settings page with avatar, edit profile,
//           change password, notifications, help & support, T&C, privacy.
//         - Terms & Conditions now shows a dialog (no longer redirects to home).
//         - Privacy Policy shows inline dialog.
//         - Help & Support shows contact dialog.
//         - Scroll overlap fixed: SingleChildScrollView with proper bottom padding.
//         - Save profile stays on the profile screen (no redirect to home).
//         - Full glassmorphism on all cards.

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
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/data/auth_repository.dart';

class LenderProfileScreen extends ConsumerStatefulWidget {
  const LenderProfileScreen({super.key});
  @override
  ConsumerState<LenderProfileScreen> createState() => _LenderProfileScreenState();
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
  bool _notifLoan = true;
  bool _notifPayment = true;
  bool _notifPromo = false;
  bool _editProfileExpanded = false;
  bool _securityExpanded = false;
  bool _notifExpanded = false;

  static const _accent = AppColors.lenderAccent;

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
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Avatar ──────────────────────────────────────────────────────────────────

  Future<void> _pickAvatar(ImageSource src) async {
    final file = await ImagePicker()
        .pickImage(source: src, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    setState(() => _uploadingAvatar = true);
    final bytes = await file.readAsBytes();
    final ext = _sanitizeExt(file.path.split('.').last);
    final err = await AuthRepository().uploadAvatar(userId, bytes, ext);
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
    if (kIsWeb) { _pickAvatar(ImageSource.gallery); return; }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16245C),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          ListTile(leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _pickAvatar(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _pickAvatar(ImageSource.gallery); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Save profile — stays on profile page ────────────────────────────────────

  Future<void> _save() async {
    if (_firstCtrl.text.trim().isEmpty || _lastCtrl.text.trim().isEmpty) {
      context.showSnack('First and last name are required', isError: true);
      return;
    }
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
      if (err == null) {
        ref.read(authProvider.notifier).refreshProfile();
        setState(() => _editProfileExpanded = false); // collapse, stay on page
      }
    }
  }

  Future<void> _changePass() async {
    if (_newPassCtrl.text != _confirmCtrl.text) {
      context.showSnack('Passwords do not match', isError: true); return;
    }
    if (_newPassCtrl.text.length < 8) {
      context.showSnack('At least 8 characters required', isError: true); return;
    }
    setState(() => _saving = true);
    final err = await ref.read(authProvider.notifier)
        .changePassword(_oldPassCtrl.text, _newPassCtrl.text);
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(err ?? 'Password changed', isError: err != null);
      if (err == null) {
        _oldPassCtrl.clear(); _newPassCtrl.clear(); _confirmCtrl.clear();
        setState(() => _securityExpanded = false);
      }
    }
  }

  // ── Dialogs ─────────────────────────────────────────────────────────────────

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Help & Support'),
        content: const SingleChildScrollView(child: Column(
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
            Text('• Loan approval takes 1–3 business days after KYC is verified.\n'
                '• Payment can be made via rider collection or GCash/PayMongo.\n'
                '• For disputes, contact our support line within 24 hours.'),
          ],
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const SingleChildScrollView(child: Text(
          'By using Jireta LMS, you agree to our lending terms.\n\n'
          '1. Loan amounts range from ₱3,000 to ₱500,000.\n'
          '2. A 20% flat interest applies to all loans.\n'
          '3. Payment schedules are set at application (daily, weekly, or monthly).\n'
          '4. Late payments may incur penalties as defined by the head manager.\n'
          '5. KYC verification is required before any loan application.\n'
          '6. Jireta reserves the right to reject applications without explanation.\n'
          '7. All transactions are governed by Philippine lending regulations.',
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(child: Text(
          'Your privacy matters to us.\n\n'
          '• All personal data is encrypted using AES-256-GCM.\n'
          '• We do not sell your data to third parties.\n'
          '• Financial records are stored in a secured PostgreSQL database.\n'
          '• You may request data deletion by contacting support@jireta.ph.\n'
          '• KYC documents are stored encrypted and accessible only to authorized staff.',
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(authProvider).user;
    final isDark = ref.watch(themeModeProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Profile header card ──────────────────────────────────────────
          GlassCard(
            child: Row(children: [
              GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(children: [
                  AppAvatar(
                    imageUrl: user?.avatarUrl,
                    name: user?.displayName ?? '',
                    size: 56,
                    backgroundColor: _accent,
                  ),
                  Positioned(right: 0, bottom: 0, child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(color: _accent, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: _uploadingAvatar
                        ? const Padding(padding: EdgeInsets.all(5),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
                  )),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user?.fullName ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(user?.email ?? '',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(height: 6),
                _LGlassBadge(label: 'Lender', color: _accent),
              ])),
              _LGlassStatusBadge(active: user?.isActive ?? true),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Account info ─────────────────────────────────────────────────
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _LGlassHeader(icon: AppIcons.profile, title: 'Account Info', accent: _accent),
              const SizedBox(height: 12),
              _LGlassInfoRow(label: 'Member Since', value: user?.createdAt.toDisplayDate ?? '—'),
              const SizedBox(height: 6),
              _LGlassInfoRow(label: 'User ID', value: user?.id.substring(0, 8).toUpperCase() ?? '—'),
              const SizedBox(height: 6),
              _LGlassInfoRow(
                  label: 'Status',
                  value: user?.isActive == true ? 'Active' : 'Inactive',
                  valueColor: user?.isActive == true ? AppColors.success : AppColors.error),
              if (user?.phone != null) ...[ const SizedBox(height: 6), _LGlassInfoRow(label: 'Phone', value: user!.phone!) ],
              if (user?.address != null) ...[ const SizedBox(height: 6), _LGlassInfoRow(label: 'Address', value: user!.address!) ],
            ]),
          ),
          const SizedBox(height: 12),

          // ── Edit Profile collapsible ──────────────────────────────────────
          _LGlassCollapsibleSection(
            icon: AppIcons.profile,
            title: 'Edit Profile',
            expanded: _editProfileExpanded,
            accent: _accent,
            onToggle: () => setState(() => _editProfileExpanded = !_editProfileExpanded),
            child: Column(children: [
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: AppTextField(label: 'First Name', controller: _firstCtrl,
                    isGlass: true, textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
                const SizedBox(width: 10),
                Expanded(child: AppTextField(label: 'Last Name', controller: _lastCtrl,
                    isGlass: true, textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null)),
              ]),
              const SizedBox(height: 12),
              AppTextField(label: 'Phone Number', controller: _phoneCtrl,
                  isGlass: true, keyboardType: TextInputType.phone, hint: '09XXXXXXXXX'),
              const SizedBox(height: 12),
              AppTextField(label: 'Address', controller: _addressCtrl,
                  isGlass: true, hint: 'Street, City, Province', maxLines: 2),
              const SizedBox(height: 16),
              AppButton(label: 'Save Changes', color: _accent, textColor: Colors.white,
                  isLoading: _saving, onPressed: _save, width: double.infinity),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Security (Change Password) ────────────────────────────────────
          _LGlassCollapsibleSection(
            icon: AppIcons.lock,
            title: 'Security',
            expanded: _securityExpanded,
            accent: _accent,
            onToggle: () => setState(() => _securityExpanded = !_securityExpanded),
            child: Column(children: [
              const SizedBox(height: 16),
              AppTextField(label: 'Current Password', controller: _oldPassCtrl,
                  isGlass: true, obscureText: true),
              const SizedBox(height: 12),
              AppTextField(label: 'New Password', controller: _newPassCtrl,
                  isGlass: true, obscureText: true, helperText: 'Minimum 8 characters'),
              const SizedBox(height: 12),
              AppTextField(label: 'Confirm New Password', controller: _confirmCtrl,
                  isGlass: true, obscureText: true),
              const SizedBox(height: 16),
              AppButton(label: 'Change Password', color: _accent, textColor: Colors.white,
                  isLoading: _saving, onPressed: _changePass, width: double.infinity),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Notification Preferences ──────────────────────────────────────
          _LGlassCollapsibleSection(
            icon: AppIcons.notifications,
            title: 'Notification Preferences',
            expanded: _notifExpanded,
            accent: _accent,
            onToggle: () => setState(() => _notifExpanded = !_notifExpanded),
            child: Column(children: [
              const SizedBox(height: 8),
              _LGlassSwitchTile(icon: AppIcons.loans, label: 'Loan Updates',
                  subtitle: 'Application status changes', value: _notifLoan,
                  accent: _accent, onChanged: (v) => setState(() => _notifLoan = v)),
              _LGlassDivider(),
              _LGlassSwitchTile(icon: AppIcons.payments, label: 'Payment Reminders',
                  subtitle: 'Upcoming due dates', value: _notifPayment,
                  accent: _accent, onChanged: (v) => setState(() => _notifPayment = v)),
              _LGlassDivider(),
              _LGlassSwitchTile(icon: AppIcons.bell, label: 'Promotions',
                  subtitle: 'Special offers and news', value: _notifPromo,
                  accent: _accent, onChanged: (v) => setState(() => _notifPromo = v)),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Appearance ────────────────────────────────────────────────────
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _LGlassHeader(icon: AppIcons.settings, title: 'Appearance', accent: _accent),
              const SizedBox(height: 8),
              _LGlassSwitchTile(
                icon: isDark ? AppIcons.sun : AppIcons.moon,
                label: 'Dark Mode', subtitle: 'Toggle app theme', value: isDark,
                accent: _accent,
                onChanged: (v) => ref.read(themeModeProvider.notifier).state = v,
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // ── KYC Verification ──────────────────────────────────────────────
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _LGlassTapTile(
                icon: Icons.verified_user_outlined,
                label: 'KYC Verification',
                subtitle: 'Submit identity documents',
                onTap: () => context.push(RouteConstants.lenderKyc),
              ),
              _LGlassDivider(),
              _LGlassTapTile(
                icon: AppIcons.headphones,
                label: 'Help & Support',
                subtitle: 'Get assistance',
                onTap: _showHelpDialog,
              ),
              _LGlassDivider(),
              _LGlassTapTile(
                icon: Icons.description_outlined,
                label: 'Terms & Conditions',
                subtitle: 'View our terms of service',
                onTap: _showTermsDialog,       // FIX: dialog, not redirect to home
              ),
              _LGlassDivider(),
              _LGlassTapTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: _showPrivacyDialog,
              ),
              _LGlassDivider(),
              _LGlassTapTile(
                icon: Icons.info_outline_rounded,
                label: 'App Version',
                trailing: Text('v1.0.0',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
                onTap: () {},
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Sign out ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              icon: const Icon(AppIcons.logout, color: AppColors.error, size: 18),
              label: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Glass helpers (lender-scoped) ─────────────────────────────────────────────

class _LGlassCollapsibleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final Color accent;
  final VoidCallback onToggle;
  final Widget child;
  const _LGlassCollapsibleSection({
    required this.icon, required this.title, required this.expanded,
    required this.accent, required this.onToggle, required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.5), size: 22),
              ),
            ]),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: expanded
                ? Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child)
                : const SizedBox.shrink(),
          ),
        ),
      ]),
    );
  }
}

class _LGlassHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  const _LGlassHeader({required this.icon, required this.title, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: accent, size: 15)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _LGlassSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const _LGlassSwitchTile({required this.icon, required this.label, this.subtitle,
      required this.value, required this.accent, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          if (subtitle != null)
            Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        ])),
        Switch(value: value, onChanged: onChanged, activeTrackColor: accent, activeThumbColor: Colors.white),
      ]),
    );
  }
}

class _LGlassTapTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const _LGlassTapTile({required this.icon, required this.label, this.subtitle,
      required this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
          ])),
          trailing ?? Icon(Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3), size: 20),
        ]),
      ),
    );
  }
}

class _LGlassDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 50, color: Colors.white.withValues(alpha: 0.08));
}

class _LGlassInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _LGlassInfoRow({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
      Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _LGlassBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _LGlassBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _LGlassStatusBadge extends StatelessWidget {
  final bool active;
  const _LGlassStatusBadge({required this.active});
  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(active ? 'Active' : 'Inactive',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}