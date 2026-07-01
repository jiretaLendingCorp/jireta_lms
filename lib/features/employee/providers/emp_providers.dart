// lib/features/employee/providers/emp_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/emp_repository.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/notification_model.dart';

final empRepositoryProvider = Provider<EmpRepository>((ref) => EmpRepository());

final empLoansProvider = FutureProvider.family<List<LoanModel>, String?>(
  (ref, status) async {
    final res = await ref.read(empRepositoryProvider).listLoans(status: status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final empLoanDetailProvider = FutureProvider.family<LoanModel, String>(
  (ref, id) async {
    final res = await ref.read(empRepositoryProvider).getLoan(id);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final empPaymentsProvider = FutureProvider.family<List<PaymentModel>, String?>(
  (ref, status) async {
    final res = await ref.read(empRepositoryProvider).listPayments(status: status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final empKycProvider = FutureProvider.family<List<KycModel>, String?>(
  (ref, status) async {
    final res = await ref.read(empRepositoryProvider).listKyc(status: status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final empAssignmentsProvider = FutureProvider<List<AssignmentModel>>((ref) async {
  final res = await ref.read(empRepositoryProvider).listAssignments();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final empRidersProvider = FutureProvider<List<AppUser>>((ref) async {
  final res = await ref.read(empRepositoryProvider).listRiders();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final empNotificationsProvider = FutureProvider<List<NotificationModel>>((ref) async {
  final res = await ref.read(empRepositoryProvider).listNotifications();
  if (res.success) return res.data!;
  throw Exception(res.error);
});