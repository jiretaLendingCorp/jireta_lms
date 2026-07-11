// lib/features/head_manager/screens/reports/hm_reports_screen.dart
// FIX (016): Was calling /analytics/kpi with a type param that /kpi ignores.
// Now calls GET /analytics/report via HmReportNotifier.generate(), which returns
// a properly typed ReportResult with summary and row data.
// Reports are also persisted to the reports table in Postgres.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/report_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../providers/hm_providers.dart';

class HmReportsScreen extends ConsumerStatefulWidget {
  const HmReportsScreen({super.key});

  @override
  ConsumerState<HmReportsScreen> createState() => _HmReportsScreenState();
}

class _HmReportsScreenState extends ConsumerState<HmReportsScreen> {
  ReportType _reportType = ReportType.loans;
  DateTimeRange? _range;

  static final _fmt = DateFormat('MMM d, yyyy');

  final _types = [
    (ReportType.loans, 'Loan Report', AppIcons.loans),
    (ReportType.payments, 'Payment Report', AppIcons.payments),
    (ReportType.users, 'User Report', AppIcons.users),
    (ReportType.collections, 'Collection Report', AppIcons.assignments),
    (ReportType.overdue, 'Overdue Report', AppIcons.warning),
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
    final error = await ref.read(hmReportNotifierProvider.notifier).generate(
          reportType: _reportType.value,
          dateFrom: _range?.start.toIso8601String().split('T').first,
          dateTo: _range?.end.toIso8601String().split('T').first,
        );
    if (error != null && mounted) {
      context.showSnack(error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surface =
        isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight;
    final border = isDark ? AppColors.webBorderDark : AppColors.webBorderLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final notifierState = ref.watch(hmReportNotifierProvider);
    final reportResult = ref.watch(hmReportProvider);
    final isLoading = notifierState is AsyncLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Reports',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (reportResult != null)
              TextButton.icon(
                onPressed: () =>
                    ref.read(hmReportNotifierProvider.notifier).clear(),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Clear'),
              ),
            const SizedBox(width: 8),
            AppButton(
              label: 'Generate',
              icon: AppIcons.refresh,
              isLoading: isLoading,
              onPressed: _generate,
            ),
          ]),
          const SizedBox(height: 24),

          // ── Report type selector ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Report Type',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _types.map((t) {
                  final (type, label, icon) = t;
                  final active = _reportType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _reportType = type),
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
                          color: active ? AppColors.accent : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon,
                            size: 16,
                            color: active ? AppColors.accent : textSecondary),
                        const SizedBox(width: 8),
                        Text(label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w400,
                              color: active ? AppColors.accent : textSecondary,
                            )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Date range ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Row(children: [
              Icon(AppIcons.calendar, size: 18, color: textSecondary),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Date Range',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight)),
                    const SizedBox(height: 2),
                    Text(
                      _range == null
                          ? 'All time (no filter)'
                          : '${_fmt.format(_range!.start)} → ${_fmt.format(_range!.end)}',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ])),
              TextButton(
                  onPressed: _pickDateRange, child: const Text('Select')),
              if (_range != null)
                TextButton(
                  onPressed: () => setState(() => _range = null),
                  child: const Text('Clear',
                      style: TextStyle(color: AppColors.error)),
                ),
            ]),
          ),
          const SizedBox(height: 24),

          // ── Results ────────────────────────────────────────────────────────
          if (isLoading)
            Container(
              height: 200,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            )
          else if (reportResult != null)
            _ReportResults(
              result: reportResult,
              isDark: isDark,
              border: border,
              surface: surface,
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 56),
              alignment: Alignment.center,
              child: Column(children: [
                Icon(AppIcons.download,
                    size: 48, color: textSecondary.withValues(alpha: 0.35)),
                const SizedBox(height: 16),
                Text('Select a report type and click Generate',
                    style: TextStyle(color: textSecondary, fontSize: 14)),
              ]),
            ),
        ],
      ),
    );
  }
}

// ── Results widget ─────────────────────────────────────────────────────────────

class _ReportResults extends StatelessWidget {
  final ReportResult result;
  final bool isDark;
  final Color border;
  final Color surface;

