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
//
// Redesigned (Task 8-A): Premium Material 3 glassmorphism UI on rider navy
// gradient. All form fields wired to `Validators`. Receipt uploader restyled
// with dashed-border dropzone + remove button.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/rider_providers.dart';

class RiderCollectScreen extends ConsumerStatefulWidget {
  final String id;
  const RiderCollectScreen({super.key, required this.id});

  @override
  ConsumerState<RiderCollectScreen> createState() => _RiderCollectScreenState();
}

class _RiderCollectScreenState extends ConsumerState<RiderCollectScreen> {
  final _formKey = GlobalKey<FormState>();
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
    final assignment = ref.read(riderAssignmentDetailProvider(widget.id)).value;
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
      final name = file.name.isNotEmpty ? file.name : file.path;
      _receiptExt = name.split('.').last.toLowerCase();
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
    if (!_formKey.currentState!.validate()) return;
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
      backgroundColor: const Color(0xFF0D2060),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('Attach Receipt',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            _SheetOption(
              icon: AppIcons.camera,
              label: 'Take Photo',
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickReceipt(ImageSource.camera);
              },
            ),
            _SheetOption(
              icon: AppIcons.image,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(sheetCtx);
                _pickReceipt(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignmentAsync = ref.watch(riderAssignmentDetailProvider(widget.id));

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Record Collection',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.go('/rider/assignments/${widget.id}'),
        ),
      ),
      body: assignmentAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.riderAccent)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: $e',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
          ),
        ),
        data: (assignment) {
          // Keep amount in sync with loaded assignment
          _amountToCollect ??= assignment.amountToCollect;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, MediaQuery.of(context).padding.top + 88, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header / lender card ───────────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.riderAccent
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(AppIcons.user,
                                  color: AppColors.riderAccent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Collecting from',
                                    style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    assignment.lenderName ?? 'Lender',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // FIX #4/#7: Amount is locked — shown prominently, NOT editable
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                AppColors.riderAccent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.riderAccent
                                    .withValues(alpha: 0.35),
                                width: 1.2),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(AppIcons.banknote,
                                  color: AppColors.riderAccent, size: 26),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Amount to Collect',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.65),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      assignment.amountToCollect.toPeso,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppColors.success
                                          .withValues(alpha: 0.45)),
                                ),
                                child: const Text('LOCKED',
                                    style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(AppIcons.calendar,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.5)),
                            const SizedBox(width: 6),
                            Text(
                              'Due: ${assignment.collectionDate.toDisplayDate}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Receipt photo ──────────────────────────────────────
                  Text(
                    'Receipt Photo',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Required — proof of payment collected',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  _ReceiptDropzone(
                    bytes: _receiptBytes,
                    onTap: _showPhotoOptions,
                    onRemove: () => setState(() => _receiptBytes = null),
                  ),
                  const SizedBox(height: 22),

                  // ── Notes ──────────────────────────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: AppTextField(
                      label: 'Notes (optional)',
                      hint: 'Any remarks about this collection...',
                      controller: _notesCtrl,
                      isGlass: true,
                      maxLines: 3,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) =>
                          Validators.maxLength(v, 500, label: 'Notes'),
                    ),
                  ),
                  const SizedBox(height: 26),

                  // ── Submit ─────────────────────────────────────────────
                  AppButton(
                    label: 'Submit Collection',
                    icon: AppIcons.checkCircle,
                    color: AppColors.riderAccent,
                    textColor: Colors.black87,
                    isLoading: _submitting,
                    width: double.infinity,
                    size: AppButtonSize.lg,
                    borderRadius: 14,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIcons.shieldOk,
                            size: 13,
                            color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(width: 6),
                        Text(
                          'Secured by Jireta LMS',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Receipt dropzone ──────────────────────────────────────────────────────
class _ReceiptDropzone extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _ReceiptDropzone({
    required this.bytes,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.memory(
              bytes!,
              height: 210,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            // Bottom gradient overlay for context
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(AppIcons.badgeCheck,
                        color: AppColors.riderAccent, size: 16),
                    const SizedBox(width: 6),
                    const Text('Receipt attached',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(AppIcons.refresh,
                                color: Colors.white, size: 13),
                            SizedBox(width: 4),
                            Text('Replace',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Remove button (top right)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child:
                      const Icon(AppIcons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state — dashed-border dropzone
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.riderAccent.withValues(alpha: 0.45),
              width: 1.4,
              strokeAlign: BorderSide.strokeAlignOutside,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.riderAccent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(AppIcons.camera,
                    color: AppColors.riderAccent, size: 28),
              ),
              const SizedBox(height: 14),
              const Text('Tap to attach receipt',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Camera or gallery — JPG/PNG up to ~1MP',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet option ───────────────────────────────────────────────────
class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetOption(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.riderAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.riderAccent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
              Icon(AppIcons.chevronRight,
                  color: Colors.white.withValues(alpha: 0.4), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
