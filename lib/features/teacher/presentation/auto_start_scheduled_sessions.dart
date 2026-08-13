import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/logger.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/providers.dart';
import '../providers.dart';

// Provider to monitor scheduled sessions and send notifications
final sessionNotificationMonitorProvider = Provider<SessionNotificationMonitor>(
  (ref) {
    return SessionNotificationMonitor(ref);
  },
);

class SessionNotificationMonitor {
  SessionNotificationMonitor(this.ref) {
    _startMonitoring();
  }

  final Ref ref;
  Timer? _checkTimer;
  final Set<String> _notifiedSessions = {};

  void _startMonitoring() {
    // Check every 30 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkForUpcomingSessions();
    });
    // Initial check
    Future.delayed(const Duration(seconds: 2), _checkForUpcomingSessions);
  }

  Future<void> _checkForUpcomingSessions() async {
    try {
      final auth = ref.read(authControllerProvider);
      if (auth.uid == null) return;

      // Check if already has an active session
      final activeSession = ref.read(activeSessionProvider);
      if (activeSession != null) return;

      final now = DateTime.now();

      // Get scheduled sessions
      var query = FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .where('teacherUid', isEqualTo: auth.uid);

      if (!auth.isSuperAdmin && auth.institutionCode != null) {
        query = query.where('institutionCode', isEqualTo: auth.institutionCode);
      }

      final snapshot = await query.get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final scheduledForRaw = data['scheduledFor'];

        if (scheduledForRaw is Timestamp) {
          final scheduledFor = scheduledForRaw.toDate();
          final difference = scheduledFor.difference(now);
          final minutesUntil = difference.inMinutes;

          // Logic:
          // 1. If session is starting in 1 minute (or less), send "Start Now" notification
          // 2. If session is starting in 15 minutes, send "Upcoming" reminder

          if (minutesUntil <= 1 && minutesUntil >= -10) {
            // Urgent: Starting now or slightly late
            if (!_notifiedSessions.contains('${doc.id}_urgent')) {
              await _sendNotification(
                id: doc.id.hashCode,
                title: 'Session Starting Now',
                body:
                    'Your session for ${data['subject']} is scheduled to start now. Tap to begin.',
                payload: '/teacher/dashboard', // Or specific route
              );
              _notifiedSessions.add('${doc.id}_urgent');
            }
          } else if (minutesUntil <= 15 && minutesUntil > 1) {
            // Reminder: 15 mins before
            if (!_notifiedSessions.contains('${doc.id}_reminder')) {
              await _sendNotification(
                id: doc.id.hashCode + 1,
                title: 'Upcoming Session',
                body:
                    'You have a session for ${data['subject']} starting in $minutesUntil minutes.',
                payload: '/teacher/dashboard',
              );
              _notifiedSessions.add('${doc.id}_reminder');
            }
          }
        }
      }
    } catch (e) {
      appLogger.e('Notification monitor error: $e');
    }
  }

  Future<void> _sendNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await NotificationService().showLocalNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
    } catch (e) {
      appLogger.e('Failed to send local notification: $e');
    }
  }

  void dispose() {
    _checkTimer?.cancel();
  }
}

// Widget to initialize monitoring
class SessionNotificationInitializer extends ConsumerStatefulWidget {
  const SessionNotificationInitializer({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SessionNotificationInitializer> createState() =>
      _SessionNotificationInitializerState();
}

class _SessionNotificationInitializerState
    extends ConsumerState<SessionNotificationInitializer> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(sessionNotificationMonitorProvider));
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
