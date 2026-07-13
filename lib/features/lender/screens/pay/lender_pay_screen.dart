// lib/features/lender/screens/pay/lender_pay_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../providers/lender_providers.dart';

class LenderPayScreen extends ConsumerStatefulWidget {
  final String id;
  const LenderPayScreen({super.key, required this.id});

  @override
  ConsumerState<LenderPayScreen> createState() => _LenderPayScreenState();
}

class _LenderPayScreenState extends ConsumerState<LenderPayScreen> {
  String? _selectedMethod;
  bool _paying = false;

  Future<Position?> _captureLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _pay() async {
    if (_selectedMethod == null) {
      context.showSnack('Please select a payment method', isError: true);
      return;
    }
    setState(() => _paying = true);

    if (_selectedMethod == 'cash') {
      final localCtx = context;
      final date = await showDatePicker(
        context: localCtx,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
      );
      if (!mounted) return;
      if (date == null) {
        setState(() => _paying = false);
        return;
      }
      context.showSnack('Getting your location for the rider...');
      final position = await _captureLocation();
      if (!mounted) return;

      final loan = ref.read(lenderLoanDetailProvider(widget.id)).value;
      final amount = loan?.installmentAmount ?? loan?.outstandingBalance ?? 0;

      final res =
          await ref.read(lenderRepositoryProvider).requestCashCollection(
                widget.id,
                amount,
                date,
                lat: position?.latitude,
                lng: position?.longitude,
              );
      if (!mounted) return;
      setState(() => _paying = false);
      context.showSnack(
          res.success
              ? (position != null
                  ? 'Cash collection requested! Your location was shared with the rider.'
                  : 'Cash collection requested! A rider will be assigned using your address on file.')
              : res.error!,
          isError: !res.success);
      if (res.success) context.go(RouteConstants.lenderHome);
      return;
    }

    final res = await ref
        .read(lenderRepositoryProvider)
        .initiatePayment(widget.id, _selectedMethod!);
    if (!mounted) return;
    setState(() => _paying = false);
    if (res.success && res.data != null && res.data!.isNotEmpty) {
      final uri = Uri.parse(res.data!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      context.showSnack(res.error ?? 'Payment link unavailable', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loanAsync = ref.watch(lenderLoanDetailProvider(widget.id));
    final methodsAsync = ref.watch(lenderPaymentMethodsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Make Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loan summary card
            loanAsync.when(
              loading: () => const ShimmerCard(height: 80),
              error: (_, __) => const SizedBox.shrink(),
              data: (loan) => WhiteCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Outstanding Balance',
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(loan.outstandingBalance.toPeso,
                            style: const TextStyle(
                                color: Color(0xFF1F2937),
                                fontSize: 24,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    if (loan.installmentAmount != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Next installment',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF), fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(loan.installmentAmount!.toPeso,
                              style: const TextStyle(
                                  color: AppColors.lenderAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Select Payment Method',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            methodsAsync.when(
              loading: () => Column(
                children: List.generate(
                    3,
                    (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: ShimmerCard(height: 70),
                        )),
              ),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: Colors.white70)),
              data: (methods) {
                if (methods.isEmpty) {
                  return const WhiteCard(
                    child: Text(
                      'No payment methods available. Contact your loan officer.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                    ),
                  );
                }
                return Column(
                  children: methods.where((m) => m.isEnabled).map((m) {
                    final selected = _selectedMethod == m.method.value;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedMethod = m.method.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.lenderAccent.withValues(alpha: 0.08)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.lenderAccent
                                : const Color(0xFFE5E7EB),
                            width: selected ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (selected
                                        ? AppColors.lenderAccent
                                        : const Color(0xFF9CA3AF))
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_iconFor(m.method),
                                  color: selected
                                      ? AppColors.lenderAccent
                                      : const Color(0xFF9CA3AF),
                                  size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.displayName,
                                      style: TextStyle(
                                          color: const Color(0xFF1F2937),
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 14)),
                                  if (m.description != null)
                                    Text(m.description!,
                                        style: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 12)),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(Icons.check_circle_rounded,
                                  color: AppColors.lenderAccent, size: 20)
                            else
                              const Icon(Icons.radio_button_unchecked,
                                  color: Color(0xFFD1D5DB), size: 20),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            AppButton(
              label: _selectedMethod == 'cash'
                  ? 'Request Rider Pickup'
                  : 'Proceed to Payment',
              color: AppColors.lenderAccent,
              width: double.infinity,
              isLoading: _paying,
              onPressed: _pay,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.gcash:
        return Icons.account_balance_wallet_rounded;
      case PaymentMethod.maya:
        return Icons.credit_card_rounded;
      case PaymentMethod.qr:
        return Icons.qr_code_rounded;
      case PaymentMethod.cash:
        return Icons.delivery_dining_rounded;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_rounded;
      case PaymentMethod.office:
        return Icons.store_rounded;
    }
  }
}
