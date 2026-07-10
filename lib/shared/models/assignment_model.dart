// lib/shared/models/assignment_model.dart

enum AssignmentStatus { pending, inProgress, completed, failed, cancelled }

extension AssignmentStatusX on AssignmentStatus {
  String get value {
    switch (this) {
      case AssignmentStatus.pending:
        return 'pending';
      case AssignmentStatus.inProgress:
        return 'in_progress';
      case AssignmentStatus.completed:
        return 'completed';
      case AssignmentStatus.failed:
        return 'failed';
      case AssignmentStatus.cancelled:
        return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case AssignmentStatus.pending:
        return 'Pending';
      case AssignmentStatus.inProgress:
        return 'In Progress';
      case AssignmentStatus.completed:
        return 'Completed';
      case AssignmentStatus.failed:
        return 'Failed';
      case AssignmentStatus.cancelled:
        return 'Cancelled';
    }
  }

  static AssignmentStatus fromString(String? value) {
    switch (value) {
      case 'in_progress':
        return AssignmentStatus.inProgress;
      case 'completed':
        return AssignmentStatus.completed;
      case 'failed':
        return AssignmentStatus.failed;
      case 'cancelled':
        return AssignmentStatus.cancelled;
      default:
        return AssignmentStatus.pending;
    }
  }
}

enum AssignmentType { collection, creditInvestigation }

extension AssignmentTypeX on AssignmentType {
  String get value {
    switch (this) {
      case AssignmentType.collection:
        return 'collection';
      case AssignmentType.creditInvestigation:
        return 'credit_investigation';
    }
  }

  String get label {
    switch (this) {
      case AssignmentType.collection:
        return 'Collection';
      case AssignmentType.creditInvestigation:
        return 'Credit Investigation';
    }
  }

  static AssignmentType fromString(String? value) {
    switch (value) {
      case 'credit_investigation':
        return AssignmentType.creditInvestigation;
      default:
        return AssignmentType.collection;
    }
  }
}

class AssignmentModel {
  final String id;
  final String riderId;
  final String? riderName;
  final String lenderId;
  final String? lenderName;
  final String loanId;
  final String? lenderAddress;
  final double? lenderLat;
  final double? lenderLng;
  final double amountToCollect;
  final double? amountCollected;
  final AssignmentStatus status;
  final AssignmentType assignmentType;
  final DateTime collectionDate;
  final String? notes;
  final String? receiptUrl;
  final String? failureReason;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime? completedAt;
  // CI-specific fields
  final String? ciDocumentUrl;
  final String? ciNotes;
  final DateTime? ciCompletedAt;

  const AssignmentModel({
    required this.id,
    required this.riderId,
    this.riderName,
    required this.lenderId,
    this.lenderName,
    required this.loanId,
    this.lenderAddress,
    this.lenderLat,
    this.lenderLng,
    required this.amountToCollect,
    this.amountCollected,
    required this.status,
    this.assignmentType = AssignmentType.collection,
    required this.collectionDate,
    this.notes,
    this.receiptUrl,
    this.failureReason,
    this.cancellationReason,
    required this.createdAt,
    this.completedAt,
    this.ciDocumentUrl,
    this.ciNotes,
    this.ciCompletedAt,
  });

  bool get isCreditInvestigation =>
      assignmentType == AssignmentType.creditInvestigation;
  bool get isCollection => assignmentType == AssignmentType.collection;

  factory AssignmentModel.fromJson(Map<String, dynamic> json) =>
      AssignmentModel(
        id: json['id'] as String,
        riderId: json['rider_id'] as String,
        riderName: json['rider_name'] as String?,
        lenderId: json['lender_id'] as String,
        lenderName: json['lender_name'] as String?,
        loanId: json['loan_id'] as String,
        lenderAddress: json['lender_address'] as String?,
        lenderLat: (json['lender_lat'] as num?)?.toDouble(),
        lenderLng: (json['lender_lng'] as num?)?.toDouble(),
        amountToCollect: (json['amount_to_collect'] as num).toDouble(),
        amountCollected: (json['amount_collected'] as num?)?.toDouble(),
        status: AssignmentStatusX.fromString(json['status'] as String?),
        assignmentType:
            AssignmentTypeX.fromString(json['assignment_type'] as String?),
        collectionDate: DateTime.parse(json['collection_date'] as String),
        notes: json['notes'] as String?,
        receiptUrl: json['receipt_url'] as String?,
        failureReason: json['failure_reason'] as String?,
        cancellationReason: json['cancellation_reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        ciDocumentUrl: json['ci_document_url'] as String?,
        ciNotes: json['ci_notes'] as String?,
        ciCompletedAt: json['ci_completed_at'] != null
            ? DateTime.parse(json['ci_completed_at'] as String)
            : null,
      );
}