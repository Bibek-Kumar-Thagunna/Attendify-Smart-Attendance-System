import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@immutable
class ClassGroup {
  const ClassGroup({
    required this.id,
    required this.name,
    this.description,
    required this.teacherUids,
    required this.studentUids,
    this.archivedTeacherUids = const [],
    this.archivedStudentUids = const [],
    required this.subjectIds,
    this.institutionCode,
    required this.createdAt,
    this.updatedAt,
    this.type = 'Lecture', // Default to Lecture for backward compatibility
  });

  final String id;
  final String name;
  final String? description;
  final List<String> teacherUids;
  final List<String> studentUids;
  final List<String> archivedTeacherUids;
  final List<String> archivedStudentUids;
  final List<String> subjectIds;
  final String? institutionCode;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String type; // 'Lecture' or 'Lab'

  /// Create ClassGroup from Firestore document
  factory ClassGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassGroup(
      id: doc.id,
      name: data['name'] as String,
      description: data['description'] as String?,
      teacherUids: List<String>.from(data['teacherUids'] ?? []),
      studentUids: List<String>.from(data['studentUids'] ?? []),
      archivedTeacherUids: List<String>.from(data['archivedTeacherUids'] ?? []),
      archivedStudentUids: List<String>.from(data['archivedStudentUids'] ?? []),
      subjectIds: List<String>.from(data['subjectIds'] ?? []),
      institutionCode:
          data['institutionCode'] as String? ??
          data['institutionId'] as String?, // Support both field names
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      type: data['type'] as String? ?? 'Lecture',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'teacherUids': teacherUids,
      'studentUids': studentUids,
      'archivedTeacherUids': archivedTeacherUids,
      'archivedStudentUids': archivedStudentUids,
      'subjectIds': subjectIds,
      'institutionCode': institutionCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'type': type,
    };
  }

  /// Create a copy with modified fields
  ClassGroup copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? teacherUids,
    List<String>? studentUids,
    List<String>? archivedTeacherUids,
    List<String>? archivedStudentUids,
    List<String>? subjectIds,
    String? institutionCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? type,
  }) {
    return ClassGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      teacherUids: teacherUids ?? this.teacherUids,
      studentUids: studentUids ?? this.studentUids,
      archivedTeacherUids: archivedTeacherUids ?? this.archivedTeacherUids,
      archivedStudentUids: archivedStudentUids ?? this.archivedStudentUids,
      subjectIds: subjectIds ?? this.subjectIds,
      institutionCode: institutionCode ?? this.institutionCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClassGroup &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ type.hashCode;
}
