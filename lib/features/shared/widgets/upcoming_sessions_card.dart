import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rxdart/rxdart.dart';
import '../../auth/providers.dart';
import '../../teacher/providers.dart';
import '../../../core/utils/error_handler.dart';
import 'empty_state.dart';
import 'shimmer_loading.dart';

final upcomingSessionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
      final auth = ref.watch(authControllerProvider);
      final teacherUid = auth.uid;
      final code = auth.institutionCode;

      // If auth is loading, wait
      if (auth.loading) {
        yield [];
        return;
      }

      if (teacherUid == null) {
        yield [];
        return;
      }

      final now = DateTime.now();

      // 1. Fetch all subjects/groups this teacher teaches
      final subjectsSnap = await FirebaseFirestore.instance
          .collection('subjects')
          .where('teacherUid', isEqualTo: teacherUid)
          .get();

      final myGroups = subjectsSnap.docs
          .map((d) => d.data()['group'] as String?)
          .where((g) => g != null && g != 'No Group')
          .toSet()
          .toList();

      // 2. Query active sessions
      Query<Map<String, dynamic>> activeQ = FirebaseFirestore.instance
          .collection('sessions')
          .where('active', isEqualTo: true);

      if (!auth.isSuperAdmin && code != null) {
        activeQ = activeQ.where('institutionCode', isEqualTo: code);
      }

      // 3. Query scheduled sessions
      Query<Map<String, dynamic>> scheduledQ = FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .where('teacherUid', isEqualTo: teacherUid);

      if (!auth.isSuperAdmin && code != null) {
        scheduledQ = scheduledQ.where('institutionCode', isEqualTo: code);
      }

      // Combine streams
      final activeStream = activeQ.snapshots();
      final scheduledStream = scheduledQ.snapshots();

      yield* Rx.combineLatest2(activeStream, scheduledStream, (
        QuerySnapshot activeSnap,
        QuerySnapshot scheduledSnap,
      ) {
        // Process Active Sessions
        final activeSessions = activeSnap.docs
            .map(
              (doc) => {
                'id': doc.id,
                'type': 'active',
                ...doc.data() as Map<String, dynamic>,
              },
            )
            .where((session) {
              if (session['active'] == false) return false;
              if (session['endedAt'] != null) return false;

              final expiresAtRaw = session['expiresAt'];
              DateTime? expiresAt;
              if (expiresAtRaw is Timestamp) {
                expiresAt = expiresAtRaw.toDate();
              } else if (expiresAtRaw is DateTime) {
                expiresAt = expiresAtRaw;
              } else if (expiresAtRaw is String) {
                expiresAt = DateTime.tryParse(expiresAtRaw);
              }

              if (expiresAt == null || !expiresAt.isAfter(now)) return false;

              // Visibility Logic
              final isMySession = session['teacherUid'] == teacherUid;
              final sessionGroup = session['group'] as String?;
              final isMyGroup =
                  sessionGroup != null && myGroups.contains(sessionGroup);

              return isMySession || isMyGroup;
            })
            .toList();

        // Process Scheduled Sessions
        final scheduledSessions = scheduledSnap.docs
            .map(
              (doc) => {
                'id': doc.id,
                'type': 'scheduled',
                ...doc.data() as Map<String, dynamic>,
              },
            )
            .where((session) {
              final scheduledForRaw = session['scheduledFor'];
              DateTime? scheduledFor;
              if (scheduledForRaw is Timestamp) {
                scheduledFor = scheduledForRaw.toDate();
              }

              if (scheduledFor == null) return false;

              // Show if scheduled for future OR within last 30 mins (overdue but startable)
              final diff = scheduledFor.difference(now);
              return diff.inMinutes > -30;
            })
            .toList();

        // Merge and Sort
        final allSessions = [...activeSessions, ...scheduledSessions];

        allSessions.sort((a, b) {
          final aTime = _getSessionTime(a);
          final bTime = _getSessionTime(b);
          return aTime.compareTo(bTime);
        });

        return allSessions.take(5).toList();
      });
    });

DateTime _getSessionTime(Map<String, dynamic> session) {
  if (session['type'] == 'scheduled') {
    final raw = session['scheduledFor'];
    if (raw is Timestamp) return raw.toDate();
  } else {
    final raw = session['expiresAt'];
    if (raw is Timestamp) return raw.toDate();
  }
  return DateTime(2100);
}

