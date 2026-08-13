import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/error_handler.dart';
import '../../teacher/providers.dart';
import '../../teacher/presentation/teacher_subjects_page.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_text_field.dart';

class GenerateQrPage extends ConsumerStatefulWidget {
  const GenerateQrPage({
    super.key,
    this.initialSubject,
    this.initialDuration,
    this.initialRadius,
    this.scheduledSessionId,
  });

  final String? initialSubject;
  final int? initialDuration;
  final double? initialRadius;
  final String? scheduledSessionId;

  @override
  ConsumerState<GenerateQrPage> createState() => _GenerateQrPageState();
}

class _GenerateQrPageState extends ConsumerState<GenerateQrPage> {
  String? _selectedSubject;
  late final TextEditingController _durationController;
  late final TextEditingController _radiusController;
  String? _error;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _selectedSubject = widget.initialSubject;
    _durationController = TextEditingController(
      text: (widget.initialDuration ?? 10).toString(),
    );
    _radiusController = TextEditingController(
      text: (widget.initialRadius ?? 50).toString(),
    );
  }

  @override
  void dispose() {
    _durationController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    setState(() {
      _error = null;
      _requesting = true;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _error = 'Location services are disabled.');
        return;
      }
      if (!kIsWeb) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() => _error = 'Location permission denied.');
          return;
        }
      }

      final LocationSettings locationSettings = kIsWeb
          ? const LocationSettings(accuracy: LocationAccuracy.high)
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 100,
            );

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      bool bypassLocation = false;

      // Check accuracy
      if (pos.accuracy > 100) {
        if (mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text(
                'Weak Location Signal',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
              content: Text(
                'Your location accuracy is poor (${pos.accuracy.toStringAsFixed(0)} meters). '
                'This usually happens on desktops without GPS/Wi-Fi.\n\n'
                'Students will likely fail the location check.\n'
                'Do you want to proceed and BYPASS location checks for this session?',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                  ),
                  child: const Text('Proceed & Bypass'),
                ),
              ],
            ),
          );

          if (proceed != true) {
            setState(() => _requesting = false);
            return;
          }
          bypassLocation = true;
        }
      }

      final duration = Duration(
        minutes: int.tryParse(_durationController.text) ?? 10,
      );
      final radius = double.tryParse(_radiusController.text) ?? 50;
      final subjectStr = _selectedSubject;
      String? subjectName;
      String? groupName;

      if (subjectStr != null) {
        final match = RegExp(r'^(.+) \((.+)\)$').firstMatch(subjectStr);
        if (match != null) {
          subjectName = match.group(1)?.trim();
          groupName = match.group(2)?.trim();
        } else {
          subjectName = subjectStr;
        }
      }

      await ref
          .read(activeSessionProvider.notifier)
          .startSession(
            latitude: pos.latitude,
            longitude: pos.longitude,
            duration: duration,
            radiusMeters: radius,
            subject: subjectName,
            group: groupName,
            bypassLocation: bypassLocation,
            scheduledSessionId: widget.scheduledSessionId,
          );
    } on ConflictingSessionException catch (e) {
      if (mounted) {
        setState(() => _requesting = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Session Already Running',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Currently, the session of ${e.subjectName} is running for ${e.group}.',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Started by: ${e.teacherName}',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You cannot start a new session for this group until the current session ends.',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      }
      return;
    } catch (e) {
      setState(() => _error = 'Failed to get location: $e');
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeSessionProvider);
    final controller = ref.read(activeSessionProvider.notifier);
    final timeLeft = controller.timeLeft();
    final code = controller.currentDynamicCode();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Start Session',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: BackgroundPattern(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(
                top: 80,
                bottom: 24,
                left: 24,
                right: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 104,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: active == null
                        ? GlassCard(
                            padding: const EdgeInsets.all(32),
                            child: kIsWeb
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF8B5CF6,
                                          ).withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.phonelink_ring_rounded,
                                          size: 64,
                                          color: Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Text(
                                        'Use Mobile App to Start Session',
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'To ensure accurate location tracking, please start the session from the Attendify Mobile App on your phone.',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          color: Colors.white70,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      FilledButton.icon(
                                        onPressed: () async {
                                          final uri = Uri.parse(
                                            'https://drive.google.com/uc?export=download&id=1Ml0hlqjI1YckzSO89aKw3ymBwckjMSR5',
                                          );
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.download_rounded,
                                        ),
                                        label: const Text('Download APK'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF10B981,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.05,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.info_outline_rounded,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                'Once you start the session on your phone, the QR code will automatically appear here for students to scan.',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF8B5CF6),
                                                  Color(0xFF7C3AED),
                                                ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.qr_code_2_rounded,
                                              color: Colors.white,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Create New Session',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Generate a QR code for students to scan',
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
                                      const SizedBox(height: 32),
                                      _buildSubjectDropdown(context, ref),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GlassTextField(
                                              controller: _durationController,
                                              label: 'Duration (min)',
                                              prefixIcon: Icons.timer_outlined,
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: GlassTextField(
                                              controller: _radiusController,
                                              label: 'Radius (m)',
                                              prefixIcon:
                                                  Icons.location_on_outlined,
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 32),
                                      SizedBox(
                                        height: 50,
                                        child: ElevatedButton.icon(
                                          onPressed: _requesting
                                              ? null
                                              : _startSession,
                                          icon: _requesting
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.play_arrow_rounded,
                                                ),
                                          label: Text(
                                            _requesting
                                                ? 'Starting Session...'
                                                : 'Start Session',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF8B5CF6,
                                            ),
                                            foregroundColor: Colors.white,
                                            textStyle: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 24),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFEF4444,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFFEF4444,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.error_outline,
                                                color: Color(0xFFEF4444),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  _error!,
                                                  style: GoogleFonts.outfit(
                                                    color: const Color(
                                                      0xFFEF4444,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassCard(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF10B981),
                                            Color(0xFF059669),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Session Active',
                                                style: GoogleFonts.outfit(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (timeLeft != null)
                                                Text(
                                                  'Expires in ${timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(timeLeft.inSeconds.remainder(60)).toString().padLeft(2, '0')}',
                                                  style: GoogleFonts.outfit(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    if (code != null)
                                      Container(
                                        padding: const EdgeInsets.all(24),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.2,
                                              ),
                                              blurRadius: 30,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: QrImageView(
                                          data: code,
                                          size: 280,
                                          backgroundColor: Colors.white,
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.refresh_rounded,
                                          size: 16,
                                          color: Colors.white54,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Code refreshes every 5 seconds',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 16,
                                        runSpacing: 8,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: Color(0xFF8B5CF6),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Lat: ${active.latitude.toStringAsFixed(5)}, Lng: ${active.longitude.toStringAsFixed(5)}',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.radar,
                                                size: 16,
                                                color: Color(0xFF8B5CF6),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Radius: ${active.radiusMeters.toStringAsFixed(0)} m',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 50,
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => ref
                                      .read(activeSessionProvider.notifier)
                                      .endSession(),
                                  icon: const Icon(Icons.stop_circle_outlined),
                                  label: const Text('End Session'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    textStyle: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
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
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSubjectDropdown(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      data: (groupedSubjects) {
        final allSubjects = <Map<String, dynamic>>[];
        for (final typeGroups in groupedSubjects.values) {
          for (final subjects in typeGroups.values) {
            allSubjects.addAll(subjects);
          }
        }

        if (allSubjects.isEmpty) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Subjects Added',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please add subjects in the Subjects page first',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedSubject,
              dropdownColor: const Color(0xFF1E293B),
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              hint: Row(
                children: [
                  const Icon(
                    Icons.book_outlined,
                    size: 20,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Select Subject',
                    style: GoogleFonts.outfit(color: Colors.white70),
                  ),
                ],
              ),
              items: allSubjects.map((subject) {
                final name = subject['name'] ?? 'Untitled';
                final group = subject['group'] ?? 'No Group';
                final type = subject['type'] ?? 'Lecture';
                final displayText = '$name ($group)';

                final isLab = type == 'Lab';
                final typeColor = isLab
                    ? const Color(0xFF10B981)
                    : const Color(0xFF3B82F6);
                final typeIcon = isLab
                    ? Icons.science_outlined
                    : Icons.school_outlined;

                return DropdownMenuItem<String>(
                  value: displayText,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayText,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: typeColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading subjects...',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
          ],
        ),
      ),
      error: (error, _) => ErrorHandler.buildErrorWidget(
        error,
        customMessage: 'Unable to load subjects',
      ),
    );
  }
}
