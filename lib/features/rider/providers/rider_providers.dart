// lib/features/rider/providers/rider_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/rider_repository.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/realtime_providers.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/notification_model.dart';

final riderRepositoryProvider =
    Provider<RiderRepository>((ref) => RiderRepository());

final riderAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, String?>(
  (ref, status) async {
    final userId = ref.watch(sessionUserIdProvider);
    if (userId == null) return [];
    ref.watch(realtimeAssignmentsStreamProvider);
    final res = await ref
        .read(riderRepositoryProvider)
        .listMyAssignments(status: status);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final riderAssignmentDetailProvider =
    FutureProvider.family<AssignmentModel, String>(
  (ref, id) async {
    ref.watch(sessionUserIdProvider);
    ref.watch(realtimeAssignmentsStreamProvider);
    final res = await ref.read(riderRepositoryProvider).getAssignment(id);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final riderStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return {};
  ref.watch(realtimeAssignmentsStreamProvider);
  final res = await ref.read(riderRepositoryProvider).getMyStats();
  if (res.success) return res.data!;
  return {};
});

final riderNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return [];
  ref.watch(realtimeNotificationsStreamProvider);
  final res = await ref.read(riderRepositoryProvider).listNotifications();
  if (res.success) return res.data!;
  throw Exception(res.error);
});

final riderLifetimeStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final all = await ref.watch(riderAssignmentsProvider(null).future);
  final completed = all.where((a) => a.status == AssignmentStatus.completed);
  final failed = all.where((a) => a.status == AssignmentStatus.failed);
  final pending = all.where((a) => a.status == AssignmentStatus.pending);
  final inProgress = all.where((a) => a.status == AssignmentStatus.inProgress);
  final ci = all.where((a) => a.isCreditInvestigation);
  final collection = all.where((a) => a.isCollection);
  final totalCollected = completed.fold<double>(
    0,
    (s, a) => s + (a.amountCollected ?? a.amountToCollect),
  );
  return {
    'total_assignments': all.length,
    'completed': completed.length,
    'pending': pending.length,
    'in_progress': inProgress.length,
    'failed': failed.length,
    'credit_investigations': ci.length,
    'collections': collection.length,
    'total_collected': totalCollected,
    'completion_rate':
        all.isEmpty ? 0.0 : (completed.length / all.length * 100),
  };
});
