import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/fluent_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/models/class_group.dart';
import '../../shared/providers.dart';
import '../../auth/providers.dart';
import 'admin_shell.dart';
import '../../../core/responsive_utils.dart';

// Provider for all teachers (for assignment dropdown)
final allTeachersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', whereIn: ['teacher', 'admin'])
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
});

// Provider for all subjects (for assignment dropdown)
final allSubjectsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('subjects')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
});

// Provider for all students (for details view)
final allStudentsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'student')
      .snapshots()
      .map(
        (snap) =>
            snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList(),
      );
});

class AdminClassGroupsPage extends ConsumerStatefulWidget {
  const AdminClassGroupsPage({super.key});

  @override
  ConsumerState<AdminClassGroupsPage> createState() =>
      _AdminClassGroupsPageState();
}

class _AdminClassGroupsPageState extends ConsumerState<AdminClassGroupsPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(allClassGroupsProvider);

    return AdminShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with search and add button
          FadeInDown(
            duration: const Duration(milliseconds: 500),
            child: ResponsiveBuilder(
              builder: (context, isMobile, isTablet, isDesktop) {
                final auth = ref.watch(authControllerProvider);
                final isAdmin = auth.isAdmin;

                final searchField = TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search class groups...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                );

                final createButton = FilledButton.icon(
                  onPressed: () => _showCreateGroupDialog(context),
                  icon: const Icon(Icons.group_add),
                  label: const Text('Create Group'),
                );

                final adminButtons = isAdmin
                    ? [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: Text(
                                  'Sync Group Counts',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                ),
                                content: Text(
                                  'This will rebuild teacher and subject counts for all groups based on the subjects catalog. Use this if counts appear incorrect.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: FluentColors.accentColor,
                                    ),
                                    child: Text(
                                      'Sync',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              final repo = ref.read(
                                classGroupRepositoryProvider,
                              );
                              final summary = await repo.syncGroupCounts();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Sync complete — updated: ${summary['updated']}, errors: ${summary['errors']}',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Sync failed: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.sync, size: 18),
                          label: const Text('Sync Counts'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: Text(
                                  'Backfill Institution Tags',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                ),
                                content: Text(
                                  'This will set institutionCode on legacy class groups by inferring it from assigned teachers/students. Continue?',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: FluentColors.accentColor,
                                    ),
                                    child: Text(
                                      'Run',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              final repo = ref.read(
                                classGroupRepositoryProvider,
                              );
                              final summary = await repo
                                  .backfillInstitutionCodes();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Backfill complete — updated: ${summary['updated']}, skipped: ${summary['skipped']}, errors: ${summary['errors']}',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Backfill failed: $e'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.auto_fix_high, size: 18),
                          label: const Text('Backfill Tags'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF1E293B),
                                title: Text(
                                  'Cleanup Invalid Users',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                  ),
                                ),
                                content: Text(
                                  'This will scan all class groups and remove users that no longer exist OR have incorrect roles (e.g. teachers who became admins). This fixes "ghost" users and data discrepancies.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(
                                      'Cancel',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    child: Text(
                                      'Cleanup',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              final repo = ref.read(
                                classGroupRepositoryProvider,
                              );
                              final summary = await repo.cleanupInvalidUsers();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Cleanup complete — updated: ${summary['updated']}, removed: ${summary['removed']}, errors: ${summary['errors']}',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Cleanup failed: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.person_off,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          label: const Text(
                            'Cleanup Users',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ]
                    : <Widget>[];

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.start,
                        children: [createButton, ...adminButtons],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    createButton,
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      ...adminButtons.map(
                        (btn) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: btn,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Groups list
          Expanded(
            child: groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return const EmptyState(
                    icon: Icons.groups,
                    title: 'No Class Groups',
                    subtitle:
                        'Create your first class group to organize students and teachers.',
                  );
                }

                // Filter groups by search query
                final filteredGroups = groups.where((group) {
                  if (_searchQuery.isEmpty) return true;
                  return group.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      (group.description?.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ??
                          false);
                }).toList();

                if (filteredGroups.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off,
                    title: 'No Results',
                    subtitle: 'No class groups match "$_searchQuery"',
                  );
                }

                return FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: ListView.separated(
                    itemCount: filteredGroups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      return _GroupCard(group: group);
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text(
                  'Error loading groups: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'Lecture';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'Create Class Group',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'Group Name',
                  hintText: 'e.g., CSE-A Year 3',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'Description (optional)',
                  hintText: 'Brief description of the group',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                dropdownColor: const Color(0xFF1E293B),
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'Group Type',
                  prefixIcon: Icons.category,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Lecture',
                    child: Text(
                      'Lecture Group',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Lab',
                    child: Text(
                      'Lab Group',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedType = value);
                  }
                },
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
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a group name')),
                  );
                  return;
                }

                try {
                  final auth = ref.read(authControllerProvider);
                  final repo = ref.read(classGroupRepositoryProvider);
                  await repo.createGroup(
                    name: nameController.text.trim(),
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    institutionCode: auth.institutionCode,
                    type: selectedType,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Class group created successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ErrorHandler.showErrorSnackBar(
                      context,
                      e,
                      customMessage: 'Unable to delete class group',
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: FluentColors.accentColor,
              ),
              child: Text(
                'Create',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({required this.group});

  final ClassGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLab = group.type == 'Lab';

    return FluentAcrylicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isLab ? Colors.green : FluentColors.accentColor)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isLab ? Icons.science : Icons.groups,
                  color: isLab ? Colors.green : FluentColors.accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          group.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isLab ? Colors.green : Colors.blue)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: (isLab ? Colors.green : Colors.blue)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            group.type,
                            style: TextStyle(
                              fontSize: 10,
                              color: isLab ? Colors.green : Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (group.description != null)
                      Text(
                        group.description!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: FluentColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit, size: 20, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          'Edit',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete,
                          size: 20,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: GoogleFonts.outfit(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'delete') {
                    _showDeleteConfirmation(context, ref, group);
                  } else if (value == 'edit') {
                    _showEditDialog(context, ref, group);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              _StatChip(
                icon: Icons.person,
                label: '${group.studentUids.length} Students',
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.school,
                label: '${group.teacherUids.length} Teachers',
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.book,
                label: '${group.subjectIds.length} Subjects',
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showGroupDetailsDialog(context, ref, group),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, ClassGroup group) {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description ?? '');
    String selectedType = group.type;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'Edit Class Group',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'Group Name',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'Description',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedType,
                dropdownColor: const Color(0xFF1E293B),
                style: GoogleFonts.outfit(color: Colors.white),
                decoration: fluentInputDecoration(
                  context: context,
                  labelText: 'Group Type',
                  prefixIcon: Icons.category,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'Lecture',
                    child: Text(
                      'Lecture Group',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Lab',
                    child: Text(
                      'Lab Group',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedType = value);
                  }
                },
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
                try {
                  final repo = ref.read(classGroupRepositoryProvider);
                  await repo.updateGroup(
                    groupId: group.id,
                    name: nameController.text.trim(),
                    description: descController.text.trim().isEmpty
                        ? null
                        : descController.text.trim(),
                    type: selectedType,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Group updated successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ErrorHandler.showErrorSnackBar(
                      context,
                      e,
                      customMessage: 'Unable to add class group',
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: FluentColors.accentColor,
              ),
              child: Text(
                'Update',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    ClassGroup group,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Delete Class Group',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This action cannot be undone.',
          style: GoogleFonts.outfit(color: Colors.white70),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              try {
                final repo = ref.read(classGroupRepositoryProvider);
                await repo.deleteGroup(group.id);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorHandler.showErrorSnackBar(
                    context,
                    e,
                    customMessage: 'Unable to update class group',
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupDetailsDialog(
    BuildContext context,
    WidgetRef ref,
    ClassGroup group,
  ) {
    showDialog(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final width = isMobile ? constraints.maxWidth * 0.9 : 600.0;
          final height = isMobile ? constraints.maxHeight * 0.8 : 500.0;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            title: Text(
              '${group.name} Details',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            content: SizedBox(
              width: width,
              height: height,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      labelColor: FluentColors.accentColor,
                      unselectedLabelColor: Colors.white60,
                      indicatorColor: FluentColors.accentColor,
                      labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: const [
                        Tab(text: 'Students'),
                        Tab(text: 'Teachers'),
                        Tab(text: 'Subjects'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Students Tab
                          Consumer(
                            builder: (context, ref, _) {
                              final studentsAsync = ref.watch(
                                allStudentsProvider,
                              );
                              return studentsAsync.when(
                                data: (allStudents) {
                                  final groupStudents = allStudents
                                      .where(
                                        (s) =>
                                            group.studentUids.contains(s['id']),
                                      )
                                      .toList();
                                  if (groupStudents.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No students assigned',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: groupStudents.length,
                                    itemBuilder: (context, index) {
                                      final student = groupStudents[index];
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.person,
                                          color: Colors.blueAccent,
                                        ),
                                        title: Text(
                                          student['displayName'] ?? 'Unknown',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          student['email'] ?? '',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, _) => ErrorHandler.buildErrorWidget(
                                  e,
                                  customMessage: 'Unable to load subjects',
                                ),
                              );
                            },
                          ),

                          // Teachers Tab
                          Consumer(
                            builder: (context, ref, _) {
                              final teachersAsync = ref.watch(
                                allTeachersProvider,
                              );
                              return teachersAsync.when(
                                data: (allTeachers) {
                                  final groupTeachers = allTeachers
                                      .where(
                                        (t) =>
                                            group.teacherUids.contains(t['id']),
                                      )
                                      .toList();
                                  if (groupTeachers.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No teachers assigned',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: groupTeachers.length,
                                    itemBuilder: (context, index) {
                                      final teacher = groupTeachers[index];
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.school,
                                          color: Colors.greenAccent,
                                        ),
                                        title: Text(
                                          teacher['displayName'] ?? 'Unknown',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: Text(
                                          teacher['email'] ?? '',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white54,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, _) => ErrorHandler.buildErrorWidget(
                                  e,
                                  customMessage: 'Unable to load teachers',
                                ),
                              );
                            },
                          ),

                          // Subjects Tab
                          Consumer(
                            builder: (context, ref, _) {
                              final subjectsAsync = ref.watch(
                                allSubjectsProvider,
                              );
                              return subjectsAsync.when(
                                data: (allSubjects) {
                                  final groupSubjects = allSubjects
                                      .where(
                                        (s) =>
                                            group.subjectIds.contains(s['id']),
                                      )
                                      .toList();
                                  if (groupSubjects.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No subjects assigned',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white54,
                                        ),
                                      ),
                                    );
                                  }
                                  return ListView.builder(
                                    itemCount: groupSubjects.length,
                                    itemBuilder: (context, index) {
                                      final subject = groupSubjects[index];
                                      return ListTile(
                                        leading: const Icon(
                                          Icons.book,
                                          color: Colors.orangeAccent,
                                        ),
                                        title: Text(
                                          subject['name'] ?? 'Unknown',
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              subject['code'] ?? '',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white54,
                                              ),
                                            ),
                                            // Show current teacher name
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final teachersAsync = ref.watch(
                                                  allTeachersProvider,
                                                );
                                                return teachersAsync.when(
                                                  data: (teachers) {
                                                    final teacher = teachers
                                                        .firstWhere(
                                                          (t) =>
                                                              t['id'] ==
                                                              subject['teacherUid'],
                                                          orElse: () => {
                                                            'displayName':
                                                                'Unknown',
                                                          },
                                                        );
                                                    return Text(
                                                      'Teacher: ${teacher['displayName']}',
                                                      style: GoogleFonts.outfit(
                                                        color: Colors.white38,
                                                        fontSize: 12,
                                                      ),
                                                    );
                                                  },
                                                  loading: () =>
                                                      const SizedBox.shrink(),
                                                  error: (_, __) =>
                                                      const SizedBox.shrink(),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: FluentColors.accentColor,
                                          ),
                                          tooltip: 'Transfer Subject',
                                          onPressed: () =>
                                              _showTransferSubjectDialog(
                                                context,
                                                ref,
                                                subject,
                                                group.id,
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (e, _) => ErrorHandler.buildErrorWidget(
                                  e,
                                  customMessage: 'Unable to load subjects',
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
          );
        },
      ),
    );
  }

  void _showTransferSubjectDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> subject,
    String groupId,
  ) {
    String? selectedTeacherUid;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'Transfer Subject',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer "${subject['name']}" to a new teacher.\nThis will preserve past session history for the previous teacher.',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, _) {
                  final teachersAsync = ref.watch(allTeachersProvider);
                  return teachersAsync.when(
                    data: (teachers) {
                      // Filter out current teacher
                      final availableTeachers = teachers
                          .where((t) => t['id'] != subject['teacherUid'])
                          .toList();

                      if (availableTeachers.isEmpty) {
                        return Text(
                          'No other teachers available.',
                          style: GoogleFonts.outfit(color: Colors.orange),
                        );
                      }

                      return DropdownButtonFormField<String>(
                        initialValue: selectedTeacherUid,
                        dropdownColor: const Color(0xFF1E293B),
                        style: GoogleFonts.outfit(color: Colors.white),
                        decoration: fluentInputDecoration(
                          context: context,
                          labelText: 'New Teacher',
                          prefixIcon: Icons.person,
                        ),
                        items: availableTeachers.map((t) {
                          return DropdownMenuItem(
                            value: t['id'] as String,
                            child: Text(
                              t['displayName'] ?? 'Unknown',
                              style: GoogleFonts.outfit(color: Colors.white),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => selectedTeacherUid = value),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Error loading teachers'),
                  );
                },
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
              onPressed: selectedTeacherUid == null
                  ? null
                  : () async {
                      try {
                        final repo = ref.read(classGroupRepositoryProvider);
                        await repo.transferSubject(
                          subjectId: subject['id'],
                          groupId: groupId,
                          oldTeacherUid: subject['teacherUid'],
                          newTeacherUid: selectedTeacherUid!,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Subject transferred successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ErrorHandler.showErrorSnackBar(
                            context,
                            e,
                            customMessage: 'Unable to transfer subject',
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: FluentColors.accentColor,
              ),
              child: Text(
                'Transfer',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
