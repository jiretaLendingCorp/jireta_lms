// lib/shared/models/loan_model.dart
// FIX (016): Added tierLabel field — loan-apply Edge Function stores tier_label
// in the loans table but the model was not parsing it, causing it to be null
// everywhere in the UI.

enum LoanStatus {
  pending,
  underReview,
  approved,
  active,
  completed,
  rejected,
  defaulted,
}

enum PaymentFrequency { daily, weekly, monthly }

extension LoanStatusX on LoanStatus {
  String get value {
    switch (this) {
      case LoanStatus.pending:
        return 'pending';
      case LoanStatus.underReview:
        return 'under_review';
      case LoanStatus.approved:
        return 'approved';
      case LoanStatus.active:
        return 'active';
      case LoanStatus.completed:
        return 'completed';
      case LoanStatus.rejected:
        return 'rejected';
      case LoanStatus.defaulted:
        return 'defaulted';
    }
  }

  String get label {
    switch (this) {
      case LoanStatus.pending:
        return 'Pending';
      case LoanStatus.underReview:
        return 'Under Review';
      case LoanStatus.approved:
        return 'Approved';
      case LoanStatus.active:
        return 'Active';
      case LoanStatus.completed:
        return 'Completed';
      case LoanStatus.rejected:
        return 'Rejected';
      case LoanStatus.defaulted:
        return 'Defaulted';
    }
  }

  static LoanStatus fromString(String? value) {
    switch (value) {
      case 'under_review':
        return LoanStatus.underReview;
      case 'approved':
        return LoanStatus.approved;
      case 'active':
        return LoanStatus.active;
      case 'completed':
        return LoanStatus.completed;
      case 'rejected':
        return LoanStatus.rejected;
      case 'defaulted':
        return LoanStatus.defaulted;
      case 'pending':
      default:
        return LoanStatus.pending;
    }
  }
}

extension PaymentFrequencyX on PaymentFrequency {
  String get value {
    switch (this) {
      case PaymentFrequency.daily:
        return 'daily';
      case PaymentFrequency.weekly:
        return 'weekly';
      case PaymentFrequency.monthly:
        return 'monthly';
    }
  }

  String get label {
    switch (this) {
      case PaymentFrequency.daily:
        return 'Daily';
      case PaymentFrequency.weekly:
        return 'Weekly';
      case PaymentFrequency.monthly:
        return 'Monthly';
    }
  }

  static PaymentFrequency fromString(String? value) {
    switch (value) {
      case 'weekly':
        return PaymentFrequency.weekly;
      case 'monthly':
        return PaymentFrequency.monthly;
      case 'daily':
      default:
        return PaymentFrequency.daily;
    }
  }
}

class LoanModel {
  final String id;
  final String lenderId;
  final String? lenderName;
  final double principalAmount;
  final double interestAmount;
  final double totalPayable;
  final double outstandingBalance;
  final double penaltyAmount;
  final LoanStatus status;
  final PaymentFrequency? preferredFrequency;
  final PaymentFrequency? paymentFrequency;
  final int? termDays;
  final double? installmentAmount;
  final String? purpose;
  final String? rejectionReason;
  final String? approvedById;
  final String? disbursedById;
  final String? disbursementMethod;
  // FIX (016): was missing — loan-apply stores tier_label but model ignored it
  final String? tierLabel;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? disbursedAt;
  final DateTime? maturityDate;
  final DateTime? closedAt;
  final ComakerInfo? comaker;
  final bool hasPenalty;
  final int? daysOverdue;

  const LoanModel({
    required this.id,
    required this.lenderId,
    this.lenderName,
    required this.principalAmount,
    required this.interestAmount,
    required this.totalPayable,
    required this.outstandingBalance,
    this.penaltyAmount = 0,
    required this.status,
    this.preferredFrequency,
    this.paymentFrequency,
    this.termDays,
    this.installmentAmount,
    this.purpose,
    this.rejectionReason,
    this.approvedById,
    this.disbursedById,
    this.disbursementMethod,
    this.tierLabel,
    required this.createdAt,
    this.approvedAt,
    this.disbursedAt,
    this.maturityDate,
    this.closedAt,
    this.comaker,
    this.hasPenalty = false,
    this.daysOverdue,
  });

  double get progressPercentage {
    if (totalPayable <= 0) return 0;
    final paid = totalPayable - outstandingBalance;
    return (paid / totalPayable).clamp(0.0, 1.0);
  }

