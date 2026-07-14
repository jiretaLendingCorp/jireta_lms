// lib/features/rider/screens/ci/rider_ci_upload_screen.dart
//
// Redesigned (Task 8-A): Premium Material 3 glassmorphism UI on rider navy
// gradient. CI instructions card, dashed-border photo uploader with replace/
// remove, validated optional notes field via `Validators.maxLength`.

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/utils/validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/rider_providers.dart';

class RiderCiUploadScreen extends ConsumerStatefulWidget {
  final String assignmentId;
  const RiderCiUploadScreen({super.key, required this.assignmentId});

  @override
  ConsumerState<RiderCiUploadScreen> createState() =>
      _RiderCiUploadScreenState();
}

class _RiderCiUploadScreenState extends ConsumerState<RiderCiUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  Uint8List? _documentBytes;
  String _documentExt = 'jpg';
  bool _submitting = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final src = await showModalBottomSheet<ImageSource>(
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
              child: Text('CI Document',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            _SheetOption(
              icon: AppIcons.camera,
              label: 'Camera',
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
            _SheetOption(
              icon: AppIcons.image,
              label: 'Gallery',
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (src == null) return;
    final file = await ImagePicker().pickImage(
        source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _documentBytes = bytes;
      final name = file.name.isNotEmpty ? file.name : file.path;
      _documentExt = name.split('.').last.toLowerCase();
    });
  }

  Future<void> _submit() async {
    if (_documentBytes == null) {
      context.showSnack('Upload a CI document photo', isError: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final formData = FormData.fromMap({
        'assignment_id': widget.assignmentId,
        'ci_notes': _notesCtrl.text.trim(),
        'document': MultipartFile.fromBytes(
          _documentBytes!,
          filename: 'ci_document.$_documentExt',
        ),
      });
      await DioClient.instance.uploadMultipart(
        '${ApiEndpoints.assignmentUpdate}/ci-upload',
        formData,
      );
      if (mounted) {
        context.showSnack('Credit Investigation submitted successfully!');
        ref.invalidate(riderAssignmentDetailProvider(widget.assignmentId));
        ref.invalidate(riderAssignmentsProvider(null));
        context.pop();
      }
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Upload failed';
      if (mounted) context.showSnack(msg.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Credit Investigation',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 88, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Instructions card ──────────────────────────────────
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
                              color:
                                  AppColors.riderAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(AppIcons.shieldOk,
                                color: AppColors.riderAccent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CI Instructions',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                SizedBox(height: 2),
                                Text(
                                  'Visit the lender and verify their information',
                                  style: TextStyle(
                                      color: Color(0xB3FFFFFF), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _InstructionStep(
                          number: '1',
                          text: 'Visit the lender at their registered address'),
                      const _InstructionStep(
                          number: '2',
                          text: 'Verify their identity and living situation'),
                      const _InstructionStep(
                          number: '3',
                          text:
                              'Take a photo of proof: house, valid ID, or signed form'),
                      const _InstructionStep(
                          number: '4',
                          text: 'Add notes about your findings then submit'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Document upload card ───────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upload Document / Photo',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      const Text('Required: photo of proof of visit or CI form',
                          style: TextStyle(
                              color: Color(0x8CFFFFFF), fontSize: 12)),
                      const SizedBox(height: 16),
                      _DocumentDropzone(
                        bytes: _documentBytes,
                        onTap: _pickDocument,
                        onRemove: () => setState(() => _documentBytes = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Notes card ─────────────────────────────────────────
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Investigation Notes',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'Your findings (optional)',
                        controller: _notesCtrl,
                        isGlass: true,
                        maxLines: 4,
                        maxLength: 1000,
                        hint: 'Describe what you observed during the visit...',
                        textCapitalization: TextCapitalization.sentences,
                        validator: (v) =>
                            Validators.maxLength(v, 1000, label: 'Notes'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Submit ─────────────────────────────────────────────
                AppButton(
                  label: 'Submit CI Report',
                  icon: AppIcons.shieldOk,
                  isLoading: _submitting,
                  color: AppColors.riderAccent,
                  textColor: Colors.black87,
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
                          size: 13, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                        'Confidential — visible to staff only',
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
        ),
      ),
    );
  }
}

// ── Instruction step ──────────────────────────────────────────────────────
class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.riderAccent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.riderAccent.withValues(alpha: 0.45),
                  width: 1),
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: AppColors.riderAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 13,
                      height: 1.4))),
        ],
      ),
    );
  }
}

// ── Document dropzone ─────────────────────────────────────────────────────
class _DocumentDropzone extends StatelessWidget {
  final Uint8List? bytes;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _DocumentDropzone({
    required this.bytes,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Image.memory(
              bytes!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            // Bottom action bar
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
                    const Text('Document attached',
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

    // Empty state
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
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
              const Text('Tap to take or upload photo',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('House photo, valid ID, or signed CI form',
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
