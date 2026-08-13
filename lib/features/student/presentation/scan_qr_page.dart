import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../student/models/attendance_record.dart';
import '../../student/providers.dart';
import '../../auth/providers.dart';
import '../../attendance/providers.dart';
import '../../notifications/repository.dart';
import '../../notifications/providers.dart';
import '../../shared/providers.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../shared/widgets/glass_card.dart';
import 'package:google_fonts/google_fonts.dart';

class ScanQrPage extends ConsumerStatefulWidget {
  const ScanQrPage({super.key});

  @override
  ConsumerState<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends ConsumerState<ScanQrPage> {
  bool _handled = false;
  String? _message;
  Color? _messageColor;
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_handled) return;
    final barcode = capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
    if (barcode == null || barcode.rawValue == null) return;
    _handled = true;

    final raw = barcode.rawValue!;
    final parts = raw.split(':');
    String result = 'Rejected';
    String note = '';
    String subject = 'Attendance Session';
    try {
      if (parts.length < 2) {
        note = 'Invalid code.';
      } else {
        final sessionId = parts.first;
        final slotStr = parts[1];
        final nowSlot = DateTime.now().millisecondsSinceEpoch ~/ 5000;
        final codeSlot = int.tryParse(slotStr) ?? -1;
        if ((codeSlot - nowSlot).abs() > 1) {
          note = 'QR code outdated. Please rescan.';
          throw Exception(note);
        }
        final repo = ref.read(attendanceRepositoryProvider);
        final data = await repo.getSession(sessionId);
        if (data == null) {
          note = 'Session not found.';
          throw Exception(note);
        }
        // Get subject from session data
        subject = (data['subject'] as String?) ?? 'Attendance Session';
        final group = (data['group'] as String?) ?? '';

        // Enforce Group Enrollment
        if (group.isNotEmpty && group != 'No Group') {
          // Aggressive normalization: remove ALL whitespace and lowercase
          String normalize(String s) =>
              s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

          final sessionGroupClean = normalize(group);

          // Fetch enrolled groups (resolve IDs to Names)
          // We use the cached data from the watched provider (see build method)
          // This avoids "provider disposed" errors and ensures we have the latest data.
          final enrolledGroupsAsync = ref.read(studentClassGroupsProvider);

          final enrolledClassGroups = enrolledGroupsAsync.value ?? [];

          // If data is still loading or error, we might want to wait or fail gracefully.
          // But since we watch it in build, it should be loading as soon as the page opens.
          if (enrolledClassGroups.isEmpty && enrolledGroupsAsync.isLoading) {
            note =
                'Verifying enrollment... Please wait a moment and try again.';
            throw Exception(note);
          }

          final enrolledGroupNames = enrolledClassGroups
              .map((g) => normalize(g.name))
              .toList();

          if (!enrolledGroupNames.contains(sessionGroupClean)) {
            note = 'You are not enrolled in group "$group".';
            throw Exception(note);
          }
        }

        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
        final active = (data['active'] as bool?) ?? false;
        if (!active || expiresAt == null || DateTime.now().isAfter(expiresAt)) {
          note = 'Session expired.';
          throw Exception(note);
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          note = 'Location denied.';
        } else {
          final pos = await Geolocator.getCurrentPosition();
          final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
          final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
          final radius = (data['radiusMeters'] as num?)?.toDouble() ?? 0;
          final bypassLocation = (data['bypassLocation'] as bool?) ?? false;

          final distance = Geolocator.distanceBetween(
            lat,
            lng,
            pos.latitude,
            pos.longitude,
          );

          if (bypassLocation || distance <= radius + 2.0) {
            result = 'Present';
            final rollNumber =
                ref.read(authControllerProvider).rollNumber ?? '';
            final idNumber =
                rollNumber; // User confirmed ID and Roll Number are the same/reflected
            if (idNumber.isEmpty) {
              note = 'No ID/Roll number on profile. Complete onboarding.';
              throw Exception(note);
            }
            await repo.markAttendancePresent(
              sessionId: sessionId,
              idNumber: idNumber,
              rollNumber: rollNumber,
              distanceMeters: distance,
            );
            note = bypassLocation
                ? 'Location check bypassed by teacher (${distance.toStringAsFixed(1)} m)'
                : 'Marked within ${distance.toStringAsFixed(1)} m';
          } else {
            note =
                'Too far (${distance.toStringAsFixed(1)} m > ${radius.toStringAsFixed(0)} m)';

            // Send notification to teacher
            final teacherUid = data['teacherUid'] as String?;
            if (teacherUid != null) {
              final student = ref.read(authControllerProvider);
              final notificationRepo = ref.read(notificationRepositoryProvider);

              final notification = NotificationModel(
                id: '', // Firestore will generate ID
                recipientUid: teacherUid,
                senderUid: student.uid ?? 'unknown',
                senderName: student.displayName ?? 'Unknown Student',
                senderRollNumber: student.rollNumber ?? 'Unknown Roll No',
                title: 'Location Violation Attempt',
                message:
                    '${student.displayName} attempted to mark attendance from ${distance.toStringAsFixed(1)}m away (Allowed: ${radius.toStringAsFixed(0)}m).',
                type: 'location_violation',
                timestamp: DateTime.now(),
                read: false,
                metadata: {
                  'sessionId': sessionId,
                  'subject': subject,
                  'distance': distance,
                  'radius': radius,
                  'latitude': pos.latitude,
                  'longitude': pos.longitude,
                },
              );

              // Fire and forget - don't block UI
              notificationRepo.createNotification(notification);
            }
          }
        }
      }
    } catch (e) {
      // note variable already contains user-friendly message from specific error cases above
      // Don't expose technical error to user
    }

