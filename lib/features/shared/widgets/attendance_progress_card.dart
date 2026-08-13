import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/error_handler.dart';
import '../../auth/providers.dart';
import 'glass_card.dart';
import 'package:rxdart/rxdart.dart';
import '../../student/models/attendance_record.dart';

import '../../student/providers.dart'; // Import studentSubjectsProvider

final attendanceProgressProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final auth = ref.watch(authControllerProvider);
  final code = auth.institutionCode;
  final isSuperAdmin = auth.isSuperAdmin;

  // Get student's subjects
  final subjectsAsync = ref.watch(studentSubjectsProvider);
  // Get student's attendance records
  final attendanceAsync = ref.watch(studentAttendanceStreamProvider);

  return Rx.combineLatest2(
    subjectsAsync.when(
      data: (s) => Stream.value(s),
      loading: () => const Stream<List<Map<String, dynamic>>>.empty(),
      error: (_, __) => Stream.value(<Map<String, dynamic>>[]),
    ),
    attendanceAsync.when(
      data: (a) => Stream.value(a),
      loading: () => const Stream<List<AttendanceRecord>>.empty(),
      error: (_, __) => Stream.value(<AttendanceRecord>[]),
    ),
    (
      List<Map<String, dynamic>> subjects,
      List<AttendanceRecord> attendanceRecords,
    ) {
      if (subjects.isEmpty) {
        return Stream.value({
          'percentage': 0.0,
          'totalSessions': 0,
          'totalPresent': 0,
          'status': 'good',
        });
      }

      // Construct valid composite subject names: "Name (Group)"
      // This matches the format used in GenerateQrPage when creating sessions
      final validSubjectNames = subjects.map((s) {
        final name = s['name'] as String? ?? '';
        final group = s['group'] as String? ?? 'No Group';
        return '$name ($group)';
      }).toSet();

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      Query<Map<String, dynamic>> sessionsQ = FirebaseFirestore.instance
          .collection('sessions');

      // Avoid composite index by only querying on createdAt
      // We will filter by institutionCode in memory
      sessionsQ = sessionsQ
          .where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
          .limit(200);

      return sessionsQ.snapshots().map((sessionsSnap) {
        // Filter sessions that belong to the student's subjects AND institution
        final relevantSessions = sessionsSnap.docs.where((doc) {
          final data = doc.data();

          // Filter by institution if needed
          if (!isSuperAdmin && code != null && code.isNotEmpty) {
            if (data['institutionCode'] != code &&
                data['institutionId'] != code) {
              return false;
            }
          }

          // Filter by Subject Name (Composite)
          final sSubject = data['subject'] as String? ?? '';
          final sGroupField = data['group'] as String?;

          String? sGroup = sGroupField;
          String sName = sSubject;

          if (sSubject.contains('(') && sSubject.endsWith(')')) {
            final parts = sSubject.split('(');
            sName = parts.first.trim();
            sGroup ??= parts.last.replaceAll(')', '').trim();
          }

          // Check if this session matches ANY of the student's enrolled subjects
          for (final subject in subjects) {
            final enrolledName = (subject['name'] as String? ?? '')
                .trim()
                .toLowerCase();
            final enrolledGroup = (subject['group'] as String? ?? '')
                .trim()
                .toLowerCase();

            final sNameLower = sName.trim().toLowerCase();
            final sGroupLower = sGroup?.trim().toLowerCase();

            final groupMatch = sGroupLower == enrolledGroup;
            final nameMatch = sNameLower == enrolledName;

            // Also match if the session has NO group but the name matches (General/Lecture session)
            final isGeneralSession =
                nameMatch && (sGroupLower == null || sGroupLower.isEmpty);

            if ((groupMatch && nameMatch) ||
                validSubjectNames.contains(sSubject) ||
                isGeneralSession) {
              return true;
            }
          }
          return false;
        }).toList();

        final totalSessions = relevantSessions.length;

        if (totalSessions == 0) {
          return {
            'percentage': 0.0,
            'totalSessions': 0,
            'totalPresent': 0,
            'status': 'good',
          };
        }

        // Calculate present count using in-memory attendance records
        int totalPresent = 0;
        for (final session in relevantSessions) {
          final sessionId = session.id;
          final isPresent = attendanceRecords.any(
            (r) => r.sessionId == sessionId && r.result == 'Present',
          );
          if (isPresent) totalPresent++;
        }

        final percentage = totalSessions > 0
            ? ((totalPresent / totalSessions) * 100).clamp(0.0, 100.0)
            : 0.0;

        return {
          'percentage': percentage,
          'totalSessions': totalSessions,
          'totalPresent': totalPresent,
          'status': percentage >= 75
              ? 'good'
              : percentage >= 50
              ? 'warning'
              : 'critical',
        };
      });
    },
  ).switchMap((stream) => stream);
});

class AttendanceProgressCard extends ConsumerWidget {
  const AttendanceProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(attendanceProgressProvider);
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Overview',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          progressAsync.when(
            data: (data) {
              final percentage = data['percentage'] as double;
              final totalSessions = data['totalSessions'] as int;
              final totalPresent = data['totalPresent'] as int;
              final status = data['status'] as String;

              final statusColor = status == 'good'
                  ? const Color(0xFF10B981)
                  : status == 'warning'
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFDC2626);

              return Column(
                children: [
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(150, 150),
                          painter: _CircularProgressPainter(
                            percentage: percentage,
                            color: statusColor,
                            trackColor: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: GoogleFonts.outfit(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                            Text(
                              'Attendance Rate',
                              style: GoogleFonts.outfit(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.check_circle_rounded,
                        label: 'Present',
                        value: '$totalPresent',
                        color: const Color(0xFF10B981),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      _StatItem(
                        icon: Icons.event_note_rounded,
                        label: 'Sessions',
                        value: '$totalSessions',
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: ErrorHandler.buildErrorWidget(
                  e,
                  customMessage: 'Unable to load attendance',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.percentage,
    required this.color,
    required this.trackColor,
  });

  final double percentage;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background circle
    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * (percentage / 100);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
