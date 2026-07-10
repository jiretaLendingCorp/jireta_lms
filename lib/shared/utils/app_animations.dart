// lib/shared/utils/app_animations.dart
// Reusable page-route animations used throughout the app.

import 'package:flutter/material.dart';

class AppAnimations {
  AppAnimations._();

  // Slide up from bottom (for mobile screens)
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  // Fade + scale for dialogs/modals
  static Widget fadeScale({
    required Animation<double> animation,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: child,
      ),
    );
  }
}

/// Mixin that adds a standard fade+slide-up entrance animation to any State.
mixin EntranceAnimationMixin<T extends StatefulWidget> on State<T>,
    SingleTickerProviderStateMixin<T> {
  late final AnimationController entranceCtrl;
  late final Animation<double> fadeAnim;
  late final Animation<Offset> slideAnim;

  void initEntranceAnimation({Duration duration = const Duration(milliseconds: 480)}) {
    entranceCtrl = AnimationController(vsync: this, duration: duration);
    fadeAnim = CurvedAnimation(parent: entranceCtrl, curve: Curves.easeOut);
    slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: entranceCtrl, curve: Curves.easeOutCubic));
    entranceCtrl.forward();
  }

  Widget animateEntrance(Widget child) {
    return FadeTransition(
      opacity: fadeAnim,
      child: SlideTransition(position: slideAnim, child: child),
    );
  }

  @override
  void dispose() {
    entranceCtrl.dispose();
    super.dispose();
  }
}

/// Simple staggered list item animator
class StaggeredItem extends StatelessWidget {
  final int index;
  final Animation<double> parent;
  final Widget child;
  final double staggerStep;

  const StaggeredItem({
    super.key,
    required this.index,
    required this.parent,
    required this.child,
    this.staggerStep = 0.07,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * staggerStep).clamp(0.0, 0.9);
    final end = (start + 0.4).clamp(0.0, 1.0);

    final fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: parent, curve: Interval(start, end, curve: Curves.easeOut)),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: parent, curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}