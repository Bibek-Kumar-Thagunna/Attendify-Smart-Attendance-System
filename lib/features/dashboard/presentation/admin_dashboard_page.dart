import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:go_router/go_router.dart';
import '../../../core/responsive_utils.dart';
import '../../../core/utils/error_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../features/auth/providers.dart';
import '../../shared/widgets/attendance_chart.dart';
import '../providers.dart';
import '../../admin/backfill_institution_codes.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/background_pattern.dart';
import 'admin_shell.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.read(authControllerProvider).displayName ?? 'Admin';
    final auth = ref.read(authControllerProvider);
    final isSuperAdmin = auth.isSuperAdmin;
    final isMobile = context.isMobile;

    return AdminShell(
      child: BackgroundPattern(
        child: ListView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: _HeroHeader(name: name),
            ),
            // Super Admin Maintenance Tools
            if (isSuperAdmin) ...[
              const SizedBox(height: 24),
              FadeInDown(
                duration: const Duration(milliseconds: 600),
                delay: const Duration(milliseconds: 100),
                child: const _MaintenanceTools(),
              ),
            ],
            const SizedBox(height: 32),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 200),
              child: const _TopStats(),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 300),
              child: const AttendanceChart(),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 400),
              child: const _PendingTeachersCard(),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isMobile;

    return GlassCard(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dashboard_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Admin Dashboard',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome back, $name!',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome back, $name! Monitor attendance, manage institutions, users, and review system analytics.',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PendingTeachersCard extends ConsumerWidget {
  const _PendingTeachersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCountAsync = ref.watch(pendingTeachersCountProvider);
    final pendingListAsync = ref.watch(pendingTeachersListProvider);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pending_actions_rounded,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pending Approvals',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              pendingCountAsync.when(
                data: (pendingCount) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$pendingCount',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          pendingListAsync.when(
            data: (teachers) {
              if (teachers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No pending approvals',
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  ...teachers.map(
                    (teacher) =>
                        _buildPendingTeacherItem(context, ref, teacher),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => context.go('/admin/teachers'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text('View All'),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            error: (error, _) => Center(
              child: ErrorHandler.buildErrorWidget(
                error,
                customMessage: 'Unable to load dashboard data',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTeacherItem(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> teacher,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                child: Text(
                  (teacher['displayName'] as String? ?? 'T')[0].toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teacher['displayName'] as String? ?? 'Unknown',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      teacher['email'] as String? ?? '',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _approveTeacher(context, teacher['id'] as String),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Colors.green),
                    foregroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _rejectTeacher(context, teacher['id'] as String),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Colors.red),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveTeacher(BuildContext context, String teacherId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .update({
            'approved': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'approvedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teacher approved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Unable to approve teacher',
        );
      }
    }
  }

  Future<void> _rejectTeacher(BuildContext context, String teacherId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teacher registration rejected'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Unable to reject teacher',
        );
      }
    }
  }
}

class _TopStats extends ConsumerWidget {
  const _TopStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrations = ref.watch(registrationsTodayCountProvider);
    final sessions = ref.watch(activeSessionsCountProvider);
    final totalUsers = ref.watch(totalUsersCountProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine grid columns based on width - matching Student Dashboard logic
        final width = constraints.maxWidth;
        int crossAxisCount = 4;
        if (width < 1200) crossAxisCount = 3;
        if (width < 900) crossAxisCount = 2;
        // Keep 2 columns on mobile for better density, unless very small
        if (width < 400) crossAxisCount = 2;

        // Match aspect ratio from Student Dashboard, but slightly taller for Admin metrics
        final isMobile = width < 600;
        final childAspectRatio = isMobile
            ? 0.9
            : 1.4; // Made taller (0.9) to fit content without truncation

        final cards = [
          totalUsers.when(
            data: (v) => _FluentMetricCard(
              title: 'Total Users',
              value: '$v',
              subtitle: 'In System',
              icon: Icons.people_alt_rounded,
              color: const Color(0xFF3B82F6),
            ),
            loading: () => const _FluentMetricCard(
              title: 'Total Users',
              value: '—',
              subtitle: 'Loading...',
              icon: Icons.people_alt_rounded,
              color: Color(0xFF3B82F6),
            ),
            error: (e, _) => const _FluentMetricCard(
              title: 'Total Users',
              value: '—',
              subtitle: 'Error',
              icon: Icons.people_alt_rounded,
              color: Color(0xFFEF4444),
            ),
          ),
          registrations.when(
            data: (v) => _FluentMetricCard(
              title: 'New Registrations',
              value: '$v',
              subtitle: 'Today',
              icon: Icons.person_add_rounded,
              color: const Color(0xFF8B5CF6),
            ),
            loading: () => const _FluentMetricCard(
              title: 'New Registrations',
              value: '—',
              subtitle: 'Loading...',
              icon: Icons.person_add_rounded,
              color: Color(0xFF8B5CF6),
            ),
            error: (e, _) => const _FluentMetricCard(
              title: 'New Registrations',
              value: '—',
              subtitle: 'Error',
              icon: Icons.person_add_rounded,
              color: Color(0xFFEF4444),
            ),
          ),
          sessions.when(
            data: (v) => _FluentMetricCard(
              title: 'Active Sessions',
              value: '$v',
              subtitle: 'Right now',
              icon: Icons.qr_code_2_rounded,
              color: const Color(0xFFEC4899),
            ),
            loading: () => const _FluentMetricCard(
              title: 'Active Sessions',
              value: '—',
              subtitle: 'Loading...',
              icon: Icons.qr_code_2_rounded,
              color: Color(0xFFEC4899),
            ),
            error: (e, _) => const _FluentMetricCard(
              title: 'Active Sessions',
              value: '—',
              subtitle: 'Error',
              icon: Icons.qr_code_2_rounded,
              color: Color(0xFFEF4444),
            ),
          ),
          const _SystemStatusCard(),
        ];

        // Build grid
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing:
                16, // Reduced spacing to match Student Dashboard (was 24)
            mainAxisSpacing: 16,
          ),
          itemCount: cards.length,
          itemBuilder: (context, index) => cards[index],
        );
      },
    );
  }
}

