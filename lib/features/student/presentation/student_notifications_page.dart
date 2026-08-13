import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'student_shell.dart';
import '../../notifications/providers.dart';
import '../../../core/fluent_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../features/auth/providers.dart';

class StudentNotificationsPage extends ConsumerWidget {
  const StudentNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);
    final authState = ref.watch(authControllerProvider);

    return StudentShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Mark all as read button
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final uid = authState.uid;
                                if (uid != null) {
                                  ref
                                      .read(notificationRepositoryProvider)
                                      .markAllAsRead(
                                        uid,
                                        role: authState.role.name,
                                      );
                                }
                              },
                              icon: const Icon(Icons.done_all, size: 18),
                              label: const Text('Mark all read'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00B0FF),
                                side: const BorderSide(
                                  color: Color(0xFF00B0FF),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final uid = authState.uid;
                                if (uid != null) {
                                  ref
                                      .read(notificationRepositoryProvider)
                                      .clearAllNotifications(
                                        uid,
                                        role: authState.role.name,
                                      );
                                }
                              },
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Clear all'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final uid = authState.uid;
                            if (uid != null) {
                              ref
                                  .read(notificationRepositoryProvider)
                                  .markAllAsRead(
                                    uid,
                                    role: authState.role.name,
                                  );
                            }
                          },
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Mark all as read'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF00B0FF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            final uid = authState.uid;
                            if (uid != null) {
                              ref
                                  .read(notificationRepositoryProvider)
                                  .clearAllNotifications(
                                    uid,
                                    role: authState.role.name,
                                  );
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Clear all'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: notificationsAsync.when(
              data: (notifications) {
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          size: 64,
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isRead = notification.read;
                    final createdAt = notification.timestamp;

                    return FluentAcrylicCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.grey.withValues(alpha: 0.1)
                                  : FluentColors.info.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getIconForType(notification.type),
                              color: isRead ? Colors.grey : FluentColors.info,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontWeight: isRead
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                          fontSize: 16,
                                          color: isRead ? Colors.grey : null,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      DateFormat.MMMd().add_jm().format(
                                        createdAt,
                                      ),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.message,
                                  style: TextStyle(
                                    color: isRead ? Colors.grey : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isRead)
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              tooltip: 'Mark as read',
                              onPressed: () {
                                ref
                                    .read(notificationRepositoryProvider)
                                    .markAsRead(
                                      notification.id,
                                      userId: authState.uid,
                                    );
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorHandler.buildErrorWidget(
                e,
                customMessage: 'Unable to load notifications',
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'attendance_report':
        return Icons.analytics_outlined;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'location_violation':
        return Icons.location_off;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }
}
