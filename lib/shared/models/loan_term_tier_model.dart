// lib/shared/models/loan_term_tier_model.dart
// NEW (016): Model for loan_term_tiers table.
// Head manager and employee can update tier parameters via /system-settings/tiers/update.
// Lenders see these tiers in the apply screen preview via /system-settings/public.

class LoanTermTierModel {
  final String id;
  final String tierLabel;
  final double minAmount;
  final double maxAmount;
  final int termDays;
  final double interestRate;
  final double penaltyRate;
  final int penaltyGraceDays;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const LoanTermTierModel({
    required this.id,
    required this.tierLabel,
    required this.minAmount,
    required this.maxAmount,
    required this.termDays,
    required this.interestRate,
    required this.penaltyRate,
    required this.penaltyGraceDays,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
  });

  // ── Computed helpers ────────────────────────────────────────────────────────

  String get displayLabel {
    switch (tierLabel) {
      case 'micro':
        return 'Micro  (₱3K – ₱9.9K)';
      case 'small':
        return 'Small  (₱10K – ₱49.9K)';
      case 'medium':
        return 'Medium (₱50K – ₱99.9K)';
      case 'large':
        return 'Large  (₱100K – ₱500K)';
      default:
        return tierLabel;
    }
  }

  int get monthCount => (termDays / 30).ceil();

  /// Preview installment amounts — authoritative values come from backend.
  double previewInstallment(double amount, String frequency) {
    final total = amount * (1 + interestRate);
    final daily = (total / termDays * 100).round() / 100;
    final weekly = (daily * 7 * 100).round() / 100;
    final monthly = (total / monthCount * 100).round() / 100;
    switch (frequency) {
      case 'daily':
        return daily;
      case 'weekly':
        return weekly;
      case 'monthly':
        return monthly;
      default:
        return monthly;
    }
  }

  double get interestRatePercent => interestRate * 100;
  double get penaltyRatePercent => penaltyRate * 100;

  // ── Serialisation ───────────────────────────────────────────────────────────

  factory LoanTermTierModel.fromJson(Map<String, dynamic> json) =>
      LoanTermTierModel(
        id: json['id'] as String? ?? '',
        tierLabel: json['tier_label'] as String,
        minAmount: (json['min_amount'] as num).toDouble(),
        maxAmount: (json['max_amount'] as num).toDouble(),
        termDays: json['term_days'] as int,
        interestRate: (json['interest_rate'] as num).toDouble(),
        penaltyRate: (json['penalty_rate'] as num).toDouble(),
        penaltyGraceDays: json['penalty_grace_days'] as int? ?? 30,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'tier_label': tierLabel,
        'min_amount': minAmount,
        'max_amount': maxAmount,
        'term_days': termDays,
        'interest_rate': interestRate,
        'penalty_rate': penaltyRate,
        'penalty_grace_days': penaltyGraceDays,
        'is_active': isActive,
      };

  LoanTermTierModel copyWith({
    int? termDays,
    double? minAmount,
    double? maxAmount,
    double? interestRate,
    double? penaltyRate,
    int? penaltyGraceDays,
    bool? isActive,
  }) =>
      LoanTermTierModel(
        id: id,
        tierLabel: tierLabel,
        minAmount: minAmount ?? this.minAmount,
        maxAmount: maxAmount ?? this.maxAmount,
        termDays: termDays ?? this.termDays,
        interestRate: interestRate ?? this.interestRate,
        penaltyRate: penaltyRate ?? this.penaltyRate,
        penaltyGraceDays: penaltyGraceDays ?? this.penaltyGraceDays,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  /// Returns the matching tier for [amount], or null if out of range.
  static LoanTermTierModel? forAmount(
      List<LoanTermTierModel> tiers, double amount) {
    for (final t in tiers) {
      if (t.isActive && amount >= t.minAmount && amount <= t.maxAmount)
        return t;
    }
    return null;
  }
}
