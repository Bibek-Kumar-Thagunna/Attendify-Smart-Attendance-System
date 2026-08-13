import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/responsive_utils.dart';
import '../../shared/widgets/modern_sidebar.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../../features/auth/providers.dart';
import '../../dashboard/notification_provider.dart';

class SuperAdminShell extends ConsumerStatefulWidget {
  const SuperAdminShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends ConsumerState<SuperAdminShell> {
  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final location = GoRouterState.of(context).uri.toString();
        final isSidebarRoute = [
          '/super-admin',
          '/super-admin/institutions',
          '/super-admin/notifications',
          '/super-admin/profile',
          '/super-admin/about',
        ].contains(location);

        return Scaffold(
          drawer: isMobile ? const Drawer(child: _Sidebar()) : null,
          appBar: isMobile
              ? AppBar(
                  title: const Text('Super Admin'),
                  backgroundColor: const Color(0xFF0B1121),
                  foregroundColor: Colors.white,
                  leading: isSidebarRoute
                      ? Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        )
                      : (context.canPop() ? const BackButton() : null),
                  actions: [
                    Consumer(
                      builder: (context, ref, _) {
                        final notifications = ref.watch(
                          adminNotificationListProvider,
                        );
                        final unreadCount = notifications
                            .where((n) => !n.read)
                            .length;
                        final location = GoRouterState.of(
                          context,
                        ).uri.toString();

                        if (location.contains('/super-admin/notifications')) {
                          return const SizedBox.shrink();
                        }

                        return Stack(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  context.go('/super-admin/notifications'),
                              icon: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                              ),
                              tooltip: 'Notifications',
                            ),
                            if (unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF0B1121),
                                        width: 2,
                                      ),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Center(
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : null,
          body: BackgroundPattern(
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isMobile) const _Sidebar(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isMobile) const _Topbar(),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.all(isMobile ? 16 : 24),
                            child: widget.child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Topbar extends ConsumerWidget {
  const _Topbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final isSidebarRoute = [
      '/super-admin',
      '/super-admin/institutions',
      '/super-admin/notifications',
      '/super-admin/profile',
      '/super-admin/about',
    ].contains(location);
    final canPop = context.canPop();

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1121),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          if (!isSidebarRoute && canPop)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Back',
              ),
            ),
          const Spacer(),
          Consumer(
            builder: (context, ref, _) {
              final notifications = ref.watch(adminNotificationListProvider);
              final unreadCount = notifications.where((n) => !n.read).length;
              final location = GoRouterState.of(context).uri.toString();

              if (location.contains('/super-admin/notifications')) {
                return const SizedBox.shrink();
              }

              return Stack(
                children: [
                  IconButton(
                    onPressed: () => context.go('/super-admin/notifications'),
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                    ),
                    tooltip: 'Notifications',
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0B1121),
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Center(
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 16),
          const _UserMenuButton(),
        ],
      ),
    );
  }
}

class _UserMenuButton extends ConsumerWidget {
  const _UserMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final displayName = authState.displayName ?? 'Super Admin';
    final email = authState.email ?? '';
    final photoUrl = authState.photoUrl;

    return PopupMenuButton<String>(
      offset: const Offset(0, 8),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            foregroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                'SUPER ADMIN',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: const Color(0xFF8B5CF6),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: Colors.white54,
          ),
        ],
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                email,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Color(0xFFEF4444)),
              SizedBox(width: 12),
              Text('Logout', style: TextStyle(color: Color(0xFFEF4444))),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'logout') {
          ref.read(authControllerProvider.notifier).signOut();
          context.go('/login');
        }
      },
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();

    final items = [
      SidebarItem.header('Governance'),
      SidebarItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/super-admin',
      ),
      SidebarItem(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        path: '/super-admin/notifications',
      ),
      SidebarItem(
        icon: Icons.apartment_rounded,
        label: 'Institutions',
        path: '/super-admin/institutions',
      ),
      SidebarItem.divider(),
      SidebarItem.header('System'),
      SidebarItem(
        icon: Icons.analytics_rounded,
        label: 'System Health',
        path: '/super-admin/health', // Placeholder
      ),
      SidebarItem.divider(),
      SidebarItem.header('Account'),
      SidebarItem(
        icon: Icons.person_rounded,
        label: 'Profile',
        path: '/super-admin/profile',
      ),
      SidebarItem.divider(),
      SidebarItem.header('Administration'),
      SidebarItem(
        icon: Icons.people_outline_rounded,
        label: 'Users',
        path: '/super-admin/users',
      ),
      SidebarItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        path: '/super-admin/settings',
      ),
      SidebarItem.divider(),
      SidebarItem.header('Tools'),
      SidebarItem(
        icon: Icons.history_edu_rounded,
        label: 'Audit Logs',
        path: '/super-admin/audit-logs',
      ),
      SidebarItem(
        icon: Icons.campaign_rounded,
        label: 'Broadcast',
        path: '/super-admin/broadcast',
      ),
    ];

    return SafeArea(
      child: ModernSidebar(
        items: items,
        currentPath: location,
        footer: const _LogoutButton(),
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          ref.read(authControllerProvider.notifier).signOut();
          context.go('/login');
        },
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text('Logout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: const Color(0xFFEF4444),
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
