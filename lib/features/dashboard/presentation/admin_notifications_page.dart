import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dashboard/presentation/admin_shell.dart';
import '../../dashboard/notification_provider.dart';
import '../../../core/fluent_theme.dart';
import '../../notifications/providers.dart'; // Added
import '../../../features/auth/providers.dart'; // Added

class AdminNotificationsPage extends ConsumerWidget {
  const AdminNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(adminNotificationListProvider);

    return AdminShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final dynamicIds = notifications
                                    .where(
                                      (n) =>
                                          n.id.startsWith('new_user_') ||
                                          n.id.startsWith('approval_') ||
                                          n.id.startsWith('low_attendance_') ||
                                          n.id.startsWith('new_institutions'),
                                    )
                                    .map((n) => n.id)
                                    .toList();

                                ref
                                    .read(readNotificationsProvider.notifier)
                                    .markAllAsRead(dynamicIds);

                                // Also mark persistent ones
                                final authState = ref.read(
                                  authControllerProvider,
                                );
                                if (authState.uid != null) {
                                  ref
                                      .read(notificationRepositoryProvider)
                                      .markAllAsRead(
                                        authState.uid!,
                                        role: authState.role.name,
                                      );
                                }
                              },
                              icon: const Icon(
                                Icons.done_all_rounded,
                                size: 18,
                              ),
                              label: const Text('Mark all read'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: FluentColors.accentColor,
                                side: BorderSide(
                                  color: FluentColors.accentColor,
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
                                final authState = ref.read(
                                  authControllerProvider,
                                );
                                if (authState.uid != null) {
                                  ref
                                      .read(notificationRepositoryProvider)
                                      .clearAllNotifications(
                                        authState.uid!,
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
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            final dynamicIds = notifications
                                .where(
                                  (n) =>
                                      n.id.startsWith('new_user_') ||
                                      n.id.startsWith('approval_') ||
                                      n.id.startsWith('low_attendance_') ||
                                      n.id.startsWith('new_institutions'),
                                )
                                .map((n) => n.id)
                                .toList();

                            ref
                                .read(readNotificationsProvider.notifier)
                                .markAllAsRead(dynamicIds);

                            // Also mark persistent ones
                            final authState = ref.read(authControllerProvider);
                            if (authState.uid != null) {
                              ref
                                  .read(notificationRepositoryProvider)
                                  .markAllAsRead(
                                    authState.uid!,
                                    role: authState.role.name,
                                  );
                            }
                          },
                          icon: const Icon(Icons.done_all_rounded, size: 18),
                          label: Text(
                            'Mark all as read',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: FluentColors.accentColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            final authState = ref.read(authControllerProvider);
                            if (authState.uid != null) {
                              ref
                                  .read(notificationRepositoryProvider)
                                  .clearAllNotifications(
                                    authState.uid!,
                                    role: authState.role.name,
                                  );
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(
                            'Clear all',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
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
            child: notifications.isEmpty
                ? Center(
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
                  )
                : ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      final isRead = notification.read;
                      final createdAt = notification.timestamp;

                      return FluentAcrylicCard(
                        padding: const EdgeInsets.all(16),
                        onTap: () {
                          if (notification.metadata.containsKey('route')) {
                            context.go(notification.metadata['route']);
                          }
                        },
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
                                            color: isRead
                                                ? Colors.grey
                                                : Colors.white,
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
                                      color: isRead
                                          ? Colors.grey
                                          : Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (notification.type == 'action_required' &&
                                notification.metadata['action'] ==
                                    'approve_teacher') ...[
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Reject',
                                    onPressed: () => _rejectTeacher(
                                      context,
                                      ref,
                                      notification.metadata['teacherId'],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                    tooltip: 'Approve',
                                    onPressed: () => _approveTeacher(
                                      context,
                                      ref,
                                      notification.metadata['teacherId'],
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (!isRead)
                              IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.white54,
                                ),
                                tooltip: 'Mark as read',
                                onPressed: () {
                                  // Check if it's a dynamic notification (starts with new_user_, approval_, low_attendance_)
                                  if (notification.id.startsWith('new_user_') ||
                                      notification.id.startsWith('approval_') ||
                                      notification.id.startsWith(
                                        'low_attendance_',
                                      ) ||
                                      notification.id.startsWith(
                                        'new_institutions',
                                      )) {
                                    ref
                                        .read(
                                          readNotificationsProvider.notifier,
                                        )
                                        .markAsRead(notification.id);
                                  } else {
                                    // Persistent notification - use repository
                                    final authState = ref.read(
                                      authControllerProvider,
                                    );
                                    if (authState.uid != null) {
                                      ref
                                          .read(notificationRepositoryProvider)
                                          .markAsRead(
                                            notification.id,
                                            userId: authState.uid,
                                          );
                                    }
                                  }
                                },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'alert':
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'info':
        return Icons.info_outline;
      case 'success':
        return Icons.check_circle_outline;
      case 'action_required':
        return Icons.person_add_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Future<void> _approveTeacher(
    BuildContext context,
    WidgetRef ref,
    String? teacherId,
  ) async {
    if (teacherId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .update({
            'approved': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teacher approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving teacher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectTeacher(
    BuildContext context,
    WidgetRef ref,
    String? teacherId,
  ) async {
    if (teacherId == null) return;
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Teacher Application'),
        content: const Text(
          'Are you sure you want to reject this application? The user will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teacher application rejected')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting teacher: $e')),
          );
        }
      }
    }
  }
}
