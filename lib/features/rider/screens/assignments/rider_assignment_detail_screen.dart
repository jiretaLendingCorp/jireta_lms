// lib/features/rider/screens/assignments/rider_assignment_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/assignment_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/rider_providers.dart';

class RiderAssignmentDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const RiderAssignmentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<RiderAssignmentDetailScreen> createState() =>
      _RiderAssignmentDetailScreenState();
}

class _RiderAssignmentDetailScreenState
    extends ConsumerState<RiderAssignmentDetailScreen> {
  bool _acting = false;

  Future<void> _markInProgress(AssignmentModel a) async {
    setState(() => _acting = true);
    final res = await ref
        .read(riderRepositoryProvider)
        .updateAssignmentStatus(a.id, 'in_progress');
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Marked as In Progress');
        ref.invalidate(riderAssignmentDetailProvider(widget.id));
        ref.invalidate(riderAssignmentsProvider(null));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _markFailed(AssignmentModel a) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Mark as Failed'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    setState(() => _acting = true);
    final res = await ref.read(riderRepositoryProvider).updateAssignmentStatus(
        a.id, 'failed',
        failureReason: ctrl.text.trim());
    setState(() => _acting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Assignment marked as failed');
        ref.invalidate(riderAssignmentDetailProvider(widget.id));
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  Future<void> _openMaps(AssignmentModel a) async {
    if (a.lenderLat == null || a.lenderLng == null) {
      if (a.lenderAddress != null) {
        final uri = Uri.parse(
            'https://maps.google.com/?q=${Uri.encodeComponent(a.lenderAddress!)}');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      }
      return;
    }
    final uri =
        Uri.parse('https://maps.google.com/?q=${a.lenderLat},${a.lenderLng}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(riderAssignmentDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Assignment Detail'),
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => context.go(RouteConstants.riderAssignments),
        ),
      ),
      body: asyncData.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.riderAccent)),
        error: (e, _) => Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $e',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
        )),
        data: (a) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount hero card
              _AmountHero(a: a),
              const SizedBox(height: 14),

              // Lender info card
              _LenderInfoCard(a: a, onNavigate: () => _openMaps(a)),
              const SizedBox(height: 14),

              // CI type badge
              if (a.isCreditInvestigation) ...[
                _CiNoticeCard(),
                const SizedBox(height: 14),
              ],

              // CI submitted card
              if (a.ciDocumentUrl != null) ...[
                _CiSubmittedCard(a: a),
                const SizedBox(height: 14),
              ],

              // Failure reason (if failed)
              if (a.status == AssignmentStatus.failed &&
                  a.failureReason != null) ...[
                _FailureCard(reason: a.failureReason!),
                const SizedBox(height: 14),
              ],

              // Action buttons
              if (a.status == AssignmentStatus.pending) ...[
                AppButton(
                  label: 'Start Assignment',
                  icon: AppIcons.bike,
                  color: AppColors.riderAccent,
                  textColor: Colors.black87,
                  isLoading: _acting,
                  width: double.infinity,
                  size: AppButtonSize.lg,
                  onPressed: () => _markInProgress(a),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Mark as Failed',
                  isDanger: true,
                  isOutlined: true,
                  isLoading: _acting,
                  width: double.infinity,
                  onPressed: () => _markFailed(a),
                ),
              ],
              if (a.status == AssignmentStatus.inProgress) ...[
                if (a.isCreditInvestigation) ...[
                  AppButton(
                    label: 'Submit Credit Investigation',
                    icon: Icons.policy_rounded,
                    color: AppColors.warning,
                    textColor: Colors.black87,
                    isLoading: _acting,
                    width: double.infinity,
                    size: AppButtonSize.lg,
                    onPressed: () => context.go('/rider/ci-upload/${a.id}'),
                  ),
                ] else ...[
                  AppButton(
                    label: 'Record Collection',
                    icon: Icons.payments_rounded,
                    color: AppColors.riderAccent,
                    textColor: Colors.black87,
                    isLoading: _acting,
                    width: double.infinity,
                    size: AppButtonSize.lg,
                    onPressed: () => context.go('/rider/collect/${a.id}'),
                  ),
                ],
                const SizedBox(height: 12),
                AppButton(
                  label: 'Mark as Failed',
                  isDanger: true,
                  isOutlined: true,
                  isLoading: _acting,
                  width: double.infinity,
                  onPressed: () => _markFailed(a),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Amount Hero Card ───────────────────────────────────────────────────────────

class _AmountHero extends StatelessWidget {
  final AssignmentModel a;
  const _AmountHero({required this.a});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      isGlass: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.riderAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(AppIcons.coins,
                        color: AppColors.riderAccent, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text('Collection Amount',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              StatusChip.assignmentStatus(a.status.value),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            a.amountToCollect.toPeso,
            style: GoogleFonts.jetBrainsMono(
              color: AppColors.riderAccent,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                AppIcons.calendar,
                size: 13,
                color: Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 5),
              Text(
                'Due ${a.collectionDate.toDisplayDate}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Lender Info Card ───────────────────────────────────────────────────────────

class _LenderInfoCard extends StatelessWidget {
  final AssignmentModel a;
  final VoidCallback onNavigate;
  const _LenderInfoCard({required this.a, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      isGlass: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.riderAccent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(AppIcons.user,
                    color: AppColors.riderAccent, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Lender Info',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow('Name', a.lenderName ?? '—'),
          _InfoRow('Address', a.lenderAddress ?? 'Not provided'),
          const SizedBox(height: 14),
          AppButton(
            label: 'Navigate to Location',
            icon: AppIcons.mapPin,
            color: AppColors.riderAccent,
            textColor: Colors.black87,
            width: double.infinity,
            size: AppButtonSize.lg,
            onPressed: onNavigate,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── CI Notice Card ─────────────────────────────────────────────────────────────

class _CiNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      backgroundColor: AppColors.warning.withValues(alpha: 0.10),
      borderColor: AppColors.warning.withValues(alpha: 0.30),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.policy_outlined,
                color: AppColors.warning, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Credit Investigation Assignment',
                    style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('Visit the lender, verify info, and submit CI report.',
                    style: TextStyle(
                        color: AppColors.warning, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── CI Submitted Card ──────────────────────────────────────────────────────────

class _CiSubmittedCard extends StatelessWidget {
  final AssignmentModel a;
  const _CiSubmittedCard({required this.a});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      isGlass: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(AppIcons.checkCircle,
                    color: AppColors.success, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('CI Report Submitted',
                  style: TextStyle(
                      color: AppColors.success,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              if (a.ciCompletedAt != null)
                Text(a.ciCompletedAt!.toDisplayDate,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
            ],
          ),
          if (a.ciNotes != null && a.ciNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Notes: ${a.ciNotes}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Failure Card ───────────────────────────────────────────────────────────────

class _FailureCard extends StatelessWidget {
  final String reason;
  const _FailureCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      backgroundColor: AppColors.error.withValues(alpha: 0.10),
      borderColor: AppColors.error.withValues(alpha: 0.30),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(AppIcons.warning, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Marked as Failed',
                    style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(reason,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
