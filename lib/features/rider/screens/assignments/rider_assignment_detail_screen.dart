// lib/features/rider/screens/assignments/rider_assignment_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final res = await ref
        .read(riderRepositoryProvider)
        .updateAssignmentStatus(a.id, 'failed',
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
    final uri = Uri.parse(
        'https://maps.google.com/?q=${a.lenderLat},${a.lenderLng}');
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go(RouteConstants.riderAssignments),
        ),
      ),
      body: asyncData.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) =>
            Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
        data: (a) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Collection Amount',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                        StatusChip.assignmentStatus(a.status.value),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      a.amountToCollect.toPeso,
                      style: GoogleFonts.jetBrainsMono(
                        color: AppColors.riderAccent,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due: ${a.collectionDate.toDisplayDate}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lender Info',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 14),
                    _InfoRow('Name', a.lenderName ?? '-'),
                    _InfoRow('Address', a.lenderAddress ?? 'Not provided'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openMaps(a),
                        icon: const Icon(Icons.navigation_rounded, size: 18),
                        label: const Text('Navigate to Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.riderAccent,
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (a.status == AssignmentStatus.pending) ...[
                AppButton(
                  label: 'Mark as In Progress',
                  icon: Icons.directions_bike_rounded,
                  color: AppColors.riderAccent,
                  textColor: Colors.black87,
                  isLoading: _acting,
                  width: double.infinity,
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
                AppButton(
                  label: 'Record Collection',
                  icon: Icons.payments_rounded,
                  color: AppColors.riderAccent,
                  textColor: Colors.black87,
                  isLoading: _acting,
                  width: double.infinity,
                  onPressed: () => context.go('/rider/collect/${a.id}'),
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
            ],
          ),
        ),
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
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}