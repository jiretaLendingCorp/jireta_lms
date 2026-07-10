// lib/features/head_manager/screens/kyc/hm_kyc_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/kyc_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/hm_providers.dart';

class HmKycScreen extends ConsumerStatefulWidget {
  const HmKycScreen({super.key});

  @override
  ConsumerState<HmKycScreen> createState() => _HmKycScreenState();
}

class _HmKycScreenState extends ConsumerState<HmKycScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _statuses = ['all', 'pending', 'under_review', 'approved', 'rejected'];

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
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
                .map((s) => Tab(text: s == 'all' ? 'All' : s.replaceAll('_', ' ').titleCase))
                .toList(),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _statuses.map((s) => _KycList(status: s)).toList(),
          ),
        ),
      ],
    );
  }
}

class _KycList extends ConsumerWidget {
  final String status;
  const _KycList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycAsync = ref.watch(hmKycProvider(status));
    return kycAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (kycs) {
        if (kycs.isEmpty) return const EmptyState(icon: Icons.verified_user_outlined, title: 'No KYC submissions');
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: kycs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final k = kycs[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: AppColors.accent, size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.lenderName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('${k.idType} · ${k.createdAt.toDisplayDate}', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    StatusChip.kycStatus(k.status.value, small: true),
                    if (k.status.value == 'pending' || k.status.value == 'under_review') ...[
                      const SizedBox(width: 12),
                      _KycActions(kycId: k.id),
                    ],
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

class _KycActions extends ConsumerStatefulWidget {
  final String kycId;
  const _KycActions({required this.kycId});

  @override
  ConsumerState<_KycActions> createState() => _KycActionsState();
}

class _KycActionsState extends ConsumerState<_KycActions> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
          onPressed: () async {
            setState(() => _loading = true);
            final res = await ref.read(hmRepositoryProvider).approveKyc(widget.kycId);
            setState(() => _loading = false);
            if (context.mounted) {
              context.showSnack(res.success ? 'KYC approved' : res.error!, isError: !res.success);
              if (res.success) {
                ref.invalidate(hmKycProvider('pending'));
                ref.invalidate(hmKycProvider('all'));
              }
            }
          },
          tooltip: 'Approve',
        ),
        IconButton(
          icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
          onPressed: () async {
            final ctrl = TextEditingController();
            final ok = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                title: const Text('Reject KYC'),
                content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()), maxLines: 2),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                  FilledButton(onPressed: () => Navigator.pop(dialogCtx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.error), child: const Text('Reject')),
                ],
              ),
            );
            if (ok != true || ctrl.text.trim().isEmpty) return;
            setState(() => _loading = true);
            final res = await ref.read(hmRepositoryProvider).rejectKyc(widget.kycId, ctrl.text.trim());
            setState(() => _loading = false);
            if (context.mounted) {
              context.showSnack(res.success ? 'KYC rejected' : res.error!, isError: !res.success);
              if (res.success) ref.invalidate(hmKycProvider('all'));
            }
          },
          tooltip: 'Reject',
        ),
      ],
    );
  }
}