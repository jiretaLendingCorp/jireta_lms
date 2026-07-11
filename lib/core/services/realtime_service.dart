// lib/core/services/realtime_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  final _client = Supabase.instance.client;
  final Map<String, RealtimeChannel> _channels = {};

  RealtimeChannel _getOrCreate(String channelName) => _channels.putIfAbsent(
        channelName,
        () => _client.channel(channelName),
      );

  void subscribeToTable({
    required String table,
    required String schema,
    required void Function(Map<String, dynamic> payload) onInsert,
    required void Function(Map<String, dynamic> payload) onUpdate,
    required void Function(Map<String, dynamic> payload) onDelete,
    String? filter,
  }) {
    final channel = _getOrCreate('public:$table');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: schema,
          table: table,
          filter: filter != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: filter.split('=')[0],
                  value: filter.split('=')[1])
              : null,
          callback: (payload) => onInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: schema,
          table: table,
          filter: filter != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: filter.split('=')[0],
                  value: filter.split('=')[1])
              : null,
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: schema,
          table: table,
          filter: filter != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: filter.split('=')[0],
                  value: filter.split('=')[1])
              : null,
          callback: (payload) => onDelete(payload.oldRecord),
        )
        .subscribe();
  }

  void unsubscribe(String table) {
    final channel = _channels.remove('public:$table');
    if (channel != null) _client.removeChannel(channel);
  }

  void unsubscribeAll() {
    for (final channel in _channels.values) {
      _client.removeChannel(channel);
    }
    _channels.clear();
  }
}

final realtimeServiceProvider = Provider<RealtimeService>(
  (_) => RealtimeService.instance,
);
