import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audit_log_service.dart';

final userManagementServiceProvider = Provider<UserManagementService>((ref) {
  return UserManagementService(ref);
});

class UserManagementService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserManagementService(this._ref);

  Future<void> toggleUserActive(String uid, bool isActive) async {
    await _firestore.collection('users').doc(uid).update({'active': isActive});
    await _log(
      'USER_STATUS_CHANGE',
      'User $uid active status set to $isActive',
    );
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
    await _log('USER_UPDATE', 'User $uid updated with data: $data');
  }

  Future<void> _log(String action, String details) async {
    await _ref
        .read(auditLogServiceProvider)
        .logAction(action: action, details: details);
  }
}
