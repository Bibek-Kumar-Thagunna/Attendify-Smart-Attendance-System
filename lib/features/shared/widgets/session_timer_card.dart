import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/logger.dart';
import '../../auth/providers.dart';
import 'empty_state.dart';
import 'glass_card.dart';

final dashboardActiveSessionProvider = StreamProvider<Map<String, dynamic>?>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);
  final code = auth.institutionCode;

  // If auth is loading, wait
  if (auth.loading) {
    return const Stream<Map<String, dynamic>?>.empty();
  }

  // If user has no institution code and is not superadmin, return null
  if (!auth.isSuperAdmin && (code == null || code.isEmpty)) {
    return Stream.value(null);
  }

  try {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('sessions')
        .where('active', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(1);

    // Add institution filter for non-superadmin users
    if (!auth.isSuperAdmin && code != null && code.isNotEmpty) {
      query = query.where('institutionCode', isEqualTo: code);
    }

    // Filter by teacherUid to only show own sessions
    if (auth.uid != null) {
      query = query.where('teacherUid', isEqualTo: auth.uid);
    }

    return query
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          final data = doc.data();

          // DEFENSIVE CHECKS to handle Firestore sync delays

          // Check 1: Verify active is not explicitly false
          if (data['active'] == false) {
            return null;
          }

          // Check 2: Check if session was manually ended
          if (data['endedAt'] != null) {
            return null;
          }

          // Check 3: Double-check the session is not expired
          final expiresAtRaw = data['expiresAt'];
          if (expiresAtRaw is Timestamp) {
            final expiresAt = expiresAtRaw.toDate();
            if (DateTime.now().isAfter(expiresAt)) {
              // Session expired, should not be shown as active
              return null;
            }
          }

          return {'id': doc.id, ...data};
        })
        .handleError((error) {
          appLogger.i('Error in dashboardActiveSessionProvider: $error');
          return null;
        });
  } catch (e) {
    appLogger.i('Error setting up dashboardActiveSessionProvider: $e');
    return Stream.value(null);
  }
});

class SessionTimerCard extends ConsumerStatefulWidget {
  const SessionTimerCard({super.key});

  @override
  ConsumerState<SessionTimerCard> createState() => _SessionTimerCardState();
}

class _SessionTimerCardState extends ConsumerState<SessionTimerCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime startTime) {
    _timer?.cancel();
    _elapsed = DateTime.now().difference(startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(startTime);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _elapsed = Duration.zero;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(dashboardActiveSessionProvider);

    return sessionAsync.when(
      data: (session) {
        if (session == null) {
          _stopTimer();
          return GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.timer_outlined,
                        color: Colors.white54,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Session Timer',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const EmptyState(
                  icon: Icons.timer_off_outlined,
                  title: 'No Active Session',
                  subtitle: 'Start a session to begin tracking time',
                  color: Colors.white54,
                ),
              ],
            ),
          );
        }

        // Active session found
        final createdAtTimestamp = session['createdAt'] as Timestamp?;
        final expiresAtTimestamp = session['expiresAt'] as Timestamp?;
        if (createdAtTimestamp != null) {
          _startTimer(createdAtTimestamp.toDate());
        }

        final expiresAt = expiresAtTimestamp?.toDate();
        final isExpiringSoon =
            expiresAt != null &&
            expiresAt.difference(DateTime.now()).inMinutes < 5;

        return GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B0FF), Color(0xFF0081CB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.timer_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Session Timer',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      _formatDuration(_elapsed),
                      style: GoogleFonts.outfit(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00B0FF),
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () {
                        // Navigate to Start Session page to show the QR code
                        context.go('/teacher/generate');
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isExpiringSoon
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFFDC2626),
                                    Color(0xFFB91C1C),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF00B0FF),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isExpiringSoon
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF00B0FF))
                                      .withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              size: 8,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isExpiringSoon
                                  ? 'Expiring Soon'
                                  : 'Active Session',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.qr_code_2,
                              size: 14,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (expiresAt != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Expires at ${TimeOfDay.fromDateTime(expiresAt).format(context)}',
                        style: GoogleFonts.outfit(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => GlassCard(
        child: Container(
          height: 200,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Color(0xFF00B0FF)),
        ),
      ),
      error: (e, _) {
        // If it's an index error, show a friendly message
        final errorMsg = e.toString();
        if (errorMsg.contains('index') ||
            errorMsg.contains('failed-precondition')) {
          return GlassCard(
            child: Container(
              height: 200,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.build_circle_outlined,
                    color: Color(0xFFF59E0B),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Setting Up Database',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait 2-3 minutes for indexes to build',
                    style: GoogleFonts.outfit(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Force refresh by invalidating provider
                      ref.invalidate(dashboardActiveSessionProvider);
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B0FF),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return GlassCard(
          child: Container(
            height: 200,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFDC2626),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Unable to load session data',
                  style: GoogleFonts.outfit(color: const Color(0xFFDC2626)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(dashboardActiveSessionProvider),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
