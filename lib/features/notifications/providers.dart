import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'repository.dart';
import '../../core/services/notification_service.dart';
import '../auth/providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(firestore: FirebaseFirestore.instance);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final userNotificationsProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
      final auth = ref.watch(authControllerProvider);
      final uid = auth.uid;

      if (uid == null) return const Stream.empty();

      return ref
          .watch(notificationRepositoryProvider)
          .streamNotifications(uid, role: auth.role.name);
    });

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notificationsAsync = ref.watch(userNotificationsProvider);
  return notificationsAsync.when(
    data: (notifications) => notifications.where((n) => !n.read).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
