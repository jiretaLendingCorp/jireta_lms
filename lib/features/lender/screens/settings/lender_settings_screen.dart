// lib/features/lender/screens/settings/lender_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';

class LenderSettingsScreen extends ConsumerWidget {
  const LenderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GlassCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => context.push(RouteConstants.terms),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => context.push(RouteConstants.terms),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.verified_user_outlined,
                    label: 'KYC Status',
                    onTap: () => context.go(RouteConstants.lenderKyc),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    label: 'About Jireta Loans',
                    onTap: () => _showAbout(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.lenderAccent.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.support_agent_rounded, color: AppColors.lenderAccent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Need Help?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('Contact your loan officer', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Jireta Loans v1.0.0',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Jireta Loans & Credit Corp Inc.',
              style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('About Jireta Loans', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('Jireta Loans & Credit Corp Inc. provides accessible lending services to Filipinos with a transparent 20% flat interest rate and flexible payment terms.', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.6)),
              const SizedBox(height: 16),
              Text('Version: 1.0.0', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
              const SizedBox(height: 8),
              Text('Support: support@jiretaloans.com', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.lenderAccent, size: 22),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(color: Colors.white.withOpacity(0.08), height: 1, indent: 56);
}