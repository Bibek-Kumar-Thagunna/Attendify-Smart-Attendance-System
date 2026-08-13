import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/offline_service.dart';
import 'repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final connectivity = ref.watch(connectivityServiceProvider);
  final offline = ref.watch(offlineServiceProvider);

  final repo = AttendanceRepository(
    connectivity: connectivity,
    offline: offline,
  );

  // Auto-sync when back online
  ref.listen(connectionStatusProvider, (previous, next) {
    if (next.value == ConnectionStatus.online) {
      repo.syncPendingActions();
    }
  });

  return repo;
});
