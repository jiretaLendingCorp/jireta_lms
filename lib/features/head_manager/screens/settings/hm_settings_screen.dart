// lib/features/head_manager/screens/settings/hm_settings_screen.dart
// ADDED (016): Loan Term Tier Management card — head_manager (and employee
// in read mode) can edit each tier's term_days, interest_rate, penalty_rate,
// min/max amounts, and penalty_grace_days.
// The tier settings drive get_loan_tier() server-side — lenders see real DB
// values in their apply-screen preview (via /system-settings/public?tiers=).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_term_tier_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../providers/hm_providers.dart';

class HmSettingsScreen extends ConsumerStatefulWidget {
  const HmSettingsScreen({super.key});
  @override
  ConsumerState<HmSettingsScreen> createState() => _HmSettingsScreenState();
}

class _HmSettingsScreenState extends ConsumerState<HmSettingsScreen> {
  final _minCtrl = TextEditingController(text: '3000');
  final _maxCtrl = TextEditingController(text: '500000');
  final _interestCtrl = TextEditingController(text: '20');
  final _penaltyCtrl = TextEditingController(text: '20');
  final _graceDaysCtrl = TextEditingController(text: '30');
  bool _saving = false;
  bool _settingsApplied = false;

  final _paymentMethods = [
    _PayMethod('gcash', 'GCash', 'GCash via Xendit Payment Link', true),
    _PayMethod('maya', 'Maya', 'Maya via Xendit Payment Link', true),
    _PayMethod('qr', 'QR Payment', 'Scannable QR code (GCash/Maya)', true),
    _PayMethod('cash', 'Cash on Pickup', 'Rider collects at location', true),
    _PayMethod('bank_transfer', 'Bank Transfer', 'Manual bank transfer', false),
    _PayMethod('office', 'Office Pickup', 'Pay at our office', false),
  ];

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _interestCtrl.dispose();
    _penaltyCtrl.dispose();
    _graceDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(hmSystemSettingsProvider);

    if (!_settingsApplied) {
      settingsAsync.whenData((data) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applySettings(data);
        });
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Settings',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 4),
          Text('Configure global system parameters',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),

          // ── Row 1: Loan limits + Payment methods ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _LoanLimitsCard(
                minCtrl: _minCtrl,
                maxCtrl: _maxCtrl,
                interestCtrl: _interestCtrl,
                penaltyCtrl: _penaltyCtrl,
                graceDaysCtrl: _graceDaysCtrl,
                saving: _saving,
                onSave: _saveLoanLimits,
              )),
              const SizedBox(width: 16),
              Expanded(
                  child: _PaymentMethodsCard(
                methods: _paymentMethods,
                onToggle: (i, v) =>
                    setState(() => _paymentMethods[i].isEnabled = v),
                saving: _saving,
                onSave: _savePaymentMethods,
              )),
            ],
          ),
          const SizedBox(height: 16),

          // ── Row 2: Tier Management (NEW 016) ─────────────────────────────
          _TierManagementCard(),
          const SizedBox(height: 16),

          const _TermsCard(),
        ],
      ),
    );
  }

  void _applySettings(Map<String, dynamic> data) {
    if (_settingsApplied) return;
    setState(() {
      final min = data['min_loan_amount'];
      final max = data['max_loan_amount'];
      final interest = data['interest_rate'];
      final penalty = data['penalty_rate'];
      final grace = data['penalty_grace_days'];

      if (min != null) _minCtrl.text = (min as num).toInt().toString();
      if (max != null) _maxCtrl.text = (max as num).toInt().toString();
      if (interest != null)
        _interestCtrl.text = ((interest as num) * 100).toStringAsFixed(1);
      if (penalty != null)
        _penaltyCtrl.text = ((penalty as num) * 100).toStringAsFixed(1);
      if (grace != null)
        _graceDaysCtrl.text = (grace as num).toInt().toString();

      final methods = data['payment_methods'] as List<dynamic>?;
      if (methods != null) {
        for (final raw in methods) {
          final m = raw as Map<String, dynamic>;
          final idx = _paymentMethods
              .indexWhere((pm) => pm.method == m['method'] as String?);
          if (idx != -1) {
            _paymentMethods[idx].isEnabled =
                m['is_enabled'] as bool? ?? _paymentMethods[idx].isEnabled;
          }
        }
      }
      _settingsApplied = true;
    });
  }

  Future<void> _saveLoanLimits() async {
    final min = double.tryParse(_minCtrl.text);
    final max = double.tryParse(_maxCtrl.text);
    final interest = double.tryParse(_interestCtrl.text);
    final penalty = double.tryParse(_penaltyCtrl.text);
    final grace = int.tryParse(_graceDaysCtrl.text);

    if (min == null || max == null || min >= max) {
      context.showSnack('Invalid loan amount range', isError: true);
      return;
    }
    if (interest == null || interest < 0 || interest > 100) {
      context.showSnack('Interest rate must be 0–100%', isError: true);
      return;
    }
    if (penalty == null || penalty < 0 || penalty > 100) {
      context.showSnack('Penalty rate must be 0–100%', isError: true);
      return;
    }
    if (grace == null || grace < 0) {
      context.showSnack('Grace period must be ≥ 0 days', isError: true);
      return;
    }

    setState(() => _saving = true);
    final res = await ref.read(hmRepositoryProvider).updateSystemSettings({
      'min_loan_amount': min,
      'max_loan_amount': max,
      'interest_rate': interest / 100,
      'penalty_rate': penalty / 100,
      'penalty_grace_days': grace,
    });
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(res.success ? 'Loan parameters saved' : res.error!,
          isError: !res.success);
      if (res.success) ref.invalidate(hmSystemSettingsProvider);
    }
  }

  Future<void> _savePaymentMethods() async {
    setState(() => _saving = true);
    final res = await ref.read(hmRepositoryProvider).updateSystemSettings({
      'payment_methods': _paymentMethods
          .asMap()
          .entries
          .map((e) => {
                'method': e.value.method,
                'display_name': e.value.displayName,
                'description': e.value.description,
                'is_enabled': e.value.isEnabled,
                'sort_order': e.key,
              })
          .toList(),
    });
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(res.success ? 'Payment methods updated' : res.error!,
          isError: !res.success);
    }
  }
}

