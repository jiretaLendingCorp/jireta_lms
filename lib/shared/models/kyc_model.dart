// lib/shared/models/kyc_model.dart

enum KycStatus { pending, underReview, approved, rejected }

extension KycStatusX on KycStatus {
  String get value {
    switch (this) {
      case KycStatus.pending:
        return 'pending';
      case KycStatus.underReview:
        return 'under_review';
      case KycStatus.approved:
        return 'approved';
      case KycStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case KycStatus.pending:
        return 'Pending';
      case KycStatus.underReview:
        return 'Under Review';
      case KycStatus.approved:
        return 'Approved';
      case KycStatus.rejected:
        return 'Rejected';
    }
  }

  static KycStatus fromString(String? value) {
    switch (value) {
      case 'under_review':
        return KycStatus.underReview;
      case 'approved':
        return KycStatus.approved;
      case 'rejected':
        return KycStatus.rejected;
      default:
        return KycStatus.pending;
    }
  }
}

class KycModel {
  final String id;
  final String lenderId;
  final String? lenderName;
  final KycStatus status;
  final String idType;
  final String idNumber;
  final String? idFrontUrl;
  final String? idBackUrl;
  final String? selfieUrl;
  final String? employer;
  final double? monthlyIncome;
  final String? rejectionReason;
  final String? reviewedById;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const KycModel({
    required this.id,
    required this.lenderId,
    this.lenderName,
    required this.status,
    required this.idType,
    required this.idNumber,
    this.idFrontUrl,
    this.idBackUrl,
    this.selfieUrl,
    this.employer,
    this.monthlyIncome,
    this.rejectionReason,
    this.reviewedById,
    required this.createdAt,
    this.reviewedAt,
  });

  factory KycModel.fromJson(Map<String, dynamic> json) => KycModel(
        id: json['id'] as String,
        lenderId: json['lender_id'] as String,
        lenderName: json['lender_name'] as String?,
        status: KycStatusX.fromString(json['status'] as String?),
        idType: json['id_type'] as String? ?? '',
        idNumber: json['id_number'] as String? ?? '',
        idFrontUrl: json['id_front_url'] as String?,
        idBackUrl: json['id_back_url'] as String?,
        selfieUrl: json['selfie_url'] as String?,
        employer: json['employer'] as String?,
        monthlyIncome: (json['monthly_income'] as num?)?.toDouble(),
        rejectionReason: json['rejection_reason'] as String?,
        reviewedById: json['reviewed_by_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.parse(json['reviewed_at'] as String)
            : null,
      );
}