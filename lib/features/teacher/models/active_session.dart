import 'package:flutter/foundation.dart';

@immutable
class ActiveSession {
  const ActiveSession({
    required this.sessionId,
    required this.expiresAt,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String sessionId;
  final DateTime expiresAt;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get currentDynamicToken {
    final slot = DateTime.now().millisecondsSinceEpoch ~/ 5000;
    return '$sessionId:$slot';
  }
}
