// lib/features/head_manager/screens/users/hm_users_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/utils/extensions.dart';
import '../../../../shared/widgets/app_avatar.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/shimmer_box.dart';
import '../../providers/hm_providers.dart';

class HmUsersScreen extends ConsumerStatefulWidget {
  const HmUsersScreen({super.key});

  @override
  ConsumerState<HmUsersScreen> createState() => _HmUsersScreenState();
}

class _HmUsersScreenState extends ConsumerState<HmUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _roles = ['all', 'head_manager', 'employee', 'rider', 'lender'];
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

  void _onSearchChanged(String v) {
    setState(() => _searchQuery = v.trim());
  }

  Future<void> _createUser() async {
    final roleNotifier = ValueNotifier<String?>(null);
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
            constraints: const BoxConstraints(maxWidth: 520),
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
                            const Text(
                              'Create New User',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(AppIcons.close, size: 18),
                              onPressed: () => Navigator.pop(ctx, false),
                              splashRadius: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Default password: 12345678 — user must change on first login',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 20),
                        // Role selector
                        _dialogLabel('Account Role', ctx),
                        const SizedBox(height: 7),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(hintText: 'Select a role'),
                          items: const [
                            DropdownMenuItem(value: 'head_manager', child: Text('Head Manager')),
                            DropdownMenuItem(value: 'employee', child: Text('Employee')),
                            DropdownMenuItem(value: 'rider', child: Text('Rider (Collector)')),
                            DropdownMenuItem(value: 'lender', child: Text('Lender (Borrower)')),
                          ],
                          validator: (v) => v == null ? 'Please select a role' : null,
                          onChanged: (v) { roleNotifier.value = v; setSt(() {}); },
                        ),
                        const SizedBox(height: 18),
                        // ── Common fields ─────────────────────────────────────
                        _dialogSection('Personal Information', ctx),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: AppTextField(label: 'First Name', hint: 'Juan', controller: firstCtrl, textCapitalization: TextCapitalization.words, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null, prefixIcon: const Icon(AppIcons.user, size: 16))),
                            const SizedBox(width: 12),
                            Expanded(child: AppTextField(label: 'Last Name', hint: 'Dela Cruz', controller: lastCtrl, textCapitalization: TextCapitalization.words, validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Middle Name (optional)',
                          hint: 'Santos',
                          controller: middleCtrl,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Email Address',
                          hint: 'user@example.com',
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
                          label: 'Phone Number (optional)',
                          hint: '09XXXXXXXXX',
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(AppIcons.phone, size: 16),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (!v.isValidPhone) return 'Invalid PH number';
                            return null;
                          },
                        ),
                        // ── Rider-specific fields ─────────────────────────────
                        if (role == 'rider') ...[
                          const SizedBox(height: 18),
                          _dialogSection('Rider Information', ctx),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Address',
                            hint: 'House No., Street, Barangay, City',
                            controller: addressCtrl,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: "Driver's License No. (optional)",
                            hint: 'N01-23-456789',
                            controller: licenseCtrl,
                            prefixIcon: const Icon(Icons.badge_outlined, size: 16),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Vehicle / Motorcycle (optional)',
                            hint: 'Honda Click 125i - ABC 1234',
                            controller: vehicleCtrl,
                            prefixIcon: const Icon(Icons.two_wheeler_rounded, size: 16),
                          ),
                        ],
                        // ── Lender-specific fields ────────────────────────────
                        if (role == 'lender') ...[
                          const SizedBox(height: 18),
                          _dialogSection('Lender / Borrower Information', ctx),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Home Address',
                            hint: 'House No., Street, Barangay, City',
                            controller: addressCtrl,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Employer / Business Name (optional)',
                            hint: 'ABC Company',
                            controller: employerCtrl,
                            prefixIcon: const Icon(Icons.business_outlined, size: 16),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Monthly Income (₱, optional)',
                            hint: '25000',
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
                                bdayCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                                setSt(() {});
                              }
                            },
                            child: AbsorbPointer(
                              child: AppTextField(
                                label: 'Birthday (optional)',
                                hint: 'YYYY-MM-DD',
                                controller: bdayCtrl,
                                prefixIcon: const Icon(Icons.cake_outlined, size: 16),
                              ),
                            ),
                          ),
                        ],
                        // ── Employee-specific ─────────────────────────────────
                        if (role == 'employee') ...[
                          const SizedBox(height: 18),
                          _dialogSection('Employee Information', ctx),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Home Address (optional)',
                            hint: 'House No., Street, Barangay, City',
                            controller: addressCtrl,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                        // ── Head Manager ──────────────────────────────────────
                        if (role == 'head_manager') ...[
                          const SizedBox(height: 18),
                          _dialogSection('Head Manager Information', ctx),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Home Address (optional)',
                            hint: 'House No., Street, Barangay, City',
                            controller: addressCtrl,
                            maxLines: 2,
                            textCapitalization: TextCapitalization.sentences,
                          ),
                        ],
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            const SizedBox(width: 8),
                            AppButton(
                              label: 'Create User',
                              icon: AppIcons.userPlus,
                              isLoading: loading,
                              onPressed: () async {
                                if (!formKey.currentState!.validate()) return;
                                final selectedRole = roleNotifier.value!;
                                setSt(() => loading = true);
                                final err = await ref.read(hmUsersNotifierProvider.notifier).createUser(
                                  role: selectedRole,
                                  firstName: firstCtrl.text.trim(),
                                  lastName: lastCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
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
      context.showSnack('User created successfully! Default password: 12345678');
    }
  }

  static Widget _dialogLabel(String label, BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Text(label, style: TextStyle(
      fontSize: 13, fontWeight: FontWeight.w500,
      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
    ));
  }

  static Widget _dialogSection(String title, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(title, style: const TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        color: AppColors.accent, letterSpacing: 0.3,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final surfaceColor = isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight;
    final borderColor = isDark ? AppColors.webBorderDark : AppColors.webBorderLight;
    final hintColor = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Column(
      children: [
        Container(
          color: surfaceColor,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by name or email…',
                        hintStyle: TextStyle(color: hintColor, fontSize: 13),
                        prefixIcon: Icon(AppIcons.search, size: 16, color: hintColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(AppIcons.close, size: 16, color: hintColor),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? AppColors.webBorderSoftDk : AppColors.webBorderSoftL,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    label: 'New User',
                    icon: AppIcons.userPlus,
                    size: AppButtonSize.sm,
                    onPressed: _createUser,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.accent,
                unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
                tabs: _roles.map((r) => Tab(text: r == 'all' ? 'All Users' : r.snakeToLabel)).toList(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: _roles.map((r) => _UserList(role: r, search: _searchQuery)).toList(),
          ),
        ),
      ],
    );
  }
}

class _UserList extends ConsumerWidget {
  final String role;
  final String search;
  const _UserList({required this.role, required this.search});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = UsersFilter(
      role: role == 'all' ? null : role,
      search: search.isEmpty ? null : search,
    );
    final usersAsync = ref.watch(hmUsersProvider(filter));
    final isDark = context.isDark;

    return usersAsync.when(
      loading: () => const _LoadingUsers(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (users) {
        if (users.isEmpty) {
          return EmptyState(
            icon: AppIcons.users,
            title: search.isNotEmpty ? 'No results for "$search"' : 'No users found',
            subtitle: search.isNotEmpty ? 'Try a different search term.' : 'No ${role == "all" ? "users" : "${role.snakeToLabel.toLowerCase()}s"} yet.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _UserCard(user: users[i], isDark: isDark),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final bool isDark;
  const _UserCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(user.role.value);
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.webBorderDark : AppColors.webBorderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/hm/users/${user.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              AppAvatar(imageUrl: user.avatarUrl, name: user.displayName, size: 40, backgroundColor: roleColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      user.email.isNotEmpty ? user.email : (user.phone ?? '—'),
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                    ),
                  ],
                ),
              ),
              if (!user.isActive)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Inactive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(user.role.value.snakeToLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: roleColor)),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, size: 16, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'head_manager': return AppColors.accent;
      case 'employee': return AppColors.info;
      case 'rider': return AppColors.riderAccent;
      case 'lender': return AppColors.lenderAccent;
      default: return AppColors.textSecondaryLight;
    }
  }
}

class _LoadingUsers extends StatelessWidget {
  const _LoadingUsers();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => Container(
        height: 70,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            ShimmerBox(width: 40, height: 40, radius: 20),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShimmerBox(width: 160, height: 13, radius: 4),
                  SizedBox(height: 7),
                  ShimmerBox(width: 220, height: 11, radius: 4),
                ],
              ),
            ),
            ShimmerBox(width: 70, height: 24, radius: 12),
          ],
        ),
      ),
    );
  }
}