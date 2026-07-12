// lib/features/lender/providers/lender_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/lender_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/loan_term_tier_model.dart';

final lenderRepositoryProvider =
    Provider<LenderRepository>((ref) => LenderRepository());

final lenderMyLoansProvider = FutureProvider<List<LoanModel>>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return [];
  final res = await ref.read(lenderRepositoryProvider).listMyLoans();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final lenderLoanDetailProvider = FutureProvider.family<LoanModel, String>(
  (ref, id) async {
    ref.watch(sessionUserIdProvider);
    final res = await ref.read(lenderRepositoryProvider).getLoan(id);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final lenderScheduleProvider =
    FutureProvider.family<List<LoanSchedule>, String>(
  (ref, loanId) async {
    ref.watch(sessionUserIdProvider);
    final res = await ref.read(lenderRepositoryProvider).getSchedule(loanId);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final lenderPaymentHistoryProvider =
    FutureProvider.family<List<PaymentModel>, String>(
  (ref, loanId) async {
    ref.watch(sessionUserIdProvider);
    final res =
        await ref.read(lenderRepositoryProvider).getPaymentHistory(loanId);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final lenderPaymentMethodsProvider =
    FutureProvider<List<SystemPaymentMethod>>((ref) async {
  ref.watch(sessionUserIdProvider);
  final res =
      await ref.read(lenderRepositoryProvider).getAvailablePaymentMethods();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final lenderMyKycProvider = FutureProvider<KycModel?>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return null;
  final res = await ref.read(lenderRepositoryProvider).getMyKyc();
  if (res.success) return res.data;
  throw Exception(res.error);
});

final lenderNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return [];
  final res = await ref.read(lenderRepositoryProvider).listNotifications();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final lenderLifetimeStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final loans = await ref.watch(lenderMyLoansProvider.future);
  final totalLoans = loans.length;
  final activeLoans = loans.where((l) => l.status == LoanStatus.active).length;
  final completedLoans =
      loans.where((l) => l.status == LoanStatus.completed).length;
  final totalBorrowed = loans.fold<double>(0, (s, l) => s + l.principalAmount);
  final totalPayable = loans.fold<double>(0, (s, l) => s + l.totalPayable);
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

final lenderLoanTermTiersProvider =
    FutureProvider<List<LoanTermTierModel>>((ref) async {
  final res = await ref.read(lenderRepositoryProvider).getLoanTermTiers();
  if (res.success) return res.data!;
  throw Exception(res.error);
});
