// lib/features/employee/screens/users/emp_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../providers/emp_providers.dart';

class EmpUsersScreen extends ConsumerStatefulWidget {
  const EmpUsersScreen({super.key});

  @override
  ConsumerState<EmpUsersScreen> createState() => _EmpUsersScreenState();
}

class _EmpUsersScreenState extends ConsumerState<EmpUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _roles = ['all', 'lender', 'rider'];
  final _labels = ['All', 'Lenders', 'Riders'];
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _roles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showCreateDialog() async {
    final roleNotifier = ValueNotifier<String?>('lender');
    final firstCtrl = TextEditingController();
    final middleCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final employerCtrl = TextEditingController();
    final incomeCtrl = TextEditingController();
    final licenseCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final bdayCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: roleNotifier,
                    builder: (_, role, __) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(AppIcons.userPlus, color: AppColors.accent, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('Create Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(AppIcons.close, size: 18),
                              onPressed: () => Navigator.pop(ctx, false),
                              splashRadius: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text('Default password: 12345678 — user must change on first login',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                        const SizedBox(height: 20),
                        // Role
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'Account Type'),
                          items: const [
                            DropdownMenuItem(value: 'lender', child: Text('Lender (Borrower)')),
                            DropdownMenuItem(value: 'rider', child: Text('Rider (Collector)')),
                          ],
                          validator: (v) => v == null ? 'Required' : null,
                          onChanged: (v) { roleNotifier.value = v; setSt(() {}); },
                        ),
                        const SizedBox(height: 16),
                        // Name row
                        Row(
                          children: [
                            Expanded(child: AppTextField(
                              label: 'First Name', controller: firstCtrl,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: AppTextField(
                              label: 'Last Name', controller: lastCtrl,
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppTextField(label: 'Middle Name (optional)', controller: middleCtrl, textCapitalization: TextCapitalization.words),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Email',
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(AppIcons.email, size: 16),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (!v.isValidEmail) return 'Invalid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Phone (optional)',
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(AppIcons.phone, size: 16),
                        ),
                        // Lender extra fields
                        if (role == 'lender') ...[
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Home Address',
                            controller: addressCtrl,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Employer / Business (optional)',
                            controller: employerCtrl,
                            textCapitalization: TextCapitalization.words,
                            prefixIcon: const Icon(Icons.business_outlined, size: 16),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Monthly Income ₱ (optional)',
                            controller: incomeCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            prefixIcon: const Icon(Icons.payments_outlined, size: 16),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime(now.year - 25),
                                firstDate: DateTime(1940),
                                lastDate: DateTime(now.year - 18),
                              );
                              if (picked != null) {
                                bdayCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                                setSt(() {});
                              }
                            },
                            child: AbsorbPointer(
                              child: AppTextField(
                                label: 'Birthday (optional)',
                                controller: bdayCtrl,
                                hint: 'YYYY-MM-DD',
                                prefixIcon: const Icon(Icons.cake_outlined, size: 16),
                              ),
                            ),
                          ),
                        ],
                        // Rider extra fields
                        if (role == 'rider') ...[
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Address (optional)',
                            controller: addressCtrl,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: "Driver's License No. (optional)",
                            controller: licenseCtrl,
                            prefixIcon: const Icon(Icons.badge_outlined, size: 16),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Vehicle / Motorcycle (optional)',
                            controller: vehicleCtrl,
                            prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 16),
                          ),
                        ],
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            const SizedBox(width: 8),
                            AppButton(
                              label: 'Create',
                              icon: AppIcons.userPlus,
                              isLoading: loading,
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                setSt(() => loading = true);
                                final err = await ref
                                    .read(empUsersNotifierProvider.notifier)
                                    .createUser(
                                      role: roleNotifier.value!,
                                      firstName: firstCtrl.text.trim(),
                                      lastName: lastCtrl.text.trim(),
                                      middleName: middleCtrl.text.trim().isEmpty ? null : middleCtrl.text.trim(),
                                      email: emailCtrl.text.trim(),
                                      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                                      address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                                      driverLicense: licenseCtrl.text.trim().isEmpty ? null : licenseCtrl.text.trim(),
                                      vehicleInfo: vehicleCtrl.text.trim().isEmpty ? null : vehicleCtrl.text.trim(),
                                      employer: employerCtrl.text.trim().isEmpty ? null : employerCtrl.text.trim(),
                                      monthlyIncome: incomeCtrl.text.trim().isEmpty ? null : incomeCtrl.text.trim(),
                                      birthday: bdayCtrl.text.trim().isEmpty ? null : bdayCtrl.text.trim(),
                                    );
                                setSt(() => loading = false);
                                if (err != null && ctx.mounted) {
                                  ctx.showSnack(err, isError: true);
                                } else if (ctx.mounted) {
                                  Navigator.pop(ctx, true);
                                }
                              },
                              size: AppButtonSize.md,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (ok == true && mounted) {
      context.showSnack('Account created! Default password: 12345678');
      ref.invalidate(empUsersListProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar row with Create button
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.accent,
                  unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                  indicatorColor: AppColors.accent,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: _labels.map((l) => Tab(text: l)).toList(),
                ),
              ),
              AppButton(
                label: 'Create User',
                icon: AppIcons.userPlus,
                size: AppButtonSize.sm,
                onPressed: _showCreateDialog,
              ),
            ],
          ),
        ),
        // Search bar
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search by name or email...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); })
                  : null,
              filled: true,
              fillColor: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _roles.map((r) => _UserList(role: r, searchQuery: _searchQuery)).toList(),
          ),
        ),
      ],
    );
  }
}

class _UserList extends ConsumerWidget {
  final String role;
  final String searchQuery;
  const _UserList({required this.role, this.searchQuery = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(empUsersListProvider(role));
    final isDark = context.isDark;

    return usersAsync.when(
      loading: () => const ShimmerRow(count: 6),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allUsers) {
        final users = searchQuery.isEmpty
          ? allUsers
          : allUsers.where((u) =>
              u.displayName.toLowerCase().contains(searchQuery) ||
              u.email.toLowerCase().contains(searchQuery) ||
              (u.phone?.toLowerCase().contains(searchQuery) ?? false)
            ).toList();
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.users,
                    size: 48,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                const SizedBox(height: 12),
                Text('No ${role == 'all' ? 'users' : '${role}s'} found',
                    style: TextStyle(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final u = users[i];
            return AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  AppAvatar(imageUrl: u.avatarUrl, name: u.displayName, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(u.email,
                            style: TextStyle(fontSize: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            overflow: TextOverflow.ellipsis),
                        if (u.phone != null && u.phone!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(u.phone!,
                              style: TextStyle(fontSize: 11,
                                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                        ],
                        const SizedBox(height: 2),
                        Text('Joined: ${u.createdAt.toDisplayDate}',
                            style: TextStyle(fontSize: 10,
                                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(
                        label: u.role.value.replaceAll('_', ' ').titleCase,
                        color: u.role == UserRole.lender ? AppColors.lenderAccent : AppColors.riderAccent,
                        small: true,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (u.isActive ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          u.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            color: u.isActive ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}