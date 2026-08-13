import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/responsive_utils.dart';
import '../../shared/widgets/modern_sidebar.dart';
import '../../shared/widgets/background_pattern.dart';
import '../notification_provider.dart';
import '../../../features/auth/providers.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  @override
  Widget build(BuildContext context) {
    // Listen for new registrations to show notifications
    ref.listen(newRegistrationsProvider, (previous, next) {
      next.whenData((registrations) {
        final prevRegistrations = previous?.value ?? [];

        // Find new ones
        final newUsers = registrations.where((user) {
          return !prevRegistrations.any((prev) => prev['id'] == user['id']);
        }).toList();

        for (final user in newUsers) {
          final name = user['displayName'] as String? ?? 'New User';
          final role = user['role'] as String? ?? 'User';

          // Show in-app notification (SnackBar or Toast) if needed,
          // but the dropdown badge updates automatically via provider.
          // We can also trigger a system notification here if we want.

          // For now, let's show a SnackBar for immediate feedback
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('New $role registered: $name'),
                action: SnackBarAction(
                  label: 'View',
                  onPressed: () => context.go('/admin/users'),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );

            // Trigger system notification
            // We need to access NotificationService but it's a singleton/service
            // We can add a provider for it or just import it.
            // Importing it is fine for now as it's a singleton.
          }
        }
      });
    });

    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final location = GoRouterState.of(context).uri.toString();
        // Define top-level sidebar paths that should show the hamburger menu
        final isSidebarRoute = [
          '/admin',
          '/admin/notifications',
          '/admin/institutions',
          '/admin/users',
          '/admin/class-groups',
          '/admin/approve-teachers',
          '/admin/teachers-analytics',
          '/admin/analytics',
          '/admin/subjects',
          '/admin/reports',
          '/admin/profile',
          '/admin/about',
        ].contains(location);

        return Scaffold(
          // Drawer for mobile
          drawer: isMobile ? const Drawer(child: _Sidebar()) : null,
          // AppBar only for mobile (matching Student/Teacher pattern)
          appBar: isMobile
              ? AppBar(
                  title: const Text('Attendify Admin'),
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
                    // Notification button for mobile - far right
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

                        if (location.contains('/admin/notifications')) {
                          return const SizedBox.shrink();
                        }

                        return Stack(
                          children: [
                            IconButton(
                              onPressed: () =>
                                  context.go('/admin/notifications'),
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
            // Wrap in BackgroundPattern
            child: SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Permanent sidebar for tablet and desktop
                  if (!isMobile) const _Sidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        // Topbar only for desktop/tablet (has search bar)
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
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1121), // Dark background
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          // Notification Button with Badge - far right
          Consumer(
            builder: (context, ref, _) {
              final notifications = ref.watch(adminNotificationListProvider);
              final unreadCount = notifications.where((n) => !n.read).length;
              final location = GoRouterState.of(context).uri.toString();

              if (location.contains('/admin/notifications')) {
                return const SizedBox.shrink();
              }

              return Stack(
                children: [
                  IconButton(
                    onPressed: () => context.go('/admin/notifications'),
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
    final displayName = authState.displayName ?? 'User';
    final email = authState.email ?? '';
    final photoUrl = authState.photoUrl;
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      offset: const Offset(0, 8),
      color: const Color(0xFF1E293B), // Dark slate
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primary.withValues(alpha: 0.2),
            foregroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            onForegroundImageError: photoUrl != null
                ? (exception, stackTrace) {
                    // Silently handle image load errors
                  }
                : null,
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
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
                authState.isSuperAdmin
                    ? 'SUPER ADMIN'
                    : authState.role.name.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: authState.isSuperAdmin
                      ? const Color(0xFF8B5CF6)
                      : Colors.white54,
                  fontWeight: authState.isSuperAdmin
                      ? FontWeight.bold
                      : FontWeight.normal,
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
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: Colors.white),
              SizedBox(width: 12),
              Text('Profile', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'about',
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.white),
              SizedBox(width: 12),
              Text('About', style: TextStyle(color: Colors.white)),
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
        switch (value) {
          case 'profile':
            context.go('/admin/profile');
            break;
          case 'about':
            context.go('/admin/about');
            break;
          case 'logout':
            ref.read(authControllerProvider.notifier).signOut();
            context.go('/login');
            break;
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
      SidebarItem.header('Main'),
      SidebarItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/admin',
      ),
      SidebarItem(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        path: '/admin/notifications',
      ),
      SidebarItem(
        icon: Icons.verified_user_rounded,
        label: 'User Management',
        path: '/admin/users',
      ),
      SidebarItem(
        icon: Icons.groups_rounded,
        label: 'Class Groups',
        path: '/admin/class-groups',
      ),
      SidebarItem(
        icon: Icons.how_to_reg_rounded,
        label: 'Teacher Approvals',
        path: '/admin/approve-teachers',
      ),
      SidebarItem(
        icon: Icons.school_rounded,
        label: 'Teacher Analytics',
        path: '/admin/teachers-analytics',
      ),
      SidebarItem.divider(),
      SidebarItem.header('Analytics'),
      SidebarItem(
        icon: Icons.analytics_rounded,
        label: 'Attendance Analytics',
        path: '/admin/analytics',
      ),
      SidebarItem(
        icon: Icons.book_outlined,
        label: 'Subjects',
        path: '/admin/subjects',
      ),
      SidebarItem(
        icon: Icons.bar_chart_rounded,
        label: 'Reports',
        path: '/admin/reports',
      ),
      SidebarItem(
        icon: Icons.campaign_rounded,
        label: 'Broadcast',
        path: '/admin/broadcast',
      ),
      SidebarItem.divider(),
      SidebarItem.header('Account'),
      SidebarItem(
        icon: Icons.person_rounded,
        label: 'Profile',
        path: '/admin/profile',
      ),
      SidebarItem(
        icon: Icons.info_outline,
        label: 'About',
        path: '/admin/about',
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
