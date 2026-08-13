import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/fluent_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../auth/providers.dart';
import '../../teacher/providers.dart';

// Provider to get the next session starting soon
final nextSessionProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth.uid == null) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('scheduled_sessions')
      .where('teacherUid', isEqualTo: auth.uid)
      .snapshots()
      .map((snap) {
        final now = DateTime.now();

        // Find sessions within next 5 minutes
        for (final doc in snap.docs) {
          final data = doc.data();
          final scheduledForRaw = data['scheduledFor'];

          if (scheduledForRaw is Timestamp) {
            final scheduledFor = scheduledForRaw.toDate();
            final difference = scheduledFor.difference(now);

            // Show notification if within 5 minutes
            if (difference.inMinutes >= 0 && difference.inMinutes <= 5) {
              return {'id': doc.id, ...data};
            }
          }
        }

        return null;
      });
});

class UpcomingSessionNotification extends ConsumerStatefulWidget {
  const UpcomingSessionNotification({super.key});

  @override
  ConsumerState<UpcomingSessionNotification> createState() =>
      _UpcomingSessionNotificationState();
}

class _UpcomingSessionNotificationState
    extends ConsumerState<UpcomingSessionNotification> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    // Update every second for countdown
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  String _getCountdown(DateTime scheduledFor) {
    final now = DateTime.now();
    final difference = scheduledFor.difference(now);

    if (difference.isNegative) {
      return 'Starting now...';
    }

    final minutes = difference.inMinutes;
    final seconds = difference.inSeconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _startNow(Map<String, dynamic> session) async {
    try {
      // Check location permission
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled')),
          );
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }

      // Get current position
      final pos = await Geolocator.getCurrentPosition();

      // Start session
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

      // Delete the scheduled session
      await FirebaseFirestore.instance
          .collection('scheduled_sessions')
          .doc(session['id'])
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Started session: ${subject ?? "Session"}'),
            backgroundColor: FluentColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Unable to start session',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nextSessionAsync = ref.watch(nextSessionProvider);
    final activeSession = ref.watch(activeSessionProvider);

    // Don't show if already has an active session
    if (activeSession != null) return const SizedBox.shrink();

    return nextSessionAsync.when(
      data: (session) {
        if (session == null) return const SizedBox.shrink();

        final scheduledForRaw = session['scheduledFor'];
        if (scheduledForRaw is! Timestamp) return const SizedBox.shrink();

        final scheduledFor = scheduledForRaw.toDate();
        final now = DateTime.now();
        final difference = scheduledFor.difference(now);

        // Auto-hide if more than 5 minutes away
        if (difference.inMinutes > 5) return const SizedBox.shrink();

        final countdown = _getCountdown(scheduledFor);
        final isUrgent = difference.inMinutes < 2;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isUrgent
                      ? [const Color(0xFFEF4444), const Color(0xFFF59E0B)]
                      : [const Color(0xFF3B82F6), const Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (isUrgent ? Colors.red : Colors.blue).withValues(
                      alpha: 0.3,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isUrgent ? Icons.alarm : Icons.schedule,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['subject'] ?? 'Upcoming Session',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isUrgent
                              ? 'Starting in $countdown - Tap to start'
                              : 'Starts at ${DateFormat('h:mm a').format(scheduledFor)} • $countdown',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _startNow(session),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Start Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: isUrgent
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
