// lib/features/lender/screens/pay/lender_pay_methods_screen.dart
//
// REDESIGN (Task 7-A): Material 3 polish, premium glass method cards with
// consistent 14px radius, AppIcons for visual consistency, animated selection
// state on tap. Empty state and shimmer preserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/models/payment_model.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../providers/lender_providers.dart';

class LenderPayMethodsScreen extends ConsumerWidget {
  const LenderPayMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(lenderPaymentMethodsProvider);
    final loansAsync = ref.watch(lenderMyLoansProvider);

    final activeLoan = loansAsync.valueOrNull
        ?.where((l) => l.status == LoanStatus.active)
        .firstOrNull;

    final bottomPad = MediaQuery.of(context).padding.bottom + 100;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lenderAccent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(AppIcons.payments,
                      color: AppColors.lenderAccent, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Payment Methods',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                'Choose how you want to pay your loan',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            if (activeLoan == null)
              GlassCard(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.lenderAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(AppIcons.info,
                          color: AppColors.lenderAccent, size: 32),
                    ),
                    const SizedBox(height: 14),
                    const Text('No Active Loan',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'You need an active loan to make a payment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    AppButton.gradient(
                      label: 'Apply for a Loan',
                      icon: AppIcons.plusCircle,
                      width: double.infinity,
                      size: AppButtonSize.lg,
                      onPressed: () => context.go(RouteConstants.lenderApply),
                    ),
                  ],
                ),
              )
            else
              methodsAsync.when(
                loading: () => Column(
                  children: List.generate(
                    4,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ShimmerCard(height: 78),
                    ),
                  ),
                ),
                error: (e, _) => GlassCard(
                  child: Row(
                    children: [
                      const Icon(AppIcons.warning,
                          color: AppColors.warning, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Unable to load payment methods: $e',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                data: (methods) => Column(
                  children: methods
                      .where((m) => m.isEnabled)
                      .map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PayMethodCard(
                              method: m,
                              loanId: activeLoan.id,
                            ),
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

class _PayMethodCard extends StatelessWidget {
  final SystemPaymentMethod method;
  final String loanId;
  const _PayMethodCard({required this.method, required this.loanId});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () =>
          context.go('/lender/pay/$loanId?method=${method.method.name}'),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.lenderAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconFor(method.method.name),
                color: AppColors.lenderAccent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.displayName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                if (method.description != null)
                  Text(method.description!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          height: 1.3)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(AppIcons.chevronRight,
                color: Colors.white.withValues(alpha: 0.5), size: 16),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String m) {
    switch (m) {
      case 'gcash':
        return AppIcons.wallet;
      case 'maya':
        return AppIcons.payments;
      case 'qr':
        return AppIcons.qrCode;
      case 'cash':
        return AppIcons.banknote;
      case 'bankTransfer':
        return AppIcons.landmark;
      case 'office':
        return AppIcons.store;
      default:
        return AppIcons.payments;
    }
  }
}
