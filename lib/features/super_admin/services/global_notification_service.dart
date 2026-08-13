import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audit_log_service.dart';

final globalNotificationServiceProvider = Provider<GlobalNotificationService>((
  ref,
) {
  return GlobalNotificationService(ref);
});

class GlobalNotificationService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GlobalNotificationService(this._ref);

  Future<void> sendGlobalNotification({
    required String title,
    required String message,
    required String targetRole, // 'all', 'student', 'teacher', 'admin'
    String? institutionId, // Optional: null means all institutions
  }) async {
    // We will write to a 'global_notifications' collection.
    // Clients (Student/Teacher dashboards) should listen to this collection
    // AND their personal notifications.

    await _firestore.collection('global_notifications').add({
      'title': title,
      'message': message,
      'targetRole': targetRole,
      'institutionId': institutionId,
      'timestamp': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      ), // Auto-expire after 7 days
    });

    // Log this action
    await _ref
        .read(auditLogServiceProvider)
        .logAction(
          action: 'BROADCAST_SENT',
          details:
              'Sent broadcast "$title" to $targetRole${institutionId != null ? " (Inst: $institutionId)" : ""}',
        );
  }
}
