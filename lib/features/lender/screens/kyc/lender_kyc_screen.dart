// lib/features/lender/screens/kyc/lender_kyc_screen.dart
//
// REDESIGN (Task 7-A): Material 3 polish, Form state with Validators on all
// text fields, premium photo upload boxes, animated selection state,
// consistent 14px corner radius, AppIcons for visual consistency.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/kyc_model.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/utils/validators.dart';
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
  final _formKey = GlobalKey<FormState>();

  final _idTypes = [
    'SSS',
    'PhilHealth',
    'Passport',
    "Driver's License",
    'UMID',
    'Postal ID',
    'Voter ID'
  ];

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
      backgroundColor: const Color(0xFF10173A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Select Source',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
            ListTile(
                leading:
                    const Icon(AppIcons.camera, color: AppColors.lenderAccent),
                title:
                    const Text('Camera', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.camera)),
            ListTile(
                leading:
                    const Icon(AppIcons.image, color: AppColors.lenderAccent),
                title: const Text('Gallery',
                    style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (src == null) return;
    final file = await ImagePicker().pickImage(
        source: src, maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final name = file.name.isNotEmpty ? file.name : file.path;
    final ext = _cleanImageExt(name.split('.').last);
    setState(() {
      if (field == 'front') {
        _idFrontBytes = bytes;
        _idFrontExt = ext;
      } else if (field == 'back') {
        _idBackBytes = bytes;
        _idBackExt = ext;
      } else {
        _selfieBytes = bytes;
        _selfieExt = ext;
      }
    });
  }

  String _cleanImageExt(String raw) {
    final ext = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
  }

  DioMediaType _imageContentType(String ext) {
    final normalized = ext == 'jpg' ? 'jpeg' : ext;
    return DioMediaType('image', normalized);
  }

  Future<void> _submit() async {
    // Validate text fields
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      context.showSnack('Please complete required fields', isError: true);
      return;
    }
    if (_idFrontBytes == null) {
      context.showSnack('Upload front of your ID', isError: true);
      return;
    }
    if (_selfieBytes == null) {
      context.showSnack('Upload a selfie photo', isError: true);
      return;
    }

    setState(() => _submitting = true);

    final formData = FormData.fromMap({
      'id_type': _idType,
      'id_number': _idNumberCtrl.text.trim(),
      'employer': _employerCtrl.text.trim(),
      'monthly_income': _incomeCtrl.text.trim(),
      'id_front': MultipartFile.fromBytes(
        _idFrontBytes!,
        filename: 'id_front.$_idFrontExt',
        contentType: _imageContentType(_idFrontExt),
      ),
      if (_idBackBytes != null)
        'id_back': MultipartFile.fromBytes(
          _idBackBytes!,
          filename: 'id_back.$_idBackExt',
          contentType: _imageContentType(_idBackExt),
        ),
      'selfie': MultipartFile.fromBytes(
        _selfieBytes!,
        filename: 'selfie.$_selfieExt',
        contentType: _imageContentType(_selfieExt),
      ),
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
        leading: IconButton(
            icon: const Icon(AppIcons.arrowLeft),
            onPressed: () => Navigator.maybePop(context)),
      ),
      body: kycAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: Colors.white70))),
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
    final icon = isApproved ? AppIcons.shieldOk : Icons.hourglass_top_rounded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 56),
              ),
              const SizedBox(height: 18),
              StatusChip.kycStatus(kyc.status.value),
              const SizedBox(height: 12),
              Text(
                isApproved
                    ? 'Your identity has been verified!'
                    : 'KYC documents are under review.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              if (!isApproved) ...[
                const SizedBox(height: 8),
                Text('This usually takes 1-2 business days.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13)),
              ],
              const SizedBox(height: 18),
              _InfoRow('ID Type', kyc.idType),
              _InfoRow('Submitted', kyc.createdAt.toDisplayDate),
              if (kyc.rejectionReason != null) ...[
                const Divider(color: Colors.white12, height: 20),
                Text('Reason: ${kyc.rejectionReason}',
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 13)),
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
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.lenderAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.lenderAccent, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

class _KycForm extends StatelessWidget {
  final _LenderKycScreenState s;
  const _KycForm(this.s);

  @override
  Widget build(BuildContext context) {
    return Form(
      key: s._formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: AppIcons.shieldOk,
              title: 'Submit KYC Documents',
              subtitle: 'Required to apply for a loan',
            ),
            const SizedBox(height: 24),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: AppIcons.badgeCheck,
                    title: 'Government ID',
                  ),
                  const SizedBox(height: 16),
                  const Text('ID Type',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: s._idType,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF14183C),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        iconEnabledColor: Colors.white54,
                        items: s._idTypes
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => s.setIdType(v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'ID Number',
                    hint: 'Enter your ${s._idType} number',
                    controller: s._idNumberCtrl,
                    isGlass: true,
                    textCapitalization: TextCapitalization.characters,
                    prefixIcon: const Icon(AppIcons.key,
                        size: 18, color: Colors.white54),
                    validator: (v) =>
                        Validators.idNumber(v, label: '${s._idType} number'),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: _PhotoBox(
                            label: 'ID Front *',
                            bytes: s._idFrontBytes,
                            onTap: () => s._pickImage('front'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _PhotoBox(
                            label: 'ID Back',
                            bytes: s._idBackBytes,
                            onTap: () => s._pickImage('back'))),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: AppIcons.camera,
                    title: 'Selfie Verification',
                    subtitle: 'Take a clear photo of your face',
                  ),
                  const SizedBox(height: 16),
                  _PhotoBox(
                      label: 'Selfie *',
                      bytes: s._selfieBytes,
                      onTap: () => s._pickImage('selfie'),
                      tall: true),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(
                    icon: AppIcons.building,
                    title: 'Employment Info (optional)',
                    subtitle: 'Helps us process your application faster',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: 'Employer / Business Name',
                    hint: 'e.g. ACME Corp, Self-employed',
                    controller: s._employerCtrl,
                    isGlass: true,
                    textCapitalization: TextCapitalization.words,
                    prefixIcon: const Icon(AppIcons.building,
                        size: 18, color: Colors.white54),
                    validator: (v) {
                      // Optional — only validate non-empty format
                      if (v == null || v.trim().isEmpty) return null;
                      if (v.trim().length < 2) return 'Too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    label: 'Monthly Income (₱)',
                    hint: 'e.g. 25000',
                    controller: s._incomeCtrl,
                    isGlass: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    prefixIcon: const Icon(AppIcons.coins,
                        size: 18, color: Colors.white54),
                    validator: (v) {
                      // Optional — only validate non-empty format
                      if (v == null || v.trim().isEmpty) return null;
                      final amt = double.tryParse(v.replaceAll(',', ''));
                      if (amt == null || amt < 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton.gradient(
              label: 'Submit KYC',
              icon: AppIcons.checkCircle,
              width: double.infinity,
              size: AppButtonSize.lg,
              isLoading: s._submitting,
              onPressed: s._submit,
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final VoidCallback onTap;
  final bool tall;
  const _PhotoBox(
      {required this.label,
      required this.bytes,
      required this.onTap,
      this.tall = false});

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: tall ? 170 : 120,
        decoration: BoxDecoration(
          color: hasImage
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage
                ? AppColors.lenderAccent
                : Colors.white.withValues(alpha: 0.15),
            width: hasImage ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            if (hasImage)
              Image.memory(bytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity)
            else
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(AppIcons.camera,
                      color: Colors.white.withValues(alpha: 0.4), size: 28),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                ],
              ),
            // Badge when image is present
            if (hasImage)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.lenderAccent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_rounded, color: Colors.white, size: 11),
                      SizedBox(width: 3),
                      Text('Uploaded',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
