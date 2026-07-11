// lib/shared/widgets/empty_state.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final bool isGlass;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isGlass
        ? Colors.white.withValues(alpha: 0.3)
        : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight);
    final titleColor = isGlass
        ? Colors.white.withValues(alpha: 0.8)
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final subColor = isGlass
        ? Colors.white.withValues(alpha: 0.5)
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isGlass
                    ? Colors.white.withValues(alpha: 0.06)
                    : (isDark
                        ? AppColors.webBorderSoftDk
                        : AppColors.webBorderSoftL),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: subColor,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with retry button.
class ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorState({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Something went wrong',
      subtitle: message ?? 'Please try again.',
      action: onRetry != null
          ? AppButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              isOutlined: true,
              size: AppButtonSize.sm,
            )
          : null,
    );
  }
}
