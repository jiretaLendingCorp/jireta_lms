// lib/shared/widgets/shimmer_box.dart

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

class ShimmerBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double radius;
  final bool isGlass;

  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.radius = 8,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isGlass
        ? Colors.white.withOpacity(0.08)
        : (isDark
            ? AppColors.webBorderSoftDk
            : const Color(0xFFEBECF0));
    final highlightColor = isGlass
        ? Colors.white.withOpacity(0.16)
        : (isDark
            ? AppColors.webBorderDark
            : const Color(0xFFF5F5F7));

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height ?? 16,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerCard extends StatelessWidget {
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool isGlass;

  const ShimmerCard({
    super.key,
    this.height,
    this.padding,
    this.isGlass = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = padding ?? const EdgeInsets.all(20);
    if (isGlass) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: p,
        child: _shimmerContent(context),
      );
    }
    return Card(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: p,
          child: _shimmerContent(context),
        ),
      ),
    );
  }

  Widget _shimmerContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ShimmerBox(width: 40, height: 40, radius: 10, isGlass: isGlass),
            ShimmerBox(width: 60, height: 22, radius: 12, isGlass: isGlass),
          ],
        ),
        const SizedBox(height: 16),
        ShimmerBox(width: 100, height: 24, radius: 6, isGlass: isGlass),
        const SizedBox(height: 8),
        ShimmerBox(width: 140, height: 14, radius: 4, isGlass: isGlass),
      ],
    );
  }
}

class ShimmerRow extends StatelessWidget {
  final int count;
  const ShimmerRow({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          child: Row(
            children: [
              ShimmerBox(width: 36, height: 36, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(
                      width: double.infinity,
                      height: 13,
                      radius: 4,
                    ),
                    const SizedBox(height: 6),
                    ShimmerBox(width: 180, height: 11, radius: 4),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ShimmerBox(width: 80, height: 13, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}