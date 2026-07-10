// lib/features/head_manager/screens/audit/hm_audit_screen.dart
// Fixed: shows actor full name, role, and human-readable description.
// Added: live search by actor name, action, or table.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/audit_log_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../providers/hm_providers.dart';

class HmAuditScreen extends ConsumerStatefulWidget {
  const HmAuditScreen({super.key});
  @override
  ConsumerState<HmAuditScreen> createState() => _HmAuditScreenState();
}

class _HmAuditScreenState extends ConsumerState<HmAuditScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(hmAuditLogsProvider);
    final isDark = context.isDark;

    return Column(
      children: [
        Container(
          color: isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by actor, action, or table...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
                        : null,
                    filled: true,
                    fillColor: isDark ? AppColors.webBorderSoftDk : AppColors.webBorderSoftL,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 16),
              Text('Audit logs are immutable', style: TextStyle(fontSize: 12, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
            ],
          ),
        ),
        Expanded(
          child: logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (logs) {
              final filtered = _query.isEmpty
                  ? logs
                  : logs.where((l) =>
                      (l.actorName?.toLowerCase().contains(_query) ?? false) ||
                      l.action.toLowerCase().contains(_query) ||
                      l.tableName.toLowerCase().contains(_query) ||
                      (l.description?.toLowerCase().contains(_query) ?? false)).toList();
              if (filtered.isEmpty) {
                return EmptyState(
                  icon: Icons.history_rounded,
                  title: _query.isNotEmpty ? 'No results for "$_query"' : 'No audit logs',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _AuditCard(log: filtered[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AuditCard extends StatelessWidget {
  final AuditLogModel log;
  const _AuditCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final actionColor = _colorFor(log.action);
    final isDark = context.isDark;
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
                color: actionColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_iconFor(log.action), size: 16, color: actionColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: actionColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(log.action.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: actionColor, letterSpacing: 0.5)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      log.tableName.snakeToLabel,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                    ),
                    const Spacer(),
                    Text(log.createdAt.toRelative, style: TextStyle(fontSize: 11, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                  ]),
                  const SizedBox(height: 4),
                  // Human-readable description
                  if (log.description != null)
                    Text(log.description!, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.person_outline_rounded, size: 13, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                    const SizedBox(width: 4),
                    Text(
                      log.actorName ?? log.userName ?? 'Unknown',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                    if (log.actorRole != null) ...[ 
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(log.actorRole!.snakeToLabel, style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  if (log.recordId != null) ...[
                    const SizedBox(height: 2),
                    Text('Record: ${log.recordId}', style: TextStyle(fontSize: 10, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight, fontFamily: 'monospace')),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorFor(String action) {
    switch (action) {
      case 'create': return AppColors.success;
      case 'update': return AppColors.info;
      case 'delete': case 'deactivate': return AppColors.error;
      case 'reactivate': return AppColors.warning;
      default: return AppColors.textSecondaryLight;
    }
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'create': return Icons.add_circle_outline_rounded;
      case 'update': return Icons.edit_outlined;
      case 'delete': return Icons.delete_outline_rounded;
      case 'deactivate': return Icons.block_outlined;
      case 'reactivate': return Icons.check_circle_outline_rounded;
      case 'change_password': return Icons.lock_outline_rounded;
      default: return Icons.history_rounded;
    }
  }
}