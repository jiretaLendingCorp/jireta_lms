// lib/features/auth/screens/register_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../core/constants/route_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/utils/extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/logo_widget.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _termsAccepted = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      context.showSnack('Please accept the Terms & Conditions', isError: true);
      return;
    }
    final err = await ref.read(authProvider.notifier).register(
          email: _emailCtrl.text,
          password: _passCtrl.text,
          firstName: _firstCtrl.text.trim(),
          lastName: _lastCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
    if (err != null && mounted) {
      context.showSnack(err, isError: true);
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
          Text(
            'Create Account',
            style: isGlass
                ? const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700)
                : Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Join Jireta Loans as a borrower',
            style: isGlass
                ? TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)
                : Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'First Name',
                  controller: _firstCtrl,
                  isGlass: isGlass,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => Validators.required(v, label: 'First name'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Last Name',
                  controller: _lastCtrl,
                  isGlass: isGlass,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => Validators.required(v, label: 'Last name'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Email',
            hint: 'you@example.com',
            controller: _emailCtrl,
            isGlass: isGlass,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            prefixIcon: Icon(Icons.email_outlined,
                size: 18, color: isGlass ? Colors.white54 : null),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Phone (optional)',
            hint: '09XXXXXXXXX',
            controller: _phoneCtrl,
            isGlass: isGlass,
            keyboardType: TextInputType.phone,
            prefixIcon: Icon(Icons.phone_outlined,
                size: 18, color: isGlass ? Colors.white54 : null),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Password',
            hint: 'At least 8 characters',
            controller: _passCtrl,
            isGlass: isGlass,
            obscureText: true,
            validator: Validators.password,
            prefixIcon: Icon(Icons.lock_outline,
                size: 18, color: isGlass ? Colors.white54 : null),
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Confirm Password',
            hint: '••••••••',
            controller: _confirmCtrl,
            isGlass: isGlass,
            obscureText: true,
            validator: (v) => Validators.confirmPassword(v, _passCtrl.text),
            prefixIcon: Icon(Icons.lock_outline,
                size: 18, color: isGlass ? Colors.white54 : null),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _termsAccepted = !_termsAccepted),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _termsAccepted,
                    onChanged: (v) =>
                        setState(() => _termsAccepted = v ?? false),
                    activeColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    children: [
                      Text(
                        'I agree to the ',
                        style: TextStyle(
                          fontSize: 13,
                          color: isGlass ? Colors.white70 : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push(RouteConstants.terms),
                        child: Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            fontSize: 13,
                            color: isGlass ? Colors.white : AppColors.accent,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        ' and ',
                        style: TextStyle(
                          fontSize: 13,
                          color: isGlass ? Colors.white70 : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push(RouteConstants.terms),
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 13,
                            color: isGlass ? Colors.white : AppColors.accent,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Create Account',
            isLoading: isLoading,
            width: double.infinity,
            onPressed: _submit,
            fontSize: 15,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(
                  fontSize: 14,
                  color: isGlass ? Colors.white60 : null,
                ),
              ),
              TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Sign In',
                  style: TextStyle(
                    color: isGlass ? Colors.white : AppColors.accent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!isGlass) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 480,
            child: SingleChildScrollView(padding: const EdgeInsets.all(48), child: form),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const LogoWidget(size: 48, showName: true),
                const SizedBox(height: 32),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
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