// lib/features/lender/screens/apply/lender_apply_screen.dart
//
// FIXES applied:
//   • Issue 4:  ALL tiers show Daily + Weekly + Monthly (even micro ₱3k-₱9k).
//               Monthly = total / ceil(term_days/30) = total / 2 for 40-day tier.
//   • Issue 4:  Loan amount field turns red (error state) when < ₱3,000.
//   • Issue 12: Added Step 4 — "Where do you want to receive the money?"
//               Options: Cash (rider delivers), GCash (auto-transfer), Office.
//               GCash option shows GCash Name + GCash Number fields.
//               Disbursement method + meta sent to backend in payload.
//               Total steps: 4 (was 3).
//   • Error "No loan term tier found":  is_active was missing in migration 013
//               seed → fixed in migration 015.  Also, the client-side
//               LoanTerms.from() now always includes monthly.
//   All computation still done server-side in loan-apply/index.ts.
//   Flutter only shows a preview; final amounts come from backend response.
//
// REDESIGN (Task 7-A): Material 3 polish, per-step Form state with Validators,
// numbered step indicator, animated transitions, premium glass cards.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_term_tier_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/lender_providers.dart';

// ── Client-side loan preview (mirrors backend get_loan_tier logic) ─────────────
// NOTE: This is ONLY for the live UI preview. The authoritative computation
// happens in loan-apply/index.ts via get_loan_tier() RPC. If values diverge
// the backend wins.
class LoanTerms {
  final double principal;
  final double totalPayable;
  final double interest;
  final int termDays;
  final double dailyPayment;
  final double weeklyPayment;
  final double monthlyPayment; // always available now (all tiers get monthly)

  const LoanTerms({
    required this.principal,
    required this.totalPayable,
    required this.interest,
    required this.termDays,
    required this.dailyPayment,
    required this.weeklyPayment,
    required this.monthlyPayment,
  });

  // FIX: monthly is now computed for ALL tiers. For micro (40 days): 2 months.
  // When liveTiers is provided the rate/termDays come from the backend config;
  // otherwise falls back to the hardcoded preview values.
  static LoanTerms? from(double? amount, {List<LoanTermTierModel>? liveTiers}) {
    if (amount == null || amount < 3000 || amount > 500000) return null;

    int termDays;
    double rate;

    if (liveTiers != null && liveTiers.isNotEmpty) {
      try {
        final tier = liveTiers.firstWhere(
          (t) => amount >= t.minAmount && amount <= t.maxAmount,
        );
        termDays = tier.termDays;
        rate = tier.interestRate;
      } catch (_) {
        return null;
      }
    } else {
      if (amount < 10000) {
        termDays = 40;
      } else if (amount < 50000) {
        termDays = 60;
      } else if (amount < 100000) {
        termDays = 80;
      } else {
        termDays = 120;
      }
      rate = 0.20;
    }

    final total = _round(amount * (1 + rate));
    final daily = _round(total / termDays);
    final weekly = _round(daily * 7);
    final months = (termDays / 30).ceil();
    final monthly = _round(total / months);

    return LoanTerms(
      principal: amount,
      totalPayable: total,
      interest: _round(amount * rate),
      termDays: termDays,
      dailyPayment: daily,
      weeklyPayment: weekly,
      monthlyPayment: monthly,
    );
  }

  static double _round(double v) => (v * 100).round() / 100;
}

// ── Disbursement method enum ───────────────────────────────────────────────────
enum DisbursementMethod { cash, gcash, office }

extension DisbursementMethodX on DisbursementMethod {
  String get value => name; // 'cash' | 'gcash' | 'office'
  String get label {
    switch (this) {
      case DisbursementMethod.cash:
        return 'Cash';
      case DisbursementMethod.gcash:
        return 'GCash';
      case DisbursementMethod.office:
        return 'Office';
    }
  }

  String get subtitle {
    switch (this) {
      case DisbursementMethod.cash:
        return 'A rider will deliver cash to your address';
      case DisbursementMethod.gcash:
        return 'Funds auto-transferred to your GCash account';
      case DisbursementMethod.office:
        return 'Pick up cash at our office';
    }
  }

