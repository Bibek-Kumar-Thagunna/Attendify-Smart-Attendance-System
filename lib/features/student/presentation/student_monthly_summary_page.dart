import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'student_shell.dart';
import '../../attendance/providers.dart';
import '../../auth/providers.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/providers.dart';
import '../../../core/utils/error_handler.dart';

class MonthlySummaryStats {
  final double overallPercentage;
  final int presentCount;
  final int absentCount; // Inferred from total sessions - present (simplified)
  final int lateCount;
  final Map<String, double> subjectAttendance;
  final List<WeeklyStat> weeklyTrend;
  final String monthName;

  MonthlySummaryStats({
    required this.overallPercentage,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.subjectAttendance,
    required this.weeklyTrend,
    required this.monthName,
  });
}

class WeeklyStat {
  final int weekNumber;
  final double percentage;
  WeeklyStat(this.weekNumber, this.percentage);
}

final monthlySummaryStatsProvider = StreamProvider<MonthlySummaryStats>((ref) {
  final uid = ref.watch(authControllerProvider).uid;
  final userJoinedAt = ref.watch(authControllerProvider).createdAt;
  if (uid == null) return const Stream.empty();

  final now = DateTime.now();
  // Use the later of: student's join date or start of this month
  final startDate =
      userJoinedAt != null &&
          userJoinedAt.isAfter(DateTime(now.year, now.month, 1))
      ? userJoinedAt
      : DateTime(now.year, now.month, 1);
  final repo = ref.watch(attendanceRepositoryProvider);

  // 1. Get Student's Enrolled Groups
  final groupsAsync = ref.watch(studentClassGroupsProvider);

  // 2. Stream All Sessions since start date
  final sessionsStream = repo.streamSessionsSince(startDate);

  // 3. Stream Student's Attendance since start date
  final attendanceStream = repo.streamMyAttendanceDocs(uid, since: startDate);

  return Rx.combineLatest3(
    Stream.value(groupsAsync.value ?? []), // Use current value of groups
    sessionsStream,
    attendanceStream,
    (groups, allSessions, myAttendance) {
      // Filter sessions relevant to this student
      // A session is relevant if:
      // a) It has no 'group' (general session) - Assuming all students attend? Or maybe none?
      //    Let's assume general sessions are for everyone or handled separately.
      //    For now, let's include them if we want to be safe, or exclude if they are noise.
      //    Better logic: Match by 'group' field.
      // b) Its 'group' matches one of the student's enrolled groups (normalized).

      final enrolledGroupNames = groups
          .map((g) => g.name.trim().toLowerCase())
          .toSet();

      final relevantSessions = allSessions.where((session) {
        final sessionGroup = (session['group'] as String?)
            ?.trim()
            .toLowerCase();
        // If session has no group, is it for everyone? Let's assume YES for now, or NO?
        // Usually sessions have a group. If null, maybe it's a test or general assembly.
        // Let's include it if it's explicitly null, or maybe we should check subject?
        // For safety in this specific app logic:
        if (sessionGroup == null || sessionGroup.isEmpty) return true;
        return enrolledGroupNames.contains(sessionGroup);
      }).toList();

      // Map Attendance by Session ID for fast lookup
      final attendanceMap = {
        for (var a in myAttendance) a['sessionId'] as String: a,
      };

      int present = 0;
      int late = 0;
      int missed = 0;

      Map<String, int> subjectPresent = {};
      Map<String, int> subjectTotal = {};
      // Change to use date strings instead of week numbers
      Map<String, int> dailyPresent = {};
      Map<String, int> dailyTotal = {};

      for (var session in relevantSessions) {
        final sessionId = session['id'] as String;
        final subject = session['subject'] as String? ?? 'Unknown';
        final timestamp = (session['createdAt'] as Timestamp).toDate();

        // Use date string (YYYY-MM-DD) as key
        final dateKey = DateFormat('yyyy-MM-dd').format(timestamp);

        // Check if attended
        final attendanceRecord = attendanceMap[sessionId];
        final isAttended = attendanceRecord != null;

        if (isAttended) {
          final status = attendanceRecord['status'] as String? ?? 'present';
          if (status == 'present') present++;
          if (status == 'late') {
            present++; // Count late as present for "Attended" stats usually, or separate?
            late++;
          }

          subjectPresent[subject] = (subjectPresent[subject] ?? 0) + 1;
          dailyPresent[dateKey] = (dailyPresent[dateKey] ?? 0) + 1;
        } else {
          missed++;
        }

        subjectTotal[subject] = (subjectTotal[subject] ?? 0) + 1;
        dailyTotal[dateKey] = (dailyTotal[dateKey] ?? 0) + 1;
      }

      // Calculate Subject Percentages
      Map<String, double> subjectPercentages = {};
      subjectTotal.forEach((subj, total) {
        final p = subjectPresent[subj] ?? 0;
        subjectPercentages[subj] = total > 0 ? (p / total) * 100 : 0;
      });

      // Calculate Daily Trend (last 7 days or since join, whichever is shorter)
      List<WeeklyStat> weeklyTrend = [];
      final sortedDates = dailyTotal.keys.toList()..sort();

      // Take up to the last 7 dates that have sessions
      final recentDates = sortedDates.length > 7
          ? sortedDates.sublist(sortedDates.length - 7)
          : sortedDates;

      for (int i = 0; i < recentDates.length; i++) {
        final dateKey = recentDates[i];
        final total = dailyTotal[dateKey]!;
        final p = dailyPresent[dateKey] ?? 0;
        final percentage = total > 0 ? (p / total) * 100.0 : 0.0;
        // Use index as weekNumber for chart positioning
        weeklyTrend.add(WeeklyStat(i + 1, percentage));
      }

      final totalSessions = relevantSessions.length;

      return MonthlySummaryStats(
        overallPercentage: totalSessions > 0
            ? (present / totalSessions) * 100
            : 0,
        presentCount: present,
        absentCount: missed,
        lateCount: late,
        subjectAttendance: subjectPercentages,
        weeklyTrend: weeklyTrend,
        monthName: DateFormat('MMMM yyyy').format(now),
      );
    },
  );
});

