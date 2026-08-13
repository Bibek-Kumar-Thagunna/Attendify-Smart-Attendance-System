import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/widgets/session_timer_card.dart';
import '../../shared/widgets/upcoming_sessions_card.dart';
import '../../shared/widgets/recent_attendance_card.dart';
import '../../shared/widgets/upcoming_session_notification.dart';
import '../../auth/providers.dart';
import 'teacher_shell.dart';
import '../../../core/responsive_utils.dart';
import '../../shared/widgets/shimmer_loading.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    // If logging out or unauthenticated, show loading to prevent empty dashboard flash
    if (authState.role == UserRole.none) {
      return const Scaffold(
        body: Center(
          child: ShimmerLoading(
            isLoading: true,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Skeleton(borderRadius: 16),
            ),
          ),
        ),
      );
    }

    final name = authState.displayName ?? 'Teacher';
    final scheme = Theme.of(context).colorScheme;
    final isMobile = context.isMobile;

    return TeacherShell(
      child: BackgroundPattern(
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            // Auto-start notification banner
            const UpcomingSessionNotification(),

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
                              color: scheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: scheme.primary,
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
                            'Manage your classes, track attendance, and engage with students.',
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
                              onPressed: () => context.go('/teacher/generate'),
                              icon: const Icon(Icons.qr_code_2_rounded),
                              label: const Text('Start Session'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: scheme.primary,
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
                              color: scheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Icon(
                              Icons.school_rounded,
                              color: scheme.primary,
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
                                  'Manage your classes, track attendance, and engage with students.',
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
                            onPressed: () => context.go('/teacher/generate'),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: const Text('Start Session'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: scheme.primary,
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
            const SizedBox(height: 32),

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
                  if (width < 400) columns = 2; // Keep 2 columns on mobile

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: columns,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: isMobile ? 1.0 : 1.5,
                    children: [
                      _QuickActionCard(
                        icon: Icons.people_alt_rounded,
                        title: 'Students',
                        subtitle: 'Manage list',
                        color: const Color(0xFF3B82F6),
                        onTap: () => context.go('/teacher/students'),
                      ),
                      _QuickActionCard(
                        icon: Icons.book_rounded,
                        title: 'Subjects',
                        subtitle: 'View subjects',
                        color: const Color(0xFF8B5CF6),
                        onTap: () => context.go('/teacher/subjects'),
                      ),
                      _QuickActionCard(
                        icon: Icons.fact_check_rounded,
                        title: 'Attendance',
                        subtitle: 'View records',
                        color: const Color(0xFF10B981),
                        onTap: () => context.go('/teacher/attendance'),
                      ),
                      _QuickActionCard(
                        icon: Icons.file_download_rounded,
                        title: 'Reports',
                        subtitle: 'Export data',
                        color: const Color(0xFFF59E0B),
                        onTap: () => context.go('/teacher/exports'),
                      ),
                      _QuickActionCard(
                        icon: Icons.edit_calendar_rounded,
                        title: 'Manual',
                        subtitle: 'Mark attendance',
                        color: const Color(0xFFEC4899),
                        onTap: () => context.go('/teacher/manual-attendance'),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Session Timer & Upcoming Sessions
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 200),
              child: isMobile
                  ? Column(
                      children: [
                        const SessionTimerCard(),
                        const SizedBox(height: 16),
                        const UpcomingSessionsCard(),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: SessionTimerCard()),
                        const SizedBox(width: 24),
                        const Expanded(child: UpcomingSessionsCard()),
                      ],
                    ),
            ),
            const SizedBox(height: 32),

            // Recent Attendance
            FadeInUp(
              duration: const Duration(milliseconds: 500),
              delay: const Duration(milliseconds: 300),
              child: const RecentAttendanceCard(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
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
