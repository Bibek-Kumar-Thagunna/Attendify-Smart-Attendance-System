import 'package:flutter_test/flutter_test.dart';
import 'package:attendify/features/student/models/attendance_record.dart';
import 'package:attendify/features/teacher/models/active_session.dart';
import 'package:attendify/features/institutions/models.dart';

void main() {
  group('Core Domain Models Unit Tests', () {
    test('AttendanceRecord model instantiation and properties', () {
      final now = DateTime.now();
      final record = AttendanceRecord(
        sessionId: 'session_101',
        timestamp: now,
        subject: 'Data Structures',
        result: 'Present',
        locationNote: 'Within 25m',
      );

      expect(record.sessionId, 'session_101');
      expect(record.timestamp, now);
      expect(record.subject, 'Data Structures');
      expect(record.result, 'Present');
      expect(record.locationNote, 'Within 25m');
    });

    test('ActiveSession expiration and dynamic token calculation', () {
      final futureExpiry = DateTime.now().add(const Duration(minutes: 10));
      final session = ActiveSession(
        sessionId: 'session_202',
        expiresAt: futureExpiry,
        latitude: 30.3545,
        longitude: 76.3688,
        radiusMeters: 50.0,
      );

      expect(session.isExpired, isFalse);
      expect(session.currentDynamicToken.startsWith('session_202:'), isTrue);

      final pastExpiry = DateTime.now().subtract(const Duration(minutes: 5));
      final expiredSession = ActiveSession(
        sessionId: 'session_203',
        expiresAt: pastExpiry,
        latitude: 30.3545,
        longitude: 76.3688,
        radiusMeters: 50.0,
      );
      expect(expiredSession.isExpired, isTrue);
    });

    test('Institution model properties and copyWith', () {
      const inst = Institution(
        name: 'Thapar Institute of Engineering & Technology',
        code: 'TIET',
        status: 'Active',
        students: 4500,
        emailDomain: 'thapar.edu',
      );

      expect(inst.name, 'Thapar Institute of Engineering & Technology');
      expect(inst.code, 'TIET');
      expect(inst.status, 'Active');
      expect(inst.students, 4500);
      expect(inst.emailDomain, 'thapar.edu');

      final updated = inst.copyWith(students: 4600);
      expect(updated.students, 4600);
      expect(updated.code, 'TIET');
    });
  });
}
