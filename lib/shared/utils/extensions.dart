// lib/shared/utils/extensions.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

extension StringX on String {
  String get capitalized =>
      isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : this;

  String get titleCase =>
      split(' ').map((w) => w.isNotEmpty ? w.capitalized : w).join(' ');

  bool get isValidEmail =>
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
          .hasMatch(this);

  bool get isValidPhone =>
      RegExp(r'^(09|\+639)\d{9}$').hasMatch(replaceAll(' ', ''));

  String get masked {
    if (length <= 4) return replaceAll(RegExp(r'.'), '*');
    return '${substring(0, 2)}${'*' * (length - 4)}${substring(length - 2)}';
  }

  String get snakeToLabel => replaceAll('_', ' ').titleCase;
}

extension DoubleX on double {
  String get toPeso {
    final f = NumberFormat('#,##0.00', 'en_PH');
    return '₱${f.format(this)}';
  }

  String get toPesoCompact {
    if (this >= 1000000) {
      return '₱${(this / 1000000).toStringAsFixed(1)}M';
    } else if (this >= 1000) {
      return '₱${(this / 1000).toStringAsFixed(1)}K';
    }
    return toPeso;
  }

  String get toPercent => '${(this * 100).toStringAsFixed(1)}%';

  String get toPercentDirect => '${toStringAsFixed(1)}%';
}

extension DateTimeX on DateTime {
  String get toDisplayDate => DateFormat('MMM d, yyyy').format(this);

  String get toDisplayDateShort => DateFormat('MMM d').format(this);

  String get toDisplayDateTime => DateFormat('MMM d, yyyy h:mm a').format(this);

  String get toDisplayTime => DateFormat('h:mm a').format(this);

  String get toRelative {
    final now = DateTime.now();
    final diff = now.difference(this);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return toDisplayDate;
  }

  String get toApiDate => DateFormat('yyyy-MM-dd').format(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
}

// Null-safe variants so `nullable?.toDisplayDate` works without ?.
extension DateTimeNullX on DateTime? {
  String get toDisplayDate =>
      this != null ? DateFormat('MMM d, yyyy').format(this!) : '—';
  String get toDisplayDateShort =>
      this != null ? DateFormat('MMM d').format(this!) : '—';
  String get toDisplayDateTime =>
      this != null ? DateFormat('MMM d, yyyy h:mm a').format(this!) : '—';
  String get toRelative => this?.toRelative ?? '—';
}

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;
  bool get isDark => theme.brightness == Brightness.dark;
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  // Responsive breakpoints
  bool get isDesktop => screenWidth >= 1200;
  bool get isWeb => screenWidth >= 900;
  bool get isTablet => screenWidth >= 600 && screenWidth < 900;
  bool get isMobile => screenWidth < 600;

  // Responsive value helper
  T responsive<T>({required T mobile, T? tablet, required T desktop}) {
    if (isDesktop) return desktop;
    if (isWeb) return tablet ?? desktop;
    return mobile;
  }

  // Responsive padding
  EdgeInsets get pagePadding {
    if (isDesktop) return const EdgeInsets.all(32);
    if (isWeb) return const EdgeInsets.all(24);
    return const EdgeInsets.all(16);
  }

  void showSnack(
    String message, {
    bool isError = false,
    bool isWarning = false,
    IconData? icon,
    Duration? duration,
  }) {
    final Color bg = isError
        ? const Color(0xFFEF4444)
        : isWarning
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    // Auto-select icon based on type if not explicitly provided
    final IconData effectiveIcon = icon ??
        (isError
            ? Icons.error_outline_rounded
            : isWarning
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded);

    ScaffoldMessenger.of(this).hideCurrentSnackBar();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(effectiveIcon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          isWeb ? 24 : 80,
        ),
        duration: duration ?? const Duration(seconds: 4),
        elevation: 4,
      ),
    );
  }
}
