import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../auth/providers.dart';
import '../attendance/providers.dart';
import 'models/attendance_record.dart';

final attendanceListProvider =
    NotifierProvider<AttendanceListController, List<AttendanceRecord>>(
      AttendanceListController.new,
    );

class AttendanceListController extends Notifier<List<AttendanceRecord>> {
  @override
  List<AttendanceRecord> build() => const [];

  void add(AttendanceRecord record) {
    state = [...state, record];
  }
}

// Live attendance stream for a specific student
final studentAttendanceFamilyProvider = StreamProvider.family<List<AttendanceRecord>, String>((
  ref,
  uid,
) {
  final repo = ref.watch(attendanceRepositoryProvider);
  // Last 90 days by default for history
  final cutoff = DateTime.now().subtract(const Duration(days: 90));
  return repo.streamMyAttendanceDocs(uid, since: cutoff).asyncMap((rows) async {
    // 1. Identify sessions that need subject resolution (missing subject field)
    final sessionIdsToFetch = <String>{};
    for (final data in rows) {
      if (data['subject'] == null && data['sessionId'] != null) {
        sessionIdsToFetch.add(data['sessionId'] as String);
      }
    }

    // 2. Fetch session details
    final sessionSubjects = <String, String>{};
    if (sessionIdsToFetch.isNotEmpty) {
      // Fetch in batches or parallel
      // Since we only need the 'subject' field, we can optimize if needed, but get() is fine.
      // We limit to 10 concurrent fetches to be safe, though Firestore handles more.
      final futures = sessionIdsToFetch.map(
        (sid) =>
            FirebaseFirestore.instance.collection('sessions').doc(sid).get(),
      );

      final snapshots = await Future.wait(futures);
      for (final snap in snapshots) {
        if (snap.exists) {
          final data = snap.data();
          if (data != null && data['subject'] != null) {
            sessionSubjects[snap.id] = data['subject'] as String;
          }
        }
      }
    }

    // 3. Map to AttendanceRecord
    return rows.map((data) {
      final ts = data['timestamp'];
      DateTime date;
      if (ts is Timestamp) {
        date = ts.toDate();
      } else if (ts is DateTime) {
        date = ts;
      } else {
        date = DateTime.tryParse(ts?.toString() ?? '') ?? DateTime.now();
      }

      final status = (data['status'] as String?) ?? 'present';
      final sessionId = (data['sessionId'] as String?) ?? 'unknown';

      // Resolve subject: Use stored subject, or fetched subject, or fallback
      String subject =
          (data['subject'] as String?) ??
          sessionSubjects[sessionId] ??
          'Session';

      return AttendanceRecord(
        sessionId: sessionId,
        timestamp: date,
        subject: subject,
        result: status.toLowerCase() == 'present' ? 'Present' : 'Rejected',
        locationNote: data['distanceMeters'] != null
            ? 'Within ${((data['distanceMeters'] as num).toDouble()).toStringAsFixed(1)} m'
            : null,
      );
    }).toList();
  });
});

// Live attendance stream for the current user
final studentAttendanceStreamProvider = StreamProvider<List<AttendanceRecord>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);
  final uid = auth.uid;
  if (uid == null) return const Stream.empty();
  final records =
      ref.watch(studentAttendanceFamilyProvider(uid)).asData?.value ?? [];
  return Stream.value(records);
});

typedef StudentSubjectParams = ({
  String? lectureGroup,
  String? labGroup,
  List<String>? electives,
});

