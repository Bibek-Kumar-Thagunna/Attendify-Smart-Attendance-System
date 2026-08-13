import 'package:flutter/foundation.dart';

@immutable
class AttendanceRecord {
  const AttendanceRecord({
    required this.sessionId,
    required this.timestamp,
    required this.subject,
    required this.result,
    this.locationNote,
  });

  final String sessionId;
  final DateTime timestamp;
  final String subject;
  final String result; // Present/Rejected
  final String? locationNote;
}
