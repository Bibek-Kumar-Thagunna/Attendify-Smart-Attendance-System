import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/responsive_utils.dart';
import '../../shared/widgets/modern_sidebar.dart';
import '../../../features/auth/providers.dart';
import '../../notifications/providers.dart';
import '../services/scheduler_service.dart';

class StudentShell extends ConsumerWidget {
  const StudentShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final authState = ref.watch(authControllerProvider);
    final isImpersonating = authState.originalAdminUid != null;

    // Initialize SchedulerService for class reminders
    ref.watch(schedulerServiceProvider);

    // Listen for new notifications
    ref.listen(userNotificationsProvider, (previous, next) {
      next.whenData((notifications) {
        if (notifications.isEmpty) return;

        // Check if the latest notification is unread and different from previous
        final latest = notifications.first;
        if (latest.read) return;

        // Simple check: if previous was empty or latest ID is different
        final previousList = previous?.asData?.value ?? [];
        if (previousList.isEmpty || previousList.first.id != latest.id) {
          // Show system notification (local)
          ref
              .read(notificationServiceProvider)
              .showNotification(
                id: latest.hashCode, // Use hashcode as ID since we need an int
                title: latest.title,
                body: latest.message,
              );

          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latest.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(latest.message),
                ],
              ),
              action: SnackBarAction(
                label: 'Mark Read',
                onPressed: () {
                  if (authState.uid != null) {
                    ref
                        .read(notificationRepositoryProvider)
                        .markAsRead(latest.id, userId: authState.uid);
                  }
                },
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
    });

    final items = [
      SidebarItem.header('Main'),
      SidebarItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/student',
      ),
      SidebarItem(
        icon: Icons.library_books_rounded,
        label: 'My Subjects',
        path: '/student/subjects',
      ),
      SidebarItem(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        path: '/student/notifications',
      ),
      SidebarItem(
        icon: Icons.analytics_rounded,
        label: 'Analytics',
        path: '/student/analytics',
      ),
      SidebarItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Scan QR',
        path: '/student/scan',
      ),
      SidebarItem.divider(),
      SidebarItem.header('Records'),
      SidebarItem(
        icon: Icons.history_rounded,
        label: 'Attendance History',
        path: '/student/history',
      ),
      SidebarItem.divider(),
      SidebarItem.header('Account'),
      SidebarItem(
        icon: Icons.person_rounded,
        label: 'Profile',
        path: '/student/profile',
      ),
    ];

    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final notificationsAsync = ref.watch(userNotificationsProvider);
        final unreadCount =
            notificationsAsync.asData?.value.where((n) => !n.read).length ?? 0;

        final notificationIcon = Stack(
          children: [
            IconButton(
              onPressed: () => context.go('/student/notifications'),
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
                    if (!location.contains('/student/notifications'))
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
                                !location.contains('/student/notifications'))
                              Positioned(
                                top: 12,
                                right: 24,
                                child: Material(
                                  color: Colors.transparent,
                                  child: notificationIcon,
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
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () {
        ref.read(authControllerProvider.notifier).signOut();
        context.go('/login');
      },
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Logout'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: const Color(0xFF94A3B8),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
