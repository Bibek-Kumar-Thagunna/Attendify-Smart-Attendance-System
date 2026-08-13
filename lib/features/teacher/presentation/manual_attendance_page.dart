import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_dropdown.dart';
import '../../teacher/providers.dart';
import '../../auth/providers.dart';
import 'teacher_shell.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../attendance/providers.dart';

class ManualAttendancePage extends ConsumerStatefulWidget {
  const ManualAttendancePage({super.key});

  @override
  ConsumerState<ManualAttendancePage> createState() =>
      _ManualAttendancePageState();
}

class _ManualAttendancePageState extends ConsumerState<ManualAttendancePage> {
  String? _selectedSubject;
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  List<Map<String, dynamic>> _students = [];
  Map<String, String> _attendanceStatus =
      {}; // uid -> status ('present', 'absent', 'late')

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchStudents() async {
    if (_selectedSubject == null) return;

    setState(() => _loading = true);

    try {
      final auth = ref.read(authControllerProvider);
      final institutionCode = auth.institutionCode;

      if (institutionCode == null) return;

      // Parse subject string "Name (Group)"
      final match = RegExp(r'^(.+) \((.+)\)$').firstMatch(_selectedSubject!);
      String? groupName;
      if (match != null) {
        groupName = match.group(2)?.trim();
      }

      if (groupName == null) {
        setState(() {
          _loading = false;
          _students = [];
        });
        return;
      }

      // 1. Get Group ID from Name
      final groupsSnap = await FirebaseFirestore.instance
          .collection('class_groups')
          .where('institutionCode', isEqualTo: institutionCode)
          .where('name', isEqualTo: groupName)
          .limit(1)
          .get();

      if (groupsSnap.docs.isEmpty) {
        setState(() {
          _loading = false;
          _students = [];
        });
        return;
      }

      final groupId = groupsSnap.docs.first.id;

      // 2. Fetch Students in Group
      // We need to check lectureGroup, labGroup, and legacy group field
      final studentsSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('institutionCode', isEqualTo: institutionCode)
          .where('role', isEqualTo: 'student')
          .get(); // Fetch all students in inst is safer than complex OR queries in Firestore

      final filteredStudents = studentsSnap.docs
          .where((doc) {
            final data = doc.data();
            return data['lectureGroup'] == groupId ||
                data['labGroup'] == groupId ||
                data['group'] == groupName; // Legacy check
          })
          .map((doc) {
            final data = doc.data();
            return {
              'uid': doc.id,
              'displayName': data['displayName'] ?? 'Unknown',
              'rollNumber': data['rollNumber'] ?? data['idNumber'] ?? '',
              'email': data['email'] ?? '',
            };
          })
          .toList();

      // Sort by Name
      filteredStudents.sort(
        (a, b) =>
            (a['displayName'] as String).compareTo(b['displayName'] as String),
      );

      setState(() {
        _students = filteredStudents;
        // Default to Present
        _attendanceStatus = {
          for (var s in filteredStudents) s['uid'] as String: 'present',
        };
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching students: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveAttendance() async {
    if (_selectedSubject == null || _students.isEmpty) return;

    setState(() => _loading = true);

    try {
      final auth = ref.read(authControllerProvider);
      final teacherUid = auth.uid!;
      final institutionCode = auth.institutionCode!;

      // Parse subject string "Name (Group)"
      final match = RegExp(r'^(.+) \((.+)\)$').firstMatch(_selectedSubject!);
      String? subjectName;
      String? groupName;
      if (match != null) {
        subjectName = match.group(1)?.trim();
        groupName = match.group(2)?.trim();
      } else {
        subjectName = _selectedSubject;
      }

      // 1. Create Session
      final repo = ref.read(attendanceRepositoryProvider);
      final sessionId = await repo.createSession(
        teacherUid: teacherUid,
        latitude: 0, // Manual
        longitude: 0, // Manual
        radiusMeters: 0, // Manual
        duration: const Duration(hours: 1), // Default duration
        subject: subjectName,
        group: groupName,
        institutionCode: institutionCode,
        bypassLocation: true,
      );

      // 2. Prepare Bulk Data
      final studentData = _students.map((s) {
        final uid = s['uid'] as String;
        return {
          'uid': uid,
          'status': _attendanceStatus[uid] ?? 'absent',
          'displayName': s['displayName'],
          'rollNumber': s['rollNumber'],
          'email': s['email'],
        };
      }).toList();

      // 3. Bulk Mark
      await repo.markBulkAttendance(
        sessionId: sessionId,
        students: studentData,
        institutionCode: institutionCode,
        subject: subjectName,
        group: groupName,
      );

      // 4. End Session immediately (it's a manual record)
      await repo.endSession(sessionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance Saved Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markAll(String status) {
    setState(() {
      for (var uid in _attendanceStatus.keys) {
        _attendanceStatus[uid] = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    'Manual Attendance',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mark attendance for a class manually.',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // Controls
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSubjectDropdown(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFF8B5CF6),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1E293B),
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (date != null) {
                              setState(() => _selectedDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(_selectedDate),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Student List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : _students.isEmpty
                  ? Center(
                      child: Text(
                        _selectedSubject == null
                            ? 'Select a subject to load students'
                            : 'No students found for this group',
                        style: GoogleFonts.outfit(color: Colors.white54),
                      ),
                    )
                  : Column(
                      children: [
                        // Bulk Actions
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _markAll('present'),
                                child: const Text('Mark All Present'),
                              ),
                              TextButton(
                                onPressed: () => _markAll('absent'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                                child: const Text('Mark All Absent'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _students.length,
                            separatorBuilder: (c, i) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final student = _students[index];
                              final uid = student['uid'] as String;
                              final status = _attendanceStatus[uid];

                              return GlassCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: Text(
                                        (student['displayName'] as String)[0]
                                            .toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            student['displayName'],
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            student['rollNumber'],
                                            style: GoogleFonts.outfit(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status Toggles
                                    Row(
                                      children: [
                                        _StatusButton(
                                          label: 'P',
                                          color: const Color(0xFF10B981),
                                          isSelected: status == 'present',
                                          onTap: () => setState(
                                            () => _attendanceStatus[uid] =
                                                'present',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _StatusButton(
                                          label: 'L',
                                          color: const Color(0xFFF59E0B),
                                          isSelected: status == 'late',
                                          onTap: () => setState(
                                            () =>
                                                _attendanceStatus[uid] = 'late',
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _StatusButton(
                                          label: 'A',
                                          color: const Color(0xFFEF4444),
                                          isSelected: status == 'absent',
                                          onTap: () => setState(
                                            () => _attendanceStatus[uid] =
                                                'absent',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveAttendance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Save Attendance (${_students.length})',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectDropdown() {
    final subjectsAsync = ref.watch(teacherSubjectsProvider);

    return subjectsAsync.when(
      data: (allSubjects) {
        return GlassDropdown<String>(
          value: _selectedSubject,
          hint: 'Select Subject & Group',
          icon: const Icon(Icons.class_, color: Colors.white70),
          items: allSubjects.map((subject) {
            final name = subject['name'] ?? 'Untitled';
            final group = subject['group'] ?? 'No Group';
            final displayText = '$name ($group)';
            return DropdownMenuItem(
              value: displayText,
              child: Text(displayText),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedSubject = val;
              _students = []; // Reset students
            });
            _fetchStudents();
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (_, __) => const Text(
        'Error loading subjects',
        style: TextStyle(color: Colors.red),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
