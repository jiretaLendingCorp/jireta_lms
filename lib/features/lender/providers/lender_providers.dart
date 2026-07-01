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