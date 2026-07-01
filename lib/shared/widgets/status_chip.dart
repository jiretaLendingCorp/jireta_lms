// lib/shared/widgets/status_chip.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.small = false,
  });

  factory StatusChip.loanStatus(String status, {bool small = false}) {
    final Map<String, Color> colors = {
      'pending': AppColors.warning,
      'under_review': AppColors.info,
      'approved': AppColors.success,
      'active': AppColors.success,
      'completed': AppColors.textSecondaryLight,
      'rejected': AppColors.error,
      'defaulted': AppColors.statusDefaulted,
    };
    return StatusChip(
      label: _labelFor(status),
      color: colors[status] ?? AppColors.textSecondaryLight,
      small: small,
    );
  }

  factory StatusChip.paymentStatus(String status, {bool small = false}) {
    final Map<String, Color> colors = {
      'pending': AppColors.warning,
      'verified': AppColors.success,
      'rejected': AppColors.error,
      'reversed': AppColors.textSecondaryLight,
    };
    return StatusChip(
      label: _labelFor(status),
      color: colors[status] ?? AppColors.textSecondaryLight,
      small: small,
    );
  }

  factory StatusChip.kycStatus(String status, {bool small = false}) {
    final Map<String, Color> colors = {
      'pending': AppColors.warning,
      'under_review': AppColors.info,
      'approved': AppColors.success,
      'rejected': AppColors.error,
    };
    return StatusChip(
      label: _labelFor(status),
      color: colors[status] ?? AppColors.textSecondaryLight,
      small: small,
    );
  }

  factory StatusChip.assignmentStatus(String status, {bool small = false}) {
    final Map<String, Color> colors = {
      'pending': AppColors.warning,
      'in_progress': AppColors.info,
      'completed': AppColors.success,
      'failed': AppColors.error,
      'cancelled': AppColors.textSecondaryLight,
    };
    return StatusChip(
      label: _labelFor(status),
      color: colors[status] ?? AppColors.textSecondaryLight,
      small: small,
    );
  }

  static String _labelFor(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}