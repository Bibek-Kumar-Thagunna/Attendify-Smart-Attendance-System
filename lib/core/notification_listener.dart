import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/notifications/repository.dart';
import '../features/auth/providers.dart';
import 'services/notification_service.dart';

/// Provider that listens to user notifications and triggers system notifications
final notificationListenerProvider = StreamProvider.autoDispose<void>((
  ref,
) async* {
  final authState = ref.watch(authControllerProvider);
  final userId = authState.uid;

  if (userId == null) {
    yield null;
    return;
  }

  final repository = NotificationRepository();
  final notificationService = NotificationService();
  final prefs = await SharedPreferences.getInstance();

  // Key to store shown notification IDs for this user
  final shownKey = 'shown_notifications_$userId';

  // Get previously shown notification IDs from persistent storage
  final persistedShownIds =
      prefs.getStringList(shownKey)?.toSet() ?? <String>{};

  // Track shown IDs in this session (in-memory)
  final sessionShownIds = <String>{...persistedShownIds};

  await for (final notifications in repository.streamNotifications(userId)) {
    if (notifications.isEmpty) {
      yield null;
      continue;
    }

    // Filter to only unread notifications
    final unreadNotifications = notifications.where((n) => !n.read).toList();

    if (unreadNotifications.isEmpty) {
      yield null;
      continue;
    }

    // Track if we showed any new notifications in this iteration
    bool showedNewNotification = false;

    // Check for new notifications that haven't been shown yet
    for (final notification in unreadNotifications) {
      // Skip if we've already shown this notification (in session or persisted)
      if (sessionShownIds.contains(notification.id)) {
        continue;
      }

      // Show the system notification
      await notificationService.showNotification(
        id: notification.id.hashCode,
        title: notification.title,
        body: notification.message,
      );

      // Mark as shown in this session
      sessionShownIds.add(notification.id);
      showedNewNotification = true;
    }

    // Only persist if we actually showed new notifications
    if (showedNewNotification) {
      // Persist the shown IDs (keep only last 100 to avoid bloat)
      final idsToKeep = sessionShownIds.toList();
      if (idsToKeep.length > 100) {
        idsToKeep.removeRange(0, idsToKeep.length - 100);
      }
      await prefs.setStringList(shownKey, idsToKeep);
    }

    yield null;
  }
});
