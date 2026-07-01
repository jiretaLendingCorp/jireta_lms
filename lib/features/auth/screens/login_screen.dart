// lib/features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../core/constants/app_icons.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/validators.dart';
import '../../../shared/utils/extensions.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
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
    if (err != null && mounted) {
      context.showSnack(err, isError: true);
    }
  }

  Future<void> _googleSignIn() async {
    final err = await ref.read(authProvider.notifier).signInWithGoogle();
    if (err != null && mounted) {
      context.showSnack(err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.isWeb) return _WebLogin(this);
    return _MobileLogin(this);
  }
}

// ── Web Layout ────────────────────────────────────────────────────────────────

class _WebLogin extends StatelessWidget {
  final _LoginScreenState s;
  const _WebLogin(this.s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left hero panel
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2D1B69),
                    AppColors.accent,
                    Color(0xFF1A0A4A),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Decorative circles
                  Positioned(
                    top: -80,
                    left: -80,
                    child: _DecorCircle(size: 320, opacity: 0.06),
                  ),
                  Positioned(
                    bottom: -60,
                    right: -40,
                    child: _DecorCircle(size: 260, opacity: 0.07),
                  ),
                  Positioned(
                    top: 160,
                    right: -30,
                    child: _DecorCircle(size: 160, opacity: 0.05),
                  ),
                  // Content
                  Padding(
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
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lending Management\nSystem',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Streamline your lending operations\nwith precision and control.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                        _FeatureRow(
                          icon: AppIcons.shieldOk,
                          label: 'Bank-grade security & encryption',
                        ),
                        const SizedBox(height: 14),
                        _FeatureRow(
                          icon: AppIcons.trendUp,
                          label: 'Real-time portfolio analytics',
                        ),
                        const SizedBox(height: 14),
                        _FeatureRow(
                          icon: AppIcons.coins,
                          label: 'Automated billing & collections',
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right form panel — same glassmorphic gradient treatment as mobile
          Container(
            width: context.isDesktop ? 500 : 440,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A0533),
                  Color(0xFF2D1B69),
                  Color(0xFF0F1117),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -90,
                  right: -70,
                  child: _DecorCircle(size: 240, opacity: 0.06),
                ),
                Positioned(
                  bottom: -60,
                  left: -50,
                  child: _DecorCircle(size: 200, opacity: 0.05),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 40,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: _LoginForm(s: s, isGlass: true),
                          ),
                        ),
                      ),
                    ),
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

class _DecorCircle extends StatelessWidget {
  final double size;
  final double opacity;
  const _DecorCircle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ── Mobile Layout ─────────────────────────────────────────────────────────────

class _MobileLogin extends StatelessWidget {
  final _LoginScreenState s;
  const _MobileLogin(this.s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0533),
              Color(0xFF2D1B69),
              Color(0xFF0F1117),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -80,
              child: _DecorCircle(size: 280, opacity: 0.08),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: _DecorCircle(size: 220, opacity: 0.06),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Column(
                    children: [
                      const LogoWidget(size: 52, showName: true),
                      const SizedBox(height: 40),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.14),
                              ),
                            ),
                            child: _LoginForm(s: s, isGlass: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Form ───────────────────────────────────────────────────────────────

class _LoginForm extends ConsumerWidget {
  final _LoginScreenState s;
  final bool isGlass;
  const _LoginForm({required this.s, required this.isGlass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authProvider).isLoading;

    return Form(
      key: s._formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Heading
          Text(
            'Welcome back',
            style: isGlass
                ? const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  )
                : context.textTheme.displaySmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to your account',
            style: TextStyle(
              color: isGlass
                  ? Colors.white.withValues(alpha: 0.55)
                  : context.textTheme.bodyMedium?.color,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Email
          AppTextField(
            label: 'Email address',
            hint: 'you@example.com',
            controller: s._emailCtrl,
            keyboardType: TextInputType.emailAddress,
            isGlass: isGlass,
            prefixIcon: Icon(
              AppIcons.email,
              size: 18,
              color: isGlass ? Colors.white54 : null,
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),

          // Password
          AppTextField(
            label: 'Password',
            hint: '••••••••',
            controller: s._passCtrl,
            obscureText: true,
            isGlass: isGlass,
            prefixIcon: Icon(
              AppIcons.lock,
              size: 18,
              color: isGlass ? Colors.white54 : null,
            ),
            validator: (v) =>
                v == null || v.isEmpty ? 'Password is required' : null,
          ),
          const SizedBox(height: 8),

          // Forgot password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push(RouteConstants.forgotPassword),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot password?',
                style: TextStyle(
                  color:
                      isGlass ? Colors.white60 : AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sign In button
          AppButton.gradient(
            label: 'Sign In',
            isLoading: isLoading,
            width: double.infinity,
            size: AppButtonSize.lg,
            onPressed: s._submit,
          ),
          const SizedBox(height: 20),

          // Divider OR
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isGlass
                      ? Colors.white.withValues(alpha: 0.18)
                      : context.theme.dividerColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: isGlass
                        ? Colors.white.withValues(alpha: 0.35)
                        : context.textTheme.bodySmall?.color,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isGlass
                      ? Colors.white.withValues(alpha: 0.18)
                      : context.theme.dividerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Continue with Google — uses the actual asset PNG
          _GoogleSignInButton(
            isLoading: isLoading,
            isGlass: isGlass,
            onPressed: s._googleSignIn,
          ),
          const SizedBox(height: 28),

          // Register link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: isGlass ? Colors.white54 : null,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () => context.push(RouteConstants.register),
                child: Text(
                  'Register',
                  style: TextStyle(
                    color: isGlass ? Colors.white : AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Google Sign-In Button ─────────────────────────────────────────────────────

class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final bool isGlass;
  final VoidCallback onPressed;

  const _GoogleSignInButton({
    required this.isLoading,
    required this.isGlass,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isGlass
        ? Colors.white.withValues(alpha: 0.22)
        : AppColors.webBorderLight;
    final bgColor = isGlass
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white;
    final textColor = isGlass ? Colors.white : const Color(0xFF3C4043);

    return SizedBox(
      height: 52,
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
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: isGlass
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Use the actual Google logo from assets
                  Image.asset(
                    'assets/images/continue with google.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}