// lib/features/auth/screens/splash_screen.dart
//
// Premium Material 3 redesign — splash screen.
// NO business logic changes; same routing logic, same auth checks.
// Smoother animation timing and refined visuals.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../shared/models/app_user.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _glow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _ctrl,
          curve: const Interval(0.2, 0.9, curve: Curves.easeOut)),
    );
    _ctrl.forward();

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 600), _navigate);
      }
    });
  }

  void _navigate() {
    if (!mounted) return;
    final authState = ref.read(authProvider);
    if (!authState.initialized) {
      ref.listenManual(authProvider, (_, next) {
        if (next.initialized && mounted) _doRoute();
      });
    } else {
      _doRoute();
    }
  }

  void _doRoute() {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      final role = auth.role;
      switch (role) {
        case UserRole.headManager:
          context.go(RouteConstants.hmDashboard);
          break;
        case UserRole.employee:
          context.go(RouteConstants.empDashboard);
          break;
        case UserRole.rider:
          context.go(RouteConstants.riderHome);
          break;
        default:
          context.go(RouteConstants.lenderHome);
      }
    } else {
      context.go(RouteConstants.login);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1040), Color(0xFF0D0826)],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo with glow ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulsing glow
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.55 * _glow.value),
                                const Color(0xFF7C3AED).withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                        // Logo box
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Image.asset(
                            'assets/images/logo.jpg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF7C3AED),
                              child: const Icon(Icons.account_balance_rounded,
                                  color: Colors.white, size: 60),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Jireta',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Loans & Credit Corp Inc.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 60),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.45),
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
