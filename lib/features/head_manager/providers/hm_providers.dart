// lib/features/head_manager/providers/hm_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/hm_repository.dart';
import '../../../core/providers/realtime_providers.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/models/loan_model.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/payment_model.dart';
import '../../../shared/models/kyc_model.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/audit_log_model.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/loan_term_tier_model.dart';
import '../../../shared/models/report_model.dart';

final hmRepositoryProvider = Provider<HmRepository>((ref) => HmRepository());

final hmLoansProvider = FutureProvider.family<List<LoanModel>, String?>(
  (ref, status) async {
    ref.watch(sessionUserIdProvider);
    ref.watch(realtimeLoansStreamProvider);
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.listLoans(status: status == 'all' ? null : status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmLoanDetailProvider = FutureProvider.family<LoanModel, String>(
  (ref, id) async {
    ref.watch(realtimeLoansStreamProvider);
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.getLoan(id);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

class UsersFilter {
  final String? role;
  final String? search;
  const UsersFilter({this.role, this.search});

  @override
  bool operator ==(Object other) =>
      other is UsersFilter && other.role == role && other.search == search;

  @override
  int get hashCode => Object.hash(role, search);
}

final hmUsersProvider = FutureProvider.family<List<AppUser>, UsersFilter>(
  (ref, filter) async {
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.listUsers(
      role: filter.role == 'all' ? null : filter.role,
      search: filter.search?.isEmpty == true ? null : filter.search,
    );
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

const kCreatableUserRoles = <String>[
  'head_manager',
  'employee',
  'rider',
  'lender',
];

class HmUsersNotifier extends StateNotifier<AsyncValue<void>> {
  HmUsersNotifier(this._ref) : super(const AsyncValue.data(null));

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
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (middleName != null && middleName.isNotEmpty)
        'middle_name': middleName,
      if (address != null && address.isNotEmpty) 'address': address,
      if (driverLicense != null && driverLicense.isNotEmpty)
        'driver_license': driverLicense,
      if (vehicleInfo != null && vehicleInfo.isNotEmpty)
        'vehicle_info': vehicleInfo,
      if (employer != null && employer.isNotEmpty) 'employer': employer,
      if (monthlyIncome != null && monthlyIncome.isNotEmpty)
        'monthly_income': monthlyIncome,
      if (birthday != null && birthday.isNotEmpty) 'birthday': birthday,
    });

    if (res.success) {
      state = const AsyncValue.data(null);
      _ref.invalidate(hmUsersProvider(const UsersFilter()));
      return null;
    }

    state = AsyncValue.error(
        res.error ?? 'Failed to create user', StackTrace.current);
    return res.error ?? 'Failed to create user';
  }

  Future<String?> updateUser(String id, Map<String, dynamic> payload) async {
    state = const AsyncValue.loading();
    final res = await _ref.read(hmRepositoryProvider).updateUser(id, payload);
    state = const AsyncValue.data(null);
    if (res.success) {
      _ref.invalidate(hmUsersProvider(const UsersFilter()));
      _ref.invalidate(hmUserDetailProvider(id));
      return null;
    }
    return res.error ?? 'Failed to update user';
  }

  Future<String?> resetPassword(String id) async {
    state = const AsyncValue.loading();
    final res = await _ref.read(hmRepositoryProvider).resetUserPassword(id);
    state = const AsyncValue.data(null);
    if (res.success) return null;
    return res.error ?? 'Failed to reset password';
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
    ref.watch(sessionUserIdProvider);
    ref.watch(realtimePaymentsStreamProvider);
    final repo = ref.read(hmRepositoryProvider);
    final res =
        await repo.listPayments(status: status == 'all' ? null : status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmKycProvider = FutureProvider.family<List<KycModel>, String?>(
  (ref, status) async {
    ref.watch(sessionUserIdProvider);
    ref.watch(realtimeKycStreamProvider);
    final repo = ref.read(hmRepositoryProvider);
    final res = await repo.listKyc(status: status == 'all' ? null : status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final hmAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, String?>(
  (ref, status) async {
    ref.watch(sessionUserIdProvider);
    ref.watch(realtimeAssignmentsStreamProvider);
    final repo = ref.read(hmRepositoryProvider);
    final res =
        await repo.listAssignments(status: status == 'all' ? null : status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);
final hmRidersProvider = FutureProvider<List<AppUser>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.listRiders();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final hmAnalyticsKpiProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.getAnalyticsKpi();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

/// All-time totals for the lifetime metrics row on the HM dashboard.
/// Re-uses the KPI response — the analytics edge function returns both
/// MTD figures and lifetime figures under the same response object.
final hmLifetimeMetricsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final kpi = await ref.watch(hmAnalyticsKpiProvider.future);
  // Lifetime keys are returned alongside MTD keys by the analytics function.
  // If the backend doesn't have them yet, default to 0 so the UI still works.
  return {
    'total_loans_ever': kpi['total_loans_ever'] ?? 0,
    'total_lenders': kpi['total_lenders'] ?? 0,
    'total_disbursed': (kpi['total_disbursed'] as num?)?.toDouble() ?? 0.0,
    'total_collected': (kpi['total_collected'] as num?)?.toDouble() ?? 0.0,
    'total_riders': kpi['total_riders'] ?? 0,
    'total_employees': kpi['total_employees'] ?? 0,
  };
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
  ref.watch(realtimeNotificationsStreamProvider);
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.listNotifications();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

/// All loan term tiers; auto-refreshes on any tier table change via Realtime.
final hmTiersProvider = FutureProvider<List<LoanTermTierModel>>((ref) async {
  ref.watch(realtimeTiersStreamProvider);
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.listSystemTiers();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

class ReportFilter {
  final String type;
  final String? dateFrom;
  final String? dateTo;
  const ReportFilter({required this.type, this.dateFrom, this.dateTo});

  @override
  bool operator ==(Object other) =>
      other is ReportFilter &&
      other.type == type &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo;

  @override
  int get hashCode => Object.hash(type, dateFrom, dateTo);
}

/// On-demand typed report provider. Pass [ReportFilter] to trigger generation.
final hmGenerateReportProvider =
    FutureProvider.family<ReportResult, ReportFilter>((ref, filter) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.generateReport(
    type: filter.type,
    dateFrom: filter.dateFrom,
    dateTo: filter.dateTo,
  );
  if (res.success) return res.data!;
  throw Exception(res.error);
});

// ── Tier update notifier ──────────────────────────────────────────────────────

class HmTiersNotifier extends StateNotifier<AsyncValue<void>> {
  HmTiersNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<String?> updateTier(
      String tierLabel, Map<String, dynamic> payload) async {
    state = const AsyncValue.loading();
    final res = await _ref
        .read(hmRepositoryProvider)
        .updateSystemTier({'tier_label': tierLabel, ...payload});
    state = const AsyncValue.data(null);
    if (res.success) {
      _ref.invalidate(hmTiersProvider);
      return null;
    }
    return res.error ?? 'Failed to update tier';
  }
}

final hmTiersNotifierProvider =
    StateNotifierProvider<HmTiersNotifier, AsyncValue<void>>(
  (ref) => HmTiersNotifier(ref),
);

// ── Report state holder + notifier ───────────────────────────────────────────

/// Holds the most recently generated [ReportResult]; null before first generate.
final hmReportProvider = StateProvider<ReportResult?>((ref) => null);

class HmReportNotifier extends StateNotifier<AsyncValue<void>> {
  HmReportNotifier(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<String?> generate({
    required String reportType,
    String? dateFrom,
    String? dateTo,
  }) async {
    state = const AsyncValue.loading();
    final res = await _ref.read(hmRepositoryProvider).generateReport(
          type: reportType,
          dateFrom: dateFrom,
          dateTo: dateTo,
        );
    if (res.success) {
      _ref.read(hmReportProvider.notifier).state = res.data;
      state = const AsyncValue.data(null);
      return null;
    }
    state = AsyncValue.error(
        res.error ?? 'Failed to generate report', StackTrace.current);
    return res.error ?? 'Failed to generate report';
  }

  void clear() {
    _ref.read(hmReportProvider.notifier).state = null;
    state = const AsyncValue.data(null);
  }
}

final hmReportNotifierProvider =
    StateNotifierProvider<HmReportNotifier, AsyncValue<void>>(
  (ref) => HmReportNotifier(ref),
);

// ── Active lenders for assignment dropdown (shows name not UUID) ───────────────
/// Returns lenders who have an active/pending/approved loan.
/// Used in the Create Assignment dialog to show lender names instead of UUIDs.
final hmActiveLendersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.getActiveLenders();
  if (res.success) return (res.data as List).cast<Map<String, dynamic>>();
  throw Exception(res.error);
});

/// Lenders whose KYC is still pending or under_review.
/// Used in the Credit Investigation assignment to pick a lender for CI.
final hmKycPendingLendersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(hmRepositoryProvider);
  final res = await repo.getKycPendingLenders();
  if (res.success) return (res.data as List).cast<Map<String, dynamic>>();
  throw Exception(res.error);
});
