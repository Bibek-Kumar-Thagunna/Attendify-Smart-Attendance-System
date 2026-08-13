import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../attendance/providers.dart';
import '../../auth/providers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_card.dart';

final attendanceChartSpotsProvider = StreamProvider<List<FlSpot>>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  final auth = ref.watch(authControllerProvider);
  final institutionCode = auth.isSuperAdmin ? null : auth.institutionCode;

  // If not super admin and no institution code, return empty spots
  if (!auth.isSuperAdmin &&
      (institutionCode == null || institutionCode.isEmpty)) {
    return Stream.value([]);
  }

  // Track last 12 hours
  final cutoff = DateTime.now().subtract(const Duration(hours: 12));
  return repo
      .streamAttendanceSince(cutoff, institutionCode: institutionCode)
      .map((rows) {
        // Bucket by hour since cutoff
        final buckets = <int, int>{}; // hourIndex -> count
        for (final data in rows) {
          final ts = data['timestamp'];
          final dt = ts is Timestamp
              ? ts.toDate()
              : DateTime.tryParse(ts?.toString() ?? '');
          if (dt == null) continue;
          final diff = dt.difference(cutoff);
          final hourIdx = diff.inHours.clamp(0, 12);
          buckets[hourIdx] = (buckets[hourIdx] ?? 0) + 1;
        }
        // Generate 0..12 inclusive points
        final spots = <FlSpot>[];
        for (int i = 0; i <= 12; i++) {
          spots.add(FlSpot(i.toDouble(), (buckets[i] ?? 0).toDouble()));
        }
        return spots;
      });
});

class AttendanceChart extends ConsumerWidget {
  const AttendanceChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final asyncSpots = ref.watch(attendanceChartSpotsProvider);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary.withValues(alpha: 0.1),
              scheme.primary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.show_chart_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendance Activity',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Last 12 Hours',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            asyncSpots.when(
              data: (spots) => SizedBox(
                height: 240,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.white.withValues(alpha: 0.1),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 2, // Show every 2 hours
                          getTitlesWidget: (value, meta) {
                            final hourOffset = value.toInt();
                            if (hourOffset > 12) return const SizedBox();
                            final time = DateTime.now().subtract(
                              Duration(hours: 12 - hourOffset),
                            );
                            final hour = time.hour;
                            final ampm = hour >= 12 ? 'PM' : 'AM';
                            final hour12 = hour > 12
                                ? hour - 12
                                : (hour == 0 ? 12 : hour);

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                '$hour12 $ampm',
                                style: GoogleFonts.outfit(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: scheme.primary,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              scheme.primary.withValues(alpha: 0.3),
                              scheme.primary.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                    minX: 0,
                    maxX: 12,
                    minY: 0,
                  ),
                ),
              ),
              loading: () => const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SizedBox(
                height: 240,
                child: Center(
                  child: Text(
                    'Failed to load chart',
                    style: GoogleFonts.outfit(color: Colors.white54),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
