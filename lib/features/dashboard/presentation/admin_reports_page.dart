import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/responsive_utils.dart';
import '../../shared/services/export_service.dart';
import '../../auth/providers.dart';
import 'admin_shell.dart';

// Report types
enum ReportType { attendance, teachers, students, sessions }

class AdminReportsPage extends ConsumerStatefulWidget {
  const AdminReportsPage({super.key});

  @override
  ConsumerState<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends ConsumerState<AdminReportsPage> {
  ReportType _selectedType = ReportType.attendance;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      child: ListView(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildReportConfiguration(),
          const SizedBox(height: 24),
          _buildQuickStats(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = context.isMobile;

    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: .08),
              const Color(0xFF1E293B),
            ],
          ),
        ),
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.description_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: isMobile ? 24 : 32,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Generate Reports',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (!isMobile) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Create detailed PDF reports for attendance, teachers, students, and sessions.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportConfiguration() {
    final isMobile = context.isMobile;

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 100),
      child: Card(
        elevation: 0,
        color: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Configuration',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // Report Type Selection
              Text(
                'Select Report Type',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  if (isMobile) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildReportTypeChip(
                                type: ReportType.attendance,
                                label: 'Attendance',
                                icon: Icons.check_circle,
                                description: 'Student attendance records',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildReportTypeChip(
                                type: ReportType.teachers,
                                label: 'Teachers',
                                icon: Icons.school,
                                description: 'Teacher details',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildReportTypeChip(
                                type: ReportType.students,
                                label: 'Students',
                                icon: Icons.people,
                                description: 'Student details',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildReportTypeChip(
                                type: ReportType.sessions,
                                label: 'Sessions',
                                icon: Icons.event,
                                description: 'Session logs',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildReportTypeChip(
                        type: ReportType.attendance,
                        label: 'Attendance',
                        icon: Icons.check_circle,
                        description: 'Student attendance records',
                      ),
                      _buildReportTypeChip(
                        type: ReportType.teachers,
                        label: 'Teachers',
                        icon: Icons.school,
                        description: 'Teacher details',
                      ),
                      _buildReportTypeChip(
                        type: ReportType.students,
                        label: 'Students',
                        icon: Icons.people,
                        description: 'Student details',
                      ),
                      _buildReportTypeChip(
                        type: ReportType.sessions,
                        label: 'Sessions',
                        icon: Icons.event,
                        description: 'Session logs',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),

              // Generate Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generateReport,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.analytics),
                  label: Text(
                    _isGenerating
                        ? 'Generating Report...'
                        : 'Generate & Download PDF',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Export All Data Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _exportAllData,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export All Data (Excel)'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportTypeChip({
    required ReportType type,
    required String label,
    required IconData icon,
    required String description,
  }) {
    final isSelected = _selectedType == type;
    final scheme = Theme.of(context).colorScheme;
    final isMobile = context.isMobile;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primary.withValues(alpha: .2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? scheme.primary
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? scheme.primary : Colors.white70,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected ? scheme.primary : Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return const SizedBox.shrink(); // Removed as requested
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);

    try {
      final auth = ref.read(authControllerProvider);
      final instituteName = auth.institutionCode ?? 'Attendify Institute';

      final data = await _fetchReportData();

      if (data.isEmpty) {
        throw Exception('No data found for this report type.');
      }

      await ExportService.exportToPDF(
        fileName:
            '${_selectedType.name}_report_${DateTime.now().millisecondsSinceEpoch}',
        title: instituteName,
        description:
            '${_getReportTitle()}\nGenerated on ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
        data: data,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report downloaded successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating report: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _exportAllData() async {
    setState(() => _isGenerating = true);

    try {
      // Fetch data for all report types
      final attendanceData = await _fetchAttendanceData();
      final teachersData = await _fetchTeachersData();
      final studentsData = await _fetchStudentsData();
      final sessionsData = await _fetchSessionsData();

      final sheets = {
        'Attendance': attendanceData,
        'Teachers': teachersData,
        'Students': studentsData,
        'Sessions': sessionsData,
      };

      await ExportService.exportAllDataToExcel(
        fileName: 'Full_Report_${DateTime.now().millisecondsSinceEpoch}',
        sheets: sheets,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Full report downloaded successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  String _getReportTitle() {
    switch (_selectedType) {
      case ReportType.attendance:
        return 'Student Attendance Report';
      case ReportType.teachers:
        return 'Teachers Directory';
      case ReportType.students:
        return 'Students Directory';
      case ReportType.sessions:
        return 'Sessions Log';
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReportData() async {
    switch (_selectedType) {
      case ReportType.attendance:
        return await _fetchAttendanceData();
      case ReportType.teachers:
        return await _fetchTeachersData();
      case ReportType.students:
        return await _fetchStudentsData();
      case ReportType.sessions:
        return await _fetchSessionsData();
    }
  }

  Future<List<Map<String, dynamic>>> _fetchAttendanceData() async {
    final auth = ref.read(authControllerProvider);
    final institutionCode = auth.institutionCode;

    // 1. Fetch all students
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    // 2. Fetch class groups to resolve IDs to names
    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('class_groups')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    final groupIdToName = {
      for (var doc in groupsSnapshot.docs) doc.id: doc.data()['name'] as String,
    };

    // 3. Fetch all sessions (limit to recent 500 for performance, or filter by date range in real app)
    // NOTE: Avoiding .where('institutionCode') + .orderBy() to skip composite index requirement
    final sessionsSnapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();

    // Filter by institution code client-side
    final sessions = sessionsSnapshot.docs
        .where(
          (doc) =>
              (doc.data()['institutionCode'] as String?) == institutionCode,
        )
        .toList();

    // 4. Pre-process sessions by group for faster lookup
    // Map<GroupName, List<SessionDoc>>
    final sessionsByGroup = <String, List<QueryDocumentSnapshot>>{};

    for (var doc in sessions) {
      final data = doc.data();
      final subjectStr = data['subject'] as String? ?? '';
      String? group = data['group'] as String?;

      // Fallback extraction
      if (group == null &&
          subjectStr.contains('(') &&
          subjectStr.endsWith(')')) {
        group = subjectStr.split('(').last.replaceAll(')', '').trim();
      }

      if (group != null) {
        final normalizedGroup = group.trim().toLowerCase();
        sessionsByGroup.putIfAbsent(normalizedGroup, () => []).add(doc);
      }
    }

    final List<Map<String, dynamic>> reportData = [];

    for (final doc in studentsSnapshot.docs) {
      final data = doc.data();
      final uid = doc.id;
      final name = data['displayName'] ?? 'Unknown';
      final id = data['rollNumber'] ?? data['idNumber'] ?? 'N/A';

      // Determine student's groups - RESOLVE IDs TO NAMES
      final lectureGroupId = data['lectureGroup'] as String?;
      final labGroupId = data['labGroup'] as String?;
      final legacyGroup = (data['group'] as String?)?.trim().toLowerCase();

      // Resolve IDs to names
      final lectureGroupName = lectureGroupId != null
          ? (groupIdToName[lectureGroupId] ?? lectureGroupId)
                .trim()
                .toLowerCase()
          : null;
      final labGroupName = labGroupId != null
          ? (groupIdToName[labGroupId] ?? labGroupId).trim().toLowerCase()
          : null;

      final studentGroups = {
        if (lectureGroupName != null) lectureGroupName,
        if (labGroupName != null) labGroupName,
        if (legacyGroup != null) legacyGroup,
      };

      int totalSessions = 0;
      int attendedSessions = 0;

      // Calculate stats
      for (var group in studentGroups) {
        final groupSessions = sessionsByGroup[group] ?? [];
        for (var session in groupSessions) {
          totalSessions++;

          // Optimization: Check attendeeUids array on session doc first
          final sessionData = session.data() as Map<String, dynamic>;
          final attendeeUids = sessionData['attendeeUids'] as List<dynamic>?;

          if (attendeeUids != null) {
            // New optimized path: O(1) check
            if (attendeeUids.contains(uid)) {
              attendedSessions++;
            }
          } else {
            // Fallback path: Check subcollection (N+1 query)
            // Necessary for old sessions created before optimization
            final attendanceDoc = await session.reference
                .collection('attendance')
                .doc(uid)
                .get();
            if (attendanceDoc.exists) {
              attendedSessions++;
            }
          }
        }
      }

      final percentage = totalSessions > 0
          ? ((attendedSessions / totalSessions) * 100).toStringAsFixed(1)
          : '0.0';

      reportData.add({
        'Student Name': name,
        'Student ID': id,
        'Total Sessions': totalSessions.toString(),
        'Attended': attendedSessions.toString(),
        'Attendance %': '$percentage%',
      });
    }

    return reportData;
  }

  Future<List<Map<String, dynamic>>> _fetchTeachersData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'Teacher Name': data['displayName'] ?? 'Unknown',
        'Teacher ID': data['idNumber'] ?? 'N/A',
        'Email': data['email'] ?? 'N/A',
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchStudentsData() async {
    final auth = ref.read(authControllerProvider);
    final institutionCode = auth.institutionCode;

    // Fetch students
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    // Fetch class groups to resolve IDs to names
    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('class_groups')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    final groupIdToName = {
      for (var doc in groupsSnapshot.docs) doc.id: doc.data()['name'] as String,
    };

    return snapshot.docs.map((doc) {
      final data = doc.data();

      // Resolve group IDs to names
      final lectureGroupId = data['lectureGroup'] as String?;
      final labGroupId = data['labGroup'] as String?;

      final lectureGroupName = lectureGroupId != null
          ? (groupIdToName[lectureGroupId] ?? lectureGroupId)
          : 'N/A';
      final labGroupName = labGroupId != null
          ? (groupIdToName[labGroupId] ?? labGroupId)
          : 'N/A';

      return {
        'Student Name': data['displayName'] ?? 'Unknown',
        'Student ID': data['rollNumber'] ?? data['idNumber'] ?? 'N/A',
        'Email': data['email'] ?? 'N/A',
        'Lecture Group': lectureGroupName,
        'Lab Group': labGroupName,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> _fetchSessionsData() async {
    final auth = ref.read(authControllerProvider);
    final institutionCode = auth.institutionCode;

    // 1. Fetch Sessions
    // NOTE: Avoiding .where('institutionCode') + .orderBy() to skip composite index requirement
    final allSessionsSnapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .limit(
          200,
        ) // Fetch more to ensure we get 50+ from our institution after filtering
        .get();

    // Filter by institution code client-side and limit to 50
    final snapshot = allSessionsSnapshot.docs
        .where(
          (doc) =>
              (doc.data()['institutionCode'] as String?) == institutionCode,
        )
        .take(50)
        .toList();

    // 2. Fetch All Students (to calculate absentees)
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    final allStudents = studentsSnapshot.docs.map((d) => d.data()).toList();

    // 3. Fetch class groups to resolve IDs
    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('class_groups')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    final groupIdToName = {
      for (var doc in groupsSnapshot.docs) doc.id: doc.data()['name'] as String,
    };

    // Helper to count students in a group
    int countStudentsInGroup(String groupName) {
      final normalizedTarget = groupName.trim().toLowerCase();
      return allStudents.where((s) {
        // RESOLVE IDs TO NAMES before comparing
        final lectureGroupId = s['lectureGroup'] as String?;
        final labGroupId = s['labGroup'] as String?;
        final legacyGroup = (s['group'] as String?)?.trim().toLowerCase();

        final lectureGroupName = lectureGroupId != null
            ? (groupIdToName[lectureGroupId] ?? lectureGroupId)
                  .trim()
                  .toLowerCase()
            : null;
        final labGroupName = labGroupId != null
            ? (groupIdToName[labGroupId] ?? labGroupId).trim().toLowerCase()
            : null;

        return lectureGroupName == normalizedTarget ||
            labGroupName == normalizedTarget ||
            legacyGroup == normalizedTarget;
      }).length;
    }

    final List<Map<String, dynamic>> reportData = [];

    for (final doc in snapshot) {
      final data = doc.data();
      final teacherId = data['teacherUid'];
      String teacherName = 'Unknown';

      if (teacherId != null) {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .get();
        teacherName = teacherDoc.data()?['displayName'] ?? 'Unknown';
      }

      // Determine Group
      final subjectStr = data['subject'] as String? ?? '';
      String? group = data['group'] as String?;
      if (group == null &&
          subjectStr.contains('(') &&
          subjectStr.endsWith(')')) {
        group = subjectStr.split('(').last.replaceAll(')', '').trim();
      }

      // Optimization: Check attendeeUids length first
      int presentCount = 0;
      final attendeeUids = data['attendeeUids'] as List<dynamic>?;

      if (attendeeUids != null) {
        presentCount = attendeeUids.length;
      } else {
        // Fallback: Count subcollection
        presentCount =
            (await doc.reference.collection('attendance').count().get())
                .count ??
            0;
      }

      String absentStr = 'N/A';
      if (group != null) {
        final totalStudents = countStudentsInGroup(group);
        final absentCount = totalStudents - presentCount;
        absentStr = absentCount < 0
            ? '0'
            : absentCount.toString(); // Safety check
      }

      reportData.add({
        'Session ID': doc.id.substring(0, 8),
        'Date': DateFormat(
          'MMM dd, HH:mm',
        ).format((data['createdAt'] as Timestamp).toDate()),
        'Created By': teacherName,
        'Group': group ?? 'N/A',
        'Present': presentCount,
        'Absent': absentStr,
      });
    }

    return reportData;
  }
}
