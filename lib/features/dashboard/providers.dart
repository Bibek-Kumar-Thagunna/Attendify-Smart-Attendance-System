import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers.dart';

// Provider to get institution name by code
final institutionNameProvider = FutureProvider.family<String, String?>((
  ref,
  institutionCode,
) async {
  if (institutionCode == null || institutionCode.isEmpty) {
    return 'No Institution';
  }

  try {
    final doc = await FirebaseFirestore.instance
        .collection('institutions')
        .doc(institutionCode)
        .get();

    if (doc.exists) {
      return (doc.data()?['name'] as String?) ?? institutionCode;
    }
    return institutionCode;
  } catch (e) {
    return institutionCode;
  }
});

final activeInstitutionsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('institutions')
      .where('status', isEqualTo: 'Active')
      .get();

  return snapshot.docs.map((doc) => {'code': doc.id, ...doc.data()}).toList();
});

final activeSessionsCountProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(authControllerProvider);
  final code = auth.institutionCode;
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance
      .collection('sessions')
      .where('active', isEqualTo: true);
  if (!(auth.isSuperAdmin)) {
    q = q.where('institutionCode', isEqualTo: code);
  }
  return q.snapshots().map((snap) => snap.docs.length);
});

final activeInstitutionsCountProvider = StreamProvider<int>((ref) {
  return FirebaseFirestore.instance
      .collection('institutions')
      .where('status', isEqualTo: 'Active')
      .snapshots()
      .map((snap) => snap.docs.length);
});

final registrationsTodayCountProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(authControllerProvider);
  final start = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  // COMPLETELY AVOID COMPOSITE INDEXES
  // Strategy: Fetch by ONLY institutionCode (or all for super admin), filter createdAt in memory
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin &&
      auth.institutionCode != null &&
      auth.institutionCode!.isNotEmpty) {
    // Institution Admin: Filter by institutionCode ONLY (auto-indexed)
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  }
  // Super Admin: NO FILTERS - fetch all users, filter in memory
  // This avoids needing a createdAt index

  return q.snapshots().map((snap) {
    // ALWAYS filter createdAt in memory (for both super admin and institution admin)
    final count = snap.docs.where((doc) {
      final createdAtRaw = doc.data()['createdAt'];
      DateTime? createdAt;

      // Handle both String (ISO8601) and Timestamp formats
      if (createdAtRaw is String) {
        createdAt = DateTime.tryParse(createdAtRaw);
      } else if (createdAtRaw is Timestamp) {
        createdAt = createdAtRaw.toDate();
      }

      // Debug logging
      // if (createdAt != null) {
      //   print('User ${doc.id} created at: $createdAt (Start today: $start) -> ${!createdAt.isBefore(start)}');
      // }

      return createdAt != null && !createdAt.isBefore(start);
    }).length;

    // print('Total registrations today: $count');
    return count;
  });
});

final pendingTeachersCountProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(authControllerProvider);

  // RBAC + AVOID COMPOSITE INDEX (institutionCode + role + approved)
  // Institution Admin: Query by institutionCode, filter role & approved in memory
  // Super Admin: Query by role only, filter approved in memory
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin && auth.institutionCode != null) {
    // Institution Admin: Scope to their institution
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  } else {
    // Super Admin: See all, but filter by role for efficiency
    q = q.where('role', isEqualTo: 'teacher');
  }

  return q.snapshots().map((snap) {
    return snap.docs.where((doc) {
      return doc.data()['role'] == 'teacher' && doc.data()['approved'] != true;
    }).length;
  });
});

final totalUsersCountProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(authControllerProvider);
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );
  if (!auth.isSuperAdmin) {
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  }
  return q.snapshots().map((snap) => snap.docs.length);
});

final totalTeachersCountProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(authControllerProvider);

  // RBAC: Institution admins see only their teachers, super admins see all
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin && auth.institutionCode != null) {
    // Institution Admin: Scope to their institution
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  } else {
    // Super Admin: See all teachers
    q = q.where('role', isEqualTo: 'teacher');
  }

  return q.snapshots().map((snap) => snap.docs.length);
});

final totalStudentsCountProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(authControllerProvider);

  // RBAC: Institution admins see only their students, super admins see all
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin && auth.institutionCode != null) {
    // Institution Admin: Scope to their institution
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  } else {
    // Super Admin: See all students
    q = q.where('role', isEqualTo: 'student');
  }

  return q.snapshots().map((snap) {
    return snap.docs.where((doc) {
      final data = doc.data();
      // In-memory filter: role='student'
      return data['role'] == 'student';
    }).length;
  });
});

final pendingTeachersListProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);

  // RBAC + AVOID COMPOSITE INDEX (institutionCode + role + approved + createdAt)
  // Institution Admin: Query by institutionCode, filter role & approved & sort in memory
  // Super Admin: Query by role, filter approved & sort in memory
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin && auth.institutionCode != null) {
    // Institution Admin: Scope to their institution
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  } else {
    // Super Admin: See all, but filter by role for efficiency
    q = q.where('role', isEqualTo: 'teacher');
  }

  return q.snapshots().map((snap) {
    // Filter for pending teachers
    var pendingTeachers = snap.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .where((data) => data['role'] == 'teacher' && data['approved'] == false)
        .toList();

    // Sort by createdAt descending
    pendingTeachers.sort((a, b) {
      final aTime = _parseDateTime(a['createdAt']);
      final bTime = _parseDateTime(b['createdAt']);
      return bTime.compareTo(aTime);
    });

    // Limit to 5
    return pendingTeachers.take(5).toList();
  });
});

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime(2000);
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime(2000);
  return DateTime(2000);
}
