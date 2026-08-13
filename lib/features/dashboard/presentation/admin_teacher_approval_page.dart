import 'package:flutter/material.dart';
import '../../shared/widgets/safe_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/responsive_utils.dart';
import '../../../core/services/email_service.dart';
import '../../../core/constants/email_constants.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/empty_state.dart';
import '../../auth/providers.dart';
import 'admin_shell.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_text_field.dart';

// Provider for pending teachers (not approved) - RBAC SCOPED
final pendingTeachersProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);

  // Institution Admin: Only see pending teachers from their institution
  // Super Admin: See all pending teachers
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin && auth.institutionCode != null) {
    // Institution Admin: Scope to their institution
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  }
  // Super Admin: No institution filter - see all

  // Filter for pending teachers (role = teacher AND approved = false)
  q = q.where('role', isEqualTo: 'teacher').where('approved', isEqualTo: false);

  return q.snapshots().map(
    (snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
  );
});

// Provider for approved teachers - RBAC SCOPED
final approvedTeachersProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  final auth = ref.watch(authControllerProvider);

  // Institution Admin: Only see approved teachers from their institution
  // Super Admin: See all approved teachers
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    'users',
  );

  if (!auth.isSuperAdmin && auth.institutionCode != null) {
    // Institution Admin: Scope to their institution
    q = q.where('institutionCode', isEqualTo: auth.institutionCode);
  }
  // Super Admin: No institution filter - see all

  // Filter for approved teachers (role = teacher AND approved = true)
  q = q.where('role', isEqualTo: 'teacher').where('approved', isEqualTo: true);

  return q.snapshots().map(
    (snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
  );
});

class AdminTeacherApprovalPage extends ConsumerStatefulWidget {
  const AdminTeacherApprovalPage({super.key});

  @override
  ConsumerState<AdminTeacherApprovalPage> createState() =>
      _AdminTeacherApprovalPageState();
}

