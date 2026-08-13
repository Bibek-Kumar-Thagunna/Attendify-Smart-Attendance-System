import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers.dart';

final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  return AuditLogService(ref);
});

class AuditLogService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuditLogService(this._ref);

  Future<void> logAction({
    required String action,
    required String details,
    String? targetUid,
    String? institutionCode,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _ref.read(authControllerProvider);
      final actorUid = user.uid;
      final actorName = user.displayName ?? 'Unknown';
      final actorRole = user.role.name;

      if (actorUid == null) return; // Should not happen for logged in actions

      await _firestore.collection('audit_logs').add({
        'action': action,
        'details': details,
        'actorUid': actorUid,
        'actorName': actorName,
        'actorRole': actorRole,
        'targetUid': targetUid,
        'institutionCode': institutionCode,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Fail silently for logs, or print to console
      debugPrint('Failed to write audit log: $e');
    }
  }
}