    ref
        .read(attendanceListProvider.notifier)
        .add(
          AttendanceRecord(
            sessionId: parts.isNotEmpty ? parts.first : 'unknown',
            timestamp: DateTime.now(),
            subject: subject,
            result: result,
            locationNote: note,
          ),
        );

    if (result == 'Present') {
      if (mounted) {
        _showSuccessDialog(context);
      }
    } else {
      setState(() {
        _message = 'Scan failed: $note';
        _messageColor = Colors.red;
      });
      _clearTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _message = null;
            _handled = false;
          });
        }
      });
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 64,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Attendance Marked!',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You have been marked present.',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    // Navigate back after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close dialog
        context.go('/student'); // Go to dashboard
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider to keep it alive and ensure data is loaded
    ref.watch(studentClassGroupsProvider);

    // Check for Web or Desktop
    final isDesktopOrWeb =
        kIsWeb || (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    if (isDesktopOrWeb) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Scan QR Code',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mobile_friendly,
                    size: 64,
                    color: Colors.white54,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Use Mobile App',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  Text(
                    'Scanning QR codes is only available on the mobile app.\nPlease use your phone to mark attendance.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                        'https://drive.google.com/uc?export=download&id=1Ml0hlqjI1YckzSO89aKw3ymBwckjMSR5',
                      );
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Download APK'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.noDuplicates,
              facing: CameraFacing.back,
              torchEnabled: false,
            ),
            onDetect: _handleBarcode,
          ),

          // Glass Overlay Frame
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Scan QR Code',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance spacing
                    ],
                  ),
                ),
                const Spacer(),
                // Scanner Frame
                Center(
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Stack(
                      children: [
                        // Corner Accents
                        Positioned(
                          top: 0,
                          left: 0,
                          child: _Corner(color: const Color(0xFF8B5CF6)),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Transform.rotate(
                            angle: 1.57,
                            child: _Corner(color: const Color(0xFF8B5CF6)),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Transform.rotate(
                            angle: -1.57,
                            child: _Corner(color: const Color(0xFF8B5CF6)),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Transform.rotate(
                            angle: 3.14,
                            child: _Corner(color: const Color(0xFF8B5CF6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    'Align QR code within the frame',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          if (_message != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: _messageColor ?? Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _message!,
                        style: GoogleFonts.outfit(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final Color color;
  const _Corner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: color, width: 4),
          left: BorderSide(color: color, width: 4),
        ),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
      ),
    );
  }
}