// ── _TierManagementCard (NEW 016) ─────────────────────────────────────────────

class _TierManagementCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiersAsync = ref.watch(hmTiersProvider);
    final savingState = ref.watch(hmTiersNotifierProvider);
    final isSaving = savingState is AsyncLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.layers_rounded,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text('Loan Term Tiers',
                  style: Theme.of(context).textTheme.headlineLarge),
              const Spacer(),
              Tooltip(
                message:
                    'Tiers control term days, interest, and penalty for each '
                    'loan amount range. Changes take effect on new applications.',
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: Theme.of(context).colorScheme.outline),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              'Each tier determines the loan term, interest rate, and penalty for '
              'its amount range. Lenders see these rates live when applying.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            tiersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Failed to load tiers: $e',
                  style: const TextStyle(color: AppColors.error)),
              data: (tiers) => Column(
                children: tiers
                    .map((tier) => _TierRow(
                          tier: tier,
                          isSaving: isSaving,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierRow extends ConsumerStatefulWidget {
  final LoanTermTierModel tier;
  final bool isSaving;
  const _TierRow({required this.tier, required this.isSaving});

  @override
  ConsumerState<_TierRow> createState() => _TierRowState();
}

class _TierRowState extends ConsumerState<_TierRow> {
  late final TextEditingController _termCtrl;
  late final TextEditingController _interestCtrl;
  late final TextEditingController _penaltyCtrl;
  late final TextEditingController _graceCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _termCtrl = TextEditingController(text: widget.tier.termDays.toString());
    _interestCtrl = TextEditingController(
        text: widget.tier.interestRatePercent.toStringAsFixed(1));
    _penaltyCtrl = TextEditingController(
        text: widget.tier.penaltyRatePercent.toStringAsFixed(1));
    _graceCtrl =
        TextEditingController(text: widget.tier.penaltyGraceDays.toString());
    _minCtrl =
        TextEditingController(text: widget.tier.minAmount.toStringAsFixed(0));
    _maxCtrl =
        TextEditingController(text: widget.tier.maxAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _termCtrl.dispose();
    _interestCtrl.dispose();
    _penaltyCtrl.dispose();
    _graceCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final termDays = int.tryParse(_termCtrl.text);
    final interest = double.tryParse(_interestCtrl.text);
    final penalty = double.tryParse(_penaltyCtrl.text);
    final grace = int.tryParse(_graceCtrl.text);
    final minAmount = double.tryParse(_minCtrl.text);
    final maxAmount = double.tryParse(_maxCtrl.text);

    if (termDays == null || termDays <= 0) {
      context.showSnack('Term days must be positive', isError: true);
      return;
    }
    if (interest == null || interest < 0 || interest > 100) {
      context.showSnack('Interest must be 0–100%', isError: true);
      return;
    }
    if (penalty == null || penalty < 0 || penalty > 100) {
      context.showSnack('Penalty must be 0–100%', isError: true);
      return;
    }
    if (grace == null || grace < 0) {
      context.showSnack('Grace days must be ≥ 0', isError: true);
      return;
    }
    if (minAmount == null || maxAmount == null || minAmount >= maxAmount) {
      context.showSnack('Max amount must exceed min amount', isError: true);
      return;
    }

    final error = await ref.read(hmTiersNotifierProvider.notifier).updateTier(
      widget.tier.tierLabel,
      {
        'term_days': termDays,
        'interest_rate': interest / 100,
        'penalty_rate': penalty / 100,
        'penalty_grace_days': grace,
        'min_amount': minAmount,
        'max_amount': maxAmount,
      },
    );

    if (mounted) {
      context.showSnack(
          error == null ? '${widget.tier.displayLabel} tier updated' : error,
          isError: error != null);
      if (error == null) setState(() => _expanded = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final tier = widget.tier;
    final accentColor = _tierColor(tier.tierLabel);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: _expanded ? accentColor : Theme.of(context).dividerColor,
          width: _expanded ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(tier.tierLabel[0].toUpperCase(),
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tier.displayLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                          '${tier.termDays}d term · '
                          '${tier.interestRatePercent.toStringAsFixed(0)}% interest · '
                          '${tier.penaltyGraceDays}d grace',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: tier.isActive
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tier.isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            tier.isActive ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ],
              ),
            ),
          ),

          // Expanded edit form
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(color: Theme.of(context).dividerColor),
                  const SizedBox(height: 12),
                  // Amount range
                  Row(children: [
                    Expanded(
                        child: _TierField(
                      ctrl: _minCtrl,
                      label: 'Min Amount (₱)',
                      prefix: '₱',
                      isInt: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _TierField(
                      ctrl: _maxCtrl,
                      label: 'Max Amount (₱)',
                      prefix: '₱',
                      isInt: true,
                    )),
                  ]),
                  const SizedBox(height: 12),
                  // Term + Interest
                  Row(children: [
                    Expanded(
                        child: _TierField(
                      ctrl: _termCtrl,
                      label: 'Term Days',
                      suffix: 'days',
                      isInt: true,
                      helperText: '${_monthCount()} months',
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _TierField(
                      ctrl: _interestCtrl,
                      label: 'Interest Rate',
                      suffix: '%',
                      helperText: 'Flat rate on principal',
                    )),
                  ]),
                  const SizedBox(height: 12),
                  // Penalty + Grace
                  Row(children: [
                    Expanded(
                        child: _TierField(
                      ctrl: _penaltyCtrl,
                      label: 'Penalty Rate',
                      suffix: '%',
                      helperText: 'Applied after grace',
                    )),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _TierField(
                      ctrl: _graceCtrl,
                      label: 'Grace Period',
                      suffix: 'days',
                      isInt: true,
                      helperText: 'Before penalty kicks in',
                    )),
                  ]),
                  const SizedBox(height: 16),
                  AppButton(
                    label: 'Save ${tier.tierLabel.toUpperCase()} Tier',
                    isLoading: widget.isSaving,
                    onPressed: _save,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int _monthCount() {
    final days = int.tryParse(_termCtrl.text) ?? widget.tier.termDays;
    return (days / 30).ceil();
  }

  Color _tierColor(String label) {
    switch (label) {
      case 'micro':
        return Colors.teal;
      case 'small':
        return Colors.blue;
      case 'medium':
        return Colors.orange;
      case 'large':
        return Colors.purple;
      default:
        return AppColors.accent;
    }
  }
}

class _TierField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? prefix;
  final String? suffix;
  final String? helperText;
  final bool isInt;

  const _TierField({
    required this.ctrl,
    required this.label,
    this.prefix,
    this.suffix,
    this.helperText,
    this.isInt = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixText: prefix,
          suffixText: suffix,
          helperText: helperText,
          isDense: true,
        ),
        keyboardType: isInt
            ? TextInputType.number
            : const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: isInt
            ? [FilteringTextInputFormatter.digitsOnly]
            : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        style: const TextStyle(fontSize: 14),
      );
}

// ── Existing sub-widgets ───────────────────────────────────────────────────────

class _PayMethod {
  final String method, displayName, description;
  bool isEnabled;
  _PayMethod(this.method, this.displayName, this.description, this.isEnabled);
}

class _LoanLimitsCard extends StatelessWidget {
  final TextEditingController minCtrl,
      maxCtrl,
      interestCtrl,
      penaltyCtrl,
      graceDaysCtrl;
  final bool saving;
  final VoidCallback onSave;
  const _LoanLimitsCard({
    required this.minCtrl,
    required this.maxCtrl,
    required this.interestCtrl,
    required this.penaltyCtrl,
    required this.graceDaysCtrl,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.tune_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Loan Parameters',
                style: Theme.of(context).textTheme.headlineLarge),
          ]),
          const SizedBox(height: 6),
          Text('Global loan limits and default rates.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: TextField(
              controller: minCtrl,
              decoration: const InputDecoration(
                  labelText: 'Min Amount (₱)',
                  border: OutlineInputBorder(),
                  prefixText: '₱ '),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            )),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
              controller: maxCtrl,
              decoration: const InputDecoration(
                  labelText: 'Max Amount (₱)',
                  border: OutlineInputBorder(),
                  prefixText: '₱ '),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            )),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: TextField(
              controller: interestCtrl,
              decoration: const InputDecoration(
                  labelText: 'Interest Rate (%)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                  helperText: 'Flat rate e.g. 20'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: TextField(
              controller: penaltyCtrl,
              decoration: const InputDecoration(
                  labelText: 'Penalty Rate (%)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                  helperText: 'Per month after grace'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            )),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: graceDaysCtrl,
            decoration: const InputDecoration(
                labelText: 'Grace Period (days)',
                border: OutlineInputBorder(),
                suffixText: 'days',
                helperText: 'Days before penalty applies'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 20),
          AppButton(
              label: 'Save Loan Parameters',
              isLoading: saving,
              onPressed: onSave,
              width: double.infinity),
        ]),
      ));
}