  IconData get icon {
    switch (this) {
      case DisbursementMethod.cash:
        return AppIcons.banknote;
      case DisbursementMethod.gcash:
        return AppIcons.phone;
      case DisbursementMethod.office:
        return AppIcons.building;
    }
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────
class LenderApplyScreen extends ConsumerStatefulWidget {
  const LenderApplyScreen({super.key});

  @override
  ConsumerState<LenderApplyScreen> createState() => _LenderApplyScreenState();
}

class _LenderApplyScreenState extends ConsumerState<LenderApplyScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const int _totalSteps = 4;
  bool _submitting = false;

  // Per-step form keys for inline validation
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step4FormKey = GlobalKey<FormState>();

  // Step 1 — Loan details
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  String _frequency = 'monthly';
  LoanTerms? _loanTerms;
  bool _amountTouched = false;
  List<LoanTermTierModel> _liveTiers = const [];

  // Step 2 — Co-maker
  final _cmFirstCtrl = TextEditingController();
  final _cmLastCtrl = TextEditingController();
  final _cmMiddleCtrl = TextEditingController();
  String _relationship = 'Spouse';
  final _sigCtrl = SignatureController(
    penStrokeWidth: 2.4,
    penColor: Colors.white,
    exportBackgroundColor: Colors.transparent,
  );
  final _relationships = [
    'Spouse',
    'Parent',
    'Sibling',
    'Relative',
    'Friend',
    'Colleague',
    'Neighbor'
  ];

  // Step 4 — Disbursement
  DisbursementMethod _disbursementMethod = DisbursementMethod.cash;
  final _gcashNameCtrl = TextEditingController();
  final _gcashNumberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_onAmountChanged);
    _fetchLiveTiers();
  }

  Future<void> _fetchLiveTiers() async {
    try {
      final tiers = await ref.read(lenderLoanTermTiersProvider.future);
      if (mounted) setState(() => _liveTiers = tiers);
    } catch (_) {
      // silently fall back to client-side LoanTerms.from()
    }
  }

  void _onAmountChanged() {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw.replaceAll(',', ''));
    final terms = LoanTerms.from(amount,
        liveTiers: _liveTiers.isEmpty ? null : _liveTiers);
    setState(() {
      _loanTerms = terms;
      _amountTouched = raw.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onAmountChanged);
    _pageCtrl.dispose();
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _cmFirstCtrl.dispose();
    _cmLastCtrl.dispose();
    _cmMiddleCtrl.dispose();
    _gcashNameCtrl.dispose();
    _gcashNumberCtrl.dispose();
    _sigCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !_validateStep1()) return;
    if (_step == 1 && !_validateStep2()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic);
    } else {
      context.go(RouteConstants.lenderHome);
    }
  }

  bool _validateStep1() {
    final raw = _amountCtrl.text.trim();
    final amount = double.tryParse(raw.replaceAll(',', ''));
    if (amount == null || amount < 3000) {
      setState(() => _amountTouched = true);
      context.showSnack('Minimum loan amount is ₱3,000', isError: true);
      return false;
    }
    if (amount > 500000) {
      context.showSnack('Maximum loan amount is ₱500,000', isError: true);
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    // Validate text fields via form
    final formValid = _step2FormKey.currentState?.validate() ?? false;
    if (!formValid) {
      context.showSnack('Please complete co-maker details', isError: true);
      return false;
    }
    if (_sigCtrl.isEmpty) {
      context.showSnack('Co-maker signature is required', isError: true);
      return false;
    }
    return true;
  }

  bool _validateStep4() {
    if (_disbursementMethod == DisbursementMethod.gcash) {
      final formValid = _step4FormKey.currentState?.validate() ?? false;
      if (!formValid) {
        return false;
      }
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validateStep4()) return;
    setState(() => _submitting = true);

    Uint8List? sigBytes;
    if (_sigCtrl.isNotEmpty) {
      sigBytes = await _sigCtrl.toPngBytes();
    }

    final raw = _amountCtrl.text.replaceAll(',', '').replaceAll('₱', '');
    final amount = double.parse(raw);

    // Upload signature first via Dio → /loan-apply/upload-signature
    String? signatureUrl;
    if (sigBytes != null) {
      final uploadRes = await ref
          .read(lenderRepositoryProvider)
          .uploadComakerSignature(sigBytes);
      if (uploadRes.success) {
        signatureUrl = uploadRes.data;
      } else {
        debugPrint('[apply] signature upload failed: ${uploadRes.error}');
      }
    }

    // Build disbursement_meta (sensitive fields sent to backend over TLS via Dio)
    final Map<String, dynamic> disbursementMeta = {};
    if (_disbursementMethod == DisbursementMethod.gcash) {
      disbursementMeta['gcash_name'] = _gcashNameCtrl.text.trim();
      disbursementMeta['gcash_number'] = _gcashNumberCtrl.text.trim();
    }

    // All computation happens in loan-apply/index.ts on the backend.
    // Flutter sends raw inputs; backend enforces business rules + tier resolution.
    final payload = {
      'principal_amount': amount,
      'preferred_frequency': _frequency,
      'purpose': _purposeCtrl.text.trim(),
      // Disbursement (Step 4)
      'disbursement_method': _disbursementMethod.value,
      'disbursement_meta': disbursementMeta,
      // Co-maker
      'comaker': {
        'first_name': _cmFirstCtrl.text.trim(),
        'last_name': _cmLastCtrl.text.trim(),
        'middle_name': _cmMiddleCtrl.text.trim(),
        'relationship': _relationship,
        if (signatureUrl != null) 'signature_url': signatureUrl,
      },
    };

    final res = await ref.read(lenderRepositoryProvider).applyLoan(payload);
    setState(() => _submitting = false);

    if (mounted) {
      if (res.success) {
        context.showSnack('Application submitted successfully!');
        context.go(RouteConstants.lenderLoans);
      } else {
        context.showSnack(res.error ?? 'Submission failed', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Text(
            'Apply for Loan — Step ${_step + 1} of $_totalSteps',
            key: ValueKey(_step),
          ),
        ),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: _back,
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step, total: _totalSteps),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Step 1 — Loan details
                Form(
                  key: _step1FormKey,
                  child: _Step1(
                    amountCtrl: _amountCtrl,
                    purposeCtrl: _purposeCtrl,
                    frequency: _frequency,
                    loanTerms: _loanTerms,
                    amountTouched: _amountTouched,
                    onFreqChanged: (v) => setState(() => _frequency = v),
                    onNext: _next,
                  ),
                ),
                // Step 2 — Co-maker
                Form(
                  key: _step2FormKey,
                  child: _Step2(
                    firstCtrl: _cmFirstCtrl,
                    lastCtrl: _cmLastCtrl,
                    middleCtrl: _cmMiddleCtrl,
                    relationship: _relationship,
                    relationships: _relationships,
                    sigCtrl: _sigCtrl,
                    onRelChanged: (v) => setState(() => _relationship = v),
                    onNext: _next,
                  ),
                ),
                // Step 3 — Review summary
                _Step3(
                  loanTerms: _loanTerms,
                  frequency: _frequency,
                  comakerName:
                      '${_cmFirstCtrl.text} ${_cmLastCtrl.text}'.trim(),
                  relationship: _relationship,
                  onNext: _next,
                ),
                // Step 4 — Disbursement method
                Form(
                  key: _step4FormKey,
                  child: _Step4(
                    selectedMethod: _disbursementMethod,
                    gcashNameCtrl: _gcashNameCtrl,
                    gcashNumberCtrl: _gcashNumberCtrl,
                    submitting: _submitting,
                    onMethodChanged: (m) =>
                        setState(() => _disbursementMethod = m),
                    onSubmit: _submit,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step indicator with numbered circles ──────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final labels = ['Loan', 'Co-maker', 'Review', 'Disburse'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: List.generate(total, (i) {
          final done = i < current;
          final active = i == current;
          final color = done || active
              ? AppColors.lenderAccent
              : Colors.white.withValues(alpha: 0.18);
          return Expanded(
            child: Row(
              children: [
                // Numbered circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: done || active
                        ? AppColors.lenderAccent
                        : Colors.white.withValues(alpha: 0.06),
                    border: Border.all(
                      color: color,
                      width: done || active ? 0 : 1.4,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.lenderAccent
                                  .withValues(alpha: 0.45),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (i < total - 1) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      height: 3,
                      decoration: BoxDecoration(
                        color: done
                            ? AppColors.lenderAccent
                            : Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  const SizedBox(width: 8),
                  if (active)
                    Text(
                      labels[i],
                      style: const TextStyle(
                        color: AppColors.lenderAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Payment terms preview card ─────────────────────────────────────────────────
class _PaymentTermsCard extends StatelessWidget {
  final LoanTerms terms;
  final String selectedFrequency;
  const _PaymentTermsCard(
      {required this.terms, required this.selectedFrequency});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.lenderAccent.withValues(alpha: 0.4),
      backgroundColor: AppColors.lenderAccent.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.coins,
                  color: AppColors.lenderAccent, size: 16),
              const SizedBox(width: 8),
              const Text('Payment Breakdown',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lenderAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${terms.termDays} days',
                    style: const TextStyle(
                        color: AppColors.lenderAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _TermBox(
                      label: 'Principal', value: terms.principal.toPeso)),
              const SizedBox(width: 8),
              Expanded(
                  child: _TermBox(
                      label: 'Interest (20%)',
                      value: terms.interest.toPeso,
                      valueColor: AppColors.warning)),
              const SizedBox(width: 8),
              Expanded(
                  child: _TermBox(
                      label: 'Total Payable',
                      value: terms.totalPayable.toPeso,
                      highlight: true)),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 12),
          // FIX: All 3 frequencies always shown
          _FreqRow(
              label: 'Daily',
              value: terms.dailyPayment,
              isSelected: selectedFrequency == 'daily'),
          const SizedBox(height: 8),
          _FreqRow(
              label: 'Weekly',
              value: terms.weeklyPayment,
              isSelected: selectedFrequency == 'weekly'),
          const SizedBox(height: 8),
          _FreqRow(
              label: 'Monthly',
              value: terms.monthlyPayment,
              isSelected: selectedFrequency == 'monthly'),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(AppIcons.info, color: Colors.white38, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Deadline: ${terms.termDays} days from disbursement. Penalty of 20% applies after 30 days overdue.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TermBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool highlight;
  const _TermBox(
      {required this.label,
      required this.value,
      this.valueColor,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.lenderAccent.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight
              ? AppColors.lenderAccent.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _FreqRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isSelected;
  const _FreqRow(
      {required this.label, required this.value, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.lenderAccent.withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? AppColors.lenderAccent.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected
                ? AppColors.lenderAccent
                : Colors.white.withValues(alpha: 0.3),
            size: 14,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              )),
          const Spacer(),
          Text(
            '${value.toPeso} / ${label.toLowerCase()}',
            style: TextStyle(
              color: isSelected
                  ? AppColors.lenderAccent
                  : Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step header ───────────────────────────────────────────────────────────────
class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lenderAccent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.lenderAccent.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, color: AppColors.lenderAccent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2)),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Step 1 — Loan details ─────────────────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final TextEditingController amountCtrl;
  final TextEditingController purposeCtrl;
  final String frequency;
  final LoanTerms? loanTerms;
  final bool amountTouched;
  final void Function(String) onFreqChanged;
  final VoidCallback onNext;

  const _Step1({
    required this.amountCtrl,
    required this.purposeCtrl,
    required this.frequency,
    required this.loanTerms,
    required this.amountTouched,
    required this.onFreqChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    // FIX: Show red border when amount is typed but below ₱3,000 (or invalid)
    final raw = amountCtrl.text.trim();
    final amount = double.tryParse(raw.replaceAll(',', ''));
    final amountError = amountTouched && (amount == null || amount < 3000)
        ? 'Minimum loan amount is ₱3,000'
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            icon: AppIcons.banknote,
            title: 'Loan Details',
            subtitle: '₱3,000 – ₱500,000 · 20% flat interest',
          ),
          const SizedBox(height: 24),

          // FIX: errorText makes field border turn red when below ₱3,000
          AppTextField(
            label: 'Loan Amount (₱)',
            hint: '10000',
            controller: amountCtrl,
            isGlass: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            prefixIcon:
                const Icon(AppIcons.banknote, size: 18, color: Colors.white54),
            errorText: amountError,
            validator: (v) => Validators.loanAmount(v),
          ),
          const SizedBox(height: 20),

          if (loanTerms != null) ...[
            _PaymentTermsCard(terms: loanTerms!, selectedFrequency: frequency),
            const SizedBox(height: 20),
          ],

          const Text('Payment Frequency',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          // FIX: Always show Daily, Weekly, Monthly for all amounts
          Row(
            children: ['daily', 'weekly', 'monthly'].asMap().entries.map((e) {
              final i = e.key;
              final f = e.value;
              final selected = frequency == f;
              final payLabel = loanTerms == null
                  ? null
                  : f == 'daily'
                      ? loanTerms!.dailyPayment.toPeso
                      : f == 'weekly'
                          ? loanTerms!.weeklyPayment.toPeso
                          : loanTerms!.monthlyPayment.toPeso;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onFreqChanged(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.lenderAccent
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.lenderAccent
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          f[0].toUpperCase() + f.substring(1),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.white60,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w400,
                            fontSize: 12,
                          ),
                        ),
                        if (payLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(payLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Purpose (optional)',
            hint: 'e.g. Business capital, Medical, Education...',
            controller: purposeCtrl,
            isGlass: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 28),
          AppButton.gradient(
            label: 'Next: Co-maker Info',
            icon: AppIcons.arrowRight,
            width: double.infinity,
            size: AppButtonSize.lg,
            onPressed: onNext,
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ── Step 2 — Co-maker ─────────────────────────────────────────────────────────
class _Step2 extends StatelessWidget {
  final TextEditingController firstCtrl;
  final TextEditingController lastCtrl;
  final TextEditingController middleCtrl;
  final String relationship;
  final List<String> relationships;
  final SignatureController sigCtrl;
  final void Function(String) onRelChanged;
  final VoidCallback onNext;

  const _Step2({
    required this.firstCtrl,
    required this.lastCtrl,
    required this.middleCtrl,
    required this.relationship,
    required this.relationships,
    required this.sigCtrl,
    required this.onRelChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            icon: AppIcons.userCheck,
            title: 'Co-maker Information',
            subtitle: 'A co-maker guarantees your loan application',
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: AppTextField(
              label: 'First Name',
              controller: firstCtrl,
              isGlass: true,
              textCapitalization: TextCapitalization.words,
              validator: Validators.firstName,
            )),
            const SizedBox(width: 10),
            Expanded(
                child: AppTextField(
              label: 'Last Name',
              controller: lastCtrl,
              isGlass: true,
              textCapitalization: TextCapitalization.words,
              validator: Validators.lastName,
            )),
          ]),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Middle Name (optional)',
            controller: middleCtrl,
            isGlass: true,
            textCapitalization: TextCapitalization.words,
            validator: Validators.middleName,
          ),
          const SizedBox(height: 16),
          const Text('Relationship',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: relationship,
                isExpanded: true,
                dropdownColor: const Color(0xFF14183C),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                iconEnabledColor: Colors.white54,
                items: relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => onRelChanged(v ?? relationship),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text('Co-maker Signature',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.lenderAccent.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Signature(
                    controller: sigCtrl,
                    height: 160,
                    backgroundColor: Colors.transparent,
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(AppIcons.edit,
                                color: Colors.white.withValues(alpha: 0.4),
                                size: 13),
                            const SizedBox(width: 6),
                            Text('Draw signature above',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12)),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: () => sigCtrl.clear(),
                          icon: const Icon(AppIcons.close,
                              color: AppColors.lenderAccent, size: 14),
                          label: const Text('Clear',
                              style: TextStyle(
                                  color: AppColors.lenderAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          AppButton.gradient(
            label: 'Next: Review',
            icon: AppIcons.arrowRight,
            width: double.infinity,
            size: AppButtonSize.lg,
            onPressed: onNext,
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ── Step 3 — Review summary ───────────────────────────────────────────────────
class _Step3 extends StatelessWidget {
  final LoanTerms? loanTerms;
  final String frequency;
  final String comakerName;
  final String relationship;
  final VoidCallback onNext;

  const _Step3({
    required this.loanTerms,
    required this.frequency,
    required this.comakerName,
    required this.relationship,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final terms = loanTerms;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            icon: AppIcons.badgeCheck,
            title: 'Review Application',
            subtitle: 'Confirm details before choosing disbursement',
          ),
          const SizedBox(height: 24),
          if (terms != null) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loan Summary',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _InfoRow('Principal', terms.principal.toPeso),
                  _InfoRow('Interest (20%)', terms.interest.toPeso),
                  _InfoRow('Total Payable', terms.totalPayable.toPeso,
                      bold: true),
                  _InfoRow('Term', '${terms.termDays} days'),
                  _InfoRow('Payment Frequency', frequency.titleCase),
                  const SizedBox(height: 8),
                  Divider(
                      color: Colors.white.withValues(alpha: 0.1), height: 1),
                  const SizedBox(height: 12),
                  // FIX: All 3 installment boxes always shown
                  Row(
                    children: [
                      Expanded(
                          child: _InstallmentBox(
                              label: 'Daily',
                              value: terms.dailyPayment.toPeso,
                              isSelected: frequency == 'daily')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _InstallmentBox(
                              label: 'Weekly',
                              value: terms.weeklyPayment.toPeso,
                              isSelected: frequency == 'weekly')),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _InstallmentBox(
                              label: 'Monthly',
                              value: terms.monthlyPayment.toPeso,
                              isSelected: frequency == 'monthly')),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            const GlassCard(
              child: Center(
                  child: Text('Amount not set',
                      style: TextStyle(color: Colors.white70))),
            ),
          ],
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Co-maker',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                _InfoRow('Name', comakerName.isEmpty ? '—' : comakerName),
                _InfoRow('Relationship', relationship),
                const _InfoRow('Signature', 'Provided ✓',
                    valueColor: AppColors.success),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AppButton.gradient(
            label: 'Next: Choose Disbursement',
            icon: AppIcons.arrowRight,
            width: double.infinity,
            size: AppButtonSize.lg,
            onPressed: onNext,
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ── Step 4 — Disbursement method (NEW per spec item 12) ───────────────────────
class _Step4 extends StatelessWidget {
  final DisbursementMethod selectedMethod;
  final TextEditingController gcashNameCtrl;
  final TextEditingController gcashNumberCtrl;
  final bool submitting;
  final void Function(DisbursementMethod) onMethodChanged;
  final VoidCallback onSubmit;

  const _Step4({
    required this.selectedMethod,
    required this.gcashNameCtrl,
    required this.gcashNumberCtrl,
    required this.submitting,
    required this.onMethodChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeader(
            icon: AppIcons.wallet,
            title: 'How do you want to receive the money?',
            subtitle: 'Choose your preferred disbursement method',
          ),
          const SizedBox(height: 24),

          // Method cards
          ...DisbursementMethod.values.map((m) {
            final selected = selectedMethod == m;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onMethodChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.lenderAccent.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? AppColors.lenderAccent.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.15),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.lenderAccent.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(m.icon,
                            color: selected
                                ? AppColors.lenderAccent
                                : Colors.white60,
                            size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.label,
                                style: TextStyle(
                                  color:
                                      selected ? Colors.white : Colors.white70,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                )),
                            const SizedBox(height: 3),
                            Text(m.subtitle,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                )),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: selected
                            ? const Icon(Icons.check_circle_rounded,
                                key: ValueKey('on'),
                                color: AppColors.lenderAccent,
                                size: 22)
                            : Icon(Icons.radio_button_unchecked_rounded,
                                key: const ValueKey('off'),
                                color: Colors.white.withValues(alpha: 0.3),
                                size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // GCash fields — only shown when GCash is selected
          if (selectedMethod == DisbursementMethod.gcash) ...[
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GCash Account Details',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'GCash Account Name',
                    hint: 'Full name registered in GCash',
                    controller: gcashNameCtrl,
                    isGlass: true,
                    textCapitalization: TextCapitalization.words,
                    prefixIcon: const Icon(AppIcons.person,
                        size: 18, color: Colors.white54),
                    validator: Validators.gcashName,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'GCash Number',
                    hint: '09XXXXXXXXX',
                    controller: gcashNumberCtrl,
                    isGlass: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    prefixIcon: const Icon(AppIcons.phone,
                        size: 18, color: Colors.white54),
                    validator: Validators.gcashNumber,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(AppIcons.info,
                          color: AppColors.lenderAccent.withValues(alpha: 0.8),
                          size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'When your loan is approved, funds will be automatically transferred to this GCash number.',
                          style: TextStyle(
                              color: AppColors.lenderAccent
                                  .withValues(alpha: 0.85),
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (selectedMethod == DisbursementMethod.cash) ...[
            const SizedBox(height: 8),
            GlassCard(
              child: Row(
                children: [
                  Icon(AppIcons.info,
                      color: AppColors.lenderAccent.withValues(alpha: 0.8),
                      size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A rider will be assigned to deliver cash to your registered address when your loan is approved.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (selectedMethod == DisbursementMethod.office) ...[
            const SizedBox(height: 8),
            GlassCard(
              child: Row(
                children: [
                  Icon(AppIcons.info,
                      color: AppColors.lenderAccent.withValues(alpha: 0.8),
                      size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'When your loan is approved, you can pick up the cash at our office. You will be notified of the schedule.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          GlassCard(
            borderColor: AppColors.warning.withValues(alpha: 0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(AppIcons.warning,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'By submitting, you agree all information is accurate. A 20% flat interest applies. '
                    'Penalty of 20% of total payable activates after 30 days of non-payment.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton.gradient(
            label: 'Submit Application',
            icon: AppIcons.checkCircle,
            width: double.infinity,
            size: AppButtonSize.lg,
            isLoading: submitting,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _InstallmentBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  const _InstallmentBox(
      {required this.label, required this.value, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.lenderAccent.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.lenderAccent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55), fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                color: isSelected ? AppColors.lenderAccent : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _InfoRow(this.label, this.value, {this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          Text(value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              )),
        ],
      ),
    );
  }
}