// Provider for subjects relevant to a specific student configuration
final studentSubjectsFamilyProvider =
    StreamProvider.family<List<Map<String, dynamic>>, StudentSubjectParams>((
      ref,
      params,
    ) {
      final lectureGroup = params.lectureGroup;
      final labGroup = params.labGroup;
      final electives = params.electives ?? [];

      if (lectureGroup == null && labGroup == null && electives.isEmpty) {
        return Stream.value([]);
      }

      final streams = <Stream<List<Map<String, dynamic>>>>[];

      // 1. Fetch Lectures matching lectureGroup (by Name)
      if (lectureGroup != null && lectureGroup.isNotEmpty) {
        streams.add(
          FirebaseFirestore.instance
              .collection('subjects')
              .where('group', isEqualTo: lectureGroup)
              .where('type', isEqualTo: 'Lecture')
              .snapshots()
              .map(
                (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
              ),
        );
        // 1b. Fetch Lectures matching lectureGroup (by ID)
        streams.add(
          FirebaseFirestore.instance
              .collection('subjects')
              .where('groupId', isEqualTo: lectureGroup)
              .where('type', isEqualTo: 'Lecture')
              .snapshots()
              .map(
                (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
              ),
        );
      }

      // 2. Fetch Labs matching labGroup (by Name)
      if (labGroup != null && labGroup.isNotEmpty) {
        streams.add(
          FirebaseFirestore.instance
              .collection('subjects')
              .where('group', isEqualTo: labGroup)
              .where('type', isEqualTo: 'Lab')
              .snapshots()
              .map(
                (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
              ),
        );
        // 2b. Fetch Labs matching labGroup (by ID)
        streams.add(
          FirebaseFirestore.instance
              .collection('subjects')
              .where('groupId', isEqualTo: labGroup)
              .where('type', isEqualTo: 'Lab')
              .snapshots()
              .map(
                (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
              ),
        );
      }

      // 3. Fetch Electives
      if (electives.isNotEmpty) {
        streams.add(
          FirebaseFirestore.instance
              .collection('subjects')
              .where(FieldPath.documentId, whereIn: electives)
              .snapshots()
              .map(
                (s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
              ),
        );
      }

      if (streams.isEmpty) return Stream.value([]);

      // Merge streams
      return Rx.combineLatest(streams, (
        List<List<Map<String, dynamic>>> results,
      ) {
        final allSubjects = <String, Map<String, dynamic>>{};
        for (final list in results) {
          for (final subject in list) {
            allSubjects[subject['id']] = subject;
          }
        }
        return allSubjects.values.toList();
      });
    });

// Provider for subjects relevant to the current student
final studentSubjectsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);

  final params = (
    lectureGroup: auth.lectureGroup,
    labGroup: auth.labGroup,
    electives: auth.electives,
  );

  final subjects =
      ref.watch(studentSubjectsFamilyProvider(params)).asData?.value ?? [];
  return Stream.value(subjects);
});

// Provider for subjects with attendance stats for the current student
// Provider for all sessions in the institution (for calculating total sessions)
final institutionSessionsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);
  final code = auth.institutionCode;
  if (code == null) return Stream.value([]);

  // We fetch sessions created in the last 6 months to keep it performant but cover the semester
  final cutoff = DateTime.now().subtract(const Duration(days: 180));

  return FirebaseFirestore.instance
      .collection('sessions')
      .where('institutionCode', isEqualTo: code)
      // .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff)) // Removed to avoid composite index
      .snapshots()
      .map((s) {
        return s.docs.map((d) => {'id': d.id, ...d.data()}).where((data) {
          // Filter by date in memory
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt == null) return false;
          return createdAt.toDate().isAfter(cutoff);
        }).toList();
      });
});

// Provider for subjects with attendance stats for the current student
final studentSubjectsWithStatsProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final subjects = ref.watch(studentSubjectsProvider).asData?.value ?? [];
  final attendance =
      ref.watch(studentAttendanceStreamProvider).asData?.value ?? [];
  final allSessions =
      ref.watch(institutionSessionsProvider).asData?.value ?? [];

  final result = subjects.map((subject) {
    final subjectName = subject['name'] as String? ?? '';
    final subjectGroup = subject['group'] as String? ?? '';

    // Construct composite name to match what's stored in sessions/attendance
    // Format: "Name (Group)"
    final compositeName = subjectGroup.isNotEmpty
        ? '$subjectName ($subjectGroup)'
        : subjectName;

    // Filter attendance for this subject (Student's records)
    // Note: Attendance records store the subject string as it was when the session was created.
    // We might need to be more flexible here too, but usually attendance records are linked by ID.
    // However, the current AttendanceRecord model uses 'subject' string.
    // Let's improve the matching for attendance records as well if possible,
    // but for now, let's focus on the session matching which drives the "Total" count.

    final subjectAttendance = attendance.where((r) {
      // Robust match for attendance record subject string
      final rSubject = r.subject;
      if (rSubject == compositeName) return true;

      // Parse "Name (Group)" from record
      String rName = rSubject;
      String? rGroup;
      if (rSubject.contains('(') && rSubject.endsWith(')')) {
        final parts = rSubject.split('(');
        rName = parts.first.trim();
        rGroup = parts.last.replaceAll(')', '').trim();
      }

      final targetName = subjectName.trim().toLowerCase();
      final targetGroup = subjectGroup.trim().toLowerCase();

      // Match if names are identical (case-insensitive)
      final nameMatch = rName.trim().toLowerCase() == targetName;

      // If record has a group, it MUST match the target group
      // If record has NO group, it matches if target group is empty OR if it's a general session

      bool groupMatch = false;
      if (targetGroup.isEmpty) {
        // If target has no group (e.g. Elective), record should ideally have no group or match name perfectly
        groupMatch = true;
      } else {
        // Target has group
        if (rGroup != null) {
          groupMatch = rGroup.trim().toLowerCase() == targetGroup;
        } else {
          // Record has no group.
          // If it's a lecture, it might be shared.
          // Allow match if the subject type is Lecture or if we want to be permissive
          final type = subject['type'] as String? ?? 'Lecture';
          if (type == 'Lecture') {
            groupMatch = true;
          } else {
            // For Labs, we might still want to be strict, but let's allow it if it's a general session matching the name
            // Consistency with session filter suggests we should allow it.
            groupMatch = true;
          }
        }
      }

      return nameMatch && groupMatch;
    }).toList();

    // Filter ALL sessions for this subject (Total sessions held)
    final subjectSessions = allSessions.where((s) {
      final sSubject = s['subject'] as String? ?? '';
      final sGroupField = s['group'] as String?;

      String? sGroup = sGroupField;
      String sName = sSubject;

      if (sSubject.contains('(') && sSubject.endsWith(')')) {
        final parts = sSubject.split('(');
        sName = parts.first.trim();
        sGroup ??= parts.last.replaceAll(')', '').trim();
      }

      final targetGroupLower = subjectGroup.trim().toLowerCase();
      final targetNameLower = subjectName.trim().toLowerCase();

      final sGroupLower = sGroup?.trim().toLowerCase();
      final sNameLower = sName.trim().toLowerCase();

      final groupMatch = sGroupLower == targetGroupLower;
      final nameMatch = sNameLower == targetNameLower;

      // Also match if the session has NO group but the name matches (General/Lecture session)
      final isGeneralSession =
          nameMatch && (sGroupLower == null || sGroupLower.isEmpty);

      return (groupMatch && nameMatch) ||
          sSubject == compositeName ||
          isGeneralSession;
    }).toList();

    // Count present sessions
    final attendedCount = subjectAttendance
        .where((r) => r.result == 'Present')
        .length;
    final totalSessions = subjectSessions.length;

    return {
      ...subject,
      'stats': {
        'attended': attendedCount,
        'total': totalSessions,
        'percentage': totalSessions > 0
            ? (attendedCount / totalSessions * 100)
            : 0.0,
      },
    };
  }).toList();

  return Stream.value(result);
});

