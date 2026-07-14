// lib/features/auth/screens/force_change_password_screen.dart
//
// Premium Material 3 redesign — force change password screen.
// NO business logic changes; same authProvider.changePassword() call.
// Form fields use Validators.password and Validators.confirmPassword.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/utils/extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/logo_widget.dart';

class ForceChangePasswordScreen extends ConsumerStatefulWidget {
  const ForceChangePasswordScreen({super.key});

  @override
  ConsumerState<ForceChangePasswordScreen> createState() =>
      _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState
    extends ConsumerState<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final err = await ref
        .read(authProvider.notifier)
        .changePassword(_currentCtrl.text, _newCtrl.text);
    if (!mounted) return;
    if (err != null) {
      context.showSnack(err, isError: true);
    } else {
      context.showSnack('Password changed successfully! Redirecting...');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final isGlass = context.screenWidth < 900;

    Widget form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.32)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_reset_outlined,
                    color: AppColors.warning,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Change Your Password',
                        style: GoogleFonts.spaceGrotesk(
                          color:
                              isGlass ? Colors.white : const Color(0xFF0F1117),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Required before you can continue.',
                        style: TextStyle(
                          color: isGlass
                              ? Colors.white.withValues(alpha: 0.65)
                              : const Color(0xFF6B7280),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Info banner — default temp password
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.info, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Default temporary password: 12345678',
                    style: TextStyle(
                        color: isGlass
                            ? Colors.white.withValues(alpha: 0.85)
                            : const Color(0xFF374151),
                        fontSize: 13,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Current Password',
            hint: '12345678 (or your current password)',
            controller: _currentCtrl,
            isGlass: isGlass,
            obscureText: true,
            prefixIcon: Icon(Icons.lock_outline,
                size: 18, color: isGlass ? Colors.white54 : null),
            validator: (v) => Validators.required(v, label: 'Current password'),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'New Password',
            hint: 'At least 8 characters',
            controller: _newCtrl,
            isGlass: isGlass,
            obscureText: true,
            prefixIcon: Icon(Icons.lock_open_outlined,
                size: 18, color: isGlass ? Colors.white54 : null),
            validator: (v) {
              if (v == null || v.isEmpty) return 'New password is required';
              if (v.length < 8) return 'Password must be at least 8 characters';
              if (v == '12345678') return 'Choose a different password';
              return null;
            },
            helperText: 'Use at least 8 characters; cannot be 12345678',
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Confirm New Password',
            hint: 'Re-enter your new password',
            controller: _confirmCtrl,
            isGlass: isGlass,
            obscureText: true,
            prefixIcon: Icon(Icons.lock_outline,
                size: 18, color: isGlass ? Colors.white54 : null),
            validator: (v) => Validators.confirmPassword(v, _newCtrl.text),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: AppButton(
              label: 'Change Password',
              isLoading: isLoading,
              width: double.infinity,
              size: AppButtonSize.lg,
              onPressed: _submit,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: ref.read(authProvider.notifier).signOut,
            child: Text(
              'Sign out',
              style: TextStyle(
                color: isGlass ? Colors.white60 : AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (!isGlass) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Center(
          child: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: form,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0533), Color(0xFF2D1B69), Color(0xFF0F1117)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              children: [
                const LogoWidget(size: 48, showName: true),
                const SizedBox(height: 36),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.16)),
                      ),
                      child: form,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
