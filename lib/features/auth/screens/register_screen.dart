// lib/features/auth/screens/register_screen.dart
//
// Premium Material 3 redesign — register screen.
// NO business logic changes; same authProvider.register() call, same routes.
// All form fields now use Validators class with proper error messages.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/utils/extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/logo_widget.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstCtrl = TextEditingController();
  final _middleCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _bdayCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _termsAccepted = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _middleCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _bdayCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 18),
      helpText: 'Select your birthday',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.accent,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _bdayCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      context.showSnack('Please accept the Terms & Conditions', isError: true);
      return;
    }
    final err = await ref.read(authProvider.notifier).register(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          firstName: _firstCtrl.text.trim(),
          lastName: _lastCtrl.text.trim(),
          middleName:
              _middleCtrl.text.trim().isEmpty ? null : _middleCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          birthday: _bdayCtrl.text.trim(),
        );
    if (!mounted) return;
    if (err != null) {
      context.showSnack(err, isError: true);
    } else {
      context.showSnack(
        'Account created successfully! Please sign in.',
        duration: const Duration(seconds: 5),
      );
      context.go(RouteConstants.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final isMobile = context.screenWidth < 900;
    final isDark = context.isDark;

    final cardBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF374151);
    final headColor = isDark ? Colors.white : const Color(0xFF0F1117);
    final subColor = isDark ? Colors.white54 : const Color(0xFF6B7280);
    final borderCol = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final fillColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF7F8FA);
    final iconColor = isDark ? Colors.white38 : const Color(0xFF9CA3AF);

    Widget form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Create Account',
              style: GoogleFonts.spaceGrotesk(
                color: headColor,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.15,
              )),
          const SizedBox(height: 6),
          Text('Join Jireta Loans as a borrower',
              style: TextStyle(color: subColor, fontSize: 14, height: 1.5)),
          const SizedBox(height: 30),
          Row(children: [
            Expanded(
                child: _Field(
              label: 'First Name',
              ctrl: _firstCtrl,
              fillColor: fillColor,
              borderColor: borderCol,
              textColor: bodyColor,
              iconColor: iconColor,
              hint: 'Juan',
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icon(Icons.person_outline_rounded,
                  size: 18, color: iconColor),
              validator: Validators.firstName,
            )),
            const SizedBox(width: 12),
            Expanded(
                child: _Field(
              label: 'Last Name',
              ctrl: _lastCtrl,
              fillColor: fillColor,
              borderColor: borderCol,
              textColor: bodyColor,
              iconColor: iconColor,
              hint: 'Dela Cruz',
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icon(Icons.person_outline_rounded,
                  size: 18, color: iconColor),
              validator: Validators.lastName,
            )),
          ]),
          const SizedBox(height: 14),
          _Field(
            label: 'Middle Name (optional)',
            ctrl: _middleCtrl,
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            iconColor: iconColor,
            hint: 'Reyes',
            textCapitalization: TextCapitalization.words,
            prefixIcon:
                Icon(Icons.person_outline_rounded, size: 18, color: iconColor),
            validator: Validators.middleName,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: _Field(
                label: 'Birthday',
                ctrl: _bdayCtrl,
                fillColor: fillColor,
                borderColor: borderCol,
                textColor: bodyColor,
                iconColor: iconColor,
                hint: 'YYYY-MM-DD',
                prefixIcon:
                    Icon(Icons.cake_outlined, size: 18, color: iconColor),
                suffixIcon: Icon(Icons.calendar_today_outlined,
                    size: 16, color: iconColor),
                validator: Validators.birthday,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Email Address',
            ctrl: _emailCtrl,
            hint: 'you@example.com',
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            iconColor: iconColor,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icon(Icons.email_outlined, size: 18, color: iconColor),
            validator: Validators.email,
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Phone Number (optional)',
            ctrl: _phoneCtrl,
            hint: '09XXXXXXXXX',
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            iconColor: iconColor,
            keyboardType: TextInputType.phone,
            prefixIcon: Icon(Icons.phone_outlined, size: 18, color: iconColor),
            validator: Validators.optionalPhone,
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Password',
            ctrl: _passCtrl,
            hint: 'At least 8 characters',
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            iconColor: iconColor,
            obscureText: _obscurePass,
            prefixIcon: Icon(Icons.lock_outline, size: 18, color: iconColor),
            suffixIcon: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  key: ValueKey(_obscurePass),
                  size: 18,
                  color: iconColor,
                ),
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
              splashRadius: 18,
            ),
            validator: Validators.password,
            helperText: 'Use at least 8 characters',
          ),
          const SizedBox(height: 14),
          _Field(
            label: 'Confirm Password',
            ctrl: _confirmCtrl,
            hint: 'Re-enter your password',
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            iconColor: iconColor,
            obscureText: _obscureConfirm,
            prefixIcon: Icon(Icons.lock_outline, size: 18, color: iconColor),
            suffixIcon: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  key: ValueKey(_obscureConfirm),
                  size: 18,
                  color: iconColor,
                ),
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              splashRadius: 18,
            ),
            validator: (v) => Validators.confirmPassword(v, _passCtrl.text),
          ),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => setState(() => _termsAccepted = !_termsAccepted),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _termsAccepted,
                    onChanged: (v) =>
                        setState(() => _termsAccepted = v ?? false),
                    activeColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                    side: BorderSide(color: borderCol, width: 1.5),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    children: [
                      Text('I agree to the ',
                          style: TextStyle(
                              fontSize: 13, color: bodyColor, height: 1.5)),
                      GestureDetector(
                        onTap: () => context.push(RouteConstants.terms),
                        child: const Text('Terms & Conditions',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                height: 1.5)),
                      ),
                      Text(' and ',
                          style: TextStyle(
                              fontSize: 13, color: bodyColor, height: 1.5)),
                      GestureDetector(
                        onTap: () => context.push(RouteConstants.terms),
                        child: const Text('Privacy Policy',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: AppButton.gradient(
              label: 'Create Account',
              isLoading: isLoading,
              width: double.infinity,
              size: AppButtonSize.lg,
              onPressed: _submit,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ',
                  style: TextStyle(fontSize: 14, color: subColor)),
              GestureDetector(
                onTap: () => context.go(RouteConstants.login),
                child: const Text('Sign In',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F1117) : const Color(0xFFF6F7FB),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                LogoWidget(size: 48, showName: true, darkText: !isDark),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.35 : 0.08),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: form,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Row(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5B4FE9), Color(0xFF3D33C5)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LogoWidget(size: 52, showName: true, darkText: false),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Join Jireta Loans',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  height: 1.15)),
                          SizedBox(height: 14),
                          Text(
                              'Access fast, transparent loans\nwith a 20% flat interest rate.',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.6)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 520,
            color: isDark ? const Color(0xFF111827) : const Color(0xFFF6F7FB),
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 4),
                            ),
                          ],
                    border: Border.all(color: borderCol),
                  ),
                  child: form,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable field widget ────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final Color fillColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final TextCapitalization textCapitalization;
  final String? helperText;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.fillColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? Colors.white70 : const Color(0xFF374151);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: labelColor,
                letterSpacing: 0.1,
                height: 1.2)),
        const SizedBox(height: 7),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: 1,
          textCapitalization: textCapitalization,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: isDark ? Colors.white24 : const Color(0xFF9CA3AF),
                fontSize: 14),
            filled: true,
            fillColor: fillColor,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1.6),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            errorStyle: const TextStyle(
              color: AppColors.error,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(helperText!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                height: 1.4,
              )),
        ],
      ],
    );
  }
}
