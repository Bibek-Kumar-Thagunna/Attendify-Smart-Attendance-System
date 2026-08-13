import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audit_log_service.dart';

final systemSettingsServiceProvider = Provider<SystemSettingsService>((ref) {
  return SystemSettingsService(ref);
});

final systemSettingsStreamProvider = StreamProvider<Map<String, dynamic>>((
  ref,
) {
  return ref.watch(systemSettingsServiceProvider).streamSettings();
});

class SystemSettingsService {
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SystemSettingsService(this._ref);

  DocumentReference get _settingsRef =>
      _firestore.collection('system_settings').doc('config');

  Stream<Map<String, dynamic>> streamSettings() {
    return _settingsRef.snapshots().map((doc) {
      if (!doc.exists) {
        return {
          'maintenanceMode': false,
          'allowNewRegistrations': true,
          'globalAnnouncement': '',
        };
      }
      return doc.data() as Map<String, dynamic>;
    });
  }

  Future<void> updateMaintenanceMode(bool enabled) async {
    await _settingsRef.set({
      'maintenanceMode': enabled,
    }, SetOptions(merge: true));
    await _log('MAINTENANCE_MODE_TOGGLE', 'Maintenance mode set to $enabled');
  }

  Future<void> updateAllowNewRegistrations(bool allowed) async {
    await _settingsRef.set({
      'allowNewRegistrations': allowed,
    }, SetOptions(merge: true));
    await _log('REGISTRATION_TOGGLE', 'New registrations set to $allowed');
  }

  Future<void> updateGlobalAnnouncement(String message) async {
    await _settingsRef.set({
      'globalAnnouncement': message,
    }, SetOptions(merge: true));
    await _log('ANNOUNCEMENT_UPDATE', 'Global announcement updated');
  }

  Future<void> _log(String action, String details) async {
    await _ref
        .read(auditLogServiceProvider)
        .logAction(action: action, details: details);
  }
}