  const _ReportResults({
    required this.result,
    required this.isDark,
    required this.border,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final fmt = NumberFormat('#,###', 'en_PH');
    final fmtCurrency = NumberFormat('₱#,###.##', 'en_PH');

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
          // Header
          Row(children: [
            Text(result.reportType.label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${fmt.format(result.rowCount)} rows',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          if (result.generatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
                'Generated ${DateFormat('MMM d, yyyy h:mm a').format(result.generatedAt!.toLocal())}',
                style: TextStyle(fontSize: 12, color: textSecondary)),
          ],
          const SizedBox(height: 16),

          // Summary cards
          if (result.summary.isNotEmpty) ...[
            Text('Summary',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary)),
            const SizedBox(height: 10),
            _buildSummary(
                result.summary, textPrimary, textSecondary, fmtCurrency, fmt),
            const SizedBox(height: 20),
          ],

          // Row preview (first 10)
          if (result.rows.isNotEmpty) ...[
            Row(children: [
              Text('Preview',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(width: 8),
              Text(
                  '(first ${result.rows.take(10).length} of ${result.rowCount} rows)',
                  style: TextStyle(fontSize: 11, color: textSecondary)),
            ]),
            const SizedBox(height: 10),
            _buildRowPreview(context, result.rows.take(10).toList(),
                textPrimary, textSecondary),
          ],
        ],
      ),
    );
  }

  Widget _buildSummary(
    Map<String, dynamic> summary,
    Color textPrimary,
    Color textSecondary,
    NumberFormat fmtCurrency,
    NumberFormat fmt,
  ) {
    // Flatten summary — show scalar values as cards, maps as sub-sections
    final scalarEntries = summary.entries
        .where((e) => e.value is! Map && e.value is! List)
        .toList();
    final mapEntries = summary.entries.where((e) => e.value is Map).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scalarEntries.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
            ),
            itemCount: scalarEntries.length,
            itemBuilder: (_, i) {
              final e = scalarEntries[i];
              final val = e.value is num
                  ? (e.key.contains('amount') ||
                          e.key.contains('outstanding') ||
                          e.key.contains('principal') ||
                          e.key.contains('collected') ||
                          e.key.contains('penalty') ||
                          e.key.contains('disbursed')
                      ? fmtCurrency.format((e.value as num).toDouble())
                      : e.key.contains('rate')
                          ? '${((e.value as num) * 100).toStringAsFixed(1)}%'
                          : fmt.format(e.value))
                  : e.value?.toString() ?? '—';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.webBorderSoftDk
                      : AppColors.webBorderSoftL,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: textSecondary)),
                    Text(val,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              );
            },
          ),
        if (mapEntries.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...mapEntries.map((e) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.key.replaceAll('_', ' '),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (e.value as Map<String, dynamic>)
                        .entries
                        .map(
                          (sub) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: isDark
                                      ? AppColors.webBorderDark
                                      : AppColors.webBorderLight),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${sub.key.replaceAll('_', ' ')}: '
                              '${sub.value is double ? (sub.value as double).toStringAsFixed(1) : sub.value}',
                              style:
                                  TextStyle(fontSize: 12, color: textPrimary),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                ],
              )),
        ],
      ],
    );
  }

  Widget _buildRowPreview(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (rows.isEmpty) return const SizedBox.shrink();

    // Pick a few key columns based on report type
    final keyColumns = _keyColumns(result.reportType);
    final cols = rows.first.keys
        .where((k) => keyColumns.isEmpty || keyColumns.contains(k))
        .take(5)
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columnSpacing: 20,
        columns: cols
            .map((c) => DataColumn(
                  label: Text(c.replaceAll('_', ' '),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary)),
                ))
            .toList(),
        rows: rows
            .map((row) => DataRow(
                  cells: cols.map((c) {
                    var val = row[c];
                    if (val is double) val = val.toStringAsFixed(2);
                    if (val is String && val.length > 28)
                      val = '${val.substring(0, 26)}…';
                    return DataCell(Text(
                      val?.toString() ?? '—',
                      style: TextStyle(fontSize: 12, color: textPrimary),
                    ));
                  }).toList(),
                ))
            .toList(),
      ),
    );
  }

  List<String> _keyColumns(ReportType type) {
    switch (type) {
      case ReportType.loans:
        return [
          'lender_name',
          'status',
          'principal_amount',
          'tier_label',
          'term_days'
        ];
      case ReportType.payments:
        return ['lender_name', 'amount', 'method', 'status', 'created_at'];
      case ReportType.users:
        return ['first_name', 'last_name', 'role', 'email', 'created_at'];
      case ReportType.collections:
        return [
          'rider_name',
          'lender_name',
          'status',
          'amount_collected',
          'collection_date'
        ];
      case ReportType.overdue:
        return [
          'lender_name',
          'outstanding_balance',
          'penalty_amount',
          'days_overdue',
          'maturity_date'
        ];
    }
  }
}
