// lib/features/lender/screens/apply/lender_apply_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/lender_providers.dart';

class LenderApplyScreen extends ConsumerStatefulWidget {
  const LenderApplyScreen({super.key});

  @override
  ConsumerState<LenderApplyScreen> createState() => _LenderApplyScreenState();
}

class _LenderApplyScreenState extends ConsumerState<LenderApplyScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _submitting = false;

  // Step 1
  final _amountCtrl = TextEditingController();
  String _frequency = 'monthly';
  final _purposeCtrl = TextEditingController();

  // Step 2 — co-maker
  final _cmFirstCtrl = TextEditingController();
  final _cmLastCtrl = TextEditingController();
  final _cmMiddleCtrl = TextEditingController();
  String _relationship = 'Spouse';
  final _sigCtrl = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.white,
    exportBackgroundColor: Colors.transparent,
  );

  final _relationships = [
    'Spouse', 'Parent', 'Sibling', 'Relative', 'Friend', 'Colleague', 'Neighbor'
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    _amountCtrl.dispose();
    _purposeCtrl.dispose();
    _cmFirstCtrl.dispose();
    _cmLastCtrl.dispose();
    _cmMiddleCtrl.dispose();
    _sigCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !_validateStep1()) return;
    if (_step == 1 && !_validateStep2()) return;
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.animateToPage(_step,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  bool _validateStep1() {
    final err = Validators.loanAmount(_amountCtrl.text);
    if (err != null) { context.showSnack(err, isError: true); return false; }
    return true;
  }

  bool _validateStep2() {
    if (_cmFirstCtrl.text.trim().isEmpty || _cmLastCtrl.text.trim().isEmpty) {
      context.showSnack('Enter co-maker name', isError: true);
      return false;
    }
    if (_sigCtrl.isEmpty) {
      context.showSnack('Co-maker signature is required', isError: true);
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    Uint8List? sigBytes;
    if (_sigCtrl.isNotEmpty) {
      final img = await _sigCtrl.toPngBytes();
      sigBytes = img;
    }

    final amount = double.parse(
        _amountCtrl.text.replaceAll(',', '').replaceAll('₱', ''));
    final interest = amount * 0.20;
    final total = amount * 1.20;

    final payload = {
      'principal_amount': amount,
      'interest_amount': interest,
      'total_payable': total,
      'preferred_frequency': _frequency,
      'purpose': _purposeCtrl.text.trim(),
      'comaker': {
        'first_name': _cmFirstCtrl.text.trim(),
        'last_name': _cmLastCtrl.text.trim(),
        'middle_name': _cmMiddleCtrl.text.trim(),
        'relationship': _relationship,
      },
      'has_signature': sigBytes != null,
    };

    final res = await ref.read(lenderRepositoryProvider).applyLoan(payload);
    setState(() => _submitting = false);

    if (mounted) {
      if (res.success) {
        context.showSnack('Application submitted successfully!');
        context.go(RouteConstants.lenderLoans);
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Apply for Loan — Step ${_step + 1} of 3'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_step > 0) {
              setState(() => _step--);
              _pageCtrl.animateToPage(_step,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut);
            } else {
              context.go(RouteConstants.lenderHome);
            }
          },
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1(
                  amountCtrl: _amountCtrl,
                  purposeCtrl: _purposeCtrl,
                  frequency: _frequency,
                  onFreqChanged: (v) => setState(() => _frequency = v),
                  onNext: _next,
                ),
                _Step2(
                  firstCtrl: _cmFirstCtrl,
                  lastCtrl: _cmLastCtrl,
                  middleCtrl: _cmMiddleCtrl,
                  relationship: _relationship,
                  relationships: _relationships,
                  sigCtrl: _sigCtrl,
                  onRelChanged: (v) => setState(() => _relationship = v),
                  onNext: _next,
                ),
                _Step3(
                  amount: double.tryParse(
                          _amountCtrl.text.replaceAll(',', '')) ?? 0,
                  frequency: _frequency,
                  comakerName:
                      '${_cmFirstCtrl.text} ${_cmLastCtrl.text}'.trim(),
                  relationship: _relationship,
                  submitting: _submitting,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: done || active
                          ? AppColors.lenderAccent
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 4),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _Step1 extends StatelessWidget {
  final TextEditingController amountCtrl;
  final TextEditingController purposeCtrl;
  final String frequency;
  final void Function(String) onFreqChanged;
  final VoidCallback onNext;

  const _Step1({
    required this.amountCtrl,
    required this.purposeCtrl,
    required this.frequency,
    required this.onFreqChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Loan Details',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('₱3,000 – ₱500,000 · 20% flat interest',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Loan Amount (₱)',
            hint: '10000',
            controller: amountCtrl,
            isGlass: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            prefixIcon: const Icon(Icons.attach_money, size: 18, color: Colors.white54),
            validator: Validators.loanAmount,
          ),
          const SizedBox(height: 20),
          const Text('Payment Frequency',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(
            children: ['daily', 'weekly', 'monthly'].map((f) {
              final selected = frequency == f;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onFreqChanged(f),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.lenderAccent
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? AppColors.lenderAccent
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Text(
                      f[0].toUpperCase() + f.substring(1),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white60,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        fontSize: 13,
                      ),
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
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Next: Co-maker Info',
            color: AppColors.lenderAccent,
            width: double.infinity,
            onPressed: onNext,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Co-maker Information',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('A co-maker guarantees your loan application',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: AppTextField(
                    label: 'First Name',
                    controller: firstCtrl,
                    isGlass: true,
                    textCapitalization: TextCapitalization.words)),
            const SizedBox(width: 10),
            Expanded(
                child: AppTextField(
                    label: 'Last Name',
                    controller: lastCtrl,
                    isGlass: true,
                    textCapitalization: TextCapitalization.words)),
          ]),
          const SizedBox(height: 14),
          AppTextField(
              label: 'Middle Name (optional)',
              controller: middleCtrl,
              isGlass: true,
              textCapitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          const Text('Relationship',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: relationship,
                isExpanded: true,
                dropdownColor: const Color(0xFF241055),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                iconEnabledColor: Colors.white54,
                items: relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => onRelChanged(v ?? relationship),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Co-maker Signature',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Signature(
                    controller: sigCtrl,
                    height: 150,
                    backgroundColor: Colors.transparent,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Draw signature above',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12)),
                        TextButton(
                          onPressed: () => sigCtrl.clear(),
                          child: const Text('Clear',
                              style: TextStyle(
                                  color: AppColors.lenderAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Next: Review & Submit',
            color: AppColors.lenderAccent,
            width: double.infinity,
            onPressed: onNext,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _Step3 extends StatelessWidget {
  final double amount;
  final String frequency;
  final String comakerName;
  final String relationship;
  final bool submitting;
  final VoidCallback onSubmit;

  const _Step3({
    required this.amount,
    required this.frequency,
    required this.comakerName,
    required this.relationship,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final interest = amount * 0.20;
    final total = amount * 1.20;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review Application',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Confirm details before submitting',
              style:
                  TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Loan Summary',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _InfoRow('Principal', amount.toPeso),
                _InfoRow('Interest (20%)', interest.toPeso),
                _InfoRow('Total Payable', total.toPeso, bold: true),
                _InfoRow('Payment Frequency', frequency.titleCase),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Co-maker',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                _InfoRow('Name', comakerName.isEmpty ? '—' : comakerName),
                _InfoRow('Relationship', relationship),
                const _InfoRow('Signature', 'Provided ✓'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GlassCard(
            borderColor: AppColors.warning.withValues(alpha: 0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'By submitting, you agree that all information is accurate. A 20% flat interest applies. Penalty of 20% of total payable activates after 30 days of non-payment.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          AppButton(
            label: 'Submit Application',
            color: AppColors.lenderAccent,
            width: double.infinity,
            isLoading: submitting,
            onPressed: onSubmit,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _InfoRow(this.label, this.value, {this.bold = false});

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
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}