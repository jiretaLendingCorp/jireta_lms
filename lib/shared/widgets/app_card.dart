// lib/shared/widgets/app_card.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Consistent card for Web screens.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? color;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool noPadding;
  final Widget? header;
  final EdgeInsetsGeometry? headerPadding;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.onTap,
    this.width,
    this.height,
    this.noPadding = false,
    this.header,
    this.headerPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ??
        (isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight);
    final border = isDark ? AppColors.webBorderDark : AppColors.webBorderLight;
    final r = BorderRadius.circular(borderRadius ?? 14);
    final effectivePadding =
        noPadding ? EdgeInsets.zero : (padding ?? const EdgeInsets.all(20));

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (header != null) ...[
          Padding(
            padding: headerPadding ??
                const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: header!,
          ),
          const SizedBox(height: 16),
          Divider(
            color: border,
            height: 1,
            thickness: 1,
          ),
          const SizedBox(height: 4),
        ],
        Padding(
          padding: effectivePadding,
          child: child,
        ),
      ],
    );

    Widget card = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: r,
        border: Border.all(color: border),
      ),
      child: content,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Section header with optional action button — used inside cards and pages.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: context.headingStyle),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: context.subtitleStyle),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

extension _ContextStyles on BuildContext {
  TextStyle get headingStyle =>
      Theme.of(this).textTheme.headlineMedium ??
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  TextStyle get subtitleStyle =>
      Theme.of(this).textTheme.bodyMedium ??
      const TextStyle(fontSize: 14);
}

/// Stat row used in card summaries.
class StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool divider;

  const StatRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.divider = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ??
                      (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
        ),
        if (divider)
          Divider(
            height: 1,
            color: isDark
                ? AppColors.webBorderDark
                : AppColors.webBorderLight,
          ),
      ],
    );
  }
}