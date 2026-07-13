// lib/features/lender/screens/settings/lender_settings_screen.dart
//
// FIX #4 + #6:
//  - Converted all WhiteCard → GlassCard (glassmorphism).
//  - Text/icon colors changed to white so they're visible on dark gradient.
//  - Fixed "BOTTOM OVERFLOWED" in collapsible sections: replaced
//    AnimatedCrossFade with ClipRect + AnimatedSize for stable height transitions.
//  - Adjusted bottom padding to account for MobileShell nav bar offset.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../auth/data/auth_repository.dart';

class LenderSettingsScreen extends ConsumerStatefulWidget {
  const LenderSettingsScreen({super.key});

  @override
  ConsumerState<LenderSettingsScreen> createState() =>
      _LenderSettingsScreenState();
}

class _LenderSettingsScreenState extends ConsumerState<LenderSettingsScreen> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _notifLoan = true;
  bool _notifPayment = true;
  bool _notifPromo = false;

  bool _editProfileExpanded = false;
  bool _securityExpanded = false;
  bool _notifExpanded = false;

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

  Future<void> _save() async {
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
      if (err == null) ref.read(authProvider.notifier).refreshProfile();
    }
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDark = ref.watch(themeModeProvider);
    // FIX: MobileShell already adds 58 to MediaQuery.padding.bottom,
    // so just add minimal extra spacing here.
    final bottomPad = MediaQuery.of(context).padding.bottom + 24;

    const accent = AppColors.lenderAccent;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Profile card — glass
            GlassCard(
              child: Row(
                children: [
                  AppAvatar(
                    imageUrl: user?.avatarUrl,
                    name: user?.displayName ?? '',
                    size: 52,
                    backgroundColor: accent,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        const _LGlassBadge(label: 'Lender', color: accent),
                      ],
                    ),
                  ),
                  _LGlassStatusBadge(active: user?.isActive ?? true),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Edit Profile — collapsible glass
            _LGlassCollapsibleSection(
              icon: AppIcons.profile,
              title: 'Edit Profile',
              expanded: _editProfileExpanded,
              accent: accent,
              onToggle: () =>
                  setState(() => _editProfileExpanded = !_editProfileExpanded),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          label: 'First Name',
                          controller: _firstCtrl,
                          isGlass: true,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTextField(
                          label: 'Last Name',
                          controller: _lastCtrl,
                          isGlass: true,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Phone Number',
                    controller: _phoneCtrl,
                    isGlass: true,
                    keyboardType: TextInputType.phone,
                    hint: '09XXXXXXXXX',
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Address',
                    controller: _addressCtrl,
                    isGlass: true,
                    hint: 'Street, City, Province',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Save Changes',
                    color: accent,
                    textColor: Colors.white,
                    isLoading: _saving,
                    onPressed: _save,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Security — collapsible glass
            _LGlassCollapsibleSection(
              icon: AppIcons.lock,
              title: 'Security',
              expanded: _securityExpanded,
              accent: accent,
              onToggle: () =>
                  setState(() => _securityExpanded = !_securityExpanded),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Current Password',
                    controller: _oldPassCtrl,
                    isGlass: true,
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'New Password',
                    controller: _newPassCtrl,
                    isGlass: true,
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Confirm New Password',
                    controller: _confirmCtrl,
                    isGlass: true,
                    obscureText: true,
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Change Password',
                    color: accent,
                    textColor: Colors.white,
                    isLoading: _saving,
                    onPressed: _changePass,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Notifications — collapsible glass
            _LGlassCollapsibleSection(
              icon: AppIcons.notifications,
              title: 'Notification Preferences',
              expanded: _notifExpanded,
              accent: accent,
              onToggle: () => setState(() => _notifExpanded = !_notifExpanded),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _LGlassSwitchTile(
                    icon: AppIcons.loans,
                    label: 'Loan Updates',
                    subtitle: 'Application status changes',
                    value: _notifLoan,
                    accent: accent,
                    onChanged: (v) => setState(() => _notifLoan = v),
                  ),
                  _LGlassDivider(),
                  _LGlassSwitchTile(
                    icon: AppIcons.payments,
                    label: 'Payment Reminders',
                    subtitle: 'Upcoming due dates',
                    value: _notifPayment,
                    accent: accent,
                    onChanged: (v) => setState(() => _notifPayment = v),
                  ),
                  _LGlassDivider(),
                  _LGlassSwitchTile(
                    icon: AppIcons.bell,
                    label: 'Promotions',
                    subtitle: 'Special offers and news',
                    value: _notifPromo,
                    accent: accent,
                    onChanged: (v) => setState(() => _notifPromo = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Appearance — glass
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LGlassHeader(
                      icon: AppIcons.settings,
                      title: 'Appearance',
                      accent: accent),
                  const SizedBox(height: 8),
                  _LGlassSwitchTile(
                    icon: isDark ? AppIcons.sun : AppIcons.moon,
                    label: 'Dark Mode',
                    subtitle: 'Toggle app theme',
                    value: isDark,
                    accent: accent,
                    onChanged: (v) =>
                        ref.read(themeModeProvider.notifier).state = v,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Info & support — glass
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _LGlassTapTile(
                    icon: AppIcons.headphones,
                    label: 'Help & Support',
                    onTap: () {},
                  ),
                  _LGlassDivider(),
                  _LGlassTapTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => context.push(RouteConstants.terms),
                  ),
                  _LGlassDivider(),
                  _LGlassTapTile(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => context.push(RouteConstants.terms),
                  ),
                  _LGlassDivider(),
                  _LGlassTapTile(
                    icon: Icons.info_outline_rounded,
                    label: 'App Version',
                    trailing: Text('v1.0.0',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13)),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Account info — glass
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _LGlassHeader(
                      icon: AppIcons.profile,
                      title: 'Account Info',
                      accent: accent),
                  const SizedBox(height: 12),
                  _LGlassInfoRow(
                      label: 'Member Since',
                      value: user?.createdAt.toDisplayDate ?? '—'),
                  const SizedBox(height: 6),
                  _LGlassInfoRow(
                    label: 'Status',
                    value: user?.isActive == true ? 'Active' : 'Inactive',
                    valueColor: user?.isActive == true
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  const SizedBox(height: 6),
                  _LGlassInfoRow(
                      label: 'User ID',
                      value: user?.id.substring(0, 8).toUpperCase() ?? '—'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sign out
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
          ],
        ),
      ),
    );
  }
}

// ── Glass collapsible section (lender) ───────────────────────────────────────

class _LGlassCollapsibleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final Color accent;
  final VoidCallback onToggle;
  final Widget child;

  const _LGlassCollapsibleSection({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.accent,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: accent, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.5), size: 22),
                  ),
                ],
              ),
            ),
          ),
          // FIX: ClipRect + AnimatedSize avoids the BOTTOM OVERFLOWED bug
          // from AnimatedCrossFade in scrollable containers.
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: child,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lender glass helpers ──────────────────────────────────────────────────────

class _LGlassHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  const _LGlassHeader(
      {required this.icon, required this.title, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accent, size: 15),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _LGlassSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const _LGlassSwitchTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: accent,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _LGlassTapTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _LGlassTapTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
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
          ],
        ),
      ),
    );
  }
}

class _LGlassDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, indent: 50, color: Colors.white.withValues(alpha: 0.08));
}

class _LGlassInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _LGlassInfoRow(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _LGlassStatusBadge extends StatelessWidget {
  final bool active;
  const _LGlassStatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: (active ? AppColors.success : AppColors.error)
                .withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              color: active ? AppColors.success : AppColors.error,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
