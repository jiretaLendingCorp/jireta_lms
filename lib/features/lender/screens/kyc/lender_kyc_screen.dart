// lib/features/lender/screens/kyc/lender_kyc_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/kyc_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/lender_providers.dart';
import 'package:dio/dio.dart';

class LenderKycScreen extends ConsumerStatefulWidget {
  const LenderKycScreen({super.key});

  @override
  ConsumerState<LenderKycScreen> createState() => _LenderKycScreenState();
}

class _LenderKycScreenState extends ConsumerState<LenderKycScreen> {
  String _idType = 'SSS';
  final _idNumberCtrl = TextEditingController();
  final _employerCtrl = TextEditingController();
  final _incomeCtrl = TextEditingController();

  Uint8List? _idFrontBytes;
  String _idFrontExt = 'jpg';
  Uint8List? _idBackBytes;
  String _idBackExt = 'jpg';
  Uint8List? _selfieBytes;
  String _selfieExt = 'jpg';

  bool _submitting = false;

  final _idTypes = ['SSS', 'PhilHealth', 'Passport', "Driver's License", 'UMID', 'Postal ID', 'Voter ID'];

  void setIdType(String? value) {
    setState(() => _idType = value ?? _idType);
  }

  @override
  void dispose() {
    _idNumberCtrl.dispose();
    _employerCtrl.dispose();
    _incomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String field) async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            ListTile(leading: const Icon(Icons.camera_alt_outlined, color: Colors.white), title: const Text('Camera', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(sheetCtx, ImageSource.camera)),
            ListTile(leading: const Icon(Icons.photo_library_outlined, color: Colors.white), title: const Text('Gallery', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (src == null) return;
    final file = await ImagePicker().pickImage(source: src, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    setState(() {
      if (field == 'front') { _idFrontBytes = bytes; _idFrontExt = ext; }
      else if (field == 'back') { _idBackBytes = bytes; _idBackExt = ext; }
      else { _selfieBytes = bytes; _selfieExt = ext; }
    });
  }

  Future<void> _submit() async {
    if (_idNumberCtrl.text.trim().isEmpty) {
      context.showSnack('Enter your ID number', isError: true); return;
    }
    if (_idFrontBytes == null) {
      context.showSnack('Upload front of your ID', isError: true); return;
    }
    if (_selfieBytes == null) {
      context.showSnack('Upload a selfie photo', isError: true); return;
    }

    setState(() => _submitting = true);

    final formData = FormData.fromMap({
      'id_type': _idType,
      'id_number': _idNumberCtrl.text.trim(),
      'employer': _employerCtrl.text.trim(),
      'monthly_income': _incomeCtrl.text.trim(),
      'id_front': MultipartFile.fromBytes(_idFrontBytes!, filename: 'id_front.$_idFrontExt'),
      if (_idBackBytes != null) 'id_back': MultipartFile.fromBytes(_idBackBytes!, filename: 'id_back.$_idBackExt'),
      'selfie': MultipartFile.fromBytes(_selfieBytes!, filename: 'selfie.$_selfieExt'),
    });

    final res = await ref.read(lenderRepositoryProvider).submitKyc(formData);
    setState(() => _submitting = false);

    if (mounted) {
      if (res.success) {
        context.showSnack('KYC submitted for review!');
        ref.invalidate(lenderMyKycProvider);
      } else {
        context.showSnack(res.error!, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycAsync = ref.watch(lenderMyKycProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('KYC Verification'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.maybePop(context)),
      ),
      body: kycAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white70))),
        data: (kyc) {
          if (kyc != null && kyc.status != KycStatus.rejected) {
            return _KycStatusView(kyc: kyc);
          }
          return _KycForm(this);
        },
      ),
    );
  }
}

class _KycStatusView extends StatelessWidget {
  final KycModel kyc;
  const _KycStatusView({required this.kyc});

  @override
  Widget build(BuildContext context) {
    final isApproved = kyc.status == KycStatus.approved;
    final color = isApproved ? AppColors.success : AppColors.warning;
    final icon = isApproved ? Icons.verified_rounded : Icons.hourglass_top_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 56),
              const SizedBox(height: 16),
              StatusChip.kycStatus(kyc.status.value),
              const SizedBox(height: 12),
              Text(
                isApproved ? 'Your identity has been verified!' : 'KYC documents are under review.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (!isApproved) ...[
                const SizedBox(height: 8),
                Text('This usually takes 1-2 business days.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
              ],
              const SizedBox(height: 16),
              _InfoRow('ID Type', kyc.idType),
              _InfoRow('Submitted', kyc.createdAt.toDisplayDate),
              if (kyc.rejectionReason != null) ...[
                const Divider(color: Colors.white12, height: 20),
                Text('Reason: ${kyc.rejectionReason}',
                    style: const TextStyle(color: AppColors.error, fontSize: 13)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _KycForm extends StatelessWidget {
  final _LenderKycScreenState s;
  const _KycForm(this.s);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Submit KYC Documents', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Required to apply for a loan', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          const SizedBox(height: 24),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Government ID', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                const Text('ID Type', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: s._idType,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF241055),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      iconEnabledColor: Colors.white54,
                      items: s._idTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => s.setIdType(v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AppTextField(label: 'ID Number', controller: s._idNumberCtrl, isGlass: true),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _PhotoBox(label: 'ID Front *', bytes: s._idFrontBytes, onTap: () => s._pickImage('front'))),
                  const SizedBox(width: 12),
                  Expanded(child: _PhotoBox(label: 'ID Back', bytes: s._idBackBytes, onTap: () => s._pickImage('back'))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selfie Verification', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Take a clear photo of your face', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                const SizedBox(height: 16),
                _PhotoBox(label: 'Selfie *', bytes: s._selfieBytes, onTap: () => s._pickImage('selfie'), tall: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employment Info (optional)', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                AppTextField(label: 'Employer / Business Name', controller: s._employerCtrl, isGlass: true),
                const SizedBox(height: 12),
                AppTextField(
                  label: 'Monthly Income (₱)',
                  controller: s._incomeCtrl,
                  isGlass: true,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Submit KYC',
            color: AppColors.lenderAccent,
            width: double.infinity,
            isLoading: s._submitting,
            onPressed: s._submit,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;
  final bool tall;
  const _PhotoBox({required this.label, required this.bytes, required this.onTap, this.tall = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: tall ? 160 : 110,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bytes != null ? AppColors.lenderAccent : Colors.white.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.hardEdge,
        child: bytes != null
            ? Image.memory(bytes!, fit: BoxFit.cover, width: double.infinity)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: Colors.white.withValues(alpha: 0.4), size: 28),
                  const SizedBox(height: 6),
                  Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11), textAlign: TextAlign.center),
                ],
              ),
      ),
    );
  }
}