class _FluentMetricCard extends StatefulWidget {
  const _FluentMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  State<_FluentMetricCard> createState() => _FluentMetricCardState();
}

class _FluentMetricCardState extends State<_FluentMetricCard> {
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
        child: GlassCard(
          padding: EdgeInsets
              .zero, // Remove padding from GlassCard to allow gradient to fill
          child: Container(
            padding: const EdgeInsets.all(16), // Reduced padding from 24 to 16
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withValues(alpha: 0.1),
                  widget.color.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(
                        10,
                      ), // Reduced icon padding slightly
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.color,
                        size: 20,
                      ), // Reduced icon size from 24
                    ),
                  ],
                ),
                const SizedBox(height: 12), // Ensure some spacing
                Expanded(
                  // Allow column to take available space but not more
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end, // Align bottom
                    children: [
                      FittedBox(
                        // Scale value text if it's too big
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.value,
                          style: GoogleFonts.outfit(
                            fontSize: 28, // Slightly smaller base font
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        // Removed maxLines/overflow to prevent truncation
                      ),
                      Text(
                        widget.subtitle,
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                        // Removed maxLines/overflow to prevent truncation
                      ),
                    ],
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

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF10B981).withValues(alpha: 0.1),
              const Color(0xFF10B981).withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'System Status',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All Systems Operational',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                      fontSize: 13,
                    ),
                    // Removed maxLines/overflow
                  ),
                  Text(
                    'Everything running smoothly',
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                    // Removed maxLines/overflow
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Maintenance Tools Widget (Super Admin Only)
class _MaintenanceTools extends ConsumerStatefulWidget {
  const _MaintenanceTools();

  @override
  ConsumerState<_MaintenanceTools> createState() => _MaintenanceToolsState();
}

class _MaintenanceToolsState extends ConsumerState<_MaintenanceTools> {
  bool _isBackfilling = false;

  Future<void> _runBackfill() async {
    setState(() => _isBackfilling = true);

    try {
      final service = InstitutionCodeBackfillService();
      final result = await service.backfillAll();

      if (!mounted) return;

      final totals = result['totals'] as Map<String, dynamic>;
      final updated = totals['updated'] as int;
      final skipped = totals['skipped'] as int;
      final errors = totals['errors'] as int;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Backfill Complete!\n'
            'Updated: $updated | Skipped: $skipped | Errors: $errors',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Backfill failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isBackfilling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.build_circle_outlined,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Maintenance Tools',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Add missing institutionCode fields to all sessions, scheduled_sessions, and attendance records. This is needed if you see permission errors.',
            style: GoogleFonts.outfit(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isBackfilling ? null : _runBackfill,
            icon: _isBackfilling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(
              _isBackfilling ? 'Running Backfill...' : 'Run Backfill Now',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
