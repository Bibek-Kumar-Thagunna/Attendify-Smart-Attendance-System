import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/active_session.dart';
import '../auth/providers.dart';
import '../attendance/repository.dart';
import '../attendance/providers.dart';
import '../../core/logger.dart';

class ConflictingSessionException implements Exception {
  final String subjectName;
  final String teacherName;
  final String group;

  ConflictingSessionException({
    required this.subjectName,
    required this.teacherName,
    required this.group,
  });

  @override
  String toString() =>
      'Session for $subjectName ($group) is already running by $teacherName';
}

final activeSessionProvider =
    NotifierProvider<ActiveSessionController, ActiveSession?>(
      ActiveSessionController.new,
    );

class ActiveSessionController extends Notifier<ActiveSession?> {
  late final StreamSubscription<int> _ticker;
  late final AttendanceRepository _repo;

  @override
  ActiveSession? build() {
    _repo = ref.watch(attendanceRepositoryProvider);

    // Listen to auth changes and reset session when user changes
    ref.listen(authControllerProvider, (previous, next) {
      appLogger.d(
        '🔄 [Session] Auth changed from ${previous?.uid} to ${next.uid}',
      );

      // If user logged out or changed, clear session and resubscribe
      if (previous?.uid != next.uid) {
        appLogger.d(
          '🧹 [Session] Clearing state and resubscribing for new user',
        );
        state = null;
        _sessionSubscription?.cancel();
        _sessionSubscription = null;

        // Resubscribe for new user if they're logged in
        if (next.uid != null) {
          _restoreActiveSessionWithRetry();
        }
      }
    });

    // Restore active session with retry mechanism
    _restoreActiveSessionWithRetry();

    // Tick every second to trigger UI updates for timer and QR code
    _ticker = Stream.periodic(const Duration(seconds: 1), (int i) => i).listen((
      _,
    ) {
      if (state != null) {
        // Force a rebuild by creating a new state instance
        // This ensures the UI updates every second for timer and QR code
        final current = state!;
        state = ActiveSession(
          sessionId: current.sessionId,
          expiresAt: current.expiresAt,
          latitude: current.latitude,
          longitude: current.longitude,
          radiusMeters: current.radiusMeters,
        );

        // Auto-end session if expired
        if (current.isExpired) {
          endSession();
        }
      }
    });
    ref.onDispose(() {
      _ticker.cancel();
      _sessionSubscription?.cancel();
    });
    return null;
  }

  StreamSubscription<QuerySnapshot>? _sessionSubscription;

  Future<void> _restoreActiveSessionWithRetry() async {
    int retries = 0;
    const maxRetries = 10;
    const retryDelay = Duration(milliseconds: 500);

    while (retries < maxRetries) {
      final auth = ref.read(authControllerProvider);
      if (auth.uid != null) {
        // Auth is ready, restore session
        await _restoreActiveSession();
        return;
      }

      // Auth not ready yet, wait and retry
      appLogger.d(
        'Auth not ready for session restore, retry ${retries + 1}/$maxRetries',
      );
      await Future.delayed(retryDelay);
      retries++;
    }

    appLogger.w(
      'Failed to restore session after $maxRetries retries - auth still not ready',
    );
  }