  bool get isOverdue =>
      maturityDate != null &&
      DateTime.now().isAfter(maturityDate!) &&
      status == LoanStatus.active;

  String get tierDisplayLabel {
    switch (tierLabel) {
      case 'micro':
        return 'Micro';
      case 'small':
        return 'Small';
      case 'medium':
        return 'Medium';
      case 'large':
        return 'Large';
      default:
        return tierLabel ?? '—';
    }
  }

  factory LoanModel.fromJson(Map<String, dynamic> json) => LoanModel(
        id: json['id'] as String,
        lenderId: json['lender_id'] as String,
        lenderName: json['lender_name'] as String?,
        principalAmount: (json['principal_amount'] as num).toDouble(),
        interestAmount: (json['interest_amount'] as num).toDouble(),
        totalPayable: (json['total_payable'] as num).toDouble(),
        outstandingBalance: (json['outstanding_balance'] as num).toDouble(),
        penaltyAmount: (json['penalty_amount'] as num?)?.toDouble() ?? 0,
        status: LoanStatusX.fromString(json['status'] as String?),
        preferredFrequency: json['preferred_frequency'] != null
            ? PaymentFrequencyX.fromString(
                json['preferred_frequency'] as String?)
            : null,
        paymentFrequency: json['payment_frequency'] != null
            ? PaymentFrequencyX.fromString(json['payment_frequency'] as String?)
            : null,
        termDays: json['term_days'] as int?,
        installmentAmount: (json['installment_amount'] as num?)?.toDouble(),
        purpose: json['purpose'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
        approvedById: json['approved_by_id'] as String?,
        disbursedById: json['disbursed_by_id'] as String?,
        disbursementMethod: json['disbursement_method'] as String?,
        // FIX (016): parse tier_label from JSON
        tierLabel: json['tier_label'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        approvedAt: json['approved_at'] != null
            ? DateTime.parse(json['approved_at'] as String)
            : null,
        disbursedAt: json['disbursed_at'] != null
            ? DateTime.parse(json['disbursed_at'] as String)
            : null,
        maturityDate: json['maturity_date'] != null
            ? DateTime.parse(json['maturity_date'] as String)
            : null,
        closedAt: json['closed_at'] != null
            ? DateTime.parse(json['closed_at'] as String)
            : null,
        comaker: json['comaker'] != null
            ? ComakerInfo.fromJson(json['comaker'] as Map<String, dynamic>)
            : null,
        hasPenalty: json['has_penalty'] as bool? ?? false,
        daysOverdue: json['days_overdue'] as int?,
      );
}

class ComakerInfo {
  final String firstName;
  final String lastName;
  final String? middleName;
  final String relationship;
  final String? signatureUrl;

  const ComakerInfo({
    required this.firstName,
    required this.lastName,
    this.middleName,
    required this.relationship,
    this.signatureUrl,
  });

  String get fullName => [firstName, middleName, lastName]
      .where((p) => p != null && p.isNotEmpty)
      .join(' ');

  factory ComakerInfo.fromJson(Map<String, dynamic> json) => ComakerInfo(
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        middleName: json['middle_name'] as String?,
        relationship: json['relationship'] as String,
        signatureUrl: json['signature_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'middle_name': middleName,
        'relationship': relationship,
        'signature_url': signatureUrl,
      };
}

class LoanSchedule {
  final String id;
  final String loanId;
  final int installmentNumber;
  final double amountDue;
  final double amountPaid;
  final DateTime dueDate;
  final DateTime? paidAt;
  final bool isPaid;
  final bool isOverdue;

  const LoanSchedule({
    required this.id,
    required this.loanId,
    required this.installmentNumber,
    required this.amountDue,
    required this.amountPaid,
    required this.dueDate,
    this.paidAt,
    required this.isPaid,
    required this.isOverdue,
  });

  double get balance => amountDue - amountPaid;

  factory LoanSchedule.fromJson(Map<String, dynamic> json) => LoanSchedule(
        id: json['id'] as String,
        loanId: json['loan_id'] as String,
        installmentNumber: json['installment_number'] as int,
        amountDue: (json['amount_due'] as num).toDouble(),
        amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
        dueDate: DateTime.parse(json['due_date'] as String),
        paidAt: json['paid_at'] != null
            ? DateTime.parse(json['paid_at'] as String)
            : null,
        isPaid: json['is_paid'] as bool? ?? false,
        isOverdue: json['is_overdue'] as bool? ?? false,
      );
}
