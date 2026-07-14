// lib/shared/widgets/app_button.dart
//
// Premium Material 3 styled button kit:
//   • AppButton          — filled / outlined / gradient / danger variants
//   • AppTextButton      — minimal text link button
//
// All variants use 12–14px corner radius, smooth press animations,
// haptic feedback on tap, and animated loading state.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

enum AppButtonSize { sm, md, lg }

enum AppButtonVariant { filled, outlined, ghost, danger, success }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final bool isDanger;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color? color;
  final Color? textColor;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final double? fontSize;
  final AppButtonSize size;
  final bool useGradient;
  final List<Color>? gradientColors;
  final double? borderRadius;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDanger = false,
    this.icon,
    this.trailingIcon,
    this.color,
    this.textColor,
    this.width,
    this.padding,
    this.fontSize,
    this.size = AppButtonSize.md,
    this.useGradient = false,
    this.gradientColors,
    this.borderRadius,
  });

  factory AppButton.gradient({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    AppButtonSize size = AppButtonSize.md,
    List<Color>? gradientColors,
    Color? color,
    Color? textColor,
  }) {
    // If a single `color` is provided, derive a two-tone gradient from it.
    final base = color ?? AppColors.accent;
    final dark = Color.lerp(base, Colors.black, 0.18) ?? AppColors.accentDark;
    final effectiveGradient = gradientColors ?? [base, dark];
    return AppButton(
      key: key,
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      width: width,
      size: size,
      useGradient: true,
      gradientColors: effectiveGradient,
      color: color,
      textColor: textColor,
    );
  }

  factory AppButton.danger({
    Key? key,
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
    IconData? icon,
    double? width,
    bool isOutlined = false,
  }) {
    return AppButton(
      key: key,
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      isDanger: true,
      icon: icon,
      width: width,
      isOutlined: isOutlined,
    );
  }

  EdgeInsets get _effectivePadding {
    if (padding != null) return padding as EdgeInsets;
    switch (size) {
      case AppButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
      case AppButtonSize.md:
        return const EdgeInsets.symmetric(horizontal: 22, vertical: 14);
      case AppButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 28, vertical: 17);
    }
  }

  double get _effectiveFontSize {
    if (fontSize != null) return fontSize!;
    switch (size) {
      case AppButtonSize.sm:
        return 13;
      case AppButtonSize.md:
        return 14;
      case AppButtonSize.lg:
        return 16;
    }
  }

  double get _iconSize {
    switch (size) {
      case AppButtonSize.sm:
        return 16;
      case AppButtonSize.md:
        return 18;
      case AppButtonSize.lg:
        return 20;
    }
  }

  double get _loaderSize {
    switch (size) {
      case AppButtonSize.sm:
        return 14;
      case AppButtonSize.md:
        return 17;
      case AppButtonSize.lg:
        return 20;
    }
  }

  double get _radius => borderRadius ?? 12;

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? (isDanger ? AppColors.error : AppColors.accent);
    final effectiveTextColor = textColor ?? Colors.white;

    Widget child;
    if (isLoading) {
      child = SizedBox(
        height: _loaderSize,
        width: _loaderSize,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(
            isOutlined ? effectiveColor : effectiveTextColor,
          ),
        ),
      );
    } else {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _iconSize),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: _effectiveFontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.2,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 8),
            Icon(trailingIcon, size: _iconSize),
          ],
        ],
      );
    }

    if (isOutlined) {
      return SizedBox(
        width: width,
        child: OutlinedButton(
          onPressed: isLoading
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: effectiveColor,
            disabledForegroundColor: effectiveColor.withValues(alpha: 0.4),
            side: BorderSide(color: effectiveColor.withValues(alpha: 0.6)),
            padding: _effectivePadding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius),
            ),
          ),
          child: child,
        ),
      );
    }

    if (useGradient) {
      final colors = gradientColors ?? [AppColors.accent, AppColors.accentDark];
      return SizedBox(
        width: width,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: onPressed == null || isLoading
                ? null
                : LinearGradient(
                    colors: colors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: onPressed == null || isLoading
                ? effectiveColor.withValues(alpha: 0.5)
                : null,
            borderRadius: BorderRadius.circular(_radius),
            boxShadow: onPressed != null && !isLoading
                ? [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: ElevatedButton(
            onPressed: isLoading
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onPressed?.call();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: effectiveTextColor,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor:
                  effectiveTextColor.withValues(alpha: 0.6),
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: _effectivePadding,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius),
              ),
            ),
            child: child,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed?.call();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: effectiveColor,
          foregroundColor: effectiveTextColor,
          disabledBackgroundColor: effectiveColor.withValues(alpha: 0.45),
          disabledForegroundColor: effectiveTextColor.withValues(alpha: 0.7),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: _effectivePadding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
        ),
        child: child,
      ),
    );
  }
}

class AppTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double? fontSize;
  final FontWeight? fontWeight;
  final IconData? icon;

  const AppTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.fontSize,
    this.fontWeight,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color ?? AppColors.accent),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color ?? AppColors.accent,
              fontSize: fontSize ?? 14,
              fontWeight: fontWeight ?? FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
