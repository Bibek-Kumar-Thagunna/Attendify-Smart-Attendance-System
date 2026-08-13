import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectionStatus { online, offline }

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<ConnectionStatus>.broadcast();

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  Stream<ConnectionStatus> get statusStream => _controller.stream;

  Future<ConnectionStatus> checkStatus() async {
    final results = await _connectivity.checkConnectivity();
    return _getStatusFromResults(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final status = _getStatusFromResults(results);
    _controller.add(status);
  }

  ConnectionStatus _getStatusFromResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      return ConnectionStatus.offline;
    }
    return ConnectionStatus.online;
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusStream;
});
