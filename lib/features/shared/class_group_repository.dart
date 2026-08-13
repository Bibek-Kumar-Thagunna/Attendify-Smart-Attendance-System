import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'models/class_group.dart';

class ClassGroupRepository {
  ClassGroupRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _groupsCollection =>
      _firestore.collection('class_groups');

  /// Create a new class group
  Future<String> createGroup({
    required String name,
    String? description,
    String? institutionCode,
    List<String>? teacherUids,
    List<String>? subjectIds,
    String type = 'Lecture',
  }) async {
    final doc = _groupsCollection.doc();
    final group = ClassGroup(
      id: doc.id,
      name: name,
      description: description,
      teacherUids: teacherUids ?? [],
      studentUids: [],
      subjectIds: subjectIds ?? [],
      institutionCode: institutionCode,
      createdAt: DateTime.now(),
      type: type,
    );
    await doc.set(group.toFirestore());
    return doc.id;
  }

  /// Update an existing class group
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    List<String>? teacherUids,
    List<String>? studentUids,
    List<String>? subjectIds,
    String? type,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updateData['name'] = name;
    if (description != null) updateData['description'] = description;
    if (teacherUids != null) updateData['teacherUids'] = teacherUids;
    if (studentUids != null) updateData['studentUids'] = studentUids;
    if (subjectIds != null) updateData['subjectIds'] = subjectIds;
    if (type != null) updateData['type'] = type;

