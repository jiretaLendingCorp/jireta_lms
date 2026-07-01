// lib/features/head_manager/providers/hm_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/hm_repository.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/audit_log_model.dart';
import '../../../shared/models/notification_model.dart';

final hmRepositoryProvider = Provider<HmRepository>((ref) => HmRepository());

final hmLoansProvider = FutureProvider.family<List<LoanModel>, String?>(
  (ref, status) async {
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.listLoans(status: status == 'all' ? null : status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmLoanDetailProvider = FutureProvider.family<LoanModel, String>(
  (ref, id) async {
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.getLoan(id);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmUsersProvider = FutureProvider.family<List<AppUser>, String?>(
  (ref, role) async {
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.listUsers(role: role == 'all' ? null : role);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

/// Valid account roles the Create User dialog is allowed to submit.
/// Kept in one place so the UI, validation, and dropdown options can never
/// drift out of sync with each other again.
const kCreatableUserRoles = <String>[
  'head_manager',
  'employee',
  'rider',
  'lender',
];

/// Drives the "Create User" dialog. Talks to Supabase exclusively through
/// [HmRepository] (Dio -> user-create Edge Function) -- no direct Supabase
/// client calls, no business logic here. The Edge Function itself further
/// restricts which roles a given caller may create (employees may only
/// create rider/lender accounts); this notifier does not attempt to
/// replicate or second-guess that server-side authorization.
class HmUsersNotifier extends StateNotifier<AsyncValue<void>> {
  HmUsersNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> createUser({
    required String role,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
  }) async {
    if (!kCreatableUserRoles.contains(role)) {
      return 'Invalid role selected.';
    }

    state = const AsyncValue.loading();
    final repo = _ref.read(hmRepositoryProvider);
    final res = await repo.createUser({
      'role': role,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      if (phone != null) 'phone': phone,
    });

    if (res.success) {
      state = const AsyncValue.data(null);
      // Refresh every role tab (including 'all') so the new user shows up
      // immediately without a manual pull-to-refresh.
      for (final role in const ['all', ...kCreatableUserRoles]) {
        _ref.invalidate(hmUsersProvider(role));
      }
      return null;
    }

    state = AsyncValue.error(res.error ?? 'Failed to create user', StackTrace.current);
    return res.error ?? 'Failed to create user';
  }
}

final hmUsersNotifierProvider =
    StateNotifierProvider<HmUsersNotifier, AsyncValue<void>>(
  (ref) => HmUsersNotifier(ref),
);

final hmUserDetailProvider = FutureProvider.family<AppUser, String>(
  (ref, id) async {
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.getUser(id);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmPaymentsProvider = FutureProvider.family<List<PaymentModel>, String?>(
  (ref, status) async {
    final repo = ref.read(hmRepositoryProvider);
    final res =
        await repo.listPayments(status: status == 'all' ? null : status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmKycProvider = FutureProvider.family<List<KycModel>, String?>(
  (ref, status) async {
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.listKyc(status: status == 'all' ? null : status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, String?>(
  (ref, status) async {
    final repo = ref.read(hmRepositoryProvider);
    final res =
        await repo.listAssignments(status: status == 'all' ? null : status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmAnalyticsKpiProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.getAnalyticsKpi();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final hmAnalyticsChartsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.getAnalyticsCharts();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final hmAuditLogsProvider = FutureProvider<List<AuditLogModel>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.listAuditLogs();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final hmSystemSettingsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.getSystemSettings();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final hmNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.listNotifications();
  if (res.success) return res.data!;
  throw Exception(res.error);
});