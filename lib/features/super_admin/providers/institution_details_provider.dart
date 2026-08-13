import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../institutions/models.dart';

// Fetch single institution details
final institutionDetailsProvider = StreamProvider.family<Institution?, String>((
  ref,
  code,
) {
  return FirebaseFirestore.instance
      .collection('institutions')
      .where('code', isEqualTo: code)
      .limit(1)
      .snapshots()
      .map((snap) {
        if (snap.docs.isEmpty) {
          // Fallback: If not found by code, try to see if the code IS the doc ID (for legacy/manual data)
          // But we can't do a doc().get() inside a stream easily without switching streams.
          // Given the repository creates docs with ID=code, this query should work if the field exists.
          // If the doc ID is code but field is missing, this fails.
          // But we assume 'code' field is always present.
          return null;
        }
        final doc = snap.docs.first;
        final data = doc.data();
        return Institution(
          name: (data['name'] as String?) ?? doc.id,
          code: (data['code'] as String?) ?? doc.id,
          status: (data['status'] as String?) ?? 'Active',
          students: (data['students'] as num?)?.toInt() ?? 0,
          emailDomain: (data['emailDomain'] as String?) ?? '',
        );
      });
});

// Fetch institution specific stats
final institutionStatsProvider = StreamProvider.family<Map<String, int>, String>((
  ref,
  code,
) {
  final firestore = FirebaseFirestore.instance;

  // We can't easily do aggregation queries in stream without cloud functions or many reads.
  // For now, we'll do separate queries for counts.
  // Optimization: In production, these should be aggregated counters on the institution document.

  final students = firestore
      .collection('users')
      .where('institutionCode', isEqualTo: code)
      .where('role', isEqualTo: 'student')
      .count()
      .get()
      .then((s) => s.count ?? 0);
  final teachers = firestore
      .collection('users')
      .where('institutionCode', isEqualTo: code)
      .where('role', isEqualTo: 'teacher')
      .count()
      .get()
      .then((s) => s.count ?? 0);
  final admins = firestore
      .collection('users')
      .where('institutionCode', isEqualTo: code)
      .where('role', isEqualTo: 'admin')
      .count()
      .get()
      .then((s) => s.count ?? 0);
  final classes = firestore
      .collection('class_groups')
      .where('institutionCode', isEqualTo: code)
      .count()
      .get()
      .then((s) => s.count ?? 0);
  final sessions = firestore
      .collection('sessions')
      .where('institutionCode', isEqualTo: code)
      .count()
      .get()
      .then((s) => s.count ?? 0);

  // Handle missing index for active sessions gracefully
  final activeSessions = firestore
      .collection('sessions')
      .where('institutionCode', isEqualTo: code)
      .where('active', isEqualTo: true)
      .count()
      .get()
      .then((s) => s.count ?? 0)
      .catchError((e) => 0);

  return Stream.fromFuture(
    Future.wait([
      students,
      teachers,
      admins,
      classes,
      sessions,
      activeSessions,
    ]).then((results) {
      return {
        'students': results[0],
        'teachers': results[1],
        'admins': results[2],
        'classes': results[3],
        'sessions': results[4],
        'activeSessions': results[5],
      };
    }),
  );
});

// Fetch institution admins
final institutionAdminsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, code) {
      return FirebaseFirestore.instance
          .collection('users')
          .where('institutionCode', isEqualTo: code)
          .where('role', isEqualTo: 'admin')
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
          );
    });
