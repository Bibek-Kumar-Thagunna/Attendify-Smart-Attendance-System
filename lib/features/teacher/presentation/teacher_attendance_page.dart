import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'teacher_shell.dart';
import '../../auth/providers.dart';
import '../../../core/pdf_generator.dart';
import '../../shared/services/file_download_helper.dart';
import '../../attendance/providers.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_text_field.dart';

// Provider for teacher's session attendance records
final teacherSessionsWithAttendanceProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authControllerProvider);
      final teacherUid = auth.uid;
      final institutionCode = auth.institutionCode;

      if (teacherUid == null || institutionCode == null) {
        return const Stream.empty();
      }

      // Get sessions created by this teacher
      return FirebaseFirestore.instance
          .collection('sessions')
          .where('teacherUid', isEqualTo: teacherUid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .asyncMap((sessionsSnapshot) async {
            final sessions = <Map<String, dynamic>>[];

            // 1. Fetch All Students in Institution (to identify absentees)
            final studentsSnap = await FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'student')
                .where('institutionCode', isEqualTo: institutionCode)
                .get();
            final allStudents = studentsSnap.docs
                .map((d) => {'id': d.id, ...d.data()})
                .toList();

            // 2. Fetch Class Groups (to resolve IDs to Names for matching)
            final groupsSnap = await FirebaseFirestore.instance
                .collection('class_groups')
                .where('institutionCode', isEqualTo: institutionCode)
                .get();
            final groupIdToName = {
              for (var doc in groupsSnap.docs)
                doc.id: doc.data()['name'] as String,
            };

            // 3. Process Sessions
            for (final sessionDoc in sessionsSnapshot.docs) {
              final sessionData = sessionDoc.data();
              final sessionId = sessionDoc.id;
              final subjectStr = sessionData['subject'] as String? ?? 'Session';

              // Extract Group Name
              String? targetGroup = sessionData['group'] as String?;

              // Fallback: Extract from Subject String "Name (Group)"
              if (targetGroup == null &&
                  subjectStr.contains('(') &&
                  subjectStr.endsWith(')')) {
                targetGroup = subjectStr
                    .split('(')
                    .last
                    .replaceAll(')', '')
                    .trim();
              }

              // Normalize for comparison
              if (targetGroup != null) {
                targetGroup = targetGroup.trim().toLowerCase();
              }

              // Fetch actual attendance records
              final attendanceSnapshot = await FirebaseFirestore.instance
                  .collection('sessions')
                  .doc(sessionId)
                  .collection('attendance')
                  .get();

              final attendanceMap = {
                for (var d in attendanceSnapshot.docs)
                  d.data()['uid'] as String: d.data(),
              };

              // Filter students belonging to this session's group
              final sessionStudents = allStudents.where((s) {
                if (targetGroup == null) {
                  return false; // Can't match if no group in subject name
                }

                final lId = s['lectureGroup'] as String?;
                final labId = s['labGroup'] as String?;
                final gVal = s['group'] as String?; // Legacy field

                final lectureGroupName = (groupIdToName[lId] ?? lId)
                    ?.trim()
                    .toLowerCase();
                final labGroupName = (groupIdToName[labId] ?? labId)
                    ?.trim()
                    .toLowerCase();
                final fallbackGroup = gVal?.trim().toLowerCase();

                return lectureGroupName == targetGroup ||
                    labGroupName == targetGroup ||
                    fallbackGroup == targetGroup;
              }).toList();

              // Merge Students with Attendance
              final mergedRecords = sessionStudents.map((student) {
                final uid = student['id'] as String;
                final attendanceRecord = attendanceMap[uid];

                // Resolve display fields
                final displayName =
                    (student['displayName'] as String?)?.isNotEmpty == true
                    ? student['displayName']
                    : (attendanceRecord?['displayName'] ?? 'Unknown');

                String? rollNum = student['rollNumber'] as String?;
                if (rollNum == null || rollNum.isEmpty) {
                  rollNum = attendanceRecord?['rollNumber'] as String?;
                }
                if (rollNum == null || rollNum.isEmpty) {
                  rollNum =
                      student['idNumber']
                          as String?; // Fallback to ID from profile
                }
                if (rollNum == null || rollNum.isEmpty) {
                  rollNum =
                      attendanceRecord?['idNumber']
                          as String?; // Fallback to ID from record
                }
                final rollNumber = rollNum ?? 'N/A';

                final status = attendanceRecord != null
                    ? (attendanceRecord['status'] as String? ?? 'present')
                    : 'absent';
                final timestamp =
                    attendanceRecord?['timestamp']; // Null if absent

                return {
                  'uid': uid,
                  'studentName': displayName,
                  'rollNumber': rollNumber,
                  'status': status,
                  'timestamp': timestamp,
                  'email': student['email'] ?? '',
                };
              }).toList();

              // Sort: Absent first, then by Name
              mergedRecords.sort((a, b) {
                final statusCompare = (a['status'] as String).compareTo(
                  b['status'] as String,
                ); // absent < present? No, 'absent' comes before 'present' alphabetically.
                if (statusCompare != 0) return statusCompare;
                return (a['studentName'] as String).compareTo(
                  b['studentName'] as String,
                );
              });

              final totalPresentCount = attendanceMap.values.where((d) {
                final s = d['status'] as String? ?? 'present';
                return s == 'present' || s == 'late';
              }).length;

              sessions.add({
                'id': sessionId,
                'subject': subjectStr,
                'createdAt': sessionData['createdAt'],
                'records': mergedRecords
                    .map((r) => {...r, 'sessionId': sessionId})
                    .toList(), // Pass sessionId to each record
                'totalPresent': totalPresentCount,
                'totalStudents': sessionStudents.length,
              });
            }

            return sessions;
          });
    });

