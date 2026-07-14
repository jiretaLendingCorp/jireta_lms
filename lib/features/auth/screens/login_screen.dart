// lib/features/auth/screens/login_screen.dart
//
// Premium Material 3 redesign — login screen (web + mobile).
// NO business logic changes; same authProvider calls, same routes, same Supabase flow.
// Form fields now require validation, animated focus, accessible labels.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
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
      backgroundColor: const Color(0xFFF6F7FB),
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              width: 920,
              constraints: const BoxConstraints(maxHeight: 660),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 60,
                    offset: const Offset(0, 24),
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 0),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Row(
                  children: [
                    const _WelcomePanel(),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 48, vertical: 40),
                          child:
                              _LoginForm(s: widget.s, onWhiteBackground: true),
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
      width: 340,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B4FE9), Color(0xFF3D33C5)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: 40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LogoWidget(size: 52, showName: false),
                const SizedBox(height: 28),
                const Text(
                  'Welcome\nBack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 44,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Jireta Lending\nManagement System',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    height: 1.55,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 40),
                const _WelcomeChip(
                    icon: Icons.people_outline_rounded, label: 'Lender Portal'),
                const SizedBox(height: 10),
                const _WelcomeChip(
                    icon: Icons.attach_money_rounded, label: 'Loan Management'),
                const SizedBox(height: 10),
                const _WelcomeChip(
                    icon: Icons.route_rounded, label: 'Rider Collections'),
                const Spacer(),
                Text(
                  '© 2025 Jireta Loans',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
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
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1)),
        ],
      ),
    );
  }
}

// ── Mobile Layout — clean, no card ────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  final _LoginScreenState s;
  const _MobileLayout({required this.s});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  56,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 56),
                  LogoWidget(size: 52, showName: true, darkText: !isDark),
                  const SizedBox(height: 48),
                  _LoginForm(s: s, onWhiteBackground: !isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared Form ───────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerStatefulWidget {
  final _LoginScreenState s;
  final bool onWhiteBackground;
  const _LoginForm({required this.s, this.onWhiteBackground = false});

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  bool _emailFocused = false;
  bool _passFocused = false;

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider).isLoading;
    final isDark = context.isDark && !widget.onWhiteBackground;

    final headColor = isDark ? Colors.white : const Color(0xFF0F1117);
    final subColor = isDark ? Colors.white60 : const Color(0xFF6B7280);
    final bodyColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final fillColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF7F8FA);
    final borderCol = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final iconColor = isDark ? Colors.white38 : const Color(0xFF9CA3AF);

    return Form(
      key: widget.s._formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Welcome back',
              style: GoogleFonts.spaceGrotesk(
                color: headColor,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.15,
              )),
          const SizedBox(height: 8),
          Text('Sign in to your account to continue',
              style: TextStyle(color: subColor, fontSize: 14, height: 1.5)),
          const SizedBox(height: 36),
          _FormField(
            label: 'Email address',
            hint: 'you@example.com',
            ctrl: widget.s._emailCtrl,
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            labelColor: bodyColor,
            iconColor: iconColor,
            isFocused: _emailFocused,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            prefixIcon: Icon(AppIcons.email, size: 18, color: iconColor),
            validator: Validators.email,
            onFocusChange: (v) => setState(() => _emailFocused = v),
          ),
          const SizedBox(height: 16),
          _FormField(
            label: 'Password',
            hint: 'Enter your password',
            ctrl: widget.s._passCtrl,
            fillColor: fillColor,
            borderColor: borderCol,
            textColor: bodyColor,
            labelColor: bodyColor,
            iconColor: iconColor,
            isFocused: _passFocused,
            obscureText: widget.s._obscure,
            textInputAction: TextInputAction.done,
            prefixIcon: Icon(AppIcons.lock, size: 18, color: iconColor),
            suffixIcon: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  widget.s._obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  key: ValueKey(widget.s._obscure),
                  size: 18,
                  color: iconColor,
                ),
              ),
              onPressed: widget.s.toggleObscure,
              splashRadius: 18,
              tooltip: widget.s._obscure ? 'Show password' : 'Hide password',
            ),
            validator: Validators.password,
            onFocusChange: (v) => setState(() => _passFocused = v),
            onSubmitted: (_) => widget.s._submit(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(RouteConstants.forgotPassword),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Forgot password?',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 52,
            child: AppButton.gradient(
              label: 'Sign In',
              isLoading: isLoading,
              width: double.infinity,
              size: AppButtonSize.lg,
              onPressed: widget.s._submit,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                  child: Divider(
                      color:
                          isDark ? Colors.white12 : const Color(0xFFE5E7EB))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text('OR',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                        color:
                            isDark ? Colors.white38 : const Color(0xFF9CA3AF))),
              ),
              Expanded(
                  child: Divider(
                      color:
                          isDark ? Colors.white12 : const Color(0xFFE5E7EB))),
            ],
          ),
          const SizedBox(height: 22),
          _GoogleSignInButton(
            isLoading: isLoading,
            onPressed: widget.s._googleSignIn,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ",
                  style: TextStyle(color: subColor, fontSize: 14)),
              GestureDetector(
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
  final Color labelColor;
  final Color iconColor;
  final TextInputType keyboardType;
  final bool obscureText;
  final bool isFocused;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final ValueChanged<bool>? onFocusChange;
  final void Function(String)? onSubmitted;
  final TextInputAction? textInputAction;

  const _FormField({
    required this.label,
    required this.ctrl,
    required this.fillColor,
    required this.borderColor,
    required this.textColor,
    required this.labelColor,
    required this.iconColor,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.isFocused = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onFocusChange,
    this.onSubmitted,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
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
        Focus(
          onFocusChange: onFocusChange,
          child: TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
            validator: validator,
            textInputAction: textInputAction,
            onFieldSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: borderColor, fontSize: 14),
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
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: AppColors.error, width: 1.6),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              errorStyle: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                height: 1.4,
              ),
            ),
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
      height: 52,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedOpacity(
            opacity: isLoading ? 0.55 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
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
