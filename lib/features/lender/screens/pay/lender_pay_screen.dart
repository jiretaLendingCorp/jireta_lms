// lib/features/lender/screens/pay/lender_pay_screen.dart
//
// REDESIGN (Task 7-A): Material 3 polish, premium glass method cards,
// animated selection state, consistent 14px radius, AppIcons for visual
// consistency. Business logic (cash collection flow + payment link launch)
// preserved exactly as-is.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_icons.dart';
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
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loan summary card
            loanAsync.when(
              loading: () => const ShimmerCard(height: 92),
              error: (_, __) => const SizedBox.shrink(),
              data: (loan) => GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(AppIcons.wallet,
                                  color: AppColors.lenderAccent, size: 16),
                              const SizedBox(width: 6),
                              Text('Outstanding Balance',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(loan.outstandingBalance.toPeso,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),
                    if (loan.installmentAmount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lenderAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                AppColors.lenderAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Next installment',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(loan.installmentAmount!.toPeso,
                                style: const TextStyle(
                                    color: AppColors.lenderAccent,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                const Icon(AppIcons.payments, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Text('Select Payment Method',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),

            methodsAsync.when(
              loading: () => Column(
                children: List.generate(
                    3,
                    (_) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: ShimmerCard(height: 72),
                        )),
              ),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: Colors.white70)),
              data: (methods) {
                if (methods.isEmpty) {
                  return GlassCard(
                    child: Row(
                      children: [
                        const Icon(AppIcons.info,
                            color: AppColors.warning, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No payment methods available. Contact your loan officer.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 14,
                                height: 1.4),
                          ),
                        ),
                      ],
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
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.lenderAccent.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppColors.lenderAccent
                                : Colors.white.withValues(alpha: 0.16),
                            width: selected ? 1.6 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.lenderAccent
                                        .withValues(alpha: 0.18),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.lenderAccent
                                        .withValues(alpha: 0.22)
                                    : Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(_iconFor(m.method),
                                  color: selected
                                      ? AppColors.lenderAccent
                                      : Colors.white.withValues(alpha: 0.7),
                                  size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.displayName,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          fontSize: 14)),
                                  if (m.description != null)
                                    Text(m.description!,
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.55),
                                            fontSize: 12,
                                            height: 1.3)),
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
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      size: 22),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 28),
            AppButton.gradient(
              label: _selectedMethod == 'cash'
                  ? 'Request Rider Pickup'
                  : 'Proceed to Payment',
              icon: _selectedMethod == 'cash'
                  ? AppIcons.truck
                  : AppIcons.arrowRight,
              width: double.infinity,
              size: AppButtonSize.lg,
              isLoading: _paying,
              onPressed: _pay,
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.gcash:
        return AppIcons.wallet;
      case PaymentMethod.maya:
        return AppIcons.payments;
      case PaymentMethod.qr:
        return AppIcons.qrCode;
      case PaymentMethod.cash:
        return AppIcons.truck;
      case PaymentMethod.bankTransfer:
        return AppIcons.landmark;
      case PaymentMethod.office:
        return AppIcons.store;
    }
  }
}
