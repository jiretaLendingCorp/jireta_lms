// lib/features/employee/screens/assignments/emp_assignments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/models/assignment_model.dart';
import '../../providers/emp_providers.dart';

class EmpAssignmentsScreen extends ConsumerWidget {
  const EmpAssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(empAssignmentsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('All Assignments', style: Theme.of(context).textTheme.headlineLarge),
              FilledButton.icon(
                onPressed: () => _showCreateDialog(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New Assignment'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: asyncData.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (assignments) {
              if (assignments.isEmpty) return const EmptyState(icon: Icons.assignment_outlined, title: 'No assignments');
              return ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: assignments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final a = assignments[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.riderAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.assignment_ind_rounded, color: AppColors.riderAccent, size: 20)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.lenderName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('Rider: ${a.riderName ?? 'Unassigned'} · ${a.collectionDate.toDisplayDate}', style: Theme.of(context).textTheme.bodyMedium),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(a.amountToCollect.toPeso, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 4),
                          StatusChip.assignmentStatus(a.status.value, small: true),
                        ]),
                      ]),
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

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final loanIdCtrl = TextEditingController();
    String? selectedRiderId;
    DateTime collectionDate = DateTime.now().add(const Duration(days: 1));
    final amountCtrl = TextEditingController();

    final ridersAsync = await ref.read(empRepositoryProvider).listRiders();
    final riders = ridersAsync.data ?? [];

    if (!context.mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Create Assignment'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: loanIdCtrl, decoration: const InputDecoration(labelText: 'Loan ID', border: OutlineInputBorder(), hintText: 'Paste loan UUID')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedRiderId,
                  decoration: const InputDecoration(labelText: 'Assign Rider', border: OutlineInputBorder()),
                  items: riders.map((r) => DropdownMenuItem(value: r.id, child: Text(r.displayName))).toList(),
                  onChanged: (v) => setSt(() => selectedRiderId = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Amount to Collect (₱)', border: OutlineInputBorder(), prefixText: '₱ '), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Collection Date: ${collectionDate.toDisplayDate}', style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: collectionDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (d != null) setSt(() => collectionDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (ok != true || selectedRiderId == null || loanIdCtrl.text.trim().isEmpty) return;
    final res = await ref.read(empRepositoryProvider).createAssignment({
      'loan_id': loanIdCtrl.text.trim(),
      'rider_id': selectedRiderId,
      'amount_to_collect': double.tryParse(amountCtrl.text) ?? 0,
      'collection_date': collectionDate.toApiDate,
    });
    if (context.mounted) {
      context.showSnack(res.success ? 'Assignment created' : res.error!, isError: !res.success);
      if (res.success) ref.invalidate(empAssignmentsProvider);
    }
  }
}