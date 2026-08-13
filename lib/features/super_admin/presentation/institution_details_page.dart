import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/responsive_utils.dart';
import '../../../core/fluent_theme.dart';
import '../../shared/widgets/glass_card.dart';
import '../providers/institution_details_provider.dart';
import 'super_admin_shell.dart';

class InstitutionDetailsPage extends ConsumerWidget {
  final String institutionId;

  const InstitutionDetailsPage({super.key, required this.institutionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(institutionDetailsProvider(institutionId));
    final statsAsync = ref.watch(institutionStatsProvider(institutionId));
    final adminsAsync = ref.watch(institutionAdminsProvider(institutionId));

    return SuperAdminShell(
      child: detailsAsync.when(
        data: (institution) {
          if (institution == null) {
            return const Center(child: Text('Institution not found'));
          }
          return ResponsiveBuilder(
            builder: (context, isMobile, isTablet, isDesktop) {
              return SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: FluentColors.accentColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.business,
                                  size: 32,
                                  color: FluentColors.accentColor,
                                ),
                              ),
                              _StatusChip(status: institution.status),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            institution.name,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Code: ${institution.code} • Domain: @${institution.emailDomain}',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: FluentColors.accentColor.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.business,
                              size: 32,
                              color: FluentColors.accentColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  institution.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Code: ${institution.code} • Domain: @${institution.emailDomain}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusChip(status: institution.status),
                        ],
                      ),
                    const SizedBox(height: 32),

                    // Stats Grid
                    statsAsync.when(
                      data: (stats) => GridView.count(
                        crossAxisCount: isMobile ? 2 : 4,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _StatCard(
                            title: 'Students',
                            value: stats['students'].toString(),
                            icon: Icons.people,
                            color: Colors.blue,
                          ),
                          _StatCard(
                            title: 'Teachers',
                            value: stats['teachers'].toString(),
                            icon: Icons.school,
                            color: Colors.green,
                          ),
                          _StatCard(
                            title: 'Total Classes',
                            value: stats['classes'].toString(),
                            icon: Icons.class_,
                            color: Colors.orange,
                          ),
                          _StatCard(
                            title: 'Total Sessions',
                            value: stats['sessions'].toString(),
                            icon: Icons.history,
                            color: Colors.purple,
                          ),
                          _StatCard(
                            title: 'Active Sessions',
                            value: stats['activeSessions'].toString(),
                            icon: Icons.timer,
                            color: Colors.redAccent,
                          ),
                        ],
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text(
                        'Error loading stats: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Admins Section
                    if (isMobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Institution Administrators',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _showAddAdminDialog(
                                context,
                                ref,
                                institutionId,
                              ),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Admin'),
                              style: FilledButton.styleFrom(
                                backgroundColor: FluentColors.accentColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Institution Administrators',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _showAddAdminDialog(
                              context,
                              ref,
                              institutionId,
                            ),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Admin'),
                            style: FilledButton.styleFrom(
                              backgroundColor: FluentColors.accentColor,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    adminsAsync.when(
                      data: (admins) {
                        if (admins.isEmpty) {
                          return const GlassCard(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: Text(
                                  'No admins assigned',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                          );
                        }
                        return GlassCard(
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: admins.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Colors.white10),
                            itemBuilder: (context, index) {
                              final admin = admins[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: FluentColors.accentColor,
                                  child: Text(
                                    (admin['displayName'] as String? ?? 'A')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(
                                  admin['displayName'] ?? 'Unknown',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  admin['email'] ?? '',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Remove Admin Access',
                                  onPressed: () =>
                                      _confirmRemoveAdmin(context, ref, admin),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text(
                        'Error loading admins: $e',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showAddAdminDialog(
    BuildContext context,
    WidgetRef ref,
    String institutionId,
  ) async {
    final emailController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Add Institution Admin',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the email of an EXISTING user to promote them to Admin for this institution.',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              style: GoogleFonts.outfit(color: Colors.white),
              decoration: fluentInputDecoration(
                context: context,
                labelText: 'User Email',
                prefixIcon: Icons.email,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white70),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;

              try {
                // Find user by email
                final snap = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .limit(1)
                    .get();

                if (snap.docs.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'User not found. They must register first.',
                        ),
                      ),
                    );
                  }
                  return;
                }

                final userDoc = snap.docs.first;

                // Update user role
                await userDoc.reference.update({
                  'role': 'admin',
                  'admin': true,
                  'institutionCode': institutionId,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('User promoted to Admin successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: FluentColors.accentColor,
            ),
            child: Text(
              'Promote',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveAdmin(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> admin,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Remove Admin?',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove admin access for ${admin['displayName']}? They will be demoted to "Teacher".',
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
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(
              'Remove',
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
            .doc(admin['id'])
            .update({
              'role': 'teacher',
              'admin': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Admin access revoked')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      default:
        color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
