import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendify/features/shared/widgets/modern_sidebar.dart';
import 'package:attendify/features/auth/providers.dart';
import 'package:attendify/core/utils/responsive_builder.dart';
import 'package:attendify/features/shared/widgets/session_notification_initializer.dart';
import 'package:attendify/features/notifications/providers.dart';

class TeacherShell extends ConsumerWidget {
  final Widget child;

  const TeacherShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final authState = ref.watch(authControllerProvider);
    final isImpersonating = authState.originalAdminUid != null;

    final items = [
      SidebarItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/teacher',
      ),
      SidebarItem(
        icon: Icons.qr_code_rounded,
        label: 'Start Session',
        path: '/teacher/generate',
      ),
      SidebarItem(
        icon: Icons.people_rounded,
        label: 'Students',
        path: '/teacher/students',
      ),
      SidebarItem(
        icon: Icons.book_rounded,
        label: 'Subjects',
        path: '/teacher/subjects',
      ),
      SidebarItem(
        icon: Icons.schedule_rounded,
        label: 'Schedule Session',
        path: '/teacher/schedule',
      ),
      SidebarItem(
        icon: Icons.calendar_today_rounded,
        label: 'Attendance',
        path: '/teacher/attendance',
      ),
      SidebarItem(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        path: '/teacher/notifications',
      ),
      SidebarItem.divider(),
      SidebarItem.header('Reports'),
      SidebarItem(
        icon: Icons.file_download_outlined,
        label: 'Export Data',
        path: '/teacher/exports',
      ),
      SidebarItem.divider(),
      SidebarItem.header('Account'),
      SidebarItem(
        icon: Icons.person_rounded,
        label: 'Profile',
        path: '/teacher/settings',
      ),
    ];

    return SessionNotificationInitializer(
      child: ResponsiveBuilder(
        builder: (context, isMobile, isTablet, isDesktop) {
          final notificationsAsync = ref.watch(userNotificationsProvider);
          final unreadCount =
              notificationsAsync.asData?.value.where((n) => !n.read).length ??
              0;

          final notificationIcon = Stack(
            children: [
              IconButton(
                onPressed: () => context.go('/teacher/notifications'),
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifications',
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          );

          return Scaffold(
            // Drawer for mobile
            drawer: isMobile
                ? Drawer(
                    child: ModernSidebar(
                      items: items,
                      currentPath: location,
                      footer: _LogoutButton(),
                    ),
                  )
                : null,
            appBar: isMobile
                ? AppBar(
                    title: const Text('Attendify'),
                    backgroundColor: const Color(0xFF0B1121),
                    foregroundColor: Colors.white,
                    leading: context.canPop() ? const BackButton() : null,
                    actions: [
                      _OfflineIndicator(),
                      if (!location.contains('/teacher/notifications'))
                        notificationIcon,
                      const SizedBox(width: 8),
                    ],
                  )
                : null,
            body: SafeArea(
              child: Column(
                children: [
                  if (isImpersonating)
                    Container(
                      width: double.infinity,
                      color: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.visibility,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'You are impersonating this user',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: () {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .stopImpersonation();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                            ),
                            child: const Text('Stop'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        // Permanent sidebar for tablet and desktop
                        if (!isMobile)
                          ModernSidebar(
                            items: items,
                            currentPath: location,
                            footer: _LogoutButton(),
                          ),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isMobile ? 16 : 24),
                                child: child,
                              ),
                              if (!isMobile &&
                                  !location.contains('/teacher/notifications'))
                                Positioned(
                                  top: 12,
                                  right: 24,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _OfflineIndicator(),
                                      const SizedBox(width: 16),
                                      Material(
                                        color: Colors.transparent,
                                        child: notificationIcon,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.white70),
      title: Text('Logout', style: GoogleFonts.outfit(color: Colors.white70)),
      onTap: () {
        ref.read(authControllerProvider.notifier).signOut();
      },
    );
  }
}

class _OfflineIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This would be connected to a connectivity provider
    return const SizedBox.shrink();
  }
}
