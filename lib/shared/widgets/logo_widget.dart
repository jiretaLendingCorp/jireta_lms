// lib/shared/widgets/logo_widget.dart

import 'package:flutter/material.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final bool showName;
  final bool darkText;

  const LogoWidget({
    super.key,
    this.size = 48,
    this.showName = true,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.2),
          child: Image.asset(
            'assets/images/logo.jpg',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showName) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Jireta Loans',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w700,
                  color: darkText ? const Color(0xFF0F1117) : Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Credit Corp Inc.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: size * 0.25,
                  fontWeight: FontWeight.w400,
                  color: darkText
                      ? const Color(0xFF6B7280)
                      : Colors.white.withOpacity(0.7),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class LogoIcon extends StatelessWidget {
  final double size;

  const LogoIcon({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.2),
      child: Image.asset(
        'assets/images/logo.jpg',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}