import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/class_group.dart';
import 'class_group_repository.dart';
import 'subject_repository.dart';
import '../auth/providers.dart';

// Repository provider
final classGroupRepositoryProvider = Provider<ClassGroupRepository>((ref) {
  return ClassGroupRepository();
});

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository(FirebaseFirestore.instance);
});

// Stream all class groups (for admin)
final allClassGroupsProvider = StreamProvider.autoDispose<List<ClassGroup>>((
  ref,
) {
  final repo = ref.watch(classGroupRepositoryProvider);
  return repo.streamAllGroups();
});

// Stream class groups assigned to current teacher
final teacherClassGroupsProvider = StreamProvider.autoDispose<List<ClassGroup>>(
  (ref) {
    final auth = ref.watch(authControllerProvider);
    final teacherUid = auth.uid;

    if (teacherUid == null) {
      return Stream.value([]);
    }

    final repo = ref.watch(classGroupRepositoryProvider);
    return repo.streamGroupsByTeacher(teacherUid);
  },
);

// Stream class groups where current student is enrolled
final studentClassGroupsProvider = StreamProvider.autoDispose<List<ClassGroup>>(
  (ref) {
    final auth = ref.watch(authControllerProvider);
    final studentUid = auth.uid;

    if (studentUid == null) {
      return Stream.value([]);
    }

    final repo = ref.watch(classGroupRepositoryProvider);
    return repo.streamGroupsByStudent(studentUid);
  },
);

// Future provider to get all groups for dropdown selection
final allClassGroupsListProvider = FutureProvider.autoDispose<List<ClassGroup>>((
  ref,
) async {
  final repo = ref.watch(classGroupRepositoryProvider);
  // Prefer institution selected during onboarding, else current user's institution
  final auth = ref.watch(authControllerProvider);
  final code = auth.selectedInstitutionForSignup ?? auth.institutionCode;
  return repo.getAllGroups(institutionCode: code);
});