// Provider for complete attendance history (attended + missed sessions)
final studentCompleteAttendanceHistoryProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authControllerProvider);
      final uid = auth.uid;

      if (uid == null) return Stream.value([]);

      final subjects = ref.watch(studentSubjectsProvider).asData?.value ?? [];
      final attendanceRecords =
          ref.watch(studentAttendanceFamilyProvider(uid)).asData?.value ?? [];
      final allSessions =
          ref.watch(institutionSessionsProvider).asData?.value ?? [];

      if (subjects.isEmpty) return Stream.value([]);

      // Build a set of composite subject names for the student
      final studentSubjectNames = subjects.map((s) {
        final name = s['name'] as String? ?? '';
        final group = s['group'] as String? ?? '';
        return group.isNotEmpty ? '$name ($group)' : name;
      }).toSet();

      // Filter sessions relevant to this student
      final relevantSessions = allSessions.where((session) {
        final sSubject = session['subject'] as String? ?? '';
        final sGroupField = session['group'] as String?;

        String? sGroup = sGroupField;
        String sName = sSubject;

        if (sSubject.contains('(') && sSubject.endsWith(')')) {
          final parts = sSubject.split('(');
          sName = parts.first.trim();
          sGroup ??= parts.last.replaceAll(')', '').trim();
        }

        // Check if this session matches ANY of the student's enrolled subjects
        // We iterate through the enrolled subjects to check for a match
        for (final enrolledSubject in subjects) {
          final enrolledName = (enrolledSubject['name'] as String? ?? '')
              .trim()
              .toLowerCase();
          final enrolledGroup = (enrolledSubject['group'] as String? ?? '')
              .trim()
              .toLowerCase();

          final sNameLower = sName.trim().toLowerCase();
          final sGroupLower = sGroup?.trim().toLowerCase();

          final groupMatch = sGroupLower == enrolledGroup;
          final nameMatch = sNameLower == enrolledName;

          // Also match if the session has NO group but the name matches (General/Lecture session)
          final isGeneralSession =
              nameMatch && (sGroupLower == null || sGroupLower.isEmpty);

          if ((groupMatch && nameMatch) ||
              studentSubjectNames.contains(sSubject) ||
              isGeneralSession) {
            return true;
          }
        }
        return false;
      }).toList();

      // Create a map of attendance by sessionId
      final attendanceMap = <String, AttendanceRecord>{};
      for (final record in attendanceRecords) {
        attendanceMap[record.sessionId] = record;
      }

      // Build complete history
      final history = <Map<String, dynamic>>[];

      for (final session in relevantSessions) {
        final sessionId = session['id'] as String;
        final subject = session['subject'] as String? ?? 'Session';
        final createdAt =
            (session['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        // Extract subject name and group from composite format
        String subjectName = subject;
        String? groupName;
        if (subject.contains('(') && subject.endsWith(')')) {
          final parts = subject.split('(');
          subjectName = parts[0].trim();
          groupName = parts[1].replaceAll(')', '').trim();
        }

        final attendance = attendanceMap[sessionId];

        history.add({
          'sessionId': sessionId,
          'subject': subjectName,
          'group': groupName,
          'timestamp': createdAt,
          'status': attendance != null ? 'Present' : 'Missed',
          'isPresent': attendance != null,
          'locationNote': attendance?.locationNote,
        });
      }

      // Sort by timestamp descending (most recent first)
      history.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      return Stream.value(history);
    });
