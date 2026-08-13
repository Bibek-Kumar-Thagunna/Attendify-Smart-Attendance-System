import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SystemStatus { healthy, degraded, down }

enum ServerLoad { low, medium, high }

final systemHealthProvider = StreamProvider<SystemStatus>((ref) async* {
  // Ping Firestore every 30 seconds
  while (true) {
    final start = DateTime.now();
    try {
      // Simple read operation to check connectivity and latency
      await FirebaseFirestore.instance
          .collection('institutions')
          .limit(1)
          .get();
      final end = DateTime.now();
      final duration = end.difference(start).inMilliseconds;

      if (duration < 2000) {
        yield SystemStatus.healthy;
      } else {
        yield SystemStatus.degraded;
      }
    } catch (e) {
      yield SystemStatus.down;
    }
    await Future.delayed(const Duration(seconds: 30));
  }
});

final serverLoadProvider = StreamProvider<ServerLoad>((ref) {
  // Calculate load based on total active sessions across the system
  return FirebaseFirestore.instance
      .collectionGroup('sessions')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final count = snapshot.docs.length;
        if (count < 10) return ServerLoad.low;
        if (count < 50) return ServerLoad.medium;
        return ServerLoad.high;
      });
});
