// lib/features/head_manager/screens/assignments/hm_assignments_screen.dart
//
// FIXES (Issue 13):
//   • "Loan ID" field replaced with lender name dropdown.
//     When Collection is selected: dropdown shows lenders with active/pending
//     loans (fetched from GET /loan-apply/active-lenders). The loan_id is
//     derived server-side from the selected lender.
//   • When Credit Investigation is selected: dropdown changes to lenders
//     whose KYC is pending/under_review (GET /kyc-review/pending-lenders).
//     Rider CI assignment triggers a document verification flow.
//   • Rider dropdown uses value: prop (not initialValue — that does not exist).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/assignment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/hm_providers.dart';

class HmAssignmentsScreen extends ConsumerStatefulWidget {
  const HmAssignmentsScreen({super.key});

  @override
  ConsumerState<HmAssignmentsScreen> createState() =>
      _HmAssignmentsScreenState();
}

class _HmAssignmentsScreenState extends ConsumerState<HmAssignmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _statuses = [
    'all',
    'pending',
    'in_progress',
    'completed',
    'failed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _createAssignment(BuildContext context) async {
    // Pre-fetch both lists before showing dialog
    ref.invalidate(hmRidersProvider);
    ref.invalidate(hmActiveLendersProvider);
    ref.invalidate(hmKycPendingLendersProvider);

    if (!mounted) return;

    final container = ProviderScope.containerOf(context);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => UncontrolledProviderScope(
        container: container,
        child: _HmCreateAssignmentDialog(
          onSubmit: (payload) async {
            final res =
                await ref.read(hmRepositoryProvider).createAssignment(payload);
            return res.success;
          },
        ),
      ),
    );

    if (ok == true && context.mounted) {
      context.showSnack('Assignment created successfully');
      ref.invalidate(hmAssignmentsProvider(null));
      for (final s in _statuses) {
        ref.invalidate(hmAssignmentsProvider(s));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.accent,
                  unselectedLabelColor:
                      Theme.of(context).textTheme.bodyMedium?.color,
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: _statuses
                      .map((s) => Tab(
                            text: s == 'all'
                                ? 'All'
                                : s.replaceAll('_', ' ').titleCase,
                          ))
                      .toList(),
                ),
              ),
              AppButton(
                label: 'Assign Rider',
                icon: Icons.assignment_ind_rounded,
                size: AppButtonSize.sm,
                onPressed: () => _createAssignment(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _statuses.map((s) => _AssignmentList(status: s)).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Create Assignment Dialog ───────────────────────────────────────────────────

class _HmCreateAssignmentDialog extends ConsumerStatefulWidget {
  final Future<bool> Function(Map<String, dynamic> payload) onSubmit;
  const _HmCreateAssignmentDialog({required this.onSubmit});

  @override
  ConsumerState<_HmCreateAssignmentDialog> createState() =>
      _HmCreateAssignmentDialogState();
}

class _HmCreateAssignmentDialogState
    extends ConsumerState<_HmCreateAssignmentDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _riderId;
  String _type = 'collection';
  DateTime? _date;
  bool _loading = false;
  String? _errorMsg;

  // For collection: selected loan entry from active-lenders list
  Map<String, dynamic>? _selectedLoan;
  // For credit investigation: selected KYC entry from pending-lenders list
  Map<String, dynamic>? _selectedKyc;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_riderId == null) {
      setState(() => _errorMsg = 'Please select a rider');
      return;
    }

    if (_type == 'collection') {
      if (_selectedLoan == null) {
        setState(() => _errorMsg = 'Please select a lender/loan');
        return;
      }
      if (_amountCtrl.text.trim().isEmpty) {
        setState(() => _errorMsg = 'Amount is required');
        return;
      }
    } else {
      // credit_investigation
      if (_selectedKyc == null) {
        setState(() =>
            _errorMsg = 'Please select a lender for credit investigation');
        return;
      }
    }

    if (_date == null) {
      setState(() => _errorMsg = 'Select a date');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final payload = <String, dynamic>{
      'rider_id': _riderId!,
      'assignment_type': _type,
      'collection_date': _date!.toApiDate,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    if (_type == 'collection') {
      payload['loan_id'] = _selectedLoan!['loan_id'];
      payload['lender_id'] = _selectedLoan!['lender_id'];
      payload['amount_to_collect'] =
          double.tryParse(_amountCtrl.text.trim()) ?? 0;
    } else {
      // credit_investigation — rider will document-verify the lender
      payload['kyc_id'] = _selectedKyc!['kyc_id'];
      payload['lender_id'] = _selectedKyc!['lender_id'];
      // amount not relevant for CI
      payload['amount_to_collect'] = 0;
    }

    final success = await widget.onSubmit(payload);
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      Navigator.pop(context, true);
    } else {
      setState(
          () => _errorMsg = 'Failed to create assignment. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ridersAsync = ref.watch(hmRidersProvider);
    final activeLendersAsync = ref.watch(hmActiveLendersProvider);
    final kycPendingAsync = ref.watch(hmKycPendingLendersProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.assignment_ind_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Create Assignment',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Assignment type toggle
                const Text('Assignment Type',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _TypeBtn(
                      label: 'Collection',
                      icon: Icons.payments_rounded,
                      selected: _type == 'collection',
                      onTap: () => setState(() {
                        _type = 'collection';
                        _selectedKyc = null;
                      }),
                    )),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _TypeBtn(
                      label: 'Credit Investigation',
                      icon: Icons.search_rounded,
                      selected: _type == 'credit_investigation',
                      onTap: () => setState(() {
                        _type = 'credit_investigation';
                        _selectedLoan = null;
                      }),
                    )),
                  ],
                ),
                const SizedBox(height: 16),

                // Rider dropdown
                const Text('Assign Rider',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ridersAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Could not load riders: $e',
                      style: const TextStyle(color: AppColors.error)),
                  data: (riders) {
                    final validRiderId =
                        riders.any((r) => r.id == _riderId) ? _riderId : null;
                    return DropdownButtonFormField<String>(
                      value: validRiderId,
                      decoration: InputDecoration(
                        hintText: 'Select a rider',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      isExpanded: true,
                      items: riders
                          .map((r) => DropdownMenuItem<String>(
                                value: r.id,
                                child: Text(
                                  '${r.displayName}${!r.isActive ? " (Inactive)" : ""}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _riderId = v),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // FIX #13: Lender name dropdown (collection) or KYC pending (CI)
                if (_type == 'collection') ...[
                  const Text('Select Lender / Loan',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Shows lenders with active or pending loans',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  const SizedBox(height: 8),
                  activeLendersAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Could not load lenders: $e',
                        style: const TextStyle(color: AppColors.error)),
                    data: (lenders) {
                      if (lenders.isEmpty) {
                        return const Text('No active loans found.',
                            style: TextStyle(color: Colors.grey));
                      }
                      final validId = lenders.any(
                              (l) => l['loan_id'] == _selectedLoan?['loan_id'])
                          ? (_selectedLoan?['loan_id'] as String?)
                          : null;
                      return DropdownButtonFormField<String>(
                        value: validId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Select lender',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: lenders
                            .map((l) => DropdownMenuItem<String>(
                                  value: l['loan_id'] as String,
                                  child: Text(
                                    '${l['lender_name']} · ${l['loan_status']?.toString().toUpperCase() ?? ''}'
                                    ' · ₱${(l['outstanding'] as num?)?.toStringAsFixed(0) ?? "0"}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          final entry = lenders.firstWhere(
                              (l) => l['loan_id'] == v,
                              orElse: () => {});
                          setState(() => _selectedLoan = entry);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Amount to Collect (₱)',
                    hint: '0.00',
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ] else ...[
                  // Credit Investigation — lender picker (KYC pending)
                  const Text('Select Lender for Credit Investigation',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Shows lenders with pending KYC submissions',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  const SizedBox(height: 8),
                  kycPendingAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Could not load KYC lenders: $e',
                        style: const TextStyle(color: AppColors.error)),
                    data: (lenders) {
                      if (lenders.isEmpty) {
                        return const Text('No pending KYC submissions found.',
                            style: TextStyle(color: Colors.grey));
                      }
                      final validKycId = lenders.any(
                              (l) => l['kyc_id'] == _selectedKyc?['kyc_id'])
                          ? (_selectedKyc?['kyc_id'] as String?)
                          : null;
                      return DropdownButtonFormField<String>(
                        value: validKycId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Select lender (KYC pending)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                        items: lenders
                            .map((l) => DropdownMenuItem<String>(
                                  value: l['kyc_id'] as String,
                                  child: Text(
                                    '${l['lender_name']} · KYC ${l['kyc_status']?.toString().toUpperCase() ?? "PENDING"}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          final entry = lenders.firstWhere(
                              (l) => l['kyc_id'] == v,
                              orElse: () => {});
                          setState(() => _selectedKyc = entry);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.info, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'The rider will visit the lender, verify documents, '
                            'and submit a credit investigation report. Once submitted, '
                            'head manager and employees can approve or reject the KYC.',
                            style:
                                TextStyle(fontSize: 12, color: AppColors.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),

                // Date picker
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          _date ?? DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: AbsorbPointer(
                    child: AppTextField(
                      label: _type == 'collection'
                          ? 'Collection Date'
                          : 'Investigation Date',
                      hint: 'Tap to select date',
                      controller:
                          TextEditingController(text: _date?.toApiDate ?? ''),
                      readOnly: true,
                      prefixIcon:
                          const Icon(Icons.calendar_today_rounded, size: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                AppTextField(
                  label: 'Notes (optional)',
                  hint: 'Instructions for rider',
                  controller: _notesCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),

                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 13)),
                  ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    AppButton(
                      label: 'Create Assignment',
                      icon: Icons.assignment_turned_in_rounded,
                      isLoading: _loading,
                      size: AppButtonSize.md,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeBtn(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent
              : AppColors.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : AppColors.accent.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: selected ? Colors.white : AppColors.accent, size: 20),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Assignment list tab ────────────────────────────────────────────────────────

class _AssignmentList extends ConsumerWidget {
  final String status;
  const _AssignmentList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(hmAssignmentsProvider(status));
    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (assignments) {
        if (assignments.isEmpty) {
          return const EmptyState(
              icon: Icons.assignment_outlined, title: 'No assignments found');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: assignments.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final a = assignments[i];
            final isCi = a.isCreditInvestigation;
            return Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (isCi ? AppColors.info : AppColors.riderAccent)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCi ? Icons.search_rounded : Icons.payments_rounded,
                        color: isCi ? AppColors.info : AppColors.riderAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(a.lenderName ?? 'Unknown Lender',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (isCi
                                        ? AppColors.info
                                        : AppColors.riderAccent)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                a.assignmentType.label,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isCi
                                        ? AppColors.info
                                        : AppColors.riderAccent),
                              ),
                            ),
                          ]),
                          Text(
                            'Rider: ${a.riderName ?? "Unassigned"} · ${a.collectionDate.toDisplayDate}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isCi ? 'CI' : a.amountToCollect.toPeso,
                          style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        StatusChip.assignmentStatus(a.status.value,
                            small: true),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
