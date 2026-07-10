// lib/shared/widgets/web_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/route_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../shared/models/app_user.dart';
import 'logo_widget.dart';
import 'app_avatar.dart';

class WebShell extends ConsumerStatefulWidget {
  final Widget child;
  final List<WebNavItem> navItems;
  final String title;

  const WebShell({
    super.key,
    required this.child,
    required this.navItems,
    required this.title,
  });

  @override
  ConsumerState<WebShell> createState() => _WebShellState();
}

class _WebShellState extends ConsumerState<WebShell> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final sidebarW = _collapsed ? 68.0 : 256.0;

    final borderColor = isDark ? AppColors.webBorderDark : AppColors.webBorderLight;
    final sidebarBg = isDark ? AppColors.webSidebarDark : AppColors.webSidebarLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.webBgDark : AppColors.webBgLight,
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOut,
            width: sidebarW,
            decoration: BoxDecoration(
              color: sidebarBg,
              border: Border(right: BorderSide(color: borderColor)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SidebarHeader(
                  collapsed: _collapsed,
                  onToggle: () => setState(() => _collapsed = !_collapsed),
                  isDark: isDark,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    children: widget.navItems
                        .map((item) => _NavTile(item: item, collapsed: _collapsed, isDark: isDark))
                        .toList(),
                  ),
                ),
                _SidebarFooter(
                  user: user,
                  collapsed: _collapsed,
                  isDark: isDark,
                  borderColor: borderColor,
                  onSignOut: () => ref.read(authProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: widget.title,
                  user: user,
                  isDark: isDark,
                  borderColor: borderColor,
                  onToggleTheme: () =>
                      ref.read(themeModeProvider.notifier).state = !isDark,
                  onSignOut: () => ref.read(authProvider.notifier).signOut(),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggle;
  final bool isDark;

  const _SidebarHeader({required this.collapsed, required this.onToggle, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 16),
      child: Row(
        children: [
          if (!collapsed) ...[
            const LogoIcon(size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Jireta Loans',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            const Spacer(),
          ],
          IconButton(
            icon: Icon(
              collapsed ? AppIcons.chevronsRight : AppIcons.chevronsLeft,
              size: 18,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            onPressed: onToggle,
            tooltip: collapsed ? 'Expand' : 'Collapse',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final WebNavItem item;
  final bool collapsed;
  final bool isDark;

  const _NavTile({required this.item, required this.collapsed, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = location == item.route ||
        (item.route != '/' && location.startsWith(item.route));

    const activeColor = AppColors.accent;
    final inactiveColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Tooltip(
      message: collapsed ? item.label : '',
      preferBelow: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: InkWell(
          onTap: () => context.go(item.route),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 12, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withValues(alpha: isDark ? 0.14 : 0.09) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (!collapsed)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 3,
                    height: 18,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: isActive ? activeColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 18,
                  color: isActive ? activeColor : inactiveColor,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? activeColor : inactiveColor,
                      ),
                    ),
                  ),
                  if (item.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(10)),
                      child: Text('${item.badge}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                ] else if (item.badge != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final AppUser? user;
  final bool collapsed;
  final bool isDark;
  final Color borderColor;
  final VoidCallback onSignOut;

  const _SidebarFooter({
    required this.user,
    required this.collapsed,
    required this.isDark,
    required this.borderColor,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(collapsed ? 8 : 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
      child: Column(
        children: [
          if (!collapsed && user != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.webBorderSoftDk : AppColors.webBorderSoftL,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  AppAvatar(imageUrl: user!.avatarUrl, name: user!.displayName, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user!.displayName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight), overflow: TextOverflow.ellipsis),
                        Text(user!.role.value.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (collapsed && user != null) ...[
            AppAvatar(imageUrl: user!.avatarUrl, name: user!.displayName, size: 34),
            const SizedBox(height: 8),
          ],
          collapsed
              ? IconButton(
                  icon: const Icon(AppIcons.logout, size: 18, color: AppColors.error),
                  onPressed: onSignOut,
                  tooltip: 'Sign out',
                  splashRadius: 18,
                )
              : InkWell(
                  onTap: onSignOut,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Icon(AppIcons.logout, size: 16, color: AppColors.error),
                        SizedBox(width: 10),
                        Text(
                          'Sign Out',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final AppUser? user;
  final bool isDark;
  final Color borderColor;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignOut;

  const _TopBar({
    required this.title,
    required this.user,
    required this.isDark,
    required this.borderColor,
    required this.onToggleTheme,
    required this.onSignOut,
  });

  String _notifRouteFor(AppUser? u) {
    if (u == null) return '/';
    switch (u.role.value) {
      case 'head_manager': return RouteConstants.hmNotifications;
      case 'employee': return RouteConstants.empNotifications;
      default: return '/';
    }
  }

  String _profileRouteFor(AppUser? u) {
    if (u == null) return '/';
    switch (u.role.value) {
      case 'head_manager': return RouteConstants.hmProfile;
      case 'employee': return RouteConstants.empProfile;
      default: return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AppColors.webSurfaceDark : AppColors.webSurfaceLight;
    final iconColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final iconBg = isDark ? AppColors.webBorderSoftDk : AppColors.webBorderSoftL;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(isDark ? AppIcons.sun : AppIcons.moon, size: 18, color: iconColor),
              onPressed: onToggleTheme,
              tooltip: isDark ? 'Light mode' : 'Dark mode',
              splashRadius: 18,
            ),
          ),
          const SizedBox(width: 10),
          // ── Tappable notification bell ─────────────────────────────────────
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(AppIcons.notifications, size: 18, color: iconColor),
              onPressed: user != null ? () => context.go(_notifRouteFor(user)) : null,
              tooltip: 'Notifications',
              splashRadius: 18,
            ),
          ),
          if (user != null) ...[
            const SizedBox(width: 10),
            // ── Avatar with profile/logout popup menu ─────────────────────
            PopupMenuButton<String>(
              tooltip: 'Account',
              offset: const Offset(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'profile') context.go(_profileRouteFor(user));
                if (v == 'logout') onSignOut();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user!.displayName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(user!.email, style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
                      Text(user!.role.value.replaceAll('_', ' '), style: TextStyle(fontSize: 11, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(children: [Icon(AppIcons.profile, size: 16), SizedBox(width: 10), Text('View Profile')]),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(children: [Icon(AppIcons.logout, size: 16, color: AppColors.error), SizedBox(width: 10), Text('Sign Out', style: TextStyle(color: AppColors.error))]),
                ),
              ],
              child: AppAvatar(imageUrl: user!.avatarUrl, name: user!.displayName, size: 36),
            ),
          ],
        ],
      ),
    );
  }
}

class WebNavItem {
  final String label;
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final int? badge;

  const WebNavItem({
    required this.label,
    required this.route,
    required this.icon,
    required this.activeIcon,
    this.badge,
  });
}