// lib/features/auth/screens/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/utils/extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/logo_widget.dart';
import 'dart:ui';

enum _ResetMethod { email, sms }

enum _Stage { request, otpEntry, done }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  _ResetMethod _method = _ResetMethod.email;
  _Stage _stage = _Stage.request;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    final err = await ref.read(authProvider.notifier).sendForgotPassword(
          email: _method == _ResetMethod.email ? _emailCtrl.text : null,
          phone: _method == _ResetMethod.sms ? _phoneCtrl.text : null,
        );
    if (err != null && mounted) {
      context.showSnack(err, isError: true);
      return;
    }
    setState(() {
      _stage = _method == _ResetMethod.sms ? _Stage.otpEntry : _Stage.done;
    });
  }

  Future<void> _submitOtpReset() async {
    if (_otpCtrl.text.trim().length != 6) {
      context.showSnack('Enter the 6-digit code', isError: true);
      return;
    }
    if (_newPassCtrl.text.length < 8) {
      context.showSnack('Password must be at least 8 characters', isError: true);
      return;
    }
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      context.showSnack('Passwords do not match', isError: true);
      return;
    }

    final err = await ref.read(authProvider.notifier).resetPasswordWithOtp(
          phone: _phoneCtrl.text,
          otp: _otpCtrl.text.trim(),
          newPassword: _newPassCtrl.text,
        );
    if (err != null && mounted) {
      context.showSnack(err, isError: true);
      return;
    }
    setState(() => _stage = _Stage.done);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final isGlass = context.screenWidth < 900;

    Widget content;
    switch (_stage) {
      case _Stage.request:
        content = _RequestForm(
          formKey: _formKey,
          method: _method,
          onMethodChanged: (m) => setState(() => _method = m),
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          isLoading: isLoading,
          isGlass: isGlass,
          onSubmit: _submitRequest,
          onBack: () => Navigator.pop(context),
        );
        break;
      case _Stage.otpEntry:
        content = _OtpForm(
          phone: _phoneCtrl.text,
          otpCtrl: _otpCtrl,
          newPassCtrl: _newPassCtrl,
          confirmPassCtrl: _confirmPassCtrl,
          isLoading: isLoading,
          isGlass: isGlass,
          onSubmit: _submitOtpReset,
          onResend: _submitRequest,
        );
        break;
      case _Stage.done:
        content = _SentView(
          method: _method,
          contact: _method == _ResetMethod.email ? _emailCtrl.text : _phoneCtrl.text,
        );
        break;
    }

    if (!isGlass) {
      return Scaffold(
        body: Center(
          child: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: content,
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
                const SizedBox(height: 40),
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
                      child: content,
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

class _RequestForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final _ResetMethod method;
  final void Function(_ResetMethod) onMethodChanged;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final bool isLoading;
  final bool isGlass;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _RequestForm({
    required this.formKey,
    required this.method,
    required this.onMethodChanged,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.isLoading,
    required this.isGlass,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reset Password',
            style: isGlass
                ? const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)
                : Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          Text(
            method == _ResetMethod.email
                ? "We'll email you a password reset link."
                : "We'll send a 6-digit code to your phone via SMS.",
            style: isGlass
                ? TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)
                : Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MethodChip(
                  label: 'Email',
                  icon: Icons.email_outlined,
                  selected: method == _ResetMethod.email,
                  isGlass: isGlass,
                  onTap: () => onMethodChanged(_ResetMethod.email),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodChip(
                  label: 'SMS',
                  icon: Icons.sms_outlined,
                  selected: method == _ResetMethod.sms,
                  isGlass: isGlass,
                  onTap: () => onMethodChanged(_ResetMethod.sms),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (method == _ResetMethod.email)
            AppTextField(
              label: 'Email',
              hint: 'you@example.com',
              controller: emailCtrl,
              isGlass: isGlass,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              prefixIcon: Icon(Icons.email_outlined,
                  size: 18, color: isGlass ? Colors.white54 : null),
            )
          else
            AppTextField(
              label: 'Phone Number',
              hint: '09XXXXXXXXX',
              controller: phoneCtrl,
              isGlass: isGlass,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              prefixIcon: Icon(Icons.phone_outlined,
                  size: 18, color: isGlass ? Colors.white54 : null),
            ),
          const SizedBox(height: 24),
          AppButton(
            label: method == _ResetMethod.email ? 'Send Reset Link' : 'Send OTP',
            isLoading: isLoading,
            width: double.infinity,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Login'),
            style: TextButton.styleFrom(
              foregroundColor: isGlass ? Colors.white70 : AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isGlass;
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isGlass,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isGlass ? Colors.white : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? (isGlass ? Colors.white.withOpacity(0.15) : AppColors.accent.withOpacity(0.1))
              : (isGlass ? Colors.white.withOpacity(0.05) : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? activeColor
                : (isGlass ? Colors.white24 : AppColors.webBorderLight),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? activeColor : (isGlass ? Colors.white54 : Colors.grey)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? activeColor : (isGlass ? Colors.white54 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpForm extends StatelessWidget {
  final String phone;
  final TextEditingController otpCtrl;
  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final bool isLoading;
  final bool isGlass;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  const _OtpForm({
    required this.phone,
    required this.otpCtrl,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.isLoading,
    required this.isGlass,
    required this.onSubmit,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 48,
      height: 52,
      textStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: isGlass ? Colors.white : AppColors.textPrimaryLight,
      ),
      decoration: BoxDecoration(
        color: isGlass ? Colors.white.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isGlass ? Colors.white.withOpacity(0.2) : AppColors.webBorderLight,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter Verification Code',
          style: isGlass
              ? const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)
              : Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to $phone',
          style: isGlass
              ? TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)
              : Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Center(
          child: Pinput(
            length: 6,
            controller: otpCtrl,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(
                border: Border.all(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          label: 'New Password',
          hint: 'At least 8 characters',
          controller: newPassCtrl,
          isGlass: isGlass,
          obscureText: true,
          prefixIcon: Icon(Icons.lock_outline, size: 18, color: isGlass ? Colors.white54 : null),
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Confirm New Password',
          hint: '••••••••',
          controller: confirmPassCtrl,
          isGlass: isGlass,
          obscureText: true,
          prefixIcon: Icon(Icons.lock_outline, size: 18, color: isGlass ? Colors.white54 : null),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Reset Password',
          isLoading: isLoading,
          width: double.infinity,
          onPressed: onSubmit,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: isLoading ? null : onResend,
          child: Text(
            'Resend Code',
            style: TextStyle(
              color: isGlass ? Colors.white70 : AppColors.accent,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _SentView extends StatelessWidget {
  final _ResetMethod method;
  final String contact;
  const _SentView({required this.method, required this.contact});

  @override
  Widget build(BuildContext context) {
    final isGlass = context.screenWidth < 900;
    final isEmail = method == _ResetMethod.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEmail ? Icons.mark_email_read_outlined : Icons.check_circle_outline,
            size: 48,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isEmail ? 'Check your email' : 'Password Reset!',
          style: isGlass
              ? const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)
              : Theme.of(context).textTheme.displaySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          isEmail
              ? 'We sent a password reset link to\n$contact'
              : 'Your password has been changed successfully.\nYou can now sign in.',
          textAlign: TextAlign.center,
          style: isGlass
              ? TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)
              : Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        AppButton(
          label: 'Back to Login',
          width: double.infinity,
          onPressed: () => Navigator.pop(context),
          isOutlined: true,
        ),
      ],
    );
  }
}