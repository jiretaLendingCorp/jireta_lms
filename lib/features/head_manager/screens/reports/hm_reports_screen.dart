// lib/features/head_manager/screens/reports/hm_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';

class HmReportsScreen extends ConsumerStatefulWidget {
  const HmReportsScreen({super.key});

  @override
  ConsumerState<HmReportsScreen> createState() => _HmReportsScreenState();
}

class _HmReportsScreenState extends ConsumerState<HmReportsScreen> {
  String _reportType = 'loans';
  DateTimeRange? _range;
  bool _loading = false;
  Map<String, dynamic>? _data;
  String? _error;

  final _types = const [
    _ReportType('loans', 'Loan Report', AppIcons.loans),
    _ReportType('payments', 'Payment Report', AppIcons.payments),
    _ReportType('users', 'User Report', AppIcons.users),
    _ReportType('collections', 'Collection Report', AppIcons.assignments),
    _ReportType('overdue', 'Overdue Report', AppIcons.warning),
  ];

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _range ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (result != null) setState(() => _range = result);
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _data = null;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        'type': _reportType,
        if (_range != null)
          'date_from': _range!.start.toIso8601String().split('T').first,
        if (_range != null)
          'date_to': _range!.end.toIso8601String().split('T').first,
      };
      final res = await DioClient.instance
          .get(ApiEndpoints.analyticsKpi, queryParameters: params);
      setState(() {
        _data = res.data as Map<String, dynamic>? ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface =
        isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight;
    final border =
        isDark ? AppColors.webBorderDark : AppColors.webBorderLight;
    final textSecondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Reports',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              AppButton(
                label: 'Generate',
                icon: AppIcons.refresh,
                isLoading: _loading,
                onPressed: _generate,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Report type cards ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _types.map((t) {
                    final active = _reportType == t.value;
                    return GestureDetector(
                      onTap: () => setState(() => _reportType = t.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.accent.withValues(alpha: 0.12)
                              : (isDark
                                  ? AppColors.webBorderSoftDk
                                  : AppColors.webBorderSoftL),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? AppColors.accent
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.icon,
                                size: 16,
                                color: active
                                    ? AppColors.accent
                                    : textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              t.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: active
                                    ? AppColors.accent
                                    : textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Date range picker ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Icon(AppIcons.calendar, size: 18, color: textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date Range',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _range == null
                            ? 'All time (no filter)'
                            : '${_range!.start.toDisplayDate} → ${_range!.end.toDisplayDate}',
                        style:
                            TextStyle(fontSize: 12, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _pickDateRange,
                  child: const Text('Select'),
                ),
                if (_range != null)
                  TextButton(
                    onPressed: () => setState(() => _range = null),
                    child: const Text('Clear',
                        style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Results ─────────────────────────────────────────────────────
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.alertCircle,
                      color: AppColors.error, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ),
                ],
              ),
            )
          else if (_data != null)
            _ReportResults(
              data: _data!,
              isDark: isDark,
              border: border,
              surface: surface,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 56),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(AppIcons.download,
                      size: 48,
                      color: textSecondary.withValues(alpha: 0.35)),
                  const SizedBox(height: 16),
                  Text(
                    'Select a report type and click Generate',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportType {
  final String value;
  final String label;
  final IconData icon;
  const _ReportType(this.value, this.label, this.icon);
}

class _ReportResults extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final Color border;
  final Color surface;

  const _ReportResults({
    required this.data,
    required this.isDark,
    required this.border,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Results',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const Spacer(),
              Text('${entries.length} metrics',
                  style: TextStyle(fontSize: 12, color: textSecondary)),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No data for this period.',
                    style: TextStyle(color: textSecondary)),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.7,
              ),
              itemCount: entries.length,
              itemBuilder: (_, i) {
                final e = entries[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.webBorderSoftDk
                        : AppColors.webBorderSoftL,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: textSecondary,
                        ),
                      ),
                      Text(
                        e.value?.toString() ?? '—',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}