// lib/features/rider/screens/collect/rider_collect_screen.dart

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
  ConsumerState<RiderCollectScreen> createState() => _RiderCollectScreenState();
}

class _RiderCollectScreenState extends ConsumerState<RiderCollectScreen> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Uint8List? _receiptBytes;
  String _receiptExt = 'jpg';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final assignment = ref.read(riderAssignmentDetailProvider(widget.id)).value;
    if (assignment != null) {
      _amountCtrl.text = assignment.amountToCollect.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
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
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      context.showSnack('Enter a valid amount', isError: true);
      return;
    }
    if (_receiptBytes == null) {
      context.showSnack('Please attach a receipt photo', isError: true);
      return;
    }

    setState(() => _submitting = true);
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

  @override
  Widget build(BuildContext context) {
    final assignmentAsync = ref.watch(riderAssignmentDetailProvider(widget.id));

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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (assignment) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Collecting from ${assignment.lenderName ?? "Lender"}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Expected: ${assignment.amountToCollect.toPeso}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Amount Collected (₱)',
                hint: '0.00',
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                isGlass: true,
                prefixIcon:
                    const Icon(Icons.payments_rounded, size: 18, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Notes (optional)',
                hint: 'Any remarks about this collection...',
                controller: _notesCtrl,
                maxLines: 3,
                isGlass: true,
              ),
              const SizedBox(height: 20),
              const Text(
                'Receipt Photo',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              GlassCard(
                onTap: () => _showPhotoOptions(),
                padding: EdgeInsets.zero,
                child: _receiptBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
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
                                  color: Colors.white.withOpacity(0.5),
                                  size: 36),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to attach receipt',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
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
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              title: const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickReceipt(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}