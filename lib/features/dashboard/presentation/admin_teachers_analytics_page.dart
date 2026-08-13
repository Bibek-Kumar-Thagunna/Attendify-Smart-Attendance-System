import 'package:flutter/material.dart';
import '../../shared/widgets/safe_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/fluent_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/responsive_utils.dart';
import '../../auth/providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'admin_shell.dart';

// Provider for teachers with analytics - RBAC SCOPED
final teachersWithAnalyticsProvider = StreamProvider<List<TeacherAnalytics>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);

  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin && auth.institutionCode != null) {
    // Institution Admin: Only see teachers from their institution
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  }
  // Super Admin: See all teachers

  q = q.where('role', isEqualTo: 'teacher').where('approved', isEqualTo: true);

  return q.snapshots().asyncMap((snapshot) async {
    final teachers = <TeacherAnalytics>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      // Get session count
      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .where('teacherUid', isEqualTo: doc.id)
          .get();

      // OPTIMIZATION: Removed expensive attendance count calculation (N+1 query).
      // We only show session count for list performance.

      teachers.add(
        TeacherAnalytics(
          id: doc.id,
          displayName: data['displayName'] as String? ?? 'Unknown',
          email: data['email'] as String? ?? '',
          idNumber: (data['idNumber'] ?? data['rollNumber'] ?? 'N/A')
              .toString(),
          approved: data['approved'] as bool? ?? false,
          createdAt: _parseTimestamp(data['createdAt']),
          totalSessions: sessionsSnapshot.docs.length,
          photoUrl: data['photoUrl'] as String?,
        ),
      );
    }

    // Sort by name
    teachers.sort((a, b) => a.displayName.compareTo(b.displayName));

    return teachers;
  });
});

DateTime? _parseTimestamp(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is Timestamp) return timestamp.toDate();
  if (timestamp is String) return DateTime.tryParse(timestamp);
  return null;
}

class TeacherAnalytics {
  final String id;
  final String displayName;
  final String email;
  final String idNumber;
  final bool approved;
  final DateTime? createdAt;
  final int totalSessions;
  final String? photoUrl;

  TeacherAnalytics({
    required this.id,
    required this.displayName,
    required this.email,
    required this.idNumber,
    required this.approved,
    this.createdAt,
    required this.totalSessions,
    this.photoUrl,
  });
}

class AdminTeachersAnalyticsPage extends ConsumerStatefulWidget {
  const AdminTeachersAnalyticsPage({super.key});

  @override
  ConsumerState<AdminTeachersAnalyticsPage> createState() =>
      _AdminTeachersAnalyticsPageState();
}

class _AdminTeachersAnalyticsPageState
    extends ConsumerState<AdminTeachersAnalyticsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersWithAnalyticsProvider);

    return AdminShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildFilters(),
          const SizedBox(height: 24),
          Expanded(
            child: teachersAsync.when(
              data: (teachers) => _buildTeachersList(teachers),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => ErrorHandler.buildErrorWidget(
                error,
                customMessage: 'Unable to load teacher analytics',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: ResponsiveBuilder(
        builder: (context, isMobile, isTablet, isDesktop) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.1),
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
                    ).colorScheme.primary.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.school_rounded,
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
                        'Teacher Analytics',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (!isMobile) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Review teacher performance and attendance statistics.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 100),
      child: TextField(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: 'Search teachers by name, email, or ID...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFF1E293B),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTeachersList(List<TeacherAnalytics> teachers) {
    // Apply filters
    final filteredTeachers = teachers.where((teacher) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!teacher.displayName.toLowerCase().contains(query) &&
            !teacher.email.toLowerCase().contains(query) &&
            !teacher.idNumber.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Status filter - removed as we only show approved
      // if (_filterStatus == 'pending' && teacher.approved) return false;
      // if (_filterStatus == 'approved' && !teacher.approved) return false;

      return true;
    }).toList();

    if (filteredTeachers.isEmpty) {
      return FadeIn(
        child: Card(
          child: EmptyState(
            icon: Icons.school_outlined,
            title: 'No Teachers Found',
            subtitle: _searchQuery.isNotEmpty
                ? 'Try adjusting your search or filters'
                : 'Teachers will appear here once they register',
            color: FluentColors.info,
          ),
        ),
      );
    }

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 200),
      child: ListView.builder(
        itemCount: filteredTeachers.length,
        itemBuilder: (context, index) {
          return _buildTeacherCard(filteredTeachers[index]);
        },
      ),
    );
  }

  Widget _buildTeacherCard(TeacherAnalytics teacher) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                SafeAvatar(
                  imageUrl: teacher.photoUrl,
                  name: teacher.displayName,
                  radius: 28,
                  backgroundColor: scheme.primary.withValues(alpha: .15),
                  foregroundColor: scheme.primary,
                ),
                const SizedBox(width: 16),
                // Teacher Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              teacher.displayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        teacher.email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        'ID: ${teacher.idNumber}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'details') {
                      _showTeacherDetails(teacher);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'View Details',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Statistics
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.event,
                      label: 'Sessions',
                      value: teacher.totalSessions.toString(),
                      color: const Color(0xFF3B82F6),
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showTeacherDetails(TeacherAnalytics teacher) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          teacher.displayName,
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Email', teacher.email),
              _buildDetailRow('ID Number', teacher.idNumber),
              _buildDetailRow('Status', 'Approved'),
              _buildDetailRow(
                'Total Sessions',
                teacher.totalSessions.toString(),
              ),
              if (teacher.createdAt != null)
                _buildDetailRow(
                  'Joined',
                  DateFormat(
                    'MMMM dd, yyyy at hh:mm a',
                  ).format(teacher.createdAt!),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
