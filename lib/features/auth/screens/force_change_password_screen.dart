// lib/features/auth/screens/force_change_password_screen.dart
//
// FIX #9:
//  - Replaced deprecated .withOpacity() with .withValues(alpha:) throughout.
//  - The router already redirects any authenticated user with
//    forcePasswordChange == true to this screen. No changes needed in the router.
//  - After successful changePassword(), _loadProfile() reloads the user profile
//    from the backend. The backend clears force_password_change = false on the
//    users table via the auth-profile/change-password Edge Function.
//  - The router then automatically redirects to the user's home screen because
//    needsForceChange becomes false.
//  - Default temporary password is shown as a hint so the user knows it is 12345678.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
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
      // Router listener on authProvider will redirect automatically once
      // forcePasswordChange becomes false after profile reload.
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
          const Icon(
            Icons.lock_reset_outlined,
            size: 48,
            color: AppColors.warning,
          ),
          const SizedBox(height: 20),
          Text(
            'Change Your Password',
            style: isGlass
                ? const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)
                : Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Your account requires a password change before you can continue.',
            style: isGlass
                ? TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 14)
                : Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          // FIX #9: Show the default temp password as a hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.warning.withValues(alpha: 0.30)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Default temporary password: 12345678',
                  style: TextStyle(
                      color: isGlass
                          ? Colors.white.withValues(alpha: 0.85)
                          : Colors.black87,
                      fontSize: 13),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Current Password',
            hint: '12345678 (or your current password)',
            controller: _currentCtrl,
            isGlass: isGlass,
            obscureText: true,
            prefixIcon: Icon(Icons.lock_outline,
                size: 18, color: isGlass ? Colors.white54 : null),
            validator: (v) =>
                v == null || v.isEmpty ? 'Current password is required' : null,
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
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Confirm New Password',
            hint: '••••••••',
            controller: _confirmCtrl,
            isGlass: isGlass,
            obscureText: true,
            prefixIcon: Icon(Icons.lock_outline,
                size: 18, color: isGlass ? Colors.white54 : null),
            validator: (v) => Validators.confirmPassword(v, _newCtrl.text),
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Change Password',
            isLoading: isLoading,
            width: double.infinity,
            onPressed: _submit,
            fontSize: 15,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: ref.read(authProvider.notifier).signOut,
            child: Text(
              'Sign out',
              style: TextStyle(
                color: isGlass ? Colors.white60 : AppColors.error,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    if (!isGlass) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: form,
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
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15)),
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