class _AdminTeacherApprovalPageState
    extends ConsumerState<AdminTeacherApprovalPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      child: BackgroundPattern(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < Breakpoints.mobile;

                    if (isMobile) {
                      // Mobile: Stack vertically
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Teacher Approvals',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Review and approve requests',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GlassTextField(
                            controller: _searchController,
                            label: 'Search',
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            hintText: 'Search teachers...',
                            prefixIcon: Icons.search,
                          ),
                        ],
                      );
                    }

                    // Desktop: Row layout
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teacher Approvals',
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Review and approve teacher registration requests',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 300,
                          child: GlassTextField(
                            controller: _searchController,
                            label: 'Search',
                            onChanged: (value) =>
                                setState(() => _searchQuery = value),
                            hintText: 'Search teachers...',
                            prefixIcon: Icons.search,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Stats Cards
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                delay: const Duration(milliseconds: 100),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.hourglass_empty,
                        title: 'Pending',
                        count:
                            ref.watch(pendingTeachersProvider).value?.length ??
                            0,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.check_circle,
                        title: 'Approved',
                        count:
                            ref.watch(approvedTeachersProvider).value?.length ??
                            0,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF8B5CF6),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'Pending Approval'),
                  Tab(text: 'Approved Teachers'),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildPendingTab(), _buildApprovedTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingTab() {
    final teachersAsync = ref.watch(pendingTeachersProvider);

    return teachersAsync.when(
      data: (teachers) {
        if (teachers.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No Pending Approvals',
              subtitle:
                  'All teacher registration requests have been processed.',
              color: Colors.white54,
            ),
          );
        }

        // Filter by search query
        final filteredTeachers = teachers.where((teacher) {
          if (_searchQuery.isEmpty) return true;
          final name = (teacher['displayName'] as String?) ?? '';
          final email = (teacher['email'] as String?) ?? '';
          final id = (teacher['idNumber'] as String?) ?? '';
          return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              id.contains(_searchQuery);
        }).toList();

        if (filteredTeachers.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No Results',
              subtitle: 'No teachers match "$_searchQuery"',
              color: Colors.white54,
            ),
          );
        }

        return FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: ListView.separated(
            itemCount: filteredTeachers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final teacher = filteredTeachers[index];
              return _TeacherCard(
                teacher: teacher,
                isPending: true,
                onApprove: () => _approveTeacher(
                  teacher['id'] as String,
                  teacher['email'] as String?,
                  teacher['displayName'] as String?,
                ),
                onReject: () => _rejectTeacher(
                  teacher['id'] as String,
                  teacher['email'] as String?,
                  teacher['displayName'] as String?,
                ),
              );
            },
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, st) => Center(
        child: Text(
          'Error loading teachers: $e',
          style: GoogleFonts.outfit(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildApprovedTab() {
    final teachersAsync = ref.watch(approvedTeachersProvider);

    return teachersAsync.when(
      data: (teachers) {
        if (teachers.isEmpty) {
          return const Center(
            child: EmptyState(
              icon: Icons.person_off,
              title: 'No Approved Teachers',
              subtitle: 'No teachers have been approved yet.',
              color: Colors.white54,
            ),
          );
        }

        // Filter by search query
        final filteredTeachers = teachers.where((teacher) {
          if (_searchQuery.isEmpty) return true;
          final name = (teacher['displayName'] as String?) ?? '';
          final email = (teacher['email'] as String?) ?? '';
          final id = (teacher['idNumber'] as String?) ?? '';
          return name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              id.contains(_searchQuery);
        }).toList();

        if (filteredTeachers.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'No Results',
              subtitle: 'No teachers match "$_searchQuery"',
              color: Colors.white54,
            ),
          );
        }

        return FadeInUp(
          duration: const Duration(milliseconds: 500),
          child: ListView.separated(
            itemCount: filteredTeachers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final teacher = filteredTeachers[index];
              return _TeacherCard(
                teacher: teacher,
                isPending: false,
                onRevoke: () => _revokeApproval(
                  teacher['id'] as String,
                  teacher['email'] as String?,
                  teacher['displayName'] as String?,
                ),
              );
            },
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (e, st) => Center(
        child: Text(
          'Error loading teachers: $e',
          style: GoogleFonts.outfit(color: Colors.red),
        ),
      ),
    );
  }

  Future<void> _approveTeacher(
    String teacherId,
    String? email,
    String? name,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherId)
          .update({
            'approved': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'approvedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Teacher approved successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Send Email
        if (email != null && email.isNotEmpty) {
          if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
            // Fallback to mailto if not configured
            final Uri emailLaunchUri = Uri(
              scheme: 'mailto',
              path: email,
              query: _encodeQueryParameters(<String, String>{
                'subject': 'Teacher Account Approved - Attendify',
                'body':
                    'Dear ${name ?? 'Teacher'},\n\nYour teacher account has been approved. You can now log in to the Attendify dashboard at https://attendify.pages.dev/\n\nBest regards,\nAdmin Team',
              }),
            );
            if (await canLaunchUrl(emailLaunchUri)) {
              await launchUrl(emailLaunchUri);
            }
          } else {
            // Use EmailJS
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sending email notification...')),
              );
            }
            await EmailService.sendEmail(
              templateId: EmailConstants.approvalTemplateId,
              templateParams: {
                'to_name': name ?? 'Teacher',
                'to_email': email,
                'message':
                    'Your teacher account has been approved. You can now log in.',
                'email': email,
                'action_url': 'https://attendify.pages.dev/',
              },
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error approving teacher: $e')));
      }
    }
  }

  Future<void> _rejectTeacher(
    String teacherId,
    String? email,
    String? name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Reject Teacher Application',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to reject this application? The user will be deleted from the system.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Reject',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teacher application rejected'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Send Email
          if (email != null && email.isNotEmpty) {
            if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
              // Fallback
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: email,
                query: _encodeQueryParameters(<String, String>{
                  'subject': 'Teacher Application Update - Attendify',
                  'body':
                      'Dear ${name ?? 'Applicant'},\n\nWe regret to inform you that your teacher application has been rejected.\n\nBest regards,\nAdmin Team',
                }),
              );
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              }
            } else {
              // EmailJS
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sending email notification...'),
                  ),
                );
              }
              await EmailService.sendEmail(
                templateId: EmailConstants.rejectionTemplateId,
                templateParams: {
                  'to_name': name ?? 'Applicant',
                  'to_email': email,
                  'message': 'Your teacher application has been rejected.',
                  'email': email,
                  'support_url': '#', // Make button unclickable/no-op
                },
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error rejecting teacher: $e')),
          );
        }
      }
    }
  }

  Future<void> _revokeApproval(
    String teacherId,
    String? email,
    String? name,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Revoke Approval',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to revoke approval for this teacher? They will no longer be able to access the system.',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orangeAccent),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Revoke',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .update({
              'approved': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Teacher approval revoked'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Send Email
          if (email != null && email.isNotEmpty) {
            if (EmailConstants.serviceId == 'YOUR_SERVICE_ID') {
              // Fallback
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: email,
                query: _encodeQueryParameters(<String, String>{
                  'subject': 'Account Access Revoked - Attendify',
                  'body':
                      'Dear ${name ?? 'Teacher'},\n\nYour teacher account approval has been revoked. You can no longer access the system.\n\nBest regards,\nAdmin Team',
                }),
              );
              if (await canLaunchUrl(emailLaunchUri)) {
                await launchUrl(emailLaunchUri);
              }
            } else {
              // EmailJS
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sending email notification...'),
                  ),
                );
              }
              await EmailService.sendEmail(
                templateId: EmailConstants
                    .rejectionTemplateId, // Reusing rejection template for revocation
                templateParams: {
                  'to_name': name ?? 'Teacher',
                  'to_email': email,
                  'message': 'Your account approval has been revoked.',
                  'email': email,
                },
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error revoking approval: $e')),
          );
        }
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}