  Future<void> _restoreActiveSession() async {
    try {
      final auth = ref.read(authControllerProvider);
      if (auth.uid == null) {
        appLogger.d('Auth UID is null, waiting...');
        // Wait a bit more for auth to be ready
        await Future.delayed(const Duration(milliseconds: 1000));
        // Re-read auth state
        final updatedAuth = ref.read(authControllerProvider);
        if (updatedAuth.uid == null) {
          appLogger.w('Auth still not ready, skipping restore');
          return;
        }
      }

      final uid = ref.read(authControllerProvider).uid!;

      appLogger.d('🔐 [Session Restore] Current authenticated UID: $uid');
      appLogger.d('🔐 [Session Restore] Institution: ${auth.institutionCode}');
      appLogger.d('🔐 [Session Restore] Is SuperAdmin: ${auth.isSuperAdmin}');

      appLogger.i('Subscribing to active session for teacher: $uid');

      // Cancel existing subscription if any
      await _sessionSubscription?.cancel();

      // Check for any active sessions by this teacher
      var query = FirebaseFirestore.instance
          .collection('sessions')
          .where('teacherUid', isEqualTo: uid)
          .where('active', isEqualTo: true);

      appLogger.d(
        '📊 [Session Restore] Query filter: teacherUid == $uid, active == true',
      );

      // Add institution filter for non-superadmin users
      if (!auth.isSuperAdmin && auth.institutionCode != null) {
        query = query.where('institutionCode', isEqualTo: auth.institutionCode);
        appLogger.d(
          '📊 [Session Restore] Added institution filter: ${auth.institutionCode}',
        );
      }

      // Listen to real-time updates
      _sessionSubscription = query
          .limit(1)
          .snapshots()
          .listen(
            (snapshot) async {
              appLogger.d(
                '🔍 [Session Restore] Snapshot received: ${snapshot.docs.length} documents',
              );

              if (snapshot.docs.isEmpty) {
                if (state != null) {
                  appLogger.d(
                    '✅ [Session Restore] No sessions found, clearing state',
                  );
                  appLogger.i('Active session ended remotely');
                  state = null;
                } else {
                  appLogger.d(
                    'ℹ️  [Session Restore] No sessions found, state already null',
                  );
                }
                return;
              }

              final doc = snapshot.docs.first;
              final data = doc.data();

              appLogger.d('📋 [Session Restore] Session document found:');
              appLogger.d('   ID: ${doc.id}');
              appLogger.d('   teacherUid: ${data['teacherUid']}');
              appLogger.d('   Expected UID: $uid');
              appLogger.d('   Match: ${data['teacherUid'] == uid}');
              appLogger.d('   Group: ${data['group']}');
              appLogger.d('   Subject: ${data['subject']}');
              appLogger.d('   Institution: ${data['institutionCode']}');

              // Parse session data
              final expiresAtRaw = data['expiresAt'];
              DateTime? expiresAt;
              if (expiresAtRaw is Timestamp) {
                expiresAt = expiresAtRaw.toDate();
              } else if (expiresAtRaw is String) {
                expiresAt = DateTime.tryParse(expiresAtRaw);
              }

              // Only restore if not expired
              if (expiresAt != null && !DateTime.now().isAfter(expiresAt)) {
                // Only log if state is changing from null to something, or ID changes
                if (state?.sessionId != doc.id) {
                  appLogger.i('Active session update: ${doc.id}');
                }

                state = ActiveSession(
                  sessionId: doc.id,
                  expiresAt: expiresAt,
                  latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
                  longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
                  radiusMeters:
                      (data['radiusMeters'] as num?)?.toDouble() ?? 50.0,
                );
              } else {
                // Session expired, mark it inactive if it was active
                if (data['active'] == true) {
                  appLogger.w('Session expired, marking as inactive');
                  await FirebaseFirestore.instance
                      .collection('sessions')
                      .doc(doc.id)
                      .update({'active': false});
                }
                state = null;
              }
            },
            onError: (e) {
              appLogger.e('Error in active session stream', error: e);
            },
          );

      ref.onDispose(() {
        _sessionSubscription?.cancel();
      });
    } catch (e) {
      appLogger.e('Failed to subscribe to active session', error: e);
    }
  }