class TeacherAttendancePage extends ConsumerWidget {
  const TeacherAttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSessions = ref.watch(teacherSessionsWithAttendanceProvider);

    return TeacherShell(
      child: BackgroundPattern(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Records',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'View attendance by session',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: asyncSessions.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return Center(
                      child: GlassCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fact_check_outlined,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Sessions Found',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start a session to begin tracking attendance',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: sessions.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _SessionAttendanceCard(session: session);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                error: (e, _) => Center(
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading attendance',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.toString(),
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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

class _SessionAttendanceCard extends StatefulWidget {
  final Map<String, dynamic> session;
  const _SessionAttendanceCard({required this.session});

  @override
  State<_SessionAttendanceCard> createState() => _SessionAttendanceCardState();
}

class _SessionAttendanceCardState extends State<_SessionAttendanceCard> {
  bool _isExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportPdf() async {
    final session = widget.session;
    final subject = session['subject'] as String;
    // Extract group from session data or subject
    String group = session['group'] as String? ?? '';
    if (group.isEmpty && subject.contains('(') && subject.endsWith(')')) {
      group = subject.split('(').last.replaceAll(')', '').trim();
    }

    final timestamp =
        (session['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final records = List<Map<String, dynamic>>.from(session['records'] as List);

    final pdfBytes = await PdfGenerator.generateAttendancePdf(
      subjectName: subject.split('(').first.trim(),
      groupName: group,
      date: timestamp,
      records: records,
    );

    await downloadFile(
      filename:
          'attendance_${subject}_${DateFormat('yyyyMMdd').format(timestamp)}.pdf',
      bytes: pdfBytes,
      mimeType: 'application/pdf',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance PDF downloaded successfully'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final subject = session['subject'] as String;
    final timestamp = (session['createdAt'] as Timestamp?)?.toDate();
    final dateStr = timestamp != null
        ? DateFormat('MMM dd, yyyy • HH:mm').format(timestamp)
        : 'N/A';
    final totalStudents = session['totalStudents'] as int;
    final totalPresent = session['totalPresent'] as int;

    final allRecords = session['records'] as List;
    final filteredRecords = allRecords.where((r) {
      final name = (r['studentName'] as String).toLowerCase();
      final roll = (r['rollNumber'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || roll.contains(query);
    }).toList();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(24),
              bottom: Radius.circular(_isExpanded ? 0 : 24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.class_, color: Color(0xFF8B5CF6)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$totalPresent / $totalStudents',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Present',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.white70,
                    ),
                    onPressed: _exportPdf,
                    tooltip: 'Export PDF',
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GlassTextField(
                controller: _searchController,
                label: 'Search',
                hintText: 'Search students...',
                prefixIcon: Icons.search,
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            if (filteredRecords.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  allRecords.isEmpty
                      ? 'No attendance records for this session.'
                      : 'No students match your search.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white70),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: filteredRecords.length,
                separatorBuilder: (c, i) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final record = filteredRecords[index] as Map<String, dynamic>;
                  return _StudentAttendanceRow(record: record);
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _StudentAttendanceRow extends ConsumerWidget {
  final Map<String, dynamic> record;
  const _StudentAttendanceRow({required this.record});

  Future<void> _updateStatus(
    BuildContext context,
    WidgetRef ref,
    String newStatus,
  ) async {
    try {
      final sessionId =
          record['sessionId']
              as String?; // Ensure sessionId is passed in record
      final uid = record['uid'] as String;

      if (sessionId == null) return;

      await ref
          .read(attendanceRepositoryProvider)
          .updateAttendanceStatus(
            sessionId: sessionId,
            studentUid: uid,
            status: newStatus,
            idNumber: record['idNumber'] as String?, // Pass these if available
            rollNumber: record['rollNumber'] as String?,
            displayName: record['studentName'] as String?,
            email: record['email'] as String?,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked as ${newStatus.toUpperCase()}',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = record['studentName'] as String;
    final rollNumber = record['rollNumber'] as String;
    final status = record['status'] as String;
    final isPresent = status == 'present';
    final isLate = status == 'late';
    final timestamp = (record['timestamp'] as Timestamp?)?.toDate();
    final timeStr = timestamp != null
        ? DateFormat('HH:mm:ss').format(timestamp)
        : '--:--';

    Color statusColor;
    String statusText;
    if (isPresent) {
      statusColor = const Color(0xFF10B981);
      statusText = 'Present';
    } else if (isLate) {
      statusColor = const Color(0xFFF59E0B);
      statusText = 'Late';
    } else {
      statusColor = const Color(0xFFEF4444);
      statusText = 'Absent';
    }

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: statusColor.withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  rollNumber,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: const Color(0xFF1E293B),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    builder: (context) => Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40,
                                  height: 4,
                                  margin: const EdgeInsets.only(bottom: 24),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Text(
                                  'Update Attendance',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildStatusOption(
                                  context,
                                  'Present',
                                  const Color(0xFF10B981),
                                  Icons.check_circle,
                                  () => _updateStatus(context, ref, 'present'),
                                ),
                                const SizedBox(height: 12),
                                _buildStatusOption(
                                  context,
                                  'Late',
                                  const Color(0xFFF59E0B),
                                  Icons.access_time,
                                  () => _updateStatus(context, ref, 'late'),
                                ),
                                const SizedBox(height: 12),
                                _buildStatusOption(
                                  context,
                                  'Absent',
                                  const Color(0xFFEF4444),
                                  Icons.cancel,
                                  () => _updateStatus(context, ref, 'absent'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusText,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 12, color: statusColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
