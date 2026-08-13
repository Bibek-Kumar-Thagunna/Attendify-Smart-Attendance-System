import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/logger.dart';
import '../../auth/providers.dart';
import 'empty_state.dart';
import 'shimmer_loading.dart';

final recentAttendanceProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);
  final code = auth.institutionCode;

  // If user has no institution code and is not superadmin, return empty
  if (!auth.isSuperAdmin && (code == null || code.isEmpty)) {
    return Stream.value([]);
  }

  try {
    // SESSION-BASED STRATEGY (No Manual Indexes Required)
    // 1. Query 'sessions' collection (uses automatic single-field index on institutionCode)
    // 2. Sort in memory to find recent sessions
    // 3. Fetch attendance subcollections for those sessions

    Query<Map<String, dynamic>> sessionsQuery = FirebaseFirestore.instance
        .collection('sessions');

    if (!auth.isSuperAdmin && code != null && code.isNotEmpty) {
      sessionsQuery = sessionsQuery.where('institutionCode', isEqualTo: code);
    }

    // Filter by teacherUid to only show own sessions
    if (auth.uid != null) {
      sessionsQuery = sessionsQuery.where('teacherUid', isEqualTo: auth.uid);
    }

    // We cannot use orderBy('createdAt') with where('institutionCode') without a composite index.
    // So we fetch all (or limit if possible) and sort in memory.
    // Note: This scales poorly if an institution has thousands of sessions, but is robust for now.

    return sessionsQuery
        .snapshots()
        .asyncMap((sessionsSnap) async {
          final sessions = sessionsSnap.docs
              .map((d) => d.data()..['id'] = d.id)
              .toList();

          // Sort by createdAt descending in memory
          sessions.sort((a, b) {
            final aTs = a['createdAt'] as Timestamp?;
            final bTs = b['createdAt'] as Timestamp?;
            if (aTs == null || bTs == null) return 0;
            return bTs.compareTo(aTs);
          });

          // Take top 10 recent sessions to check for attendance
          final recentSessions = sessions.take(10).toList();

          if (recentSessions.isEmpty) return <Map<String, dynamic>>[];

          // Fetch attendance for these sessions
          final attendanceFutures = recentSessions.map((session) async {
            final sessionId = session['id'] as String;
            final subject =
                session['subject'] as String? ??
                'Unknown Subject'; // Capture subject

            final attSnap = await FirebaseFirestore.instance
                .collection('sessions')
                .doc(sessionId)
                .collection('attendance')
                .get();

            return attSnap.docs
                .map(
                  (d) => {
                    'id': d.id,
                    'sessionId': sessionId,
                    'sessionSubject': subject, // Pass subject down
                    ...d.data(),
                  },
                )
                .toList();
          });

          final attendanceLists = await Future.wait(attendanceFutures);
          final allAttendance = attendanceLists.expand((i) => i).toList();

          // Sort attendance by timestamp descending
          allAttendance.sort((a, b) {
            final aTs = a['timestamp'];
            final bTs = b['timestamp'];
            final aDt = aTs is Timestamp
                ? aTs.toDate()
                : DateTime.tryParse(aTs?.toString() ?? '') ?? DateTime(2000);
            final bDt = bTs is Timestamp
                ? bTs.toDate()
                : DateTime.tryParse(bTs?.toString() ?? '') ?? DateTime(2000);
            return bDt.compareTo(aDt);
          });

          return allAttendance.take(20).toList(); // Increased limit to 20
        })
        .handleError((error) {
          appLogger.i('Error in recentAttendanceProvider: $error');
          return <Map<String, dynamic>>[];
        });
  } catch (e) {
    appLogger.i('Error setting up recentAttendanceProvider: $e');
    return Stream.value([]);
  }
});

class RecentAttendanceCard extends ConsumerWidget {
  const RecentAttendanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(recentAttendanceProvider);
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981),
                            const Color(0xFF34D399),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Recent Attendance',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            attendanceAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return const EmptyState(
                    icon: Icons.how_to_reg_outlined,
                    title: 'No Attendance Records',
                    subtitle:
                        'Records will appear when students mark attendance',
                    color: Color(0xFF10B981),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final displayName = record['displayName'] ?? 'Unknown';
                    final email = record['email'] ?? '';
                    final timestamp = (record['timestamp'] as Timestamp?)
                        ?.toDate();
                    final status = record['status'] ?? 'present';
                    final subject =
                        record['sessionSubject'] ??
                        'Unknown Subject'; // Get subject

                    final initials = displayName.isNotEmpty
                        ? displayName
                              .split(' ')
                              .map((n) => n.isNotEmpty ? n[0] : '')
                              .take(2)
                              .join()
                              .toUpperCase()
                        : '?';

                    final avatarColors = [
                      const Color(0xFF10B981),
                      const Color(0xFF3B82F6),
                      const Color(0xFF8B5CF6),
                      const Color(0xFFF59E0B),
                      const Color(0xFFEC4899),
                    ];
                    final avatarColor =
                        avatarColors[index % avatarColors.length];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: avatarColor.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              initials,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: avatarColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  subject, // Show Subject
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11, // Smaller font for email
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'present'
                                      ? scheme.primary.withValues(alpha: 0.15)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status == 'present' ? 'Present' : 'Absent',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: status == 'present'
                                        ? scheme.primary
                                        : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                              if (timestamp != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat(
                                    'MMM d, h:mm a',
                                  ).format(timestamp), // Date and Time
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFF94A3B8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, __) => const ShimmerListTile(),
              ),
              error: (e, _) {
                final errorMsg = e.toString();
                if (errorMsg.contains('index') ||
                    errorMsg.contains('failed-precondition')) {
                  return const EmptyState(
                    icon: Icons.build_circle_outlined,
                    title: 'Setting Up Database',
                    subtitle:
                        'Please wait 2-3 minutes for indexes to build, then refresh',
                    color: Color(0xFFF59E0B),
                  );
                }
                return const EmptyState(
                  icon: Icons.error_outline,
                  title: 'Unable to Load Attendance',
                  subtitle: 'Please try refreshing the page',
                  color: Colors.red,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