class UpcomingSessionsCard extends ConsumerWidget {
  const UpcomingSessionsCard({super.key});

  Color _getSessionColor(int index) {
    final colors = [
      const Color(0xFF10B981), // emerald
      const Color(0xFF3B82F6), // blue
      const Color(0xFF8B5CF6), // purple
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEC4899), // pink
    ];
    return colors[index % colors.length];
  }

  IconData _getSessionIcon(int index) {
    final icons = [
      Icons.edit_document,
      Icons.terminal,
      Icons.palette,
      Icons.calculate,
      Icons.science,
    ];
    return icons[index % icons.length];
  }

  String _getTimeRemaining(DateTime targetTime, {bool isScheduled = false}) {
    final now = DateTime.now();
    final difference = targetTime.difference(now);

    if (isScheduled) {
      if (difference.isNegative) {
        final abs = difference.abs();
        if (abs.inMinutes < 30) return 'Ready to start';
        return 'Overdue';
      }
      if (difference.inMinutes < 60) {
        return 'In ${difference.inMinutes}m';
      } else if (difference.inHours < 24) {
        return 'In ${difference.inHours}h';
      } else {
        return 'In ${difference.inDays}d';
      }
    } else {
      if (difference.isNegative) return 'Expired';
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m left';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h left';
      } else {
        return '${difference.inDays}d left';
      }
    }
  }

  Future<void> _startScheduledSession(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> session,
  ) async {
    try {
      // Check location permission
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      if (!kIsWeb) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      // Get current position with settings
      final LocationSettings locationSettings = kIsWeb
          ? const LocationSettings(accuracy: LocationAccuracy.high)
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 100,
            );

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      // Start session with scheduled parameters
      final duration = Duration(minutes: session['duration'] ?? 60);
      final radius = (session['radiusMeters'] as num?)?.toDouble() ?? 50.0;
      final subject = session['subject'] as String?;

      await ref
          .read(activeSessionProvider.notifier)
          .startSession(
            latitude: pos.latitude,
            longitude: pos.longitude,
            duration: duration,
            radiusMeters: radius,
            subject: subject,
            scheduledSessionId: session['id'],
          );

      // Delete the scheduled session after successfully starting
      await FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .doc(session['id'])
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started session: ${subject ?? "Session"}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        context.go('/teacher/generate');
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Unable to cancel session',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(upcomingSessionsProvider);

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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_note_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Upcoming Sessions',
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
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No Upcoming Sessions',
                    subtitle: 'Sessions will appear here once scheduled',
                    color: Color(0xFF3B82F6),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final color = _getSessionColor(index);
                    final icon = _getSessionIcon(index);
                    final isScheduled = session['type'] == 'scheduled';

                    DateTime? targetTime;
                    if (isScheduled) {
                      targetTime = (session['scheduledFor'] as Timestamp?)
                          ?.toDate();
                    } else {
                      targetTime = (session['expiresAt'] as Timestamp?)
                          ?.toDate();
                    }

                    final now = DateTime.now();
                    final canStart =
                        isScheduled &&
                        targetTime != null &&
                        targetTime.difference(now).inMinutes.abs() <= 30;

                    return Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isScheduled ? Icons.schedule_rounded : icon,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        session['subject'] ??
                                            'Session ${session['id'].substring(0, 8)}',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
                                          ),
                                          children: [
                                            TextSpan(
                                              text: isScheduled
                                                  ? 'Starts: '
                                                  : 'Expires: ',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                            TextSpan(
                                              text: targetTime != null
                                                  ? DateFormat(
                                                      'h:mm a',
                                                    ).format(targetTime)
                                                  : 'No time',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (targetTime != null)
                                      Text(
                                        _getTimeRemaining(
                                          targetTime,
                                          isScheduled: isScheduled,
                                        ),
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: canStart
                                              ? const Color(0xFF10B981)
                                              : color,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isScheduled
                                            ? const Color(
                                                0xFFF59E0B,
                                              ).withValues(alpha: 0.15)
                                            : color.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isScheduled ? 'Scheduled' : 'Active',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isScheduled
                                              ? const Color(0xFFF59E0B)
                                              : color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (isScheduled && canStart) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _startScheduledSession(
                                    context,
                                    ref,
                                    session,
                                  ),
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Start Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, __) => const ShimmerListTile(),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: ErrorHandler.buildErrorWidget(
                    e,
                    customMessage: 'Unable to load sessions',
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