class StudentMonthlySummaryPage extends ConsumerWidget {
  const StudentMonthlySummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(monthlySummaryStatsProvider);
    final theme = Theme.of(context);

    return StudentShell(
      child: statsAsync.when(
        data: (stats) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Header
            Text(
              'Monthly Summary',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              stats.monthName,
              style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 24),

            // Key Metrics Row
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Present',
                    value: '${stats.presentCount}',
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MetricCard(
                    label: 'Missed',
                    value: '${stats.absentCount}',
                    icon: Icons.cancel_outlined,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                // Expanded(child: _MetricCard(
                //   label: 'Absent',
                //   value: '${stats.absentCount}',
                //   icon: Icons.cancel_outlined,
                //   color: const Color(0xFFEF4444),
                // )),
              ],
            ),
            const SizedBox(height: 24),

            // Weekly Trend Chart
            GlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Weekly Attendance Trend',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: stats.weeklyTrend.isEmpty
                        ? Center(
                            child: Text(
                              'No data yet',
                              style: GoogleFonts.outfit(color: Colors.white54),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Day ${value.toInt()}',
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 10,
                                          ),
                                        ),
                                      );
                                    },
                                    interval: 1,
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              minX: 1,
                              maxX: stats.weeklyTrend.isEmpty
                                  ? 7
                                  : stats.weeklyTrend.length.toDouble(),
                              minY: 0,
                              maxY: 100,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: stats.weeklyTrend
                                      .map(
                                        (e) => FlSpot(
                                          e.weekNumber.toDouble(),
                                          e.percentage,
                                        ),
                                      )
                                      .toList(),
                                  isCurved: true,
                                  color: theme.colorScheme.primary,
                                  barWidth: 4,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Subject Breakdown
            Text(
              'Subject Breakdown',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...stats.subjectAttendance.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${entry.value.toStringAsFixed(0)}%',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _getColorForPercentage(entry.value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value / 100,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getColorForPercentage(entry.value),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => ErrorHandler.buildErrorWidget(
          e,
          customMessage: 'Unable to load monthly summary',
        ),
      ),
    );
  }

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 85) return const Color(0xFF10B981);
    if (percentage >= 75) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
