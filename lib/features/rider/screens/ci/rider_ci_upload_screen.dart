// lib/features/rider/screens/ci/rider_ci_upload_screen.dart

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
              title: const Text('Camera',
                  style: TextStyle(color: Color(0xFF1F2937))),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF374151)),
              title: const Text('Gallery',
                  style: TextStyle(color: Color(0xFF1F2937))),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
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
      final _name = file.name.isNotEmpty ? file.name : file.path;
      _documentExt = _name.split('.').last.toLowerCase();
    });
  }

  Future<void> _submit() async {
    if (_documentBytes == null) {
      context.showSnack('Upload a CI document photo', isError: true);
      return;
    }
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Credit Investigation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Instructions card
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color:
                                AppColors.riderAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
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
                                      color: Color(0xFF1F2937),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text(
                                'Visit the lender and verify their information',
                                style: TextStyle(
                                    color: Color(0xFF9CA3AF), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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

              // Document upload card
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upload Document / Photo',
                        style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text('Required: photo of proof of visit or CI form',
                        style:
                            TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _pickDocument,
                      child: Container(
                        width: double.infinity,
                        height: _documentBytes != null ? 200 : 140,
                        decoration: BoxDecoration(
                          color: AppColors.riderAccent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _documentBytes != null
                                ? AppColors.riderAccent.withValues(alpha: 0.4)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: _documentBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(_documentBytes!,
                                        fit: BoxFit.cover),
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.edit,
                                            color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      color: AppColors.riderAccent
                                          .withValues(alpha: 0.6),
                                      size: 36),
                                  const SizedBox(height: 10),
                                  const Text('Tap to take or upload photo',
                                      style: TextStyle(
                                          color: Color(0xFF9CA3AF),
                                          fontSize: 13)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notes card
              WhiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Investigation Notes',
                        style: TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Your findings (optional)',
                      controller: _notesCtrl,
                      maxLines: 4,
                      hint: 'Describe what you observed during the visit...',
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              AppButton(
                label: 'Submit CI Report',
                icon: AppIcons.shieldOk,
                isLoading: _submitting,
                color: AppColors.riderAccent,
                textColor: Colors.black87,
                width: double.infinity,
                size: AppButtonSize.lg,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final String number;
  final String text;
  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.riderAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: const TextStyle(
                      color: AppColors.riderAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(color: Color(0xFF374151), fontSize: 13))),
        ],
      ),
    );
  }
}