// Provider for complete attendance history for ANY student (parameterized)
final studentCompleteHistoryFamilyProvider =
    StreamProvider.family<
      List<Map<String, dynamic>>,
      ({
        String uid,
        String? lectureGroup,
        String? labGroup,
        List<String>? electives,
      })
    >((ref, params) {
      final uid = params.uid;
      final subjectParams = (
        lectureGroup: params.lectureGroup,
        labGroup: params.labGroup,
        electives: params.electives,
      );

      final subjects =
          ref
              .watch(studentSubjectsFamilyProvider(subjectParams))
              .asData
              ?.value ??
          [];
      final attendanceRecords =
          ref.watch(studentAttendanceFamilyProvider(uid)).asData?.value ?? [];

      // We need all sessions for the institution.
      // Ideally we should filter by institution code, but here we might not have it easily accessible in params.
      // However, institutionSessionsProvider relies on auth.institutionCode.
      // If the admin is viewing, auth.institutionCode is the admin's institution.
      // This should work fine for admins viewing students in their own institution.
      final allSessions =
          ref.watch(institutionSessionsProvider).asData?.value ?? [];

      if (subjects.isEmpty) return Stream.value([]);

      // Build a set of composite subject names for the student
      final studentSubjectNames = subjects.map((s) {
        final name = s['name'] as String? ?? '';
        final group = s['group'] as String? ?? '';
        return group.isNotEmpty ? '$name ($group)' : name;
      }).toSet();

      // Filter sessions relevant to this student
      final relevantSessions = allSessions.where((session) {
        final sSubject = session['subject'] as String? ?? '';
        final sGroupField = session['group'] as String?;

        String? sGroup = sGroupField;
        String sName = sSubject;

        if (sSubject.contains('(') && sSubject.endsWith(')')) {
          final parts = sSubject.split('(');
          sName = parts.first.trim();
          sGroup ??= parts.last.replaceAll(')', '').trim();
        }

        // Check if this session matches ANY of the student's enrolled subjects
        for (final enrolledSubject in subjects) {
          final enrolledName = (enrolledSubject['name'] as String? ?? '')
              .trim()
              .toLowerCase();
          final enrolledGroup = (enrolledSubject['group'] as String? ?? '')
              .trim()
              .toLowerCase();

          final sNameLower = sName.trim().toLowerCase();
          final sGroupLower = sGroup?.trim().toLowerCase();

          final groupMatch = sGroupLower == enrolledGroup;
          final nameMatch = sNameLower == enrolledName;

          // Also match if the session has NO group but the name matches (General/Lecture session)
          final isGeneralSession =
              nameMatch && (sGroupLower == null || sGroupLower.isEmpty);

          if ((groupMatch && nameMatch) ||
              studentSubjectNames.contains(sSubject) ||
              isGeneralSession) {
            return true;
          }
        }
        return false;
      }).toList();

      // Create a map of attendance by sessionId
      final attendanceMap = <String, AttendanceRecord>{};
      for (final record in attendanceRecords) {
        attendanceMap[record.sessionId] = record;
      }

      // Build complete history
      final history = <Map<String, dynamic>>[];

      for (final session in relevantSessions) {
        final sessionId = session['id'] as String;
        final subject = session['subject'] as String? ?? 'Session';
        final createdAt =
            (session['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        // Extract subject name and group from composite format
        String subjectName = subject;
        String? groupName;
        if (subject.contains('(') && subject.endsWith(')')) {
          final parts = subject.split('(');
          subjectName = parts[0].trim();
          groupName = parts[1].replaceAll(')', '').trim();
        }

        final attendance = attendanceMap[sessionId];

        history.add({
          'sessionId': sessionId,
          'subject': subjectName,
          'group': groupName,
          'timestamp': createdAt,
          'status': attendance != null ? 'Present' : 'Missed',
          'isPresent': attendance != null,
          'locationNote': attendance?.locationNote,
        });
      }

      // Sort by timestamp descending (most recent first)
      history.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      return Stream.value(history);
    });