  Future<void> startSession({
    required double latitude,
    required double longitude,
    required Duration duration,
    required double radiusMeters,
    String? subject,
    String? group,
    String? scheduledSessionId,
    bool bypassLocation = false,
  }) async {
    final auth = ref.read(authControllerProvider);
    if (auth.uid == null || auth.institutionCode == null) {
      throw Exception('Not authenticated or institution code missing');
    }

    // Check if teacher already has an active session
    final existingSession = await FirebaseFirestore.instance
        .collection('sessions')
        .where('teacherUid', isEqualTo: auth.uid)
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (existingSession.docs.isNotEmpty) {
      throw Exception(
        'You already have an active session. Please end it before creating a new one.',
      );
    }

    // Check if another teacher has an active session for the same group
    if (group != null && group.isNotEmpty && group != 'No Group') {
      final conflictingSession = await FirebaseFirestore.instance
          .collection('sessions')
          .where('institutionCode', isEqualTo: auth.institutionCode)
          .where('group', isEqualTo: group)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (conflictingSession.docs.isNotEmpty) {
        final conflictData = conflictingSession.docs.first.data();
        final conflictSubject = conflictData['subject'] ?? 'Unknown Subject';
        final conflictTeacherUid = conflictData['teacherUid'];

        // Fetch teacher name
        String conflictTeacherName = 'Another teacher';
        try {
          final teacherDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(conflictTeacherUid)
              .get();
          if (teacherDoc.exists) {
            conflictTeacherName =
                teacherDoc.data()?['displayName'] ?? 'Another teacher';
          }
        } catch (e) {
          appLogger.w('Failed to fetch conflicting teacher name', error: e);
        }

        throw ConflictingSessionException(
          subjectName: conflictSubject,
          teacherName: conflictTeacherName,
          group: group,
        );
      }
    }

    // Check for conflicting scheduled sessions (within next 30 minutes)
    if (scheduledSessionId == null) {
      final now = DateTime.now();
      final endTime = now.add(duration);

      final scheduledSessions = await FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .where('teacherUid', isEqualTo: auth.uid)
          .get();

      for (final doc in scheduledSessions.docs) {
        final data = doc.data();
        final scheduledForRaw = data['scheduledFor'];
        if (scheduledForRaw is Timestamp) {
          final scheduledFor = scheduledForRaw.toDate();
          final scheduledEnd = scheduledFor.add(
            Duration(minutes: data['duration'] ?? 60),
          );

          // Check if there's an overlap
          if ((scheduledFor.isBefore(endTime) && scheduledEnd.isAfter(now)) ||
              (scheduledFor.isAfter(now) && scheduledFor.isBefore(endTime))) {
            throw Exception(
              'Conflict with scheduled session "${data['subject'] ?? "Session"}" at ${_formatTime(scheduledFor)}. '
              'Please start that session or delete it first.',
            );
          }
        }
      }
    }

    final sessionId = await _repo.createSession(
      teacherUid: auth.uid!,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      duration: duration,
      subject: subject,
      group: group,
      institutionCode: auth.institutionCode!,
      bypassLocation: bypassLocation,
    );

    // Notify other teachers of the same group
    if (group != null && group.isNotEmpty && group != 'No Group') {
      try {
        // Find other teachers who teach this group
        final otherTeachersSnap = await FirebaseFirestore.instance
            .collection('subjects')
            .where('institutionCode', isEqualTo: auth.institutionCode)
            .where('group', isEqualTo: group)
            .get();

        final otherTeacherUids = otherTeachersSnap.docs
            .map((d) => d.data()['teacherUid'] as String?)
            .where((uid) => uid != null && uid != auth.uid)
            .toSet(); // Deduplicate

        if (otherTeacherUids.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          final now = Timestamp.now();

          for (final recipientUid in otherTeacherUids) {
            final docRef = FirebaseFirestore.instance
                .collection('notifications')
                .doc();
            batch.set(docRef, {
              'recipientUid': recipientUid,
              'senderUid': auth.uid,
              'senderName': auth.displayName ?? 'Teacher',
              'senderRollNumber':
                  '', // Teachers don't have roll numbers usually
              'title': 'Session Started: $group',
              'message':
                  '${auth.displayName ?? 'A teacher'} has started a session for $group ($subject).',
              'type': 'session_start',
              'timestamp': now,
              'read': false,
              'metadata': {
                'sessionId': sessionId,
                'group': group,
                'subject': subject,
              },
            });
          }
          await batch.commit();
          appLogger.i(
            'Notified ${otherTeacherUids.length} teachers about session for $group',
          );
        }
      } catch (e) {
        appLogger.e('Failed to send group notifications', error: e);
      }

      // Notify students of the group
      try {
        final groupSnap = await FirebaseFirestore.instance
            .collection('class_groups')
            .where('institutionCode', isEqualTo: auth.institutionCode)
            .where('name', isEqualTo: group)
            .limit(1)
            .get();

        if (groupSnap.docs.isNotEmpty) {
          final groupData = groupSnap.docs.first.data();
          final studentUids = List<String>.from(groupData['studentUids'] ?? []);

          if (studentUids.isNotEmpty) {
            final batch = FirebaseFirestore.instance.batch();
            final now = Timestamp.now();

            // Chunking for batch limit (500)
            // Assuming student count is reasonable, otherwise need multiple batches
            int count = 0;
            for (final recipientUid in studentUids) {
              if (count >= 450) break; // Safety margin for batch limit

              final docRef = FirebaseFirestore.instance
                  .collection('notifications')
                  .doc();
              batch.set(docRef, {
                'recipientUid': recipientUid,
                'senderUid': auth.uid,
                'senderName': auth.displayName ?? 'Teacher',
                'senderRollNumber': '',
                'title': 'Attendance Session Started',
                'message':
                    '${auth.displayName ?? 'A teacher'} has started attendance for $group ($subject).',
                'type': 'session_start',
                'timestamp': now,
                'read': false,
                'metadata': {
                  'sessionId': sessionId,
                  'group': group,
                  'subject': subject,
                },
              });
              count++;
            }
            await batch.commit();
            appLogger.i('Notified $count students about session for $group');
          }
        }
      } catch (e) {
        appLogger.e('Failed to send student notifications', error: e);
      }
    }

    state = ActiveSession(
      sessionId: sessionId,
      expiresAt: DateTime.now().add(duration),
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    if (time.year == now.year &&
        time.month == now.month &&
        time.day == now.day) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
    return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> endSession() async {
    final s = state;
    if (s != null) {
      await _repo.endSession(s.sessionId);
    }
    state = null;
  }

  String? currentDynamicCode() {
    return state?.currentDynamicToken;
  }

  Duration? timeLeft() {
    final s = state;
    if (s == null || s.isExpired) return null;
    return s.expiresAt.difference(DateTime.now());
  }
}

// Provider to fetch all subjects assigned to the current teacher
final teacherSubjectsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);
  final teacherUid = auth.uid;
  final institutionCode = auth.institutionCode;

  if (teacherUid == null || institutionCode == null) {
    return Stream.value([]);
  }

  return FirebaseFirestore.instance
      .collection('subjects')
      .where('institutionCode', isEqualTo: institutionCode)
      .where('teacherUid', isEqualTo: teacherUid)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .where((doc) => doc.data()['isArchived'] != true)
            .map((doc) {
              final data = doc.data();
              return {'id': doc.id, ...data};
            })
            .toList();
      });
});