class _PaymentMethodsCard extends StatelessWidget {
  final List<_PayMethod> methods;
  final void Function(int, bool) onToggle;
  final bool saving;
  final VoidCallback onSave;
  const _PaymentMethodsCard({
    required this.methods,
    required this.onToggle,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.payment_rounded,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text('Payment Methods',
                style: Theme.of(context).textTheme.headlineLarge),
          ]),
          const SizedBox(height: 4),
          Text('Only enabled methods appear to lenders',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...methods.asMap().entries.map((e) => _MethodTile(
              method: e.value, onToggle: (v) => onToggle(e.key, v))),
          const SizedBox(height: 16),
          AppButton(
              label: 'Save Payment Methods',
              isLoading: saving,
              onPressed: onSave,
              width: double.infinity),
        ]),
      ));
}

class _MethodTile extends StatelessWidget {
  final _PayMethod method;
  final void Function(bool) onToggle;
  const _MethodTile({required this.method, required this.onToggle});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SwitchListTile(
            title: Text(method.displayName,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle:
                Text(method.description, style: const TextStyle(fontSize: 12)),
            value: method.isEnabled,
            activeThumbColor: AppColors.accent,
            onChanged: onToggle,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        ),
      );
}

class _TermsCard extends StatelessWidget {
  const _TermsCard();
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            const Icon(Icons.gavel_rounded, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Terms & Privacy Policy',
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text('Publish updated T&C and Privacy Policy versions',
                      style: Theme.of(context).textTheme.bodyMedium),
                ])),
            OutlinedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (dlgCtx) => AlertDialog(
                  title: const Text('Publish New Version'),
                  content: const Text(
                      'Update the Terms and Privacy Policy visible to lenders and riders.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dlgCtx),
                        child: const Text('Close'))
                  ],
                ),
              ),
              child: const Text('Publish New Version'),
            ),
          ]),
        ),
      );
}
