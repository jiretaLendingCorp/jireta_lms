// lib/features/head_manager/widgets/kpi_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_icons.dart';
import '../../../core/theme/app_colors.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final double? change;
  final bool isCurrency;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.change,
    this.isCurrency = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = iconColor ?? AppColors.accent;
    final isPositive = (change ?? 0) >= 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.webBorderDark : AppColors.webBorderLight,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon badge
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              // Change badge
              if (change != null)
                _ChangeBadge(value: change!, isPositive: isPositive),
            ],
          ),
          const SizedBox(height: 16),
          // Value
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final double value;
  final bool isPositive;
  const _ChangeBadge({required this.value, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? AppIcons.trendUp : AppIcons.trendDown,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${value.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive KPI grid that adapts columns based on screen width.
/// Uses Wrap instead of GridView.count to avoid the ink-renderer GlobalKey
/// collision that occurs when GridView rebuilds inside SingleChildScrollView.
class KpiGrid extends StatelessWidget {
  final List<KpiCard> cards;
  const KpiGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;
    return LayoutBuilder(
      builder: (_, constraints) {
        final available = constraints.maxWidth;
        final cols = available >= 1100
            ? 4
            : available >= 800
                ? 3
                : available >= 520
                    ? 2
                    : 1;
        final itemWidth =
            (available - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards.map((card) {
            return SizedBox(width: itemWidth, child: card);
          }).toList(),
        );
      },
    );
  }
}