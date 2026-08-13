import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/error_handler.dart';
import '../../auth/providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'teacher_shell.dart';
import 'teacher_subjects_page.dart';
import '../../../core/responsive_utils.dart';
import '../../../core/services/notification_service.dart';
import 'generate_qr_page.dart';
import 'widgets/edit_session_dialog.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';

// Provider for scheduled AND active sessions
final scheduledSessionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authControllerProvider);
      final teacherUid = auth.uid;

      if (teacherUid == null) {
        return Stream.value([]);
      }

      // Build query for scheduled sessions only - use real-time snapshots
      var scheduledQuery = FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .where('teacherUid', isEqualTo: teacherUid);

      // Add institution filter for non-superadmin users
      if (!auth.isSuperAdmin && auth.institutionCode != null) {
        scheduledQuery = scheduledQuery.where(
          'institutionCode',
          isEqualTo: auth.institutionCode,
        );
      }

      // Return single collection snapshot to avoid infinite loop
      return scheduledQuery.snapshots().map((scheduledSnap) {
        final scheduled = scheduledSnap.docs
            .map((doc) => {'id': doc.id, 'type': 'scheduled', ...doc.data()})
            .toList();

        // Sort in memory to avoid needing a composite index
        scheduled.sort((a, b) {
          final aTime = _parseSessionTime(a);
          final bTime = _parseSessionTime(b);
          return aTime.compareTo(bTime); // ascending (earliest first)
        });

        return scheduled;
      });
    });

