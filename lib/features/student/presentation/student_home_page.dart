import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/widgets/attendance_progress_card.dart';
import '../../auth/providers.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import 'student_shell.dart';
import '../../../core/responsive_utils.dart';
import '../../student/providers.dart';
import '../../shared/widgets/shimmer_loading.dart';

class StudentHomePage extends ConsumerWidget {
  const StudentHomePage({super.key});

  @override
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    // If logging out or unauthenticated, show loading to prevent empty dashboard flash
    if (authState.role == UserRole.none) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final name = authState.displayName ?? 'Student';
    final theme = Theme.of(context);
    final isMobile = context.isMobile;

    return StudentShell(
      child: BackgroundPattern(
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            // Hero Header
            FadeInDown(
              duration: const Duration(milliseconds: 800),
              child: GlassCard(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                child: isMobile
                    ? Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome back, $name! 👋',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Mark your attendance, track your progress, and stay updated.',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => context.go('/student/scan'),
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              label: const Text('Scan QR'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                textStyle: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: theme.colorScheme.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back, $name! 👋',
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Mark your attendance, track your progress, and stay updated.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.go('/student/scan'),
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text('Scan QR'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              textStyle: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Low Attendance Warning
            const _LowAttendanceWarning(),

            // Quick Actions Grid
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 100),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int columns = 4;
                  if (width < 1200) columns = 3;
                  if (width < 900) columns = 2;
                  // Keep 2 columns on mobile for better density, unless very small
                  if (width < 400) columns = 2;

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: isMobile
                        ? 1.1
                        : 1.5, // Taller cards on mobile
                    children: [
                      _ActionCard(
                        title: 'Attendance',
                        subtitle: 'History',
                        icon: Icons.history_rounded,
                        color: const Color(0xFF3B82F6),
                        onTap: () => context.go('/student/history'),
                      ),
                      _ActionCard(
                        title: 'Summary',
                        subtitle: 'Monthly',
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.go('/student/summary'),
                      ),
                      _ActionCard(
                        title: 'Alerts',
                        subtitle: 'Updates',
                        icon: Icons.notifications_rounded,
                        color: const Color(0xFFF59E0B),
                        onTap: () => context.go('/student/notifications'),
                      ),
                      _ActionCard(
                        title: 'Profile',
                        subtitle: 'Account',
                        icon: Icons.person_rounded,
                        color: const Color(0xFF10B981),
                        onTap: () => context.go('/student/profile'),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Attendance Progress
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 200),
              child: const AttendanceProgressCard(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.diagonal3Values(
          _isHovered ? 1.02 : 1.0,
          _isHovered ? 1.02 : 1.0,
          1.0,
        ),
        child: GestureDetector(
          onTap: widget.onTap,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 28),
                ),
                const Spacer(),
                Text(
                  widget.title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LowAttendanceWarning extends ConsumerWidget {
  const _LowAttendanceWarning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(studentSubjectsWithStatsProvider);

    return subjectsAsync.when(
      data: (subjects) {
        final lowAttendanceSubjects = subjects.where((s) {
          final stats = s['stats'] as Map<String, dynamic>?;
          if (stats == null) return false;
          final percentage = stats['percentage'] as double? ?? 0.0;
          final total = stats['total'] as int? ?? 0;
          // Only warn if they have attended at least a few sessions to avoid noise at start of semester
          return total > 2 && percentage < 75.0;
        }).toList();

        if (lowAttendanceSubjects.isEmpty) return const SizedBox.shrink();

        return FadeInDown(
          duration: const Duration(milliseconds: 600),
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Attendance Alert',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your attendance is below 75% in the following subjects:',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...lowAttendanceSubjects.map((s) {
                  final stats = s['stats'] as Map<String, dynamic>;
                  final percentage = stats['percentage'] as double;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '• ${s['name']}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => ShimmerLoading(
        isLoading: true,
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