class _TeacherCard extends ConsumerWidget {
  const _TeacherCard({
    required this.teacher,
    required this.isPending,
    this.onApprove,
    this.onReject,
    this.onRevoke,
  });

  final Map<String, dynamic> teacher;
  final bool isPending;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = teacher['displayName'] as String? ?? 'Unknown';
    final email = teacher['email'] as String? ?? '';
    final idNumber =
        teacher['idNumber'] as String? ??
        teacher['rollNumber'] as String? ??
        'N/A';
    final institutionCode = teacher['institutionCode'] as String? ?? '';
    final createdAt =
        teacher['createdAt']; // Keep as dynamic to handle Timestamp
    final isMobile = context.isMobile;

    return GlassCard(
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Avatar
                    SafeAvatar(
                      imageUrl:
                          null, // Teacher approval usually doesn't have photoUrl yet, or check if it does
                      name: name,
                      radius: 24,
                      backgroundColor: isPending
                          ? Colors.orange.withValues(alpha: 0.2)
                          : Colors.green.withValues(alpha: 0.2),
                      fallbackIcon: isPending
                          ? Icons.hourglass_empty
                          : Icons.check_circle,
                      foregroundColor: isPending
                          ? Colors.orange[700]
                          : Colors.green[700],
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.email,
                                size: 14,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Additional Info
                Row(
                  children: [
                    Icon(Icons.badge, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      'ID: $idNumber',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    if (institutionCode.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.school, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildInstitutionText(ref, institutionCode),
                      ),
                    ],
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        'Registered: ${_formatDate(createdAt)}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isPending) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRevoke,
                          icon: const Icon(Icons.block, size: 18),
                          label: const Text('Revoke'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: BorderSide(
                              color: Colors.orange.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            )
          : Row(
              children: [
                // Avatar
                SafeAvatar(
                  imageUrl: null,
                  name: name,
                  radius: 28,
                  backgroundColor: isPending
                      ? Colors.orange.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                  fallbackIcon: isPending
                      ? Icons.hourglass_empty
                      : Icons.check_circle,
                  foregroundColor: isPending
                      ? Colors.orange[700]
                      : Colors.green[700],
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              email,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.badge, size: 14, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            'ID: $idNumber',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          if (institutionCode.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.school, size: 14, color: Colors.white54),
                            const SizedBox(width: 4),
                            Flexible(
                              child: _buildInstitutionText(
                                ref,
                                institutionCode,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Registered: ${_formatDate(createdAt)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Actions
                if (isPending) ...[
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: onReject,
                    icon: const Icon(Icons.close, color: Colors.red),
                    tooltip: 'Reject',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, color: Colors.green),
                    tooltip: 'Approve',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: onRevoke,
                    icon: const Icon(Icons.block, color: Colors.orange),
                    tooltip: 'Revoke Approval',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildInstitutionText(WidgetRef ref, String code) {
    // We could fetch institution name here if we had a provider for it
    // For now just show code
    return Text(
      'Inst: $code',
      style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
      overflow: TextOverflow.ellipsis,
    );
  }

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      final dt = date.toDate();
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return '';
  }
}
