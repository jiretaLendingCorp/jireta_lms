// lib/features/auth/screens/register_screen.dart
//
// FIX #1: "Sign In" link now uses context.go(RouteConstants.login) instead of
//         context.pop() so the browser URL changes from /#/register to /#/login.
//         context.pop() on web keeps the URL as /register while showing login UI.
//
// Self-registration for Lenders (borrowers). All calls go via
// AuthNotifier.register() → Supabase Auth signUp → on_auth_user_created
// trigger creates the users row — no direct DB writes from Flutter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    );
    if (picked != null) {
      _bdayCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
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
      final user = ref.read(authProvider).user;
      if (user == null) {
        context.showSnack(
          'Account created! Please sign in to continue.',
          duration: const Duration(seconds: 6),
        );
        // FIX: use go() so URL updates correctly
        if (mounted) context.go(RouteConstants.login);
      }
      // If user is loaded, router redirect handles navigation.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final isMobile = context.screenWidth < 900;
    final isDark = context.isDark;

    final cardBg = isDark ? const Color(0xFF1E2235) : Colors.white;
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF374151);
    final headColor = isDark ? Colors.white : const Color(0xFF111827);
    final subColor = isDark ? Colors.white54 : const Color(0xFF6B7280);
    final borderCol = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final fillColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF9FAFB);

    Widget form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Create Account',
              style: TextStyle(
                  color: headColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('Join Jireta Loans as a borrower',
              style: TextStyle(color: subColor, fontSize: 14)),
          const SizedBox(height: 28),

          // Name row
          Row(children: [
            Expanded(
                child: _Field(
                    label: 'First Name',
                    ctrl: _firstCtrl,
                    fillColor: fillColor,
                    borderColor: borderCol,
                    textColor: bodyColor,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        Validators.required(v, label: 'First name'))),
            const SizedBox(width: 10),
            Expanded(
                child: _Field(
                    label: 'Last Name',
                    ctrl: _lastCtrl,
                    fillColor: fillColor,
                    borderColor: borderCol,
                    textColor: bodyColor,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        Validators.required(v, label: 'Last name'))),
          ]),
          const SizedBox(height: 12),

          _Field(
              label: 'Middle Name (optional)',
              ctrl: _middleCtrl,
              fillColor: fillColor,
              borderColor: borderCol,
              textColor: bodyColor,
              textCapitalization: TextCapitalization.words),
          const SizedBox(height: 12),

          // Birthday
          GestureDetector(
            onTap: _pickDate,
            child: AbsorbPointer(
              child: _Field(
                label: 'Birthday',
                ctrl: _bdayCtrl,
                fillColor: fillColor,
                borderColor: borderCol,
                textColor: bodyColor,
                hint: 'YYYY-MM-DD',
                prefixIcon: Icon(Icons.cake_outlined,
                    size: 18,
                    color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Birthday is required' : null,
              ),
            ),
          ),
          const SizedBox(height: 12),

          _Field(
            label: 'Email',
            ctrl: _emailCtrl,
            hint: 'you@example.com',
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icon(Icons.email_outlined,
                size: 18,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
            validator: Validators.email,
          ),
          const SizedBox(height: 12),

          _Field(
            label: 'Phone (optional)',
            ctrl: _phoneCtrl,
            hint: '09XXXXXXXXX',
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            keyboardType: TextInputType.phone,
            prefixIcon: Icon(Icons.phone_outlined,
                size: 18,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 12),

          _Field(
            label: 'Password',
            ctrl: _passCtrl,
            hint: 'At least 8 characters',
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            obscureText: _obscurePass,
            prefixIcon: Icon(Icons.lock_outline,
                size: 18,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 12),

          _Field(
            label: 'Confirm Password',
            ctrl: _confirmCtrl,
            hint: '••••••••',
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            obscureText: _obscureConfirm,
            prefixIcon: Icon(Icons.lock_outline,
                size: 18,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) => Validators.confirmPassword(v, _passCtrl.text),
          ),
          const SizedBox(height: 20),

          // Terms checkbox
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
                    side: BorderSide(color: borderCol),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    children: [
                      Text('I agree to the ',
                          style: TextStyle(fontSize: 13, color: bodyColor)),
                      GestureDetector(
                        onTap: () => context.push(RouteConstants.terms),
                        child: const Text('Terms & Conditions',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline)),
                      ),
                      Text(' and ',
                          style: TextStyle(fontSize: 13, color: bodyColor)),
                      GestureDetector(
                        onTap: () => context.push(RouteConstants.terms),
                        child: const Text('Privacy Policy',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 50,
            child: AppButton.gradient(
              label: 'Create Account',
              isLoading: isLoading,
              width: double.infinity,
              size: AppButtonSize.lg,
              onPressed: _submit,
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Already have an account? ',
                  style: TextStyle(fontSize: 14, color: subColor)),
              GestureDetector(
                // FIX: was context.pop() — URL stayed on /register.
                // context.go replaces the route so URL shows /login.
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

    // ── Mobile layout ─────────────────────────────────────────────────────────
    if (isMobile) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F1117) : const Color(0xFFF3F4F6),
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
                    border: Border.all(
                        color:
                            isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
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

    // ── Web layout ────────────────────────────────────────────────────────────
    return Scaffold(
      body: Row(
        children: [
          // Left hero panel (identical to login)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4DD0C4), Color(0xFF00897B)],
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
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Join Jireta Loans',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6)),
                          SizedBox(height: 12),
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
          // Right form panel
          Container(
            width: 520,
            color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
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
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final TextCapitalization textCapitalization;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.fillColor,
    required this.borderColor,
    required this.textColor,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    const labelColor = Color(0xFF374151);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.isDark ? Colors.white70 : labelColor)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: 1,
          textCapitalization: textCapitalization,
          style: TextStyle(color: textColor, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color:
                    context.isDark ? Colors.white24 : const Color(0xFF9CA3AF),
                fontSize: 14),
            filled: true,
            fillColor: fillColor,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
      ],
    );
  }
}
