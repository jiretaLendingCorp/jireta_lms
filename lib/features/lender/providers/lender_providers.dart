// lib/features/lender/providers/lender_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/lender_repository.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/notification_model.dart';

final lenderRepositoryProvider =
    Provider<LenderRepository>((ref) => LenderRepository());

final lenderMyLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
  final res = await ref.read(lenderRepositoryProvider).listMyLoans();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final lenderLoanDetailProvider = FutureProvider.family<LoanModel, String>(
  (ref, id) async {
    final res = await ref.read(lenderRepositoryProvider).getLoan(id);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final lenderScheduleProvider =
    FutureProvider.family<List<LoanSchedule>, String>(
  (ref, loanId) async {
    final res =
        await ref.read(lenderRepositoryProvider).getSchedule(loanId);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final lenderPaymentHistoryProvider =
    FutureProvider.family<List<PaymentModel>, String>(
  (ref, loanId) async {
    final res =
        await ref.read(lenderRepositoryProvider).getPaymentHistory(loanId);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final lenderPaymentMethodsProvider =
    FutureProvider<List<SystemPaymentMethod>>((ref) async {
  final res =
      await ref.read(lenderRepositoryProvider).getAvailablePaymentMethods();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final lenderMyKycProvider = FutureProvider<KycModel?>((ref) async {
  final res = await ref.read(lenderRepositoryProvider).getMyKyc();
  if (res.success) return res.data;
  throw Exception(res.error);
});

final lenderNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final res =
      await ref.read(lenderRepositoryProvider).listNotifications();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

/// Computed lifetime stats derived from loans list — no extra API call needed.
final lenderLifetimeStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final loans = await ref.watch(lenderMyLoansProvider.future);
  final totalLoans = loans.length;
  final activeLoans =
      loans.where((l) => l.status == LoanStatus.active).length;
  final completedLoans =
      loans.where((l) => l.status == LoanStatus.completed).length;
  final totalBorrowed =
      loans.fold<double>(0, (s, l) => s + l.principalAmount);
  final totalPayable =
      loans.fold<double>(0, (s, l) => s + l.totalPayable);
  final totalOutstanding =
      loans.fold<double>(0, (s, l) => s + l.outstandingBalance);
  return {
    'total_loans': totalLoans,
    'active_loans': activeLoans,
    'completed_loans': completedLoans,
    'total_borrowed': totalBorrowed,
    'total_payable': totalPayable,
    'outstanding_balance': totalOutstanding,
  };
});