import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../../core/responsive_utils.dart';
import '../../../core/utils/error_handler.dart';
import '../../shared/widgets/attendance_chart.dart';
import 'admin_shell.dart';
import 'analytics_providers.dart';

class AdminAnalyticsPage extends ConsumerWidget {
  const AdminAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell(
      child: ListView(
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: _buildHeader(context),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 100),
            child: _buildOverviewCards(context, ref),
          ),
          const SizedBox(height: 24),
          FadeInUp(
            duration: const Duration(milliseconds: 500),
            delay: const Duration(milliseconds: 200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Stack vertically on mobile and tablet
                if (constraints.maxWidth < Breakpoints.desktop) {
                  return Column(
                    children: [
                      const AttendanceChart(),
                      const SizedBox(height: 20),
                      _buildRecentActivity(context, ref),
                    ],
                  );
                }

                // Side-by-side on desktop
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(flex: 2, child: AttendanceChart()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildRecentActivity(context, ref)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isMobile = context.isMobile;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            const Color(0xFF1E293B),
          ],
        ),
      ),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.analytics_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: isMobile ? 24 : 32,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white, // White text
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Monitor attendance trends, user activity, and system performance in real-time.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(
                        alpha: 0.7,
                      ), // Light white text
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;

    // Watch providers individually
    final activeSessionsAsync = ref.watch(activeSessionsCountProvider);
    final todaySessionsAsync = ref.watch(todaySessionsCountProvider);
    final totalStatsAsync = ref.watch(totalStatsProvider);
    final attendanceStatsAsync = ref.watch(attendanceStatsProvider);

    // Helper to extract data safely
    final activeSessions = activeSessionsAsync.asData?.value ?? 0;
    final todaySessions = todaySessionsAsync.asData?.value ?? 0;
    final totalStudents = totalStatsAsync.asData?.value.students ?? 0;
    final totalSessions = totalStatsAsync.asData?.value.sessions ?? 0;
    final totalAttendance =
        attendanceStatsAsync.asData?.value.totalRecords ?? 0;
    final avgAttendance =
        attendanceStatsAsync.asData?.value.avgPerSession ?? 0.0;

    // Define all cards data
    final cards = [
      _MetricCardData(
        title: 'Total Students',
        value: totalStatsAsync.isLoading ? '...' : totalStudents.toString(),
        subtitle: 'Registered students',
        icon: Icons.people,
        color: const Color(0xFF3B82F6),
      ),
      _MetricCardData(
        title: 'Total Sessions',
        value: totalStatsAsync.isLoading ? '...' : totalSessions.toString(),
        subtitle: '$todaySessions created today',
        icon: Icons.event,
        color: const Color(0xFF8B5CF6),
      ),
      _MetricCardData(
        title: 'Active Sessions',
        value: activeSessionsAsync.isLoading
            ? '...'
            : activeSessions.toString(),
        subtitle: 'Running right now',
        icon: Icons.qr_code_scanner,
        color: const Color(0xFF10B981),
      ),
      _MetricCardData(
        title: 'Total Attendance',
        value: attendanceStatsAsync.isLoading
            ? '...'
            : totalAttendance.toString(),
        subtitle: 'Records across all sessions',
        icon: Icons.check_circle,
        color: const Color(0xFF16A34A),
      ),
      _MetricCardData(
        title: 'Avg per Session',
        value: attendanceStatsAsync.isLoading
            ? '...'
            : avgAttendance.toStringAsFixed(1),
        subtitle: 'Students per session',
        icon: Icons.trending_up,
        color: const Color(0xFF06B6D4),
      ),
    ];

    if (isMobile) {
      // Mobile: 2 columns grid
      return Column(
        children: [
          for (int i = 0; i < cards.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(context: context, data: cards[i]),
                  ),
                  const SizedBox(width: 16),
                  if (i + 1 < cards.length)
                    Expanded(
                      child: _buildMetricCard(
                        context: context,
                        data: cards[i + 1],
                      ),
                    )
                  else
                    const Spacer(),
                ],
              ),
            ),
        ],
      );
    }

    // Desktop: Grid with equal sized cards
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        return _buildMetricCard(context: context, data: cards[index]);
      },
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required _MetricCardData data,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark background for better contrast
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data.value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white, // White text for better contrast
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9), // White text
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(
                alpha: 0.6,
              ), // Light white text for subtitle
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Dark background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Sessions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white, // White text
                  ),
                ),
              ),
              Icon(
                Icons.history,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          activityAsync.when(
            data: (activities) {
              if (activities.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No recent activity',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: activities.length,
                separatorBuilder: (_, __) => Divider(
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return _buildActivityItem(context, activity);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => ErrorHandler.buildErrorWidget(
              error,
              customMessage: 'Unable to load stats',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(BuildContext context, ActivityItem activity) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: activity.isActive
                ? const Color(0xFF10B981).withValues(alpha: .1)
                : const Color(0xFF64748B).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            activity.isActive ? Icons.play_circle : Icons.check_circle,
            color: activity.isActive
                ? const Color(0xFF10B981)
                : const Color(0xFF64748B),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.subject,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.white, // White text
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'by ${activity.teacherName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(
                    alpha: 0.6,
                  ), // Light white text
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${activity.attendanceCount} attended',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(
                        alpha: 0.5,
                      ), // Light white text
                    ),
                  ),
                  if (activity.timestamp != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${_formatTimestamp(activity.timestamp!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(
                          alpha: 0.5,
                        ), // Light white text
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (activity.isActive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }
}

class _MetricCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  _MetricCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
