// lib/features/lender/screens/loans/lender_loans_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/loan_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/lender_providers.dart';

class LenderLoansScreen extends ConsumerWidget {
  const LenderLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(lenderMyLoansProvider);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Loans',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                ElevatedButton.icon(
                  onPressed: () => context.go(RouteConstants.lenderApply),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Apply'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lenderAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: loansAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.white70))),
              data: (loans) {
                if (loans.isEmpty) {
                  return EmptyState(
                    icon: Icons.description_outlined,
                    title: 'No loans yet',
                    subtitle: 'Apply for your first loan.',
                    isGlass: true,
                    action: AppButton(
                      label: 'Apply Now',
                      color: AppColors.lenderAccent,
                      onPressed: () => context.go(RouteConstants.lenderApply),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: loans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final loan = loans[i];
                    return GlassCard(
                      onTap: () =>
                          context.go('/lender/loans/${loan.id}'),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.lenderAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.description_rounded,
                                color: AppColors.lenderAccent, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  loan.principalAmount.toPeso,
                                  style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  loan.createdAt.toDisplayDate,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusChip.loanStatus(loan.status.value,
                                  small: true),
                              if (loan.status == LoanStatus.active) ...[
                                const SizedBox(height: 6),
                                Text(
                                  loan.outstandingBalance.toPeso,
                                  style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded,
                              color: Colors.white.withValues(alpha: 0.4)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}