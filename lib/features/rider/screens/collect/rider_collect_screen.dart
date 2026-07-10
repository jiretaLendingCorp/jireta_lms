// lib/features/rider/screens/collect/rider_collect_screen.dart
//
// FIX #7 (rider): Amount to collect is PRE-FILLED from the assignment's
//   amountToCollect and is READ-ONLY. The rider should NEVER type an amount
//   because the amount due is set by the loan's payment schedule (daily/weekly/
//   monthly installment). This prevents over/under collection errors.
//   The amount is shown prominently but not editable.
//
// Proper Dio → TypeScript Edge Function flow maintained.
// Receipt photo upload goes through the payment-record Edge Function (TS).

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/rider_providers.dart';

class RiderCollectScreen extends ConsumerStatefulWidget {
  final String id;
  const RiderCollectScreen({super.key, required this.id});

  @override
  ConsumerState<RiderCollectScreen> createState() =>
      _RiderCollectScreenState();
}

class _RiderCollectScreenState extends ConsumerState<RiderCollectScreen> {
  final _notesCtrl = TextEditingController();
  Uint8List? _receiptBytes;
  String _receiptExt = 'jpg';
  bool _submitting = false;

  // FIX #7: Amount is read from assignment — NOT from a user-typed field.
  // This is the amount the lender is expected to pay per their chosen frequency.
  double? _amountToCollect;

  @override
  void initState() {
    super.initState();
    // Pre-load the amount from the assignment provider cache
    final assignment =
        ref.read(riderAssignmentDetailProvider(widget.id)).value;
    if (assignment != null) {
      _amountToCollect = assignment.amountToCollect;
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _receiptBytes = bytes;
      _receiptExt = file.path.split('.').last.toLowerCase();
    });
  }

  Future<void> _submit() async {
    final amount = _amountToCollect;
    if (amount == null || amount <= 0) {
      context.showSnack('Collection amount is missing from assignment',
          isError: true);
      return;
    }
    if (_receiptBytes == null) {
      context.showSnack('Please attach a receipt photo', isError: true);
      return;
    }
    setState(() => _submitting = true);
    // Sends amount (from assignment), receipt bytes, notes to the
    // payment-record TypeScript Edge Function via Dio multipart upload.
    final res = await ref.read(riderRepositoryProvider).submitCollection(
          widget.id,
          amount,
          _receiptBytes!,
          _receiptExt,
          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
    setState(() => _submitting = false);
    if (mounted) {
      if (res.success) {
        context.showSnack('Collection recorded successfully');
        ref.invalidate(riderAssignmentsProvider(null));
        ref.invalidate(riderAssignmentDetailProvider(widget.id));
        context.go(RouteConstants.riderAssignments);
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF374151)),
              title: const Text('Take Photo',
                  style: TextStyle(color: Color(0xFF1F2937))),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF374151)),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Color(0xFF1F2937))),
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickReceipt(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignmentAsync =
        ref.watch(riderAssignmentDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Record Collection'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/rider/assignments/${widget.id}'),
        ),
      ),
      body: assignmentAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white70))),
        data: (assignment) {
          // Keep amount in sync with loaded assignment
          _amountToCollect ??= assignment.amountToCollect;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info card ──────────────────────────────────────────────
                WhiteCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Collecting from ${assignment.lenderName ?? "Lender"}',
                        style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      // FIX #4/#7: Amount is locked — shown prominently, NOT editable
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.riderAccent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.riderAccent
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.payments_rounded,
                              color: AppColors.riderAccent, size: 22),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount to Collect',
                                style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    fontSize: 12),
                              ),
                              Text(
                                assignment.amountToCollect.toPeso,
                                style: const TextStyle(
                                    color: Color(0xFF1F2937),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color:
                                      AppColors.success.withValues(alpha: 0.3)),
                            ),
                            child: const Text('LOCKED',
                                style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                          ),
                        ]),
                      ),
                      if (assignment.collectionDate != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Due: ${assignment.collectionDate.toDisplayDate}',
                          style: const TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Notes ──────────────────────────────────────────────────
                AppTextField(
                  label: 'Notes (optional)',
                  hint: 'Any remarks about this collection...',
                  controller: _notesCtrl,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                // ── Receipt photo ──────────────────────────────────────────
                const Text(
                  'Receipt Photo *',
                  style: TextStyle(
                      color: Color(0xFF374151),
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                WhiteCard(
                  onTap: _showPhotoOptions,
                  padding: EdgeInsets.zero,
                  child: _receiptBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              Image.memory(
                                _receiptBytes!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _receiptBytes = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          height: 120,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    color: Colors.grey.shade400, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to attach receipt',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 28),
                AppButton(
                  label: 'Submit Collection',
                  icon: Icons.check_circle_outline,
                  color: AppColors.riderAccent,
                  textColor: Colors.black87,
                  isLoading: _submitting,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}