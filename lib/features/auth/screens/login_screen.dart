// lib/features/auth/screens/login_screen.dart
//
// FIX #1: Changed context.push(RouteConstants.register) to
//         context.go(RouteConstants.register) so the browser URL
//         updates from /#/login to /#/register on web.
//
// Two-panel web layout (gradient left + white-card right).
// Mobile: clean white/dark card.  Dark mode works correctly on both.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/utils/extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/logo_widget.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  void toggleObscure() => setState(() => _obscure = !_obscure);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final err = await ref
        .read(authProvider.notifier)
        .signIn(_emailCtrl.text, _passCtrl.text);
    if (err != null && mounted) context.showSnack(err, isError: true);
  }

  Future<void> _googleSignIn() async {
    final err = await ref.read(authProvider.notifier).signInWithGoogle();
    if (err != null && mounted) context.showSnack(err, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.screenWidth < 900;
    if (isMobile) return _MobileLayout(s: this);
    return _WebLayout(s: this);
  }
}

// ── Web Layout ────────────────────────────────────────────────────────────────

class _WebLayout extends StatefulWidget {
  final _LoginScreenState s;
  const _WebLayout({required this.s});

  @override
  State<_WebLayout> createState() => _WebLayoutState();
}

class _WebLayoutState extends State<_WebLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 750));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              width: 880,
              constraints: const BoxConstraints(maxHeight: 640),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 56,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Row(
                  children: [
                    // ── Left: teal welcome panel ──────────────────────────
                    const _WelcomePanel(),
                    // ── Right: white form panel ───────────────────────────
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 44, vertical: 36),
                          child: _LoginForm(s: widget.s),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Welcome panel (left side of web card) ─────────────────────────────────────

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4DD0C4), Color(0xFF00897B)],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -70,
            right: -70,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo at top
                const LogoWidget(size: 52, showName: false),
                const SizedBox(height: 22),
                // Welcome heading
                const Text(
                  'Welcome\nBack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Jireta Lending\nManagement System',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.55,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 36),
                // Feature chips
                const _WelcomeChip(
                    icon: Icons.people_outline_rounded, label: 'Lender Portal'),
                const SizedBox(height: 10),
                const _WelcomeChip(
                    icon: Icons.attach_money_rounded, label: 'Loan Management'),
                const SizedBox(height: 10),
                const _WelcomeChip(
                    icon: Icons.route_rounded, label: 'Rider Collections'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WelcomeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Mobile Layout ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final _LoginScreenState s;
  const _MobileLayout({required this.s});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    const cardBg = Colors.white;
    const borderCol = Color(0xFFE5E7EB);
    final scaffoldBg =
        isDark ? const Color(0xFF0F1117) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              LogoWidget(size: 52, showName: true, darkText: !isDark),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderCol),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _LoginForm(s: s, forceLight: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared Form ───────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerWidget {
  final _LoginScreenState s;
  final bool forceLight;
  const _LoginForm({required this.s, this.forceLight = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authProvider).isLoading;
    const headColor = Color(0xFF111827);
    const subColor = Color(0xFF6B7280);
    const bodyColor = Color(0xFF374151);
    const fillColor = Color(0xFFF9FAFB);
    const borderCol = Color(0xFFE5E7EB);
    const iconColor = Color(0xFF9CA3AF);
    const dividerCol = Color(0xFFE5E7EB);
    const orColor = Color(0xFF9CA3AF);

    return Form(
      key: s._formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Welcome back',
              style: TextStyle(
                  color: headColor,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4)),
          const SizedBox(height: 6),
          const Text('Sign in to your account',
              style: TextStyle(color: subColor, fontSize: 14)),
          const SizedBox(height: 32),

          // Email
          _FormField(
            label: 'Email address',
            hint: 'you@example.com',
            ctrl: s._emailCtrl,
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(AppIcons.email, size: 18, color: iconColor),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),

          // Password
          _FormField(
            label: 'Password',
            hint: '••••••••',
            ctrl: s._passCtrl,
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            obscureText: s._obscure,
            prefixIcon: const Icon(AppIcons.lock, size: 18, color: iconColor),
            suffixIcon: IconButton(
              icon: Icon(
                s._obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: iconColor,
              ),
              onPressed: s.toggleObscure,
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Password is required' : null,
          ),
          const SizedBox(height: 8),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              // Keep push for forgot password (it's a sub-page, not a sibling)
              onPressed: () => context.push(RouteConstants.forgotPassword),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Forgot password?',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(height: 20),

          // Sign In button
          SizedBox(
            height: 50,
            child: AppButton.gradient(
              label: 'Sign In',
              isLoading: isLoading,
              width: double.infinity,
              size: AppButtonSize.lg,
              onPressed: s._submit,
            ),
          ),
          const SizedBox(height: 20),

          // OR divider
          const Row(
            children: [
              Expanded(child: Divider(color: dividerCol)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Text('OR',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: orColor)),
              ),
              Expanded(child: Divider(color: dividerCol)),
            ],
          ),
          const SizedBox(height: 20),

          // Google button
          _GoogleSignInButton(
            isLoading: isLoading,
            onPressed: s._googleSignIn,
          ),
          const SizedBox(height: 28),

          // Register link — FIX: use context.go() so the browser URL updates
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account? ",
                  style: TextStyle(color: subColor, fontSize: 14)),
              GestureDetector(
                // FIX: was context.push — browser URL stayed on /login.
                // context.go replaces the current route so URL shows /register.
                onTap: () => context.go(RouteConstants.register),
                child: const Text('Register',
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
  }
}

// ── Form field widget ─────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController ctrl;
  final Color fillColor;
  final Color borderColor;
  final Color textColor;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;

  const _FormField({
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(color: textColor, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
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
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
      ],
    );
  }
}

// ── Google Sign-In Button ─────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    const bgColor = Colors.white;
    const textColor = Color(0xFF3C4043);
    const borderCol = Color(0xFFDADCE0);

    return SizedBox(
      height: 50,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedOpacity(
            opacity: isLoading ? 0.55 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderCol, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/continue with google.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  const Text('Continue with Google',
                      style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}