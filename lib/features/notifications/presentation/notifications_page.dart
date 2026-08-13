import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../repository.dart';
import '../../auth/providers.dart';
import '../../../core/utils/error_handler.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final notificationsAsync = ref.watch(userNotificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            LayoutBuilder(
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
                      const SizedBox(height: 4),
                      Text(
                        'Stay updated with important alerts',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white54,
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
                    Expanded(
                      child: Column(
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
                          const SizedBox(height: 4),
                          Text(
                            'Stay updated with important alerts',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
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
            const SizedBox(height: 24),

            // List
            Expanded(
              child: notificationsAsync.when(
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationItem(notification: notification);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => ErrorHandler.buildErrorWidget(
                  e,
                  customMessage: 'Unable to load notifications',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationItem extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationItem({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final isLocationViolation = notification.type == 'location_violation';
    final color = isLocationViolation ? Colors.red : Colors.blue;
    final icon = isLocationViolation ? Icons.location_off : Icons.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notification.read
            ? Colors.white.withValues(alpha: 0.02)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.read
              ? Colors.transparent
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                notification.title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            if (!notification.read)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              notification.message,
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.white38),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(notification.timestamp),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
                if (isLocationViolation) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.person, size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    notification.senderRollNumber,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () {
          if (!notification.read) {
            ref
                .read(notificationRepositoryProvider)
                .markAsRead(notification.id, userId: authState.uid);
          }
        },
        trailing: !notification.read
            ? IconButton(
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white54,
                ),
                tooltip: 'Mark as read',
                onPressed: () {
                  ref
                      .read(notificationRepositoryProvider)
                      .markAsRead(notification.id, userId: authState.uid);
                },
              )
            : null,
      ),
    );
  }
}