    await _groupsCollection.doc(groupId).update(updateData);
  }

  /// Delete a class group
  Future<void> deleteGroup(String groupId) async {
    await _groupsCollection.doc(groupId).delete();
  }

  /// Get a single class group by ID
  Future<ClassGroup?> getGroup(String groupId) async {
    final doc = await _groupsCollection.doc(groupId).get();
    if (!doc.exists) return null;
    return ClassGroup.fromFirestore(doc);
  }

  /// Stream all class groups (for admin)
  Stream<List<ClassGroup>> streamAllGroups({String? institutionCode}) {
    Query<Map<String, dynamic>> query = _groupsCollection;

    if (institutionCode != null) {
      query = query.where('institutionCode', isEqualTo: institutionCode);
    }

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ClassGroup.fromFirestore(doc)).toList(),
    );
  }

  /// Stream groups assigned to a specific teacher
  Stream<List<ClassGroup>> streamGroupsByTeacher(String teacherUid) {
    return _groupsCollection
        .where('teacherUids', arrayContains: teacherUid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClassGroup.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream groups where a student is enrolled
  Stream<List<ClassGroup>> streamGroupsByStudent(String studentUid) {
    return _groupsCollection
        .where('studentUids', arrayContains: studentUid)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ClassGroup.fromFirestore(doc))
              .toList(),
        );
  }

  /// Assign a teacher to a class group
  Future<void> assignTeacher({
    required String groupId,
    required String teacherUid,
  }) async {
    await _groupsCollection.doc(groupId).update({
      'teacherUids': FieldValue.arrayUnion([teacherUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a teacher from a class group
  Future<void> removeTeacher({
    required String groupId,
    required String teacherUid,
  }) async {
    await _groupsCollection.doc(groupId).update({
      'teacherUids': FieldValue.arrayRemove([teacherUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Assign a student to a class group (self-enrollment or admin assignment)
  Future<void> assignStudent({
    required String groupId,
    required String studentUid,
  }) async {
    await _groupsCollection.doc(groupId).update({
      'studentUids': FieldValue.arrayUnion([studentUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a student from a class group
  Future<void> removeStudent({
    required String groupId,
    required String studentUid,
  }) async {
    await _groupsCollection.doc(groupId).update({
      'studentUids': FieldValue.arrayRemove([studentUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add a subject to a class group
  Future<void> addSubject({
    required String groupId,
    required String subjectId,
  }) async {
    await _groupsCollection.doc(groupId).update({
      'subjectIds': FieldValue.arrayUnion([subjectId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Remove a subject from a class group
  Future<void> removeSubject({
    required String groupId,
    required String subjectId,
  }) async {
    await _groupsCollection.doc(groupId).update({
      'subjectIds': FieldValue.arrayRemove([subjectId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all groups (for dropdown selection)
  /// If institutionCode is provided, return groups matching either institutionCode or legacy institutionId
  Future<List<ClassGroup>> getAllGroups({String? institutionCode}) async {
    if (institutionCode == null) {
      final all = await _groupsCollection.get();
      return all.docs.map((doc) => ClassGroup.fromFirestore(doc)).toList();
    }

    // Query by institutionCode
    final byCode = await _groupsCollection
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    // Query by legacy institutionId (if any remain)
    final byLegacy = await _groupsCollection
        .where('institutionId', isEqualTo: institutionCode)
        .get();

    // Merge unique results
    final map = <String, ClassGroup>{};
    for (final d in byCode.docs) {
      map[d.id] = ClassGroup.fromFirestore(d);
    }
    for (final d in byLegacy.docs) {
      map[d.id] = ClassGroup.fromFirestore(d);
    }
    return map.values.toList();
  }

  /// Backfill institutionCode for legacy class_groups that are missing it.
  /// Strategy:
  /// - If group.institutionCode already set, skip
  /// - Else if teacherUids not empty: infer from first teacher's user.institutionCode
  /// - Else if studentUids not empty: infer from first student's user.institutionCode
  /// - Else skip
  /// Returns a summary map: {total, updated, skipped, errors}
  Future<Map<String, int>> backfillInstitutionCodes() async {
    final result = {'total': 0, 'updated': 0, 'skipped': 0, 'errors': 0};

    final snap = await _groupsCollection.get();
    result['total'] = snap.size;

    for (final doc in snap.docs) {
      try {
        final data = doc.data();
        final hasCode =
            (data['institutionCode'] is String) &&
            (data['institutionCode'] as String).isNotEmpty;
        if (hasCode) {
          result['skipped'] = (result['skipped'] ?? 0) + 1;
          continue;
        }

        final List<dynamic> teacherUids =
            (data['teacherUids'] as List?) ?? const [];
        final List<dynamic> studentUids =
            (data['studentUids'] as List?) ?? const [];

        String? inferredCode;
        if (teacherUids.isNotEmpty) {
          final uid = teacherUids.first as String;
          final user = await _firestore.collection('users').doc(uid).get();
          inferredCode = (user.data()?['institutionCode'] as String?)?.trim();
        }
        inferredCode ??= await (() async {
          if (studentUids.isEmpty) return null;
          final uid = studentUids.first as String;
          final user = await _firestore.collection('users').doc(uid).get();
          return (user.data()?['institutionCode'] as String?)?.trim();
        })();

        if (inferredCode == null || inferredCode.isEmpty) {
          result['skipped'] = (result['skipped'] ?? 0) + 1;
          continue;
        }

        await _groupsCollection.doc(doc.id).update({
          'institutionCode': inferredCode,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        result['updated'] = (result['updated'] ?? 0) + 1;
      } catch (e) {
        result['errors'] = (result['errors'] ?? 0) + 1;
      }
    }

    return result;
  }

  /// Syncs teacherUids and subjectIds in class_groups based on the subjects collection.
  /// This fixes data integrity issues where class_groups might be out of sync.
  Future<Map<String, int>> syncGroupCounts() async {
    final result = {'updated': 0, 'errors': 0};

    try {
      // 1. Fetch all subjects
      final subjectsSnap = await _firestore.collection('subjects').get();

      // 2. Group by groupId
      final groupMap = <String, Set<String>>{}; // groupId -> subjectIds
      final teacherMap = <String, Set<String>>{}; // groupId -> teacherUids

      for (final doc in subjectsSnap.docs) {
        final data = doc.data();
        final groupId = data['groupId'] as String?;
        final teacherUid = data['teacherUid'] as String?;

        if (groupId != null) {
          if (!groupMap.containsKey(groupId)) groupMap[groupId] = {};
          groupMap[groupId]!.add(doc.id);

          if (teacherUid != null) {
            if (!teacherMap.containsKey(groupId)) teacherMap[groupId] = {};
            teacherMap[groupId]!.add(teacherUid);
          }
        }
      }

      // 3. Update each class group
      final batch = _firestore.batch();
      int operationCount = 0;

      for (final groupId in groupMap.keys) {
        final groupRef = _groupsCollection.doc(groupId);
        batch.update(groupRef, {
          'subjectIds': groupMap[groupId]!.toList(),
          'teacherUids': teacherMap[groupId]?.toList() ?? [],
          'updatedAt': FieldValue.serverTimestamp(),
        });

        operationCount++;
        result['updated'] = (result['updated'] ?? 0) + 1;

        // Commit in chunks of 500
        if (operationCount >= 400) {
          await batch.commit();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      result['errors'] = (result['errors'] ?? 0) + 1;
      debugPrint('Error syncing group counts: $e');
    }

    return result;
  }

  /// Removes a user (student or teacher) from all class groups they are part of.
  /// This is used when a user is deleted to maintain data integrity.
  Future<void> removeUserFromAllGroups(String uid) async {
    final batch = _firestore.batch();
    bool hasUpdates = false;

    // 1. Find groups where user is a teacher
    final teacherGroups = await _groupsCollection
        .where('teacherUids', arrayContains: uid)
        .get();

    for (final doc in teacherGroups.docs) {
      batch.update(doc.reference, {
        'teacherUids': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      hasUpdates = true;
    }

    // 2. Find groups where user is a student
    final studentGroups = await _groupsCollection
        .where('studentUids', arrayContains: uid)
        .get();

    for (final doc in studentGroups.docs) {
      batch.update(doc.reference, {
        'studentUids': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      hasUpdates = true;
    }

    // 3. Find groups where user is an archived teacher
    final archivedTeacherGroups = await _groupsCollection
        .where('archivedTeacherUids', arrayContains: uid)
        .get();

    for (final doc in archivedTeacherGroups.docs) {
      batch.update(doc.reference, {
        'archivedTeacherUids': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      hasUpdates = true;
    }

    // 4. Find groups where user is an archived student
    final archivedStudentGroups = await _groupsCollection
        .where('archivedStudentUids', arrayContains: uid)
        .get();

    for (final doc in archivedStudentGroups.docs) {
      batch.update(doc.reference, {
        'archivedStudentUids': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Scans all class groups and removes any UIDs that do not exist in the users collection
  /// OR have an invalid role (e.g. a 'teacher' in a group who is now an 'admin').
  /// - Ghost users (not in DB) are removed completely.
  /// - Role mismatch users are moved to archived arrays.
  Future<Map<String, int>> cleanupInvalidUsers() async {
    final result = {'updated': 0, 'removed': 0, 'archived': 0, 'errors': 0};

    try {
      // 1. Get all valid users and their roles
      // Note: For large databases, this might need optimization
      final usersSnap = await _firestore.collection('users').get();
      final userRoles = <String, String>{};

      for (final doc in usersSnap.docs) {
        userRoles[doc.id] = (doc.data()['role'] as String?) ?? 'student';
      }

      // 2. Get all class groups
      final groupsSnap = await _groupsCollection.get();

      WriteBatch batch = _firestore.batch();
      int opCount = 0;

      for (final doc in groupsSnap.docs) {
        final data = doc.data();
        final teacherUids = List<String>.from(data['teacherUids'] ?? []);
        final studentUids = List<String>.from(data['studentUids'] ?? []);
        final archivedTeacherUids = List<String>.from(
          data['archivedTeacherUids'] ?? [],
        );
        final archivedStudentUids = List<String>.from(
          data['archivedStudentUids'] ?? [],
        );

        bool changed = false;
        int removedCount = 0;
        int archivedCount = 0;

        // --- Process Teachers ---
        final newTeacherUids = <String>[];
        final teachersToArchive = <String>[];

        for (final uid in teacherUids) {
          if (!userRoles.containsKey(uid)) {
            // Ghost user - remove
            removedCount++;
            changed = true;
          } else if (userRoles[uid] != 'teacher') {
            // Role mismatch - archive
            teachersToArchive.add(uid);
            archivedCount++;
            changed = true;
          } else {
            // Valid
            newTeacherUids.add(uid);
          }
        }

        // --- Process Students ---
        final newStudentUids = <String>[];
        final studentsToArchive = <String>[];

        for (final uid in studentUids) {
          if (!userRoles.containsKey(uid)) {
            // Ghost user - remove
            removedCount++;
            changed = true;
          } else if (userRoles[uid] != 'student') {
            // Role mismatch - archive
            studentsToArchive.add(uid);
            archivedCount++;
            changed = true;
          } else {
            // Valid
            newStudentUids.add(uid);
          }
        }

        // --- Process Archived Lists (Remove Ghosts only) ---
        final newArchivedTeacherUids = archivedTeacherUids
            .where((uid) => userRoles.containsKey(uid))
            .toList();
        // Add newly archived teachers (avoid duplicates)
        for (final uid in teachersToArchive) {
          if (!newArchivedTeacherUids.contains(uid)) {
            newArchivedTeacherUids.add(uid);
          }
        }

        if (newArchivedTeacherUids.length !=
            archivedTeacherUids.length + teachersToArchive.length) {
          // This check is approximate but indicates change if counts don't match expectation
          // Better to just set changed=true if we modified the list
        }
        // Actually, simpler: just check if lists are different
        // But since we are rebuilding the lists, we can just check if changed=true was set above
        // OR if ghost removal happened in archived lists.
        if (archivedTeacherUids.length !=
            newArchivedTeacherUids.length - teachersToArchive.length) {
          // Ghosts were removed from archived list
          removedCount +=
              (archivedTeacherUids.length -
              (newArchivedTeacherUids.length - teachersToArchive.length));
          changed = true;
        }

        final newArchivedStudentUids = archivedStudentUids
            .where((uid) => userRoles.containsKey(uid))
            .toList();
        // Add newly archived students
        for (final uid in studentsToArchive) {
          if (!newArchivedStudentUids.contains(uid)) {
            newArchivedStudentUids.add(uid);
          }
        }

        if (archivedStudentUids.length !=
            newArchivedStudentUids.length - studentsToArchive.length) {
          removedCount +=
              (archivedStudentUids.length -
              (newArchivedStudentUids.length - studentsToArchive.length));
          changed = true;
        }

        if (changed) {
          batch.update(doc.reference, {
            'teacherUids': newTeacherUids,
            'studentUids': newStudentUids,
            'archivedTeacherUids': newArchivedTeacherUids,
            'archivedStudentUids': newArchivedStudentUids,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          opCount++;
          result['updated'] = (result['updated'] ?? 0) + 1;
          result['removed'] = (result['removed'] ?? 0) + removedCount;
          result['archived'] = (result['archived'] ?? 0) + archivedCount;

          if (opCount >= 400) {
            await batch.commit();
            batch = _firestore.batch(); // Create new batch
            opCount = 0;
          }
        }
      }

      if (opCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      result['errors'] = (result['errors'] ?? 0) + 1;
      debugPrint('Error cleaning up users: $e');
    }

    return result;
  }

  /// Transfer a subject to a new teacher.
  /// - Updates the subject's teacherUid.
  /// - Updates the class group's teacherUids list (adds new teacher, removes old if no other subjects).
  /// - Preserves past sessions (they remain linked to the old teacher).
  Future<void> transferSubject({
    required String subjectId,
    required String groupId,
    required String oldTeacherUid,
    required String newTeacherUid,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // 1. Update Subject
    final subjectRef = firestore.collection('subjects').doc(subjectId);
    batch.update(subjectRef, {
      'teacherUid': newTeacherUid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update Class Group
    final groupRef = _groupsCollection.doc(groupId);

    // Add new teacher to group
    batch.update(groupRef, {
      'teacherUids': FieldValue.arrayUnion([newTeacherUid]),
    });

    // Check if old teacher has other subjects in this group
    // We need to query this *before* committing, but we can't do async inside batch.
    // So we do the check now.
    final otherSubjectsSnapshot = await firestore
        .collection('subjects')
        .where('groupId', isEqualTo: groupId)
        .where('teacherUid', isEqualTo: oldTeacherUid)
        .get();

    // The query includes the subject we are transferring because the batch hasn't committed yet.
    // So if count <= 1, it means this is their LAST subject in this group.
    if (otherSubjectsSnapshot.docs.length <= 1) {
      batch.update(groupRef, {
        'teacherUids': FieldValue.arrayRemove([oldTeacherUid]),
      });
    }

    await batch.commit();
  }
}
