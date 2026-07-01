// lib/features/head_manager/screens/audit/hm_audit_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../providers/hm_providers.dart';

class HmAuditScreen extends ConsumerWidget {
  const HmAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(hmAuditLogsProvider);

    return Column(
      children: [
        _AuditFilterBar(),
        Expanded(
          child: logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (logs) {
              if (logs.isEmpty) {
                return const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No audit logs',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: logs.length,
                itemBuilder: (_, i) {
                  final log = logs[i];
                  final actionColor = _colorFor(log.action);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: actionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _iconFor(log.action),
                              size: 16,
                              color: actionColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: actionColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        log.action.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: actionColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      log.tableName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (log.recordId != null) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '#${log.recordId!.substring(0, 8)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'By ${log.userName ?? log.userId.substring(0, 8)}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            log.createdAt.toRelative,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Color _colorFor(String action) {
    switch (action.toLowerCase()) {
      case 'insert':
      case 'create':
        return AppColors.success;
      case 'update':
      case 'approve':
      case 'verify':
        return AppColors.info;
      case 'delete':
      case 'reject':
      case 'deactivate':
        return AppColors.error;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  IconData _iconFor(String action) {
    switch (action.toLowerCase()) {
      case 'insert':
      case 'create':
        return Icons.add_circle_outline;
      case 'update':
        return Icons.edit_outlined;
      case 'approve':
      case 'verify':
        return Icons.check_circle_outline;
      case 'delete':
      case 'deactivate':
        return Icons.remove_circle_outline;
      case 'reject':
        return Icons.cancel_outlined;
      default:
        return Icons.history_rounded;
    }
  }
}

class _AuditFilterBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search logs...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Audit logs are immutable and cannot be deleted.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}