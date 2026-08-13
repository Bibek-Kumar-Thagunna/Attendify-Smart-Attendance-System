import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'models.dart';

class InstitutionsRepository {
  InstitutionsRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  // RBAC: Filter by institutionCode for institution admins, show all for super admins
  Stream<List<Institution>> streamInstitutions({String? institutionCode}) {
    debugPrint(
      '🔍 streamInstitutions called with institutionCode: $institutionCode',
    );

    if (institutionCode != null && institutionCode.isNotEmpty) {
      // Institution Admin: Return only their institution
      // FIXED: Query by 'code' field, not document ID
      debugPrint('📍 Fetching institution where code = $institutionCode');
      return _firestore
          .collection('institutions')
          .where('code', isEqualTo: institutionCode)
          .snapshots()
          .map((snap) {
            debugPrint(
              '📊 Found ${snap.docs.length} institutions with code: $institutionCode',
            );
            if (snap.docs.isEmpty) {
              debugPrint(
                '⚠️  No institution found with code: $institutionCode',
              );
              return [];
            }
            return snap.docs.map((doc) {
              final data = doc.data();
              debugPrint('✅ Institution: ${data['name']} (${data['code']})');
              return Institution(
                name: (data['name'] as String?) ?? doc.id,
                code: (data['code'] as String?) ?? doc.id,
                status: (data['status'] as String?) ?? 'Active',
                students: (data['students'] as num?)?.toInt() ?? 0,
                emailDomain: (data['emailDomain'] as String?) ?? '',
              );
            }).toList();
          });
    }

    // Super Admin: Return all institutions
    debugPrint('🌍 Fetching ALL institutions');
    return _firestore
        .collection('institutions')
        .orderBy('name')
        .snapshots()
        .map((snap) {
          debugPrint('📊 Found ${snap.docs.length} institutions');
          return snap.docs.map((d) {
            final data = d.data();
            debugPrint('  - ${data['name']} (${data['code']})');
            return Institution(
              name: (data['name'] as String?) ?? d.id,
              code: (data['code'] as String?) ?? d.id,
              status: (data['status'] as String?) ?? 'Active',
              students: (data['students'] as num?)?.toInt() ?? 0,
              emailDomain: (data['emailDomain'] as String?) ?? '',
            );
          }).toList();
        });
  }

  Future<void> createInstitution(Institution i) async {
    await _firestore.collection('institutions').doc(i.code).set({
      'name': i.name,
      'code': i.code,
      'status': i.status,
      'students': i.students,
      'emailDomain': i.emailDomain,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateInstitution(
    String code, {
    String? name,
    String? status,
    int? students,
    String? emailDomain,
  }) async {
    final update = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (name != null) update['name'] = name;
    if (status != null) update['status'] = status;
    if (students != null) update['students'] = students;
    if (emailDomain != null) update['emailDomain'] = emailDomain;
    await _firestore
        .collection('institutions')
        .doc(code)
        .set(update, SetOptions(merge: true));
  }

  Future<void> deleteInstitution(String code) async {
    await _firestore.collection('institutions').doc(code).delete();
  }
}
