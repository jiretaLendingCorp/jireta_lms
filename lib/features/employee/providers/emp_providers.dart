// lib/features/employee/providers/emp_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/emp_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/realtime_providers.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/loan_term_tier_model.dart';
import '../../../shared/models/report_model.dart';

class EmpUsersNotifier extends StateNotifier<AsyncValue<void>> {
  EmpUsersNotifier(this._ref) : super(const AsyncValue.data(null));
  final Ref _ref;

  Future<String?> createUser({
    required String role,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
    String? middleName,
    String? address,
    String? driverLicense,
    String? vehicleInfo,
    String? employer,
    String? monthlyIncome,
    String? birthday,
  }) async {
    if (!['rider', 'lender'].contains(role)) {
      return 'Employees can only create Rider or Lender accounts.';
    }
    state = const AsyncValue.loading();
    final repo = _ref.read(empRepositoryProvider);
    final res = await repo.createUser({
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      if (phone != null) 'phone': phone,
      if (middleName != null) 'middle_name': middleName,
      if (address != null) 'address': address,
      if (driverLicense != null) 'driver_license': driverLicense,
      if (vehicleInfo != null) 'vehicle_info': vehicleInfo,
      if (employer != null) 'employer': employer,
      if (monthlyIncome != null) 'monthly_income': monthlyIncome,
      if (birthday != null) 'birthday': birthday,
    });
    if (res.success) {
      state = const AsyncValue.data(null);
      return null;
    }
    state = AsyncValue.error(res.error ?? 'Failed', StackTrace.current);
    return res.error ?? 'Failed to create user';
  }
}

final empUsersNotifierProvider =
    StateNotifierProvider<EmpUsersNotifier, AsyncValue<void>>(
  (ref) => EmpUsersNotifier(ref),
);

final empRepositoryProvider = Provider<EmpRepository>((ref) => EmpRepository());

final empLoansProvider = FutureProvider.family<List<LoanModel>, String?>(
  (ref, status) async {
    ref.watch(sessionUserIdProvider);
    ref.watch(realtimeLoansStreamProvider);
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
    ref.watch(realtimePaymentsStreamProvider);
    final res =
        await ref.read(empRepositoryProvider).listPayments(status: status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final empKycProvider = FutureProvider.family<List<KycModel>, String?>(
  (ref, status) async {
    ref.watch(sessionUserIdProvider);
    ref.watch(realtimeKycStreamProvider);
    final res = await ref.read(empRepositoryProvider).listKyc(status: status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final empAssignmentsProvider =
    FutureProvider<List<AssignmentModel>>((ref) async {
  ref.watch(realtimeAssignmentsStreamProvider);
  final res = await ref.read(empRepositoryProvider).listAssignments();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final empRidersProvider = FutureProvider<List<AppUser>>((ref) async {
  final res = await ref.read(empRepositoryProvider).listRiders();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final empNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  ref.watch(sessionUserIdProvider);
  ref.watch(realtimeNotificationsStreamProvider);
  final res = await ref.read(empRepositoryProvider).listNotifications();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final empUsersListProvider = FutureProvider.family<List<AppUser>, String>(
  (ref, role) async {
    final res = await ref
        .read(empRepositoryProvider)
        .listUsers(role: role == 'all' ? null : role);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final empLoanTermTiersProvider =
    FutureProvider<List<LoanTermTierModel>>((ref) async {
  final res = await ref.read(empRepositoryProvider).getLoanTermTiers();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final empReportProvider = FutureProvider<ReportResult>((ref) async {
  final res = await ref.read(empRepositoryProvider).getReport();
  if (res.success) return res.data!;
  throw Exception(res.error);
});
