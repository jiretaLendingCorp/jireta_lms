// lib/shared/models/report_model.dart
// NEW (016): Model for the reports table + report result payload.
// Reports screen now calls GET /analytics/report?type=... which returns
// ReportResult. The reports table row is returned as ReportRecord.

enum ReportType { loans, payments, users, collections, overdue }

extension ReportTypeX on ReportType {
  String get value {
    switch (this) {
      case ReportType.loans:
        return 'loans';
      case ReportType.payments:
        return 'payments';
      case ReportType.users:
        return 'users';
      case ReportType.collections:
        return 'collections';
      case ReportType.overdue:
        return 'overdue';
    }
  }

  String get label {
    switch (this) {
      case ReportType.loans:
        return 'Loan Report';
      case ReportType.payments:
        return 'Payment Report';
      case ReportType.users:
        return 'User Report';
      case ReportType.collections:
        return 'Collection Report';
      case ReportType.overdue:
        return 'Overdue Report';
    }
  }

  static ReportType fromString(String? value) {
    switch (value) {
      case 'payments':
        return ReportType.payments;
      case 'users':
        return ReportType.users;
      case 'collections':
        return ReportType.collections;
      case 'overdue':
        return ReportType.overdue;
      default:
        return ReportType.loans;
    }
  }
}

/// The full result payload from GET /analytics/report
class ReportResult {
  final String? reportId;
  final ReportType reportType;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> rows;
  final DateTime? generatedAt;

  const ReportResult({
    this.reportId,
    required this.reportType,
    required this.summary,
    required this.rows,
    this.generatedAt,
  });

  int get rowCount => rows.length;

  factory ReportResult.fromJson(Map<String, dynamic> json) => ReportResult(
        reportId: json['report_id'] as String?,
        reportType: ReportTypeX.fromString(json['report_type'] as String?),
        summary: (json['summary'] as Map<String, dynamic>?) ?? {},
        rows: (json['rows'] as List<dynamic>?)
                ?.map((r) => r as Map<String, dynamic>)
                .toList() ??
            [],
        generatedAt: json['generated_at'] != null
            ? DateTime.tryParse(json['generated_at'] as String)
            : null,
      );
}

/// A saved report record from the reports table (for history listing)
class ReportRecord {
  final String id;
  final String generatedById;
  final ReportType reportType;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int rowCount;
  final DateTime createdAt;

  const ReportRecord({
    required this.id,
    required this.generatedById,
    required this.reportType,
    this.dateFrom,
    this.dateTo,
    required this.rowCount,
    required this.createdAt,
  });

  factory ReportRecord.fromJson(Map<String, dynamic> json) => ReportRecord(
        id: json['id'] as String,
        generatedById: json['generated_by'] as String,
        reportType: ReportTypeX.fromString(json['report_type'] as String?),
        dateFrom: json['date_from'] != null
            ? DateTime.tryParse(json['date_from'] as String)
            : null,
        dateTo: json['date_to'] != null
            ? DateTime.tryParse(json['date_to'] as String)
            : null,
        rowCount: json['row_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
