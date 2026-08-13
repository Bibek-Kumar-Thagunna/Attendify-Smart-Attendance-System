import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/providers.dart';
import 'providers.dart';
import '../shared/widgets/alerts_card.dart';
import '../notifications/repository.dart';
import '../notifications/providers.dart';

/// Combined notification data model
class NotificationData {
  final int pendingApprovals;
  final int lowAttendanceAlerts;
  final int newInstitutions;
  final List<Map<String, dynamic>> pendingTeacherRequests;
  final List<Map<String, dynamic>> newRegistrations; // Added

  const NotificationData({
    this.pendingApprovals = 0,
    this.lowAttendanceAlerts = 0,
    this.newInstitutions = 0,
    this.pendingTeacherRequests = const [],
    this.newRegistrations = const [], // Added
  });

  bool get hasNotifications =>
      pendingApprovals > 0 ||
      lowAttendanceAlerts > 0 ||
      newInstitutions > 0 ||
      newRegistrations.isNotEmpty; // Added

  int get total =>
      pendingApprovals +
      lowAttendanceAlerts +
      newInstitutions +
      newRegistrations.length;
}

/// Provider for new user registrations (last 5 minutes) to trigger notifications
final newRegistrationsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  // Listen for users created in the last 5 minutes
  // This is a "live" stream for notifications
  final cutoff = DateTime.now().subtract(const Duration(minutes: 5));

  return FirebaseFirestore.instance
      .collection('users')
      .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

/// Provider that combines all notification sources
final notificationsProvider = Provider<AsyncValue<NotificationData>>((ref) {
  // Watch all providers
  final pendingListAsync = ref.watch(pendingTeachersListProvider);
  final alertsAsync = ref.watch(lowAttendanceAlertsProvider);
  final newRegistrationsAsync = ref.watch(newRegistrationsProvider); // Added

  if (pendingListAsync.isLoading ||
      alertsAsync.isLoading ||
      newRegistrationsAsync.isLoading) {
    return const AsyncLoading();
  }

  if (pendingListAsync.hasError) {
    return AsyncError(pendingListAsync.error!, pendingListAsync.stackTrace!);
  }

  final pendingList = pendingListAsync.value ?? [];
  final alerts = alertsAsync.value ?? [];
  final newRegistrations = newRegistrationsAsync.value ?? []; // Added

  // Count different alert types
  int lowAttendance = 0;
  int newInstitutions = 0;

  for (final alert in alerts) {
    if (alert['type'] == 'low_attendance') {
      lowAttendance++;
    } else if (alert['type'] == 'new_institution') {
      newInstitutions++;
    }
  }

  return AsyncData(
    NotificationData(
      pendingApprovals: pendingList.length,
      lowAttendanceAlerts: lowAttendance,
      newInstitutions: newInstitutions,
      pendingTeacherRequests: pendingList,
      newRegistrations: newRegistrations, // Added
    ),
  );
});

/// Provider to track read status of dynamic notifications locally
final readNotificationsProvider =
    NotifierProvider<ReadNotificationsNotifier, Set<String>>(
      ReadNotificationsNotifier.new,
    );

class ReadNotificationsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return {};
  }

  void markAsRead(String id) {
    state = {...state, id};
  }

  void markAllAsRead(List<String> ids) {
    state = {...state, ...ids};
  }
}

/// Provider that returns a list of NotificationModel for the admin UI
/// This converts the dynamic counts into notification objects to match the Student/Teacher UI
final adminNotificationListProvider = Provider<List<NotificationModel>>((ref) {
  final dataAsync = ref.watch(notificationsProvider);
  final readIds = ref.watch(readNotificationsProvider);
  final authState = ref.watch(authControllerProvider);
  final userNotificationsAsync = ref.watch(userNotificationsProvider);

  return dataAsync.when(
    data: (data) {
      final List<NotificationModel> list = [];
      final now = DateTime.now();

      // 1. Add persistent notifications (Broadcasts, System Alerts)
      if (userNotificationsAsync.hasValue) {
        list.addAll(userNotificationsAsync.value!);
      }

      // New User Registrations
      for (final user in data.newRegistrations) {
        final userId = user['id'] as String;
        final name = user['displayName'] as String? ?? 'New User';
        final email = user['email'] as String? ?? '';
        final role = user['role'] as String? ?? 'student';
        final notifId = 'new_user_$userId';

        // Skip if already read (or we can keep it if we want persistent list)
        // For now, let's keep it in the list but mark as read if clicked

        list.add(
          NotificationModel(
            id: notifId,
            recipientUid: 'admin',
            senderUid: userId,
            senderName: name,
            senderRollNumber: '',
            title: 'New Registration',
            message: 'New $role registered: $name ($email)',
            type: 'info',
            timestamp: _parseTimestamp(user['createdAt']) ?? now,
            read: readIds.contains(notifId),
            metadata: {'userId': userId, 'role': role, 'email': email},
            institutionId: user['institutionCode'] as String?,
          ),
        );
      }

      // Individual Teacher Approvals
      for (final teacher in data.pendingTeacherRequests) {
        final teacherId = teacher['id'] as String;
        final name = teacher['displayName'] as String? ?? 'Unknown Teacher';
        final email = teacher['email'] as String? ?? '';

        final notifId = 'approval_$teacherId';

        list.add(
          NotificationModel(
            id: notifId,
            recipientUid: 'admin',
            senderUid: teacherId,
            senderName: name,
            senderRollNumber: '',
            title: 'New Teacher Registration',
            message: '$name ($email) requested approval.',
            type: 'action_required', // Special type for actions
            timestamp: _parseTimestamp(teacher['createdAt']) ?? now,
            read: readIds.contains(notifId),
            metadata: {
              'action': 'approve_teacher',
              'teacherId': teacherId,
              'teacherName': name,
              'teacherEmail': email,
            },
            institutionId: teacher['institutionCode'] as String?,
          ),
        );
      }

      if (data.lowAttendanceAlerts > 0) {
        final id = 'low_attendance_v2';
        list.add(
          NotificationModel(
            id: id,
            recipientUid: 'admin',
            senderUid: 'system',
            senderName: 'System',
            senderRollNumber: '',
            title: 'Low Attendance Alerts',
            message:
                '${data.lowAttendanceAlerts} student${data.lowAttendanceAlerts > 1 ? 's' : ''} with low attendance',
            type: 'warning',
            timestamp: now,
            read: readIds.contains(id),
            metadata: const {},
          ),
        );
      }

      // Only show New Institutions to Super Admin
      if (data.newInstitutions > 0 && authState.isSuperAdmin) {
        final id = 'new_institutions';
        list.add(
          NotificationModel(
            id: id,
            recipientUid: 'admin',
            senderUid: 'system',
            senderName: 'System',
            senderRollNumber: '',
            title: 'New Institutions',
            message:
                '${data.newInstitutions} new institution${data.newInstitutions > 1 ? 's' : ''} registered',
            type: 'info',
            timestamp: now,
            read: readIds.contains(id),
            metadata: {'route': '/admin/institutions'},
          ),
        );
      }

      // Sort by timestamp descending
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return list;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
