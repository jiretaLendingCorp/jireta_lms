// lib/features/rider/screens/settings/rider_settings_screen.dart
//
// FIX #6: Account info card is now at the TOP (below the header profile card).
//         Help & Support, Terms & Conditions, Privacy Policy now open proper
//         dialogs instead of routing to random pages or doing nothing.
// FIX #5: After saving profile, stays on this screen (no redirect to home).
// All glassmorphism preserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/constants/app_icons.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/data/auth_repository.dart';

class RiderSettingsScreen extends ConsumerStatefulWidget {
  const RiderSettingsScreen({super.key});
  @override
  ConsumerState<RiderSettingsScreen> createState() =>
      _RiderSettingsScreenState();
}

class _RiderSettingsScreenState extends ConsumerState<RiderSettingsScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _fuelPriceCtrl = TextEditingController(text: '64.00');
  final _consumptionCtrl = TextEditingController(text: '40');

  double? _estimatedGas;
  bool _saving = false;
  bool _uploadingAvatar = false;
  bool _notifEnabled = true;
  bool _locationEnabled = true;
  bool _editProfileExpanded = false;
  bool _securityExpanded = false;

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
    _distanceCtrl.dispose();
    _fuelPriceCtrl.dispose();
    _consumptionCtrl.dispose();
    super.dispose();
  }

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
        setState(() => _editProfileExpanded = false); // stay on page
      }
    }
  }

  Future<void> _pickAvatar(ImageSource src) async {
    final file = await ImagePicker().pickImage(
        source: src, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    if (file == null) return;
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) return;
    setState(() => _uploadingAvatar = true);
    final bytes = await file.readAsBytes();
    final ext = _cleanExt(file.path.split('.').last);
    final err = await AuthRepository().uploadAvatar(userId, bytes, ext);
    if (mounted) {
      setState(() => _uploadingAvatar = false);
      context.showSnack(err ?? 'Profile photo updated', isError: err != null);
      if (err == null) ref.read(authProvider.notifier).refreshProfile();
    }
  }

  String _cleanExt(String raw) {
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
      backgroundColor: const Color(0xFF16245C),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
            title:
                const Text('Take Photo', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _pickAvatar(ImageSource.camera);
            }),
        ListTile(
            leading:
                const Icon(Icons.photo_library_outlined, color: Colors.white),
            title: const Text('Choose from Gallery',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(ctx);
              _pickAvatar(ImageSource.gallery);
            }),
        const SizedBox(height: 8),
      ])),
    );
  }

  Future<void> _changePass() async {
    if (_newPassCtrl.text != _confirmCtrl.text) {
      context.showSnack('Passwords do not match', isError: true);
      return;
    }
    if (_newPassCtrl.text.length < 8) {
      context.showSnack('At least 8 characters required', isError: true);
      return;
    }
    setState(() => _saving = true);
    final err = await ref
        .read(authProvider.notifier)
        .changePassword(_oldPassCtrl.text, _newPassCtrl.text);
    setState(() => _saving = false);
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

  void _computeGas() {
    final distance = double.tryParse(_distanceCtrl.text);
    final price = double.tryParse(_fuelPriceCtrl.text);
    final consumption = double.tryParse(_consumptionCtrl.text);
    if (distance == null ||
        price == null ||
        consumption == null ||
        consumption == 0) {
      context.showSnack('Enter valid values', isError: true);
      return;
    }
    setState(() => _estimatedGas = (distance / consumption) * price);
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
                  Text('Contact Us',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text('📧  support@jireta.ph'),
                  SizedBox(height: 4),
                  Text('📞  +63 2 8888 0000'),
                  SizedBox(height: 16),
                  Text('Rider Guidelines',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text(
                      '• Always confirm the lender\'s identity before collecting.\n'
                      '• Take a clear photo of the receipt after collection.\n'
                      '• Report any issues to your assigned employee immediately.\n'
                      '• Never accept partial payments without supervisor approval.'),
                ],
              )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))
              ],
            ));
  }

  void _showTermsDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Terms & Conditions'),
              content: const SingleChildScrollView(
                  child: Text(
                'As a Jireta Rider, you agree to:\n\n'
                '1. Collect payments only from assigned lenders.\n'
                '2. Always issue receipts and upload proof of collection.\n'
                '3. Maintain confidentiality of lender information.\n'
                '4. Unauthorized collection is grounds for termination.\n'
                '5. All disputes must be reported within 24 hours.\n'
                '6. Jireta is not liable for rider vehicle incidents during collection.',
              )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))
              ],
            ));
  }

  void _showPrivacyDialog() {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Privacy Policy'),
              content: const SingleChildScrollView(
                  child: Text(
                'Your data is protected:\n\n'
                '• Location data is collected only during active assignments.\n'
                '• Personal information is encrypted and never sold.\n'
                '• Collection photos are stored securely and visible only to staff.\n'
                '• Contact support@jireta.ph for data deletion requests.',
              )),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDark = ref.watch(themeModeProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;
    const accent = AppColors.riderAccent;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPad),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header Profile Card ──────────────────────────────────────────
          GlassCard(
            child: Row(children: [
              GestureDetector(
                onTap: _showAvatarPicker,
                child: Stack(children: [
                  AppAvatar(
                      imageUrl: user?.avatarUrl,
                      name: user?.displayName ?? '',
                      size: 56,
                      backgroundColor: accent),
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: _uploadingAvatar
                            ? const Padding(
                                padding: EdgeInsets.all(5),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.camera_alt_rounded,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(user?.email ?? '',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12)),
                    const SizedBox(height: 6),
                    const _GlassBadge(label: 'Rider', color: accent),
                  ])),
              _GlassStatusBadge(active: user?.isActive ?? true),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Account Info (NOW AT THE TOP as per requirement) ─────────────
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _GlassHeader(icon: AppIcons.profile, title: 'Account Info'),
              const SizedBox(height: 12),
              _GlassInfoRow(
                  label: 'Member Since',
                  value: user?.createdAt.toDisplayDate ?? '—'),
              const SizedBox(height: 6),
              _GlassInfoRow(
                  label: 'User ID',
                  value: user?.id.substring(0, 8).toUpperCase() ?? '—'),
              const SizedBox(height: 6),
              _GlassInfoRow(
                  label: 'Status',
                  value: user?.isActive == true ? 'Active' : 'Inactive',
                  valueColor: user?.isActive == true
                      ? AppColors.success
                      : AppColors.error),
              if (user?.phone != null) ...[
                const SizedBox(height: 6),
                _GlassInfoRow(label: 'Phone', value: user!.phone!)
              ],
              if (user?.address != null) ...[
                const SizedBox(height: 6),
                _GlassInfoRow(label: 'Address', value: user!.address!)
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // ── Edit Profile collapsible ──────────────────────────────────────
          _GlassCollapsibleSection(
            icon: AppIcons.profile,
            title: 'Edit Profile',
            expanded: _editProfileExpanded,
            onToggle: () =>
                setState(() => _editProfileExpanded = !_editProfileExpanded),
            child: Column(children: [
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: AppTextField(
                        label: 'First Name',
                        controller: _firstCtrl,
                        isGlass: true,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null)),
                const SizedBox(width: 10),
                Expanded(
                    child: AppTextField(
                        label: 'Last Name',
                        controller: _lastCtrl,
                        isGlass: true,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null)),
              ]),
              const SizedBox(height: 12),
              AppTextField(
                  label: 'Phone Number',
                  controller: _phoneCtrl,
                  isGlass: true,
                  keyboardType: TextInputType.phone,
                  hint: '09XXXXXXXXX'),
              const SizedBox(height: 12),
              AppTextField(
                  label: 'Address',
                  controller: _addressCtrl,
                  isGlass: true,
                  maxLines: 2,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences),
              const SizedBox(height: 16),
              AppButton(
                  label: 'Save Changes',
                  color: accent,
                  textColor: Colors.black87,
                  isLoading: _saving,
                  onPressed: _save,
                  width: double.infinity),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Security ──────────────────────────────────────────────────────
          _GlassCollapsibleSection(
            icon: AppIcons.lock,
            title: 'Security',
            expanded: _securityExpanded,
            onToggle: () =>
                setState(() => _securityExpanded = !_securityExpanded),
            child: Column(children: [
              const SizedBox(height: 16),
              AppTextField(
                  label: 'Current Password',
                  controller: _oldPassCtrl,
                  isGlass: true,
                  obscureText: true),
              const SizedBox(height: 12),
              AppTextField(
                  label: 'New Password',
                  controller: _newPassCtrl,
                  isGlass: true,
                  obscureText: true,
                  helperText: 'Minimum 8 characters'),
              const SizedBox(height: 12),
              AppTextField(
                  label: 'Confirm New Password',
                  controller: _confirmCtrl,
                  isGlass: true,
                  obscureText: true),
              const SizedBox(height: 16),
              AppButton(
                  label: 'Change Password',
                  color: accent,
                  textColor: Colors.black87,
                  isLoading: _saving,
                  onPressed: _changePass,
                  width: double.infinity),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Gas Cost Estimator ────────────────────────────────────────────
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _GlassHeader(
                  icon: AppIcons.truck, title: 'Gas Cost Estimator'),
              const SizedBox(height: 4),
              Text("Estimate fuel cost to reach a lender's address",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12)),
              const SizedBox(height: 16),
              AppTextField(
                  label: 'Distance to Lender (km)',
                  controller: _distanceCtrl,
                  isGlass: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  hint: 'e.g. 12.5'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: AppTextField(
                        label: 'Fuel Price (₱/L)',
                        controller: _fuelPriceCtrl,
                        isGlass: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true))),
                const SizedBox(width: 12),
                Expanded(
                    child: AppTextField(
                        label: 'Fuel Economy (km/L)',
                        controller: _consumptionCtrl,
                        isGlass: true,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true))),
              ]),
              const SizedBox(height: 16),
              AppButton(
                  label: 'Calculate',
                  color: accent,
                  textColor: Colors.black87,
                  onPressed: _computeGas,
                  width: double.infinity),
              if (_estimatedGas != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withValues(alpha: 0.3))),
                  child: Row(children: [
                    const Icon(AppIcons.coins, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estimated Gas Cost',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12)),
                          Text('₱${_estimatedGas!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: accent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                        ]),
                  ]),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // ── Preferences ───────────────────────────────────────────────────
          GlassCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _GlassHeader(icon: AppIcons.settings, title: 'Preferences'),
              const SizedBox(height: 8),
              _GlassSwitchTile(
                  icon: AppIcons.notifications,
                  label: 'Push Notifications',
                  subtitle: 'Receive assignment alerts',
                  value: _notifEnabled,
                  onChanged: (v) => setState(() => _notifEnabled = v)),
              _GlassDivider(),
              _GlassSwitchTile(
                  icon: AppIcons.mapPin,
                  label: 'GPS / Location',
                  subtitle: 'Enable for navigation',
                  value: _locationEnabled,
                  onChanged: (v) => setState(() => _locationEnabled = v)),
              _GlassDivider(),
              _GlassSwitchTile(
                  icon: isDark ? AppIcons.sun : AppIcons.moon,
                  label: 'Dark Mode',
                  subtitle: 'Toggle app theme',
                  value: isDark,
                  onChanged: (v) =>
                      ref.read(themeModeProvider.notifier).state = v),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Info & Support ────────────────────────────────────────────────
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _GlassTapTile(
                  icon: AppIcons.headphones,
                  label: 'Help & Support',
                  onTap: _showHelpDialog), // FIX: now opens dialog
              _GlassDivider(),
              _GlassTapTile(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: _showPrivacyDialog), // FIX: now opens dialog
              _GlassDivider(),
              _GlassTapTile(
                  icon: Icons.description_outlined,
                  label: 'Terms & Conditions',
                  onTap: _showTermsDialog), // FIX: now opens dialog
              _GlassDivider(),
              _GlassTapTile(
                icon: Icons.info_outline_rounded,
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

          // ── Sign Out ──────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              icon:
                  const Icon(AppIcons.logout, color: AppColors.error, size: 18),
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
    );
  }
}

// ── Glass helpers ─────────────────────────────────────────────────────────────

class _GlassCollapsibleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  const _GlassCollapsibleSection(
      {required this.icon,
      required this.title,
      required this.expanded,
      required this.onToggle,
      required this.child});
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
                decoration: BoxDecoration(
                    color: AppColors.riderAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: AppColors.riderAccent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600))),
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
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: child)
                : const SizedBox.shrink(),
          ),
        ),
      ]),
    );
  }
}

class _GlassHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _GlassHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: AppColors.riderAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.riderAccent, size: 15)),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _GlassSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _GlassSwitchTile(
      {required this.icon,
      required this.label,
      this.subtitle,
      required this.value,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        ])),
        Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.riderAccent,
            activeThumbColor: Colors.white),
      ]),
    );
  }
}

class _GlassTapTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  const _GlassTapTile(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.trailing});
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
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500))),
          trailing ??
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 20),
        ]),
      ),
    );
  }
}

class _GlassDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, indent: 50, color: Colors.white.withValues(alpha: 0.08));
}

class _GlassInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _GlassInfoRow(
      {required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
      Text(value,
          style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class _GlassBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _GlassBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _GlassStatusBadge extends StatelessWidget {
  final bool active;
  const _GlassStatusBadge({required this.active});
  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(active ? 'Active' : 'Inactive',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
