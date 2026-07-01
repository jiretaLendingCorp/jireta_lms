// lib/features/rider/providers/rider_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/rider_repository.dart';
import '../../../shared/models/assignment_model.dart';
import '../../../shared/models/notification_model.dart';

final riderRepositoryProvider =
    Provider<RiderRepository>((ref) => RiderRepository());

final riderAssignmentsProvider =
    FutureProvider.family<List<AssignmentModel>, String?>(
  (ref, status) async {
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
    final res =
        await ref.read(riderRepositoryProvider).getAssignment(id);
    if (res.success) return res.data!;
    throw Exception(res.error);
  },
);

final riderStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ref.read(riderRepositoryProvider).getMyStats();
  if (res.success) return res.data!;
  return {};
});

final riderNotificationsProvider =
    FutureProvider<List<NotificationModel>>((ref) async {
  final res =
      await ref.read(riderRepositoryProvider).listNotifications();
  if (res.success) return res.data!;
  throw Exception(res.error);
});