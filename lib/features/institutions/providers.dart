import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/providers.dart';
import 'models.dart';
import 'repository.dart';

// RBAC: Institution admins see only their institution, super admins or users without institutionCode see all
final institutionsStreamProvider = StreamProvider<List<Institution>>((ref) {
  final auth = ref.watch(authControllerProvider);
  final repo = InstitutionsRepository();

  // Show all if: super admin OR no institutionCode set
  final shouldShowAll =
      auth.isSuperAdmin ||
      auth.institutionCode == null ||
      auth.institutionCode!.isEmpty;

  return repo.streamInstitutions(
    institutionCode: shouldShowAll ? null : auth.institutionCode,
  );
});

final institutionsActionsProvider = Provider<InstitutionsActions>((ref) {
  final repo = InstitutionsRepository();
  return InstitutionsActions(repo);
});

class InstitutionsActions {
  InstitutionsActions(this._repo);
  final InstitutionsRepository _repo;

  Future<void> addInstitution(Institution i) => _repo.createInstitution(i);

  Future<void> updateInstitution(String code, Institution updated) =>
      _repo.updateInstitution(
        code,
        name: updated.name,
        status: updated.status,
        students: updated.students,
      );

  Future<void> removeInstitution(String code) => _repo.deleteInstitution(code);
}
