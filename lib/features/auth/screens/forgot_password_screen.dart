// lib/features/auth/screens/forgot_password_screen.dart
//
// Premium Material 3 redesign — forgot password screen.
// NO business logic changes; same authProvider calls, same routes.
// OTP entry uses Validators.otp; new passwords use Validators.password and confirmPassword.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/utils/extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/logo_widget.dart';

enum _ResetMethod { email, sms }

enum _Stage { request, otpEntry, done }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
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
    // Validate using the same validators used in forms
    final otpErr = Validators.otp(_otpCtrl.text);
    if (otpErr != null) {
      context.showSnack(otpErr, isError: true);
      return;
    }
    final passErr = Validators.password(_newPassCtrl.text);
    if (passErr != null) {
      context.showSnack(passErr, isError: true);
      return;
    }
    final confirmErr =
        Validators.confirmPassword(_confirmPassCtrl.text, _newPassCtrl.text);
    if (confirmErr != null) {
      context.showSnack(confirmErr, isError: true);
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
    final isWeb = context.screenWidth >= 900;
    final isDark = context.isDark;

    final cardBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final borderCol = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

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
          onSubmit: _submitOtpReset,
          onResend: _submitRequest,
        );
        break;
      case _Stage.done:
        content = _SentView(
          method: _method,
          contact:
              _method == _ResetMethod.email ? _emailCtrl.text : _phoneCtrl.text,
        );
        break;
    }

    if (isWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: Center(
          child: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const LogoWidget(size: 52, showName: true, darkText: true),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderCol),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: content,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              const LogoWidget(size: 48, showName: true, darkText: true),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: content,
              ),
            ],
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
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const _RequestForm({
    required this.formKey,
    required this.method,
    required this.onMethodChanged,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.isLoading,
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_reset_outlined,
                    color: AppColors.accent, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reset your password',
                    style: TextStyle(
                      color: Color(0xFF0F1117),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Reset Password',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF0F1117),
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            method == _ResetMethod.email
                ? "We'll email you a password reset link."
                : "We'll send a 6-digit code to your phone via SMS.",
            style: const TextStyle(
                color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _MethodChip(
                  label: 'Email',
                  icon: Icons.email_outlined,
                  selected: method == _ResetMethod.email,
                  onTap: () => onMethodChanged(_ResetMethod.email),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodChip(
                  label: 'SMS',
                  icon: Icons.sms_outlined,
                  selected: method == _ResetMethod.sms,
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
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
            )
          else
            AppTextField(
              label: 'Phone Number',
              hint: '09XXXXXXXXX',
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
            ),
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: AppButton(
              label:
                  method == _ResetMethod.email ? 'Send Reset Link' : 'Send OTP',
              isLoading: isLoading,
              width: double.infinity,
              size: AppButtonSize.lg,
              onPressed: onSubmit,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Login'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
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
  final VoidCallback onTap;

  const _MethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.accent : const Color(0xFF9CA3AF)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.accent : const Color(0xFF6B7280),
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
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  const _OtpForm({
    required this.phone,
    required this.otpCtrl,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.isLoading,
    required this.onSubmit,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF0F1117);
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter Verification Code',
          style: GoogleFonts.spaceGrotesk(
            color: textColor,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to $phone',
          style: const TextStyle(
              color: Color(0xFF6B7280), fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 24),
        Center(
          child: Pinput(
            length: 6,
            controller: otpCtrl,
            defaultPinTheme: defaultPinTheme,
            focusedPinTheme: defaultPinTheme.copyWith(
              decoration: defaultPinTheme.decoration!.copyWith(
                border: Border.all(color: AppColors.accent, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        AppTextField(
          label: 'New Password',
          hint: 'At least 8 characters',
          controller: newPassCtrl,
          obscureText: true,
          prefixIcon: const Icon(Icons.lock_outline, size: 18),
          validator: Validators.password,
          helperText: 'Use at least 8 characters',
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Confirm New Password',
          hint: 'Re-enter your password',
          controller: confirmPassCtrl,
          obscureText: true,
          prefixIcon: const Icon(Icons.lock_outline, size: 18),
          validator: (v) => Validators.confirmPassword(v, newPassCtrl.text),
        ),
        const SizedBox(height: 26),
        SizedBox(
          height: 52,
          child: AppButton(
            label: 'Reset Password',
            isLoading: isLoading,
            width: double.infinity,
            size: AppButtonSize.lg,
            onPressed: onSubmit,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: isLoading ? null : onResend,
          child: const Text('Resend Code',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
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
    final isEmail = method == _ResetMethod.email;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isEmail
                ? Icons.mark_email_read_outlined
                : Icons.check_circle_outline,
            size: 56,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: 26),
        Text(
          isEmail ? 'Check your email' : 'Password Reset!',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFF0F1117),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            height: 1.15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Text(
          isEmail
              ? 'We sent a password reset link to\n$contact'
              : 'Your password has been changed successfully.\nYou can now sign in.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Color(0xFF6B7280), fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 52,
          child: AppButton(
            label: 'Back to Login',
            width: double.infinity,
            size: AppButtonSize.lg,
            onPressed: () => Navigator.pop(context),
            isOutlined: true,
          ),
        ),
      ],
    );
  }
}
