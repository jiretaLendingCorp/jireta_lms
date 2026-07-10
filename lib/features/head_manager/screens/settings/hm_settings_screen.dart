// lib/features/head_manager/screens/settings/hm_settings_screen.dart
// Fixed: interest_rate and penalty_rate now controllable by head manager.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
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
    _minCtrl.dispose(); _maxCtrl.dispose(); _interestCtrl.dispose();
    _penaltyCtrl.dispose(); _graceDaysCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(hmSystemSettingsProvider);
    if (!_settingsApplied) {
      settingsAsync.whenData((data) {
        WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _applySettings(data); });
      });
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('System Settings', style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 4),
          Text('Configure global system parameters', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _LoanLimitsCard(
                minCtrl: _minCtrl, maxCtrl: _maxCtrl,
                interestCtrl: _interestCtrl, penaltyCtrl: _penaltyCtrl, graceDaysCtrl: _graceDaysCtrl,
                saving: _saving, onSave: _saveLoanLimits,
              )),
              const SizedBox(width: 16),
              Expanded(child: _PaymentMethodsCard(
                methods: _paymentMethods,
                onToggle: (i, v) => setState(() => _paymentMethods[i].isEnabled = v),
                saving: _saving, onSave: _savePaymentMethods,
              )),
            ],
          ),
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
      if (interest != null) _interestCtrl.text = ((interest as num) * 100).toStringAsFixed(1);
      if (penalty != null) _penaltyCtrl.text = ((penalty as num) * 100).toStringAsFixed(1);
      if (grace != null) _graceDaysCtrl.text = (grace as num).toInt().toString();
      final methods = data['payment_methods'] as List<dynamic>?;
      if (methods != null) {
        for (final raw in methods) {
          final m = raw as Map<String, dynamic>;
          final idx = _paymentMethods.indexWhere((pm) => pm.method == m['method'] as String?);
          if (idx != -1) _paymentMethods[idx].isEnabled = m['is_enabled'] as bool? ?? _paymentMethods[idx].isEnabled;
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
    if (min == null || max == null || min >= max) { context.showSnack('Invalid loan amount range', isError: true); return; }
    if (interest == null || interest < 0 || interest > 100) { context.showSnack('Interest rate must be 0-100%', isError: true); return; }
    if (penalty == null || penalty < 0 || penalty > 100) { context.showSnack('Penalty rate must be 0-100%', isError: true); return; }
    if (grace == null || grace < 0) { context.showSnack('Grace period must be >= 0 days', isError: true); return; }
    setState(() => _saving = true);
    final res = await ref.read(hmRepositoryProvider).updateSystemSettings({
      'min_loan_amount': min, 'max_loan_amount': max,
      'interest_rate': interest / 100, 'penalty_rate': penalty / 100, 'penalty_grace_days': grace,
    });
    setState(() => _saving = false);
    if (mounted) {
      context.showSnack(res.success ? 'Loan parameters saved - lenders will see new rates' : res.error!, isError: !res.success);
      if (res.success) ref.invalidate(hmSystemSettingsProvider);
    }
  }

  Future<void> _savePaymentMethods() async {
    setState(() => _saving = true);
    final res = await ref.read(hmRepositoryProvider).updateSystemSettings({
      'payment_methods': _paymentMethods.asMap().entries.map((e) => {
        'method': e.value.method, 'display_name': e.value.displayName,
        'description': e.value.description, 'is_enabled': e.value.isEnabled, 'sort_order': e.key,
      }).toList(),
    });
    setState(() => _saving = false);
    if (mounted) context.showSnack(res.success ? 'Payment methods updated' : res.error!, isError: !res.success);
  }
}

class _PayMethod {
  final String method, displayName, description;
  bool isEnabled;
  _PayMethod(this.method, this.displayName, this.description, this.isEnabled);
}

class _LoanLimitsCard extends StatelessWidget {
  final TextEditingController minCtrl, maxCtrl, interestCtrl, penaltyCtrl, graceDaysCtrl;
  final bool saving;
  final VoidCallback onSave;
  const _LoanLimitsCard({required this.minCtrl, required this.maxCtrl, required this.interestCtrl, required this.penaltyCtrl, required this.graceDaysCtrl, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.tune_rounded, size: 18, color: AppColors.accent), const SizedBox(width: 8), Text('Loan Parameters', style: Theme.of(context).textTheme.headlineLarge)]),
        const SizedBox(height: 6),
        Text('Lenders see these limits and rates when applying.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Min Amount (P)', border: OutlineInputBorder(), prefixText: 'P '), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: maxCtrl, decoration: const InputDecoration(labelText: 'Max Amount (P)', border: OutlineInputBorder(), prefixText: 'P '), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(controller: interestCtrl, decoration: const InputDecoration(labelText: 'Interest Rate (%)', border: OutlineInputBorder(), suffixText: '%', helperText: 'Flat rate e.g. 20'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: penaltyCtrl, decoration: const InputDecoration(labelText: 'Penalty Rate (%)', border: OutlineInputBorder(), suffixText: '%', helperText: 'Per month after grace'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
        ]),
        const SizedBox(height: 16),
        TextField(controller: graceDaysCtrl, decoration: const InputDecoration(labelText: 'Grace Period (days)', border: OutlineInputBorder(), suffixText: 'days', helperText: 'Days before penalty applies'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
        const SizedBox(height: 20),
        AppButton(label: 'Save Loan Parameters', isLoading: saving, onPressed: onSave, width: double.infinity),
      ]),
    ));
  }
}

class _PaymentMethodsCard extends StatelessWidget {
  final List<_PayMethod> methods;
  final void Function(int, bool) onToggle;
  final bool saving;
  final VoidCallback onSave;
  const _PaymentMethodsCard({required this.methods, required this.onToggle, required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.payment_rounded, size: 18, color: AppColors.accent), const SizedBox(width: 8), Text('Payment Methods', style: Theme.of(context).textTheme.headlineLarge)]),
        const SizedBox(height: 4),
        Text('Only enabled methods appear to lenders', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        ...methods.asMap().entries.map((e) => _MethodTile(method: e.value, onToggle: (v) => onToggle(e.key, v))),
        const SizedBox(height: 16),
        AppButton(label: 'Save Payment Methods', isLoading: saving, onPressed: onSave, width: double.infinity),
      ]),
    ));
  }
}

class _MethodTile extends StatelessWidget {
  final _PayMethod method;
  final void Function(bool) onToggle;
  const _MethodTile({required this.method, required this.onToggle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor), borderRadius: BorderRadius.circular(10)),
      child: SwitchListTile(
        title: Text(method.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(method.description, style: const TextStyle(fontSize: 12)),
        value: method.isEnabled, activeThumbColor: AppColors.accent, onChanged: onToggle,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Terms & Privacy Policy', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 4),
          Text('Publish updated T&C and Privacy Policy versions', style: Theme.of(context).textTheme.bodyMedium),
        ])),
        OutlinedButton(
          onPressed: () => showDialog(context: context, builder: (dlgCtx) => AlertDialog(
            title: const Text('Publish New Version'),
            content: const Text('Update the Terms and Privacy Policy visible to lenders and riders.'),
            actions: [TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Close'))],
          )),
          child: const Text('Publish New Version'),
        ),
      ]),
    ),
  );
}