// lib/shared/models/payment_model.dart

enum PaymentStatus { pending, verified, rejected, reversed }

enum PaymentMethod { gcash, maya, qr, cash, bankTransfer, office }

extension PaymentStatusX on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.verified:
        return 'verified';
      case PaymentStatus.rejected:
        return 'rejected';
      case PaymentStatus.reversed:
        return 'reversed';
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.verified:
        return 'Verified';
      case PaymentStatus.rejected:
        return 'Rejected';
      case PaymentStatus.reversed:
        return 'Reversed';
    }
  }

  static PaymentStatus fromString(String? value) {
    switch (value) {
      case 'verified':
        return PaymentStatus.verified;
      case 'rejected':
        return PaymentStatus.rejected;
      case 'reversed':
        return PaymentStatus.reversed;
      default:
        return PaymentStatus.pending;
    }
  }
}

extension PaymentMethodX on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.gcash:
        return 'gcash';
      case PaymentMethod.maya:
        return 'maya';
      case PaymentMethod.qr:
        return 'qr';
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.office:
        return 'office';
    }
  }

  String get label {
    switch (this) {
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.maya:
        return 'Maya';
      case PaymentMethod.qr:
        return 'QR Payment';
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.office:
        return 'Office Pickup';
    }
  }

  static PaymentMethod fromString(String? value) {
    switch (value) {
      case 'gcash':
        return PaymentMethod.gcash;
      case 'maya':
        return PaymentMethod.maya;
      case 'qr':
        return PaymentMethod.qr;
      case 'cash':
        return PaymentMethod.cash;
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'office':
        return PaymentMethod.office;
      default:
        return PaymentMethod.cash;
    }
  }
}

class PaymentModel {
  final String id;
  final String loanId;
  final String lenderId;
  final String? lenderName;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? referenceNumber;
  final String? receiptUrl;
  final String? notes;
  final String? verifiedById;
  final String? rejectionReason;
  final String? xenditPaymentId;
  final DateTime createdAt;
  final DateTime? verifiedAt;

  const PaymentModel({
    required this.id,
    required this.loanId,
    required this.lenderId,
    this.lenderName,
    required this.amount,
    required this.method,
    required this.status,
    this.referenceNumber,
    this.receiptUrl,
    this.notes,
    this.verifiedById,
    this.rejectionReason,
    this.xenditPaymentId,
    required this.createdAt,
    this.verifiedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id'] as String,
        loanId: json['loan_id'] as String,
        lenderId: json['lender_id'] as String,
        lenderName: json['lender_name'] as String?,
        amount: (json['amount'] as num).toDouble(),
        method: PaymentMethodX.fromString(json['method'] as String?),
        status: PaymentStatusX.fromString(json['status'] as String?),
        referenceNumber: json['reference_number'] as String?,
        receiptUrl: json['receipt_url'] as String?,
        notes: json['notes'] as String?,
        verifiedById: json['verified_by_id'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
        xenditPaymentId: json['xendit_payment_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        verifiedAt: json['verified_at'] != null
            ? DateTime.parse(json['verified_at'] as String)
            : null,
      );
}

class SystemPaymentMethod {
  final String id;
  final PaymentMethod method;
  final bool isEnabled;
  final String displayName;
  final String? description;
  final int sortOrder;

  const SystemPaymentMethod({
    required this.id,
    required this.method,
    required this.isEnabled,
    required this.displayName,
    this.description,
    required this.sortOrder,
  });

  factory SystemPaymentMethod.fromJson(Map<String, dynamic> json) =>
      SystemPaymentMethod(
        id: json['id'] as String,
        method: PaymentMethodX.fromString(json['method'] as String?),
        isEnabled: json['is_enabled'] as bool? ?? false,
        displayName: json['display_name'] as String? ?? '',
        description: json['description'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}