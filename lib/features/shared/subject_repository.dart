import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectRepository {
  final FirebaseFirestore _firestore;

  SubjectRepository(this._firestore);

  /// Adds a subject and updates the corresponding class group
  Future<void> addSubject({
    required String teacherUid,
    required String institutionCode,
    required String name,
    required String code,
    required String groupName,
    required String groupId,
    required String type,
  }) async {
    final batch = _firestore.batch();

    // 1. Create subject document
    final subjectRef = _firestore.collection('subjects').doc();
    batch.set(subjectRef, {
      'teacherUid': teacherUid,
      'institutionCode': institutionCode,
      'name': name,
      'code': code,
      'group': groupName,
      'groupId': groupId,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update class group
    final groupRef = _firestore.collection('class_groups').doc(groupId);
    batch.update(groupRef, {
      'teacherUids': FieldValue.arrayUnion([teacherUid]),
      'subjectIds': FieldValue.arrayUnion([subjectRef.id]),
    });

    await batch.commit();
  }

  /// Updates an existing subject
  Future<void> updateSubject({
    required String subjectId,
    required String name,
    required String code,
    required String? groupName,
    required String? groupId,
    required String type,
    String? oldGroupId, // Required if group changed to clean up old group
    String? teacherUid, // Required if group changed to clean up old group
  }) async {
    final batch = _firestore.batch();
    final subjectRef = _firestore.collection('subjects').doc(subjectId);

    batch.update(subjectRef, {
      'name': name,
      'code': code,
      'group': groupName,
      'groupId': groupId,
      'type': type,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // If group changed, we need to move references
    if (oldGroupId != null &&
        groupId != null &&
        oldGroupId != groupId &&
        teacherUid != null) {
      // Remove from old group
      await _removeSubjectFromGroup(batch, oldGroupId, subjectId, teacherUid);

      // Add to new group
      final newGroupRef = _firestore.collection('class_groups').doc(groupId);
      batch.update(newGroupRef, {
        'teacherUids': FieldValue.arrayUnion([teacherUid]),
        'subjectIds': FieldValue.arrayUnion([subjectId]),
      });
    }

    await batch.commit();
  }

  /// Deletes a subject and updates the corresponding class group
  Future<void> deleteSubject(String subjectId) async {
    final subjectDoc = await _firestore
        .collection('subjects')
        .doc(subjectId)
        .get();
    if (!subjectDoc.exists) return;

    final data = subjectDoc.data()!;
    final groupId = data['groupId'] as String?;
    final teacherUid = data['teacherUid'] as String?;

    final batch = _firestore.batch();
    batch.delete(subjectDoc.reference);

    if (groupId != null && teacherUid != null) {
      await _removeSubjectFromGroup(batch, groupId, subjectId, teacherUid);
    }

    await batch.commit();
  }

  /// Helper to remove subject and potentially teacher from group
  Future<void> _removeSubjectFromGroup(
    WriteBatch batch,
    String groupId,
    String subjectId,
    String teacherUid,
  ) async {
    final groupRef = _firestore.collection('class_groups').doc(groupId);

    // Remove subject ID
    batch.update(groupRef, {
      'subjectIds': FieldValue.arrayRemove([subjectId]),
    });

    // Check if teacher has other subjects in this group
    final otherSubjectsQuery = await _firestore
        .collection('subjects')
        .where('groupId', isEqualTo: groupId)
        .where('teacherUid', isEqualTo: teacherUid)
        .get();

    // If the only subject found is the one we are deleting (or if none found), remove teacher
    // Note: The query might include the subject we are about to delete if we haven't deleted it yet.
    // Since we are in a transaction/batch and haven't committed, the read will still see it.
    // So we check if there are any *other* docs.
    final hasOtherSubjects = otherSubjectsQuery.docs.any(
      (doc) => doc.id != subjectId,
    );

    if (!hasOtherSubjects) {
      batch.update(groupRef, {
        'teacherUids': FieldValue.arrayRemove([teacherUid]),
      });
    }
  }

  /// Deletes a subject from catalog and all its instances
  Future<void> deleteCatalogSubject(
    String catalogId,
    String subjectCode,
  ) async {
    // 1. Find all instances
    final instancesQuery = await _firestore
        .collection('subjects')
        .where('code', isEqualTo: subjectCode)
        .get();

    // 2. Delete instances and update their groups
    // We process them individually to ensure group references are updated correctly
    for (final doc in instancesQuery.docs) {
      await deleteSubject(doc.id);
    }

    // 3. Delete from catalog
    await _firestore.collection('subject_catalog').doc(catalogId).delete();
  }
}
