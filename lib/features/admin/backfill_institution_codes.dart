import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/logger.dart';

class InstitutionCodeBackfillService {
  final FirebaseFirestore _firestore;

  InstitutionCodeBackfillService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Backfill institutionCode on all sessions that are missing it
  Future<({int updated, int skipped, int errors})> backfillSessions() async {
    int updated = 0;
    int skipped = 0;
    int errors = 0;

    try {
      // Get all sessions
      final snapshot = await _firestore.collection('sessions').get();

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Skip if already has institutionCode
          if (data['institutionCode'] != null &&
              data['institutionCode'] != '') {
            skipped++;
            continue;
          }

          // Get teacherUid
          final teacherUid = data['teacherUid'] as String?;
          if (teacherUid == null) {
            errors++;
            appLogger.i('Session ${doc.id} has no teacherUid');
            continue;
          }

          // Fetch teacher's institutionCode
          final teacherDoc = await _firestore
              .collection('users')
              .doc(teacherUid)
              .get();
          if (!teacherDoc.exists) {
            errors++;
            appLogger.i('Teacher $teacherUid not found for session ${doc.id}');
            continue;
          }

          final teacherData = teacherDoc.data();
          final institutionCode = teacherData?['institutionCode'] as String?;

          if (institutionCode == null || institutionCode.isEmpty) {
            errors++;
            appLogger.i(
              'Teacher $teacherUid has no institutionCode for session ${doc.id}',
            );
            continue;
          }

          // Update session with institutionCode
          await doc.reference.update({'institutionCode': institutionCode});
          updated++;
          appLogger.i(
            '✓ Updated session ${doc.id} with institutionCode: $institutionCode',
          );
        } catch (e) {
          errors++;
          appLogger.i('Error processing session ${doc.id}: $e');
        }
      }
    } catch (e) {
      appLogger.i('Error fetching sessions: $e');
      rethrow;
    }

    return (updated: updated, skipped: skipped, errors: errors);
  }

  /// Backfill institutionCode on all scheduled_sessions that are missing it
  Future<({int updated, int skipped, int errors})>
  backfillScheduledSessions() async {
    int updated = 0;
    int skipped = 0;
    int errors = 0;

    try {
      // Get all scheduled sessions
      final snapshot = await _firestore.collection('scheduled_sessions').get();

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Skip if already has institutionCode
          if (data['institutionCode'] != null &&
              data['institutionCode'] != '') {
            skipped++;
            continue;
          }

          // Get teacherUid
          final teacherUid = data['teacherUid'] as String?;
          if (teacherUid == null) {
            errors++;
            appLogger.i('Scheduled session ${doc.id} has no teacherUid');
            continue;
          }

          // Fetch teacher's institutionCode
          final teacherDoc = await _firestore
              .collection('users')
              .doc(teacherUid)
              .get();
          if (!teacherDoc.exists) {
            errors++;
            appLogger.i(
              'Teacher $teacherUid not found for scheduled session ${doc.id}',
            );
            continue;
          }

          final teacherData = teacherDoc.data();
          final institutionCode = teacherData?['institutionCode'] as String?;

          if (institutionCode == null || institutionCode.isEmpty) {
            errors++;
            appLogger.i(
              'Teacher $teacherUid has no institutionCode for scheduled session ${doc.id}',
            );
            continue;
          }

          // Update scheduled session with institutionCode
          await doc.reference.update({'institutionCode': institutionCode});
          updated++;
          appLogger.i(
            '✓ Updated scheduled session ${doc.id} with institutionCode: $institutionCode',
          );
        } catch (e) {
          errors++;
          appLogger.i('Error processing scheduled session ${doc.id}: $e');
        }
      }
    } catch (e) {
      appLogger.i('Error fetching scheduled sessions: $e');
      rethrow;
    }

    return (updated: updated, skipped: skipped, errors: errors);
  }

  /// Backfill institutionCode on all attendance records that are missing it
  Future<({int updated, int skipped, int errors})> backfillAttendance() async {
    int updated = 0;
    int skipped = 0;
    int errors = 0;

    try {
      // Get all attendance records using collectionGroup
      final snapshot = await _firestore.collectionGroup('attendance').get();

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Skip if already has institutionCode
          if (data['institutionCode'] != null &&
              data['institutionCode'] != '') {
            skipped++;
            continue;
          }

          // Extract sessionId from path: sessions/{sessionId}/attendance/{uid}
          final pathSegments = doc.reference.path.split('/');
          final sessionIdIndex = pathSegments.indexOf('sessions') + 1;

          if (sessionIdIndex <= 0 || sessionIdIndex >= pathSegments.length) {
            errors++;
            appLogger.i(
              'Could not extract sessionId from path: ${doc.reference.path}',
            );
            continue;
          }

          final sessionId = pathSegments[sessionIdIndex];

          // Fetch parent session's institutionCode
          final sessionDoc = await _firestore
              .collection('sessions')
              .doc(sessionId)
              .get();
          if (!sessionDoc.exists) {
            errors++;
            appLogger.i(
              'Session $sessionId not found for attendance ${doc.id}',
            );
            continue;
          }

          final sessionData = sessionDoc.data();
          final institutionCode = sessionData?['institutionCode'] as String?;

          if (institutionCode == null || institutionCode.isEmpty) {
            errors++;
            appLogger.i(
              'Session $sessionId has no institutionCode for attendance ${doc.id}',
            );
            continue;
          }

          // Update attendance with institutionCode
          await doc.reference.update({'institutionCode': institutionCode});
          updated++;
          appLogger.i(
            '✓ Updated attendance ${doc.id} with institutionCode: $institutionCode',
          );
        } catch (e) {
          errors++;
          appLogger.i('Error processing attendance ${doc.id}: $e');
        }
      }
    } catch (e) {
      appLogger.i('Error fetching attendance records: $e');
      rethrow;
    }

    return (updated: updated, skipped: skipped, errors: errors);
  }

  /// Run all backfill operations
  Future<Map<String, dynamic>> backfillAll() async {
    appLogger.i('Starting backfill of institutionCode on all collections...\n');

    appLogger.i('1. Backfilling sessions...');
    final sessionsResult = await backfillSessions();
    appLogger.i(
      'Sessions: ${sessionsResult.updated} updated, ${sessionsResult.skipped} skipped, ${sessionsResult.errors} errors\n',
    );

    appLogger.i('2. Backfilling scheduled_sessions...');
    final scheduledResult = await backfillScheduledSessions();
    appLogger.i(
      'Scheduled Sessions: ${scheduledResult.updated} updated, ${scheduledResult.skipped} skipped, ${scheduledResult.errors} errors\n',
    );

    appLogger.i('3. Backfilling attendance...');
    final attendanceResult = await backfillAttendance();
    appLogger.i(
      'Attendance: ${attendanceResult.updated} updated, ${attendanceResult.skipped} skipped, ${attendanceResult.errors} errors\n',
    );

    final totalUpdated =
        sessionsResult.updated +
        scheduledResult.updated +
        attendanceResult.updated;
    final totalSkipped =
        sessionsResult.skipped +
        scheduledResult.skipped +
        attendanceResult.skipped;
    final totalErrors =
        sessionsResult.errors +
        scheduledResult.errors +
        attendanceResult.errors;

    appLogger.i('✅ Backfill complete!');
    appLogger.i(
      'Total: $totalUpdated updated, $totalSkipped skipped, $totalErrors errors',
    );

    return {
      'sessions': {
        'updated': sessionsResult.updated,
        'skipped': sessionsResult.skipped,
        'errors': sessionsResult.errors,
      },
      'scheduled_sessions': {
        'updated': scheduledResult.updated,
        'skipped': scheduledResult.skipped,
        'errors': scheduledResult.errors,
      },
      'attendance': {
        'updated': attendanceResult.updated,
        'skipped': attendanceResult.skipped,
        'errors': attendanceResult.errors,
      },
      'totals': {
        'updated': totalUpdated,
        'skipped': totalSkipped,
        'errors': totalErrors,
      },
    };
  }
}
