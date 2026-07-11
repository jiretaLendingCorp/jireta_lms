// lib/core/providers/realtime_providers.dart
// Supabase Realtime StreamProviders — one per watched table.
// FutureProviders in hm_providers.dart call ref.watch(realtimeXxxStreamProvider)
// so they automatically re-fetch whenever the DB signals a change.
// All sensitive business logic remains server-side; this is read-only signalling.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

StreamProvider<void> _tableStreamProvider(String table) {
  return StreamProvider<void>((ref) {
    final client = Supabase.instance.client;
    final ctrl = StreamController<void>.broadcast();
    final channel = client
        .channel('realtime-$table-${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) {
            if (!ctrl.isClosed) ctrl.add(null);
          },
        )
        .subscribe();
    ref.onDispose(() {
      client.removeChannel(channel);
      ctrl.close();
    });
    return ctrl.stream;
  });
}

/// Fires whenever the loans table changes (insert / update / delete).
final realtimeLoansStreamProvider = _tableStreamProvider('loans');

/// Fires whenever the payments table changes.
final realtimePaymentsStreamProvider = _tableStreamProvider('payments');

/// Fires whenever the kyc_submissions table changes.
final realtimeKycStreamProvider = _tableStreamProvider('kyc_submissions');

/// Fires whenever the assignments table changes.
final realtimeAssignmentsStreamProvider = _tableStreamProvider('assignments');

/// Fires whenever the notifications table changes.
final realtimeNotificationsStreamProvider =
    _tableStreamProvider('notifications');

/// Fires whenever the loan_term_tiers table changes.
final realtimeTiersStreamProvider = _tableStreamProvider('loan_term_tiers');