DateTime _parseSessionTime(Map<String, dynamic> session) {
  if (session['type'] == 'active') {
    // For active sessions, use expiresAt
    final value = session['expiresAt'];
    if (value is Timestamp) return value.toDate();
    return DateTime(2100);
  } else {
    // For scheduled sessions, use scheduledFor
    final value = session['scheduledFor'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime(2100);
    return DateTime(2100);
  }
}

class TeacherSchedulePage extends ConsumerStatefulWidget {
  const TeacherSchedulePage({super.key});

  @override
  ConsumerState<TeacherSchedulePage> createState() =>
      _TeacherSchedulePageState();
}

class _TeacherSchedulePageState extends ConsumerState<TeacherSchedulePage> {
  String? _selectedSubject;
  final _durationController = TextEditingController(text: '60');
  final _radiusController = TextEditingController(text: '50');

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  void dispose() {
    _durationController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduledSessionsAsync = ref.watch(scheduledSessionsProvider);
    final isMobile = context.isMobile;

    return TeacherShell(
      child: BackgroundPattern(
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (isMobile) ...[
              _buildScheduleForm(),
              const SizedBox(height: 24),
              _buildScheduledSessions(scheduledSessionsAsync),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildScheduleForm()),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildScheduledSessions(scheduledSessionsAsync),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.event_available,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule Session',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plan sessions in advance. Location will be captured when you start the session.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white70,
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

  Widget _buildScheduleForm() {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 100),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Session Details',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _buildSubjectDropdown(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: GoogleFonts.outfit(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(_selectedDate),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time',
                                style: GoogleFonts.outfit(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _selectedTime.format(context),
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Use Column layout if width is constrained (mobile)
                if (constraints.maxWidth < 400) {
                  return Column(
                    children: [
                      GlassTextField(
                        controller: _durationController,
                        label: 'Duration (minutes)',
                        prefixIcon: Icons.timer_outlined,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        controller: _radiusController,
                        label: 'Radius (meters)',
                        prefixIcon: Icons.radar,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  );
                }
                // Use Row layout for larger screens
                return Row(
                  children: [
                    Expanded(
                      child: GlassTextField(
                        controller: _durationController,
                        label: 'Duration (minutes)',
                        prefixIcon: Icons.timer_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GlassTextField(
                        controller: _radiusController,
                        label: 'Radius (meters)',
                        prefixIcon: Icons.radar,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _scheduleSession,
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                'Schedule Session',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledSessions(
    AsyncValue<List<Map<String, dynamic>>> sessionsAsync,
  ) {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 200),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scheduled Sessions',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No Scheduled Sessions',
                    subtitle: 'Schedule your first session above',
                    color: Colors.white54,
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _buildSessionCard(session);
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, _) => ErrorHandler.buildErrorWidget(
                error,
                customMessage: 'Unable to load scheduled sessions',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final isActive = session['type'] == 'active';

    DateTime? targetTime;
    if (isActive) {
      targetTime = (session['expiresAt'] as Timestamp?)?.toDate();
    } else {
      targetTime = (session['scheduledFor'] as Timestamp?)?.toDate();
    }

    final isUpcoming =
        !isActive && targetTime != null && targetTime.isAfter(DateTime.now());
    final color = isActive ? const Color(0xFF10B981) : const Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session['subject'] ?? 'Untitled Session',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isActive
                      ? 'Active Now'
                      : isUpcoming
                      ? 'Upcoming'
                      : 'Past',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isActive ? Icons.qr_code_2 : Icons.calendar_today,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                targetTime != null
                    ? isActive
                          ? 'Expires ${DateFormat('h:mm a').format(targetTime)}'
                          : DateFormat(
                              'MMM dd, yyyy • h:mm a',
                            ).format(targetTime)
                    : 'No date',
                style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  'GPS: ${session['latitude']?.toStringAsFixed(4)}, ${session['longitude']?.toStringAsFixed(4)}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isActive)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // Navigate to Start Session page to see active session
                        context.go('/teacher/generate');
                      },
                      icon: const Icon(Icons.qr_code_2, size: 18),
                      label: const Text('View QR'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (context) => EditSessionDialog(
                            sessionId: session['id'],
                            currentTopic: session['subject'] ?? '',
                            currentNotes: session['notes'],
                          ),
                        );
                        // Refresh logic handled by stream
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        // Start the scheduled session
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GenerateQrPage(
                              initialSubject: session['subject'],
                              initialDuration: session['duration'],
                              initialRadius: (session['radiusMeters'] as num?)
                                  ?.toDouble(),
                              scheduledSessionId: session['id'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Start'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteScheduledSession(session['id']),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Color(0xFF1F2937),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Color(0xFF1F2937),
              onSurface: Colors.white,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _scheduleSession() async {
    if (_selectedSubject == null || _selectedSubject!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a subject')));
      return;
    }

    final auth = ref.read(authControllerProvider);
    if (auth.uid == null) return;

    final scheduledFor = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final duration = int.tryParse(_durationController.text) ?? 60;
    final scheduledEnd = scheduledFor.add(Duration(minutes: duration));

    // ✅ CHECK FOR CONFLICTS WITH ACTIVE SESSIONS
    try {
      final activeSessions = await FirebaseFirestore.instance
          .collection('sessions')
          .where('teacherUid', isEqualTo: auth.uid)
          .where('active', isEqualTo: true)
          .get();

      for (final doc in activeSessions.docs) {
        final data = doc.data();
        final expiresAtRaw = data['expiresAt'];

        if (expiresAtRaw is Timestamp) {
          final expiresAt = expiresAtRaw.toDate();

          // Check if there's an overlap
          // Active session is NOW to expiresAt
          // Scheduled session is scheduledFor to scheduledEnd
          final now = DateTime.now();

          if ((scheduledFor.isBefore(expiresAt) && scheduledEnd.isAfter(now))) {
            // There's an overlap!
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '⚠️ Conflict: You have an active session "${data['subject'] ?? "Session"}" '
                    'running until ${DateFormat('h:mm a').format(expiresAt)}. '
                    'Please end it first or schedule after ${DateFormat('h:mm a').format(expiresAt)}.',
                  ),
                  backgroundColor: const Color(0xFFF59E0B), // Warning orange
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      }

      // ✅ CHECK FOR CONFLICTS WITH OTHER SCHEDULED SESSIONS
      final scheduledSessions = await FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .where('teacherUid', isEqualTo: auth.uid)
          .get();

      for (final doc in scheduledSessions.docs) {
        final data = doc.data();
        final otherScheduledForRaw = data['scheduledFor'];

        if (otherScheduledForRaw is Timestamp) {
          final otherScheduledFor = otherScheduledForRaw.toDate();
          final otherDuration = data['duration'] ?? 60;
          final otherScheduledEnd = otherScheduledFor.add(
            Duration(minutes: otherDuration),
          );

          // Check if there's an overlap
          if ((scheduledFor.isBefore(otherScheduledEnd) &&
              scheduledEnd.isAfter(otherScheduledFor))) {
            // There's an overlap!
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '⚠️ Conflict: You already have a scheduled session "${data['subject'] ?? "Session"}" '
                    'at ${DateFormat('h:mm a').format(otherScheduledFor)}. '
                    'Please choose a different time.',
                  ),
                  backgroundColor: const Color(0xFFF59E0B), // Warning orange
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      }

      // ✅ NO CONFLICTS - CREATE THE SCHEDULED SESSION
      final docRef = await FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .add({
            'teacherUid': auth.uid,
            'institutionCode': auth.institutionCode,
            'subject': _selectedSubject,
            'scheduledFor': Timestamp.fromDate(scheduledFor),
            'duration': int.tryParse(_durationController.text) ?? 60,
            'radiusMeters': double.tryParse(_radiusController.text) ?? 50,
            'createdAt': FieldValue.serverTimestamp(),
          });

      // 🔔 SCHEDULE LOCAL NOTIFICATION (Teacher)
      try {
        final notificationTime = scheduledFor.subtract(
          const Duration(minutes: 1),
        );
        if (notificationTime.isAfter(DateTime.now())) {
          await NotificationService().scheduleNotification(
            id: docRef.id.hashCode,
            title: 'Session Starting Soon',
            body: 'Your session for $_selectedSubject starts in 1 minute.',
            scheduledDate: notificationTime,
            payload: docRef.id,
          );
        }
      } catch (e) {
        debugPrint('Failed to schedule local notification: $e');
      }

      // 🔔 NOTIFY STUDENTS (Firestore)
      // Parse group from subject string "Name (Group)"
      String? groupName;
      if (_selectedSubject != null) {
        final match = RegExp(r'^(.*) \((.*)\)$').firstMatch(_selectedSubject!);
        if (match != null) {
          groupName = match.group(2);
        }
      }

      if (groupName != null &&
          groupName.isNotEmpty &&
          groupName != 'No Group') {
        try {
          final groupSnap = await FirebaseFirestore.instance
              .collection('class_groups')
              .where('institutionCode', isEqualTo: auth.institutionCode)
              .where('name', isEqualTo: groupName)
              .limit(1)
              .get();

          if (groupSnap.docs.isNotEmpty) {
            final groupData = groupSnap.docs.first.data();
            final studentUids = List<String>.from(
              groupData['studentUids'] ?? [],
            );

            if (studentUids.isNotEmpty) {
              final batch = FirebaseFirestore.instance.batch();
              final now = Timestamp.now();
              final formattedTime = DateFormat(
                'MMM dd, h:mm a',
              ).format(scheduledFor);

              int count = 0;
              for (final recipientUid in studentUids) {
                if (count >= 450) break; // Safety margin

                final notifRef = FirebaseFirestore.instance
                    .collection('notifications')
                    .doc();
                batch.set(notifRef, {
                  'recipientUid': recipientUid,
                  'senderUid': auth.uid,
                  'senderName': auth.displayName ?? 'Teacher',
                  'senderRollNumber': '',
                  'title': 'Session Scheduled',
                  'message':
                      'A session for $groupName has been scheduled for $formattedTime.',
                  'type': 'session_scheduled',
                  'timestamp': now,
                  'read': false,
                  'metadata': {
                    'scheduledSessionId': docRef.id,
                    'group': groupName,
                    'subject': _selectedSubject,
                    'scheduledFor': Timestamp.fromDate(scheduledFor),
                  },
                });
                count++;
              }
              await batch.commit();
            }
          }
        } catch (e) {
          debugPrint('Failed to notify students: $e');
        }
      }

      // Clear form
      _selectedSubject = null;
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session scheduled successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Unable to create session',
        );
      }
    }
  }

  Future<void> _deleteScheduledSession(String sessionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .doc(sessionId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Session deleted')));
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Unable to delete session',
        );
      }
    }
  }

  Widget _buildSubjectDropdown() {
    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      data: (groupedSubjects) {
        // Flatten all subjects from all types and groups
        final allSubjects = <Map<String, dynamic>>[];
        for (final typeGroups in groupedSubjects.values) {
          for (final subjects in typeGroups.values) {
            allSubjects.addAll(subjects);
          }
        }

        // Remove duplicates based on subject name and group
        final uniqueSubjects = <String>{};
        final distinctSubjects = <Map<String, dynamic>>[];

        for (final subject in allSubjects) {
          final key = '${subject['name']}-${subject['group']}';
          if (!uniqueSubjects.contains(key)) {
            uniqueSubjects.add(key);
            distinctSubjects.add(subject);
          }
        }

        if (distinctSubjects.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF59E0B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No subjects assigned. Please contact admin.',
                    style: GoogleFonts.outfit(color: const Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSubject,
              hint: Text(
                'Select Subject',
                style: GoogleFonts.outfit(color: Colors.white54),
              ),
              dropdownColor: const Color(0xFF1F2937),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
              items: distinctSubjects.map((subject) {
                final subjectName = subject['name'];
                final groupName = subject['group'] ?? 'No Group';
                final value = '$subjectName ($groupName)';

                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubject = value;
                });
              },
            ),
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (error, _) => Text(
        'Error loading subjects',
        style: GoogleFonts.outfit(color: Colors.red),
      ),
    );
  }
}
