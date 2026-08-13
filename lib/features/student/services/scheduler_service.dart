import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers.dart';
import '../../shared/providers.dart';
import '../../../core/services/notification_service.dart';

final schedulerServiceProvider = Provider<SchedulerService>((ref) {
  return SchedulerService(ref);
});

class SchedulerService {
  final Ref _ref;

  SchedulerService(this._ref) {
    _initialize();
  }

  void _initialize() {
    // Start listening to scheduled sessions
    _listenToScheduledSessions();
  }

  void _listenToScheduledSessions() {
    final auth = _ref.read(authControllerProvider);
    if (auth.uid == null || auth.institutionCode == null) return;

    // We need to know the student's groups to filter relevant sessions
    _ref.listen(studentClassGroupsProvider, (previous, next) {
      next.whenData((groups) {
        final groupNames = groups.map((g) => g.name).toList();
        if (groupNames.isEmpty) return;

        _scheduleForGroups(groupNames, auth.institutionCode!);
      });
    });
  }

  Future<void> _scheduleForGroups(
    List<String> groupNames,
    String institutionCode,
  ) async {
    // Cancel all existing notifications to avoid duplicates/stale data
    await NotificationService().cancelAll();

    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Fetch scheduled sessions for today
    final snapshot = await FirebaseFirestore.instance
        .collection('scheduled_sessions')
        .where('institutionCode', isEqualTo: institutionCode)
        .where('scheduledFor', isGreaterThan: Timestamp.fromDate(now))
        .where('scheduledFor', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final group = data['group'] as String?;

      // Filter by student's enrolled groups
      if (group != null && groupNames.contains(group)) {
        final scheduledFor = (data['scheduledFor'] as Timestamp).toDate();
        final subject = data['subject'] as String? ?? 'Class';

        _scheduleNotification(
          id: doc.id.hashCode,
          title: 'Class Starting Soon',
          body: '$subject ($group) starts in 15 minutes.',
          scheduledDate: scheduledFor.subtract(const Duration(minutes: 15)),
        );
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (scheduledDate.isBefore(DateTime.now())) return;

    await NotificationService().scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
    );
  }
}
