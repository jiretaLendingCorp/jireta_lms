// lib/shared/models/notification_model.dart

enum NotificationCategory {
  loanApproved,
  loanRejected,
  loanDisbursed,
  paymentConfirmed,
  paymentDue,
  paymentOverdue,
  penaltyApplied,
  kycStatus,
  assignmentNew,
  assignmentUpdate,
  general,
}

extension NotificationCategoryX on NotificationCategory {
  String get value {
    switch (this) {
      case NotificationCategory.loanApproved:
        return 'loan_approved';
      case NotificationCategory.loanRejected:
        return 'loan_rejected';
      case NotificationCategory.loanDisbursed:
        return 'loan_disbursed';
      case NotificationCategory.paymentConfirmed:
        return 'payment_confirmed';
      case NotificationCategory.paymentDue:
        return 'payment_due';
      case NotificationCategory.paymentOverdue:
        return 'payment_overdue';
      case NotificationCategory.penaltyApplied:
        return 'penalty_applied';
      case NotificationCategory.kycStatus:
        return 'kyc_status';
      case NotificationCategory.assignmentNew:
        return 'assignment_new';
      case NotificationCategory.assignmentUpdate:
        return 'assignment_update';
      case NotificationCategory.general:
        return 'general';
    }
  }

  static NotificationCategory fromString(String? value) {
    switch (value) {
      case 'loan_approved':
        return NotificationCategory.loanApproved;
      case 'loan_rejected':
        return NotificationCategory.loanRejected;
      case 'loan_disbursed':
        return NotificationCategory.loanDisbursed;
      case 'payment_confirmed':
        return NotificationCategory.paymentConfirmed;
      case 'payment_due':
        return NotificationCategory.paymentDue;
      case 'payment_overdue':
        return NotificationCategory.paymentOverdue;
      case 'penalty_applied':
        return NotificationCategory.penaltyApplied;
      case 'kyc_status':
        return NotificationCategory.kycStatus;
      case 'assignment_new':
        return NotificationCategory.assignmentNew;
      case 'assignment_update':
        return NotificationCategory.assignmentUpdate;
      default:
        return NotificationCategory.general;
    }
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationCategory category;
  final bool isRead;
  final String? referenceId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? readAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.category,
    this.isRead = false,
    this.referenceId,
    this.metadata,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      NotificationModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        category: NotificationCategoryX.fromString(
          json['category'] as String?,
        ),
        isRead: json['is_read'] as bool? ?? false,
        referenceId: json['reference_id'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String)
            : null,
      );
}