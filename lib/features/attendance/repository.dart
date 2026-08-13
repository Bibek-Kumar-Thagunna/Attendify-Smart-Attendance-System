import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_service.dart';

class AttendanceRepository {
  AttendanceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    this.connectivity,
    this.offline,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ConnectivityService? connectivity;
  final OfflineService? offline;

  Future<String> createSession({
    required String teacherUid,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required Duration duration,
    String? subject,
    required String institutionCode,
    String? group,
    bool bypassLocation = false,
  }) async {
    // Check connectivity
    if (connectivity != null && offline != null) {
      final status = await connectivity!.checkStatus();
      if (status == ConnectionStatus.offline) {
        final id = const Uuid().v4();
        final now = DateTime.now();
        final expiresAt = now.add(duration);

        final data = {
          'teacherUid': teacherUid,
          'createdAt': now.toIso8601String(), // Store as string for JSON
          'expiresAt': expiresAt.toIso8601String(),
          'latitude': latitude,
          'longitude': longitude,
          'radiusMeters': radiusMeters,
          'active': true,
          'subject': subject ?? 'Attendance Session',
          'institutionCode': institutionCode,
          'bypassLocation': bypassLocation,
          'attendeeUids': [],
          if (group != null) 'group': group,
        };

        await offline!.queueAction(
          OfflineAction(
            id: id,
            type: 'create_session',
            data: data,
            timestamp: now,
          ),
        );

        return id;
      }
    }

    final doc = _firestore.collection('sessions').doc();
    final now = FieldValue.serverTimestamp();
    final expiresAt = DateTime.now().add(duration);
    await doc.set({
      'teacherUid': teacherUid,
      'createdAt': now,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'active': true,
      'subject': subject ?? 'Attendance Session',
      'institutionCode': institutionCode,
      'bypassLocation': bypassLocation,
      'attendeeUids': [], // Initialize empty array for performance optimization
      if (group != null) 'group': group,
    });
    return doc.id;
  }

  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    final doc = await _firestore.collection('sessions').doc(sessionId).get();
    return doc.data();
  }

  Future<void> endSession(String sessionId) async {
    // Check connectivity
    if (connectivity != null && offline != null) {
      final status = await connectivity!.checkStatus();
      if (status == ConnectionStatus.offline) {
        await offline!.queueAction(
          OfflineAction(
            id: sessionId,
            type: 'end_session',
            data: {'sessionId': sessionId},
            timestamp: DateTime.now(),
          ),
        );
        return;
      }
    }

    await _firestore.collection('sessions').doc(sessionId).set({
      'active': false,
      'endedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markAttendancePresent({
    required String sessionId,
    required String idNumber,
    required String rollNumber,
    required double distanceMeters,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }

    // Check connectivity
    if (connectivity != null && offline != null) {
      final status = await connectivity!.checkStatus();
      if (status == ConnectionStatus.offline) {
        await offline!.queueAction(
          OfflineAction(
            id: '${sessionId}_${user.uid}',
            type: 'mark_attendance',
            data: {
              'sessionId': sessionId,
              'uid': user.uid,
              'email': user.email,
              'displayName': user.displayName,
              'idNumber': idNumber,
              'rollNumber': rollNumber,
              'distanceMeters': distanceMeters,
            },
            timestamp: DateTime.now(),
          ),
        );
        return;
      }
    }

    // Optionally include institutionCode for direct filtering (read from parent session)
    String? institutionCode;
    String? subject;
    try {
      final sessionDoc = await _firestore
          .collection('sessions')
          .doc(sessionId)
          .get();
      final data = sessionDoc.data();
      institutionCode = data?['institutionCode'] as String?;
      subject = data?['subject'] as String?;
    } catch (_) {}
    final doc = _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('attendance')
        .doc(user.uid);
    await doc.set({
      'uid': user.uid,
      'sessionId': sessionId, // Critical for history linking
      'email': user.email,
      'displayName': user.displayName,
      'idNumber': idNumber,
      'rollNumber': rollNumber,
      'status': 'present',
      'distanceMeters': distanceMeters,
      'timestamp': FieldValue.serverTimestamp(),
      if (institutionCode != null) 'institutionCode': institutionCode,
      if (subject != null) 'subject': subject,
    }, SetOptions(merge: true));

    // Optimize: Update parent session's attendeeUids array
    // This allows for O(1) attendance counting without reading subcollections
    try {
      await _firestore.collection('sessions').doc(sessionId).update({
        'attendeeUids': FieldValue.arrayUnion([user.uid]),
      });
    } catch (e) {
      // Fail silently if session doc update fails (e.g. permission issue),
      // as the subcollection write is the source of truth.
      debugPrint('Failed to update session attendeeUids: $e');
    }
  }

  Future<void> updateAttendanceStatus({
    required String sessionId,
    required String studentUid,
    required String status,
    String? idNumber,
    String? rollNumber,
    String? displayName,
    String? email,
  }) async {
    // 1. Update the specific attendance record
    final docRef = _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('attendance')
        .doc(studentUid);

    final data = {
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
      'uid': studentUid,
      'sessionId': sessionId,
    };

    if (idNumber != null) data['idNumber'] = idNumber;
    if (rollNumber != null) data['rollNumber'] = rollNumber;
    if (displayName != null) data['displayName'] = displayName;
    if (email != null) data['email'] = email;

    await docRef.set(data, SetOptions(merge: true));

    // 2. Update the parent session's attendeeUids array
    // If status is 'present' or 'late', add to array. If 'absent', remove.
    final sessionRef = _firestore.collection('sessions').doc(sessionId);

    if (status == 'present' || status == 'late') {
      await sessionRef.update({
        'attendeeUids': FieldValue.arrayUnion([studentUid]),
      });
    } else {
      await sessionRef.update({
        'attendeeUids': FieldValue.arrayRemove([studentUid]),
      });
    }
  }

  Future<void> markBulkAttendance({
    required String sessionId,
    required List<Map<String, dynamic>> students,
    required String institutionCode,
    String? subject,
    String? group,
  }) async {
    final batch = _firestore.batch();
    final sessionRef = _firestore.collection('sessions').doc(sessionId);
    final attendanceCol = sessionRef.collection('attendance');
    final attendeeUids = <String>[];

    for (final student in students) {
      final uid = student['uid'] as String;
      final status = student['status'] as String;

      if (status == 'present' || status == 'late') {
        attendeeUids.add(uid);
      }

      final docRef = attendanceCol.doc(uid);
      batch.set(docRef, {
        ...student,
        'sessionId': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'institutionCode': institutionCode,
        if (subject != null) 'subject': subject,
      }, SetOptions(merge: true));
    }

    batch.update(sessionRef, {'attendeeUids': attendeeUids});

    await batch.commit();
  }

  Future<void> updateSessionDetails({
    required String sessionId,
    String? topic,
    String? notes,
  }) async {
    final data = <String, dynamic>{};
    if (topic != null) {
      data['subject'] =
          topic; // 'subject' is used as topic in UI often, but let's stick to schema
    }
    if (notes != null) data['notes'] = notes;

    if (data.isNotEmpty) {
      await _firestore.collection('sessions').doc(sessionId).update(data);
    }
  }

  // Streams all attendance documents for the current user (collectionGroup)
  Stream<List<Map<String, dynamic>>> streamMyAttendanceDocs(
    String uid, {
    DateTime? since,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collectionGroup('attendance')
        .where('uid', isEqualTo: uid);
    if (since != null) {
      q = q.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(since),
      );
    }
    return q
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            // If sessionId is missing in data (old records), extract from path
            if (data['sessionId'] == null) {
              data['sessionId'] = d.reference.parent.parent?.id;
            }
            return data;
          }).toList(),
        );
  }

  // Streams all attendance documents since a cutoff (for charts/analytics)
  // Streams all attendance documents since a cutoff (for charts/analytics)
  Stream<List<Map<String, dynamic>>> streamAttendanceSince(
    DateTime cutoff, {
    String? institutionCode,
  }) {
    // SESSION-BASED STRATEGY (No Manual Indexes Required)
    // 1. Query 'sessions' collection
    // 2. Filter by institutionCode (if provided) using auto-index
    // 3. Filter by date in memory (to avoid composite index)
    // 4. Fetch attendance subcollections

    Query<Map<String, dynamic>> sessionsQuery = _firestore.collection(
      'sessions',
    );

    if (institutionCode != null && institutionCode.isNotEmpty) {
      sessionsQuery = sessionsQuery.where(
        'institutionCode',
        isEqualTo: institutionCode,
      );
    } else {
      // If no institution code (Super Admin global view), we can use createdAt filter
      sessionsQuery = sessionsQuery.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff),
      );
    }

    return sessionsQuery.snapshots().asyncMap((sessionsSnap) async {
      // Filter sessions by date in memory if we used institutionCode filter
      // (If we didn't use institutionCode, the query already filtered by date)
      var relevantSessions = sessionsSnap.docs;

      if (institutionCode != null && institutionCode.isNotEmpty) {
        relevantSessions = relevantSessions.where((doc) {
          final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate();
          return createdAt != null && createdAt.isAfter(cutoff);
        }).toList();
      }

      if (relevantSessions.isEmpty) return <Map<String, dynamic>>[];

      // Fetch attendance for these sessions
      // Note: This might be heavy if there are many sessions in the period.
      // But it's the only way without collectionGroup indexes.

      final attendanceFutures = relevantSessions.map(
        (sessionDoc) => sessionDoc.reference.collection('attendance').get(),
      );

      final attendanceSnaps = await Future.wait(attendanceFutures);

      return attendanceSnaps
          .expand((snap) => snap.docs.map((d) => d.data()))
          .toList();
    });
  }

  // Streams sessions since a cutoff (for student summary to calculate missed sessions)
  Stream<List<Map<String, dynamic>>> streamSessionsSince(DateTime cutoff) {
    return _firestore
        .collection('sessions')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList(),
        );
  }

  Future<void> syncPendingActions() async {
    if (offline == null) return;

    final queue = offline!.getQueue();
    if (queue.isEmpty) return;

    for (final action in queue) {
      try {
        if (action.type == 'create_session') {
          await _firestore.collection('sessions').doc(action.id).set({
            ...action.data,
            'createdAt': Timestamp.fromDate(action.timestamp),
            'expiresAt': Timestamp.fromDate(
              DateTime.parse(action.data['expiresAt']),
            ),
          });
        } else if (action.type == 'end_session') {
          await _firestore.collection('sessions').doc(action.id).set({
            'active': false,
            'endedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } else if (action.type == 'mark_attendance') {
          final data = action.data;
          final sessionId = data['sessionId'];
          final uid = data['uid'];

          await _firestore
              .collection('sessions')
              .doc(sessionId)
              .collection('attendance')
              .doc(uid)
              .set({
                ...data,
                'timestamp': Timestamp.fromDate(action.timestamp),
                'status': 'present',
              }, SetOptions(merge: true));
        }

        await offline!.removeAction(action.id);
      } catch (e) {
        debugPrint('Error syncing action ${action.id}: $e');
      }
    }
  }
}
