import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import '../../../core/fluent_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../auth/providers.dart';
import '../../shared/providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'admin_shell.dart';

// Provider for all subjects, optionally filtered by institution
final subjectCatalogProvider =
    StreamProvider.autoDispose<Map<String, List<Map<String, dynamic>>>>((ref) {
      final auth = ref.watch(authControllerProvider);

      Query query = FirebaseFirestore.instance.collection('subject_catalog');

      // If not super admin, filter by institution
      if (!auth.isSuperAdmin && auth.institutionCode != null) {
        query = query.where('institutionCode', isEqualTo: auth.institutionCode);
      }

      return query.snapshots().map((snapshot) {
        final Map<String, List<Map<String, dynamic>>> grouped = {
          'First Year': [],
          'Second Year': [],
          'Third Year': [],
          'Fourth Year': [],
          'Other': [],
        };

        for (final doc in snapshot.docs) {
          final data = {'id': doc.id, ...doc.data() as Map<String, dynamic>};
          final year = data['year'] as String? ?? 'Other';

          if (grouped.containsKey(year)) {
            grouped[year]!.add(data);
          } else {
            grouped['Other']!.add(data);
          }
        }

        // Sort subjects within each year alphabetically
        for (final key in grouped.keys) {
          grouped[key]!.sort(
            (a, b) => (a['name'] as String).compareTo(b['name'] as String),
          );
        }

        return grouped;
      });
    });

class AdminSubjectsPage extends ConsumerWidget {
  const AdminSubjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectCatalogProvider);

    return AdminShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 800;

          return ListView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            children: [
              _buildHeader(context, ref, isMobile),
              const SizedBox(height: 24),
              subjectsAsync.when(
                data: (groupedSubjects) {
                  final hasSubjects = groupedSubjects.values.any(
                    (list) => list.isNotEmpty,
                  );

                  if (!hasSubjects) {
                    return FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      child: FluentAcrylicCard(
                        padding: const EdgeInsets.all(48),
                        child: const EmptyState(
                          icon: Icons.book_outlined,
                          title: 'No Subjects Found',
                          subtitle:
                              'Add a subject to the catalog to get started',
                          color: FluentColors.info,
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...groupedSubjects.entries
                          .where((entry) => entry.value.isNotEmpty)
                          .expand((entry) {
                            return [
                              _buildYearSection(
                                context,
                                ref,
                                entry.key,
                                entry.value,
                                isMobile,
                              ),
                              const SizedBox(height: 24),
                            ];
                          }),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: FluentAcrylicCard(
                    padding: const EdgeInsets.all(32),
                    child: ErrorHandler.buildErrorWidget(
                      error,
                      customMessage: 'Unable to load subjects',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isMobile) {
    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: FluentAcrylicCard(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          Icons.book,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Subjects Catalog',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage the master list of subjects for all years',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? FluentColors.textSecondaryDark
                                        : FluentColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FluentButton(
                      onPressed: () => _showAddSubjectDialog(context, ref),
                      isPrimary: true,
                      icon: Icons.add_circle_outline,
                      child: const Text('Add Subject'),
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
                      Icons.book,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subjects Catalog',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage the master list of subjects for all years',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? FluentColors.textSecondaryDark
                                    : FluentColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  FluentButton(
                    onPressed: () => _showAddSubjectDialog(context, ref),
                    isPrimary: true,
                    icon: Icons.add_circle_outline,
                    child: const Text('Add Subject'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildYearSection(
    BuildContext context,
    WidgetRef ref,
    String year,
    List<Map<String, dynamic>> subjects,
    bool isMobile,
  ) {
    final color = _getYearColor(year);

    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  year,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${subjects.length} subject${subjects.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile
                  ? 1
                  : (MediaQuery.of(context).size.width > 1200 ? 3 : 2),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              mainAxisExtent: 100,
            ),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              return _buildSubjectCard(context, ref, subjects[index], isMobile);
            },
          ),
        ],
      ),
    );
  }

  Color _getYearColor(String year) {
    switch (year) {
      case 'First Year':
        return const Color(0xFF10B981); // Emerald
      case 'Second Year':
        return const Color(0xFF3B82F6); // Blue
      case 'Third Year':
        return const Color(0xFFF59E0B); // Amber
      case 'Fourth Year':
        return const Color(0xFFEC4899); // Pink
      default:
        return Colors.grey;
    }
  }

  Widget _buildSubjectCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> subject,
    bool isMobile,
  ) {
    final colors = [
      const Color(0xFF10B981), // emerald
      const Color(0xFF3B82F6), // blue
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEC4899), // pink
    ];

    final name = subject['name']?.toString() ?? 'Untitled';
    final code = subject['code']?.toString() ?? 'No Code';
    final color = colors[name.length % colors.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? FluentColors.cardBackgroundDark
            : FluentColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.1)
              : FluentColors.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.book_outlined, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  code,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? FluentColors.textSecondaryDark
                        : FluentColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'details') _showSubjectDetails(context, subject);
              if (value == 'edit') {
                _showEditSubjectDialog(context, ref, subject);
              }
              if (value == 'delete') {
                _confirmDeleteSubject(
                  context,
                  ref,
                  subject['id'],
                  subject['name'],
                  subject['code'],
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'details',
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('View Details'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddSubjectDialog(ref: ref),
    );
  }

  void _showEditSubjectDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> subject,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditSubjectDialog(ref: ref, subject: subject),
    );
  }

  void _showSubjectDetails(BuildContext context, Map<String, dynamic> subject) {
    showDialog(
      context: context,
      builder: (context) => _SubjectDetailsDialog(subject: subject),
    );
  }

  void _confirmDeleteSubject(
    BuildContext context,
    WidgetRef ref,
    String subjectId,
    String subjectName,
    String subjectCode,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from Catalog'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$subjectName"?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Warning: This will permanently delete this subject from the catalog AND remove all active classes ($subjectCode) assigned to teachers.',
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final repo = ref.read(subjectRepositoryProvider);
                await repo.deleteCatalogSubject(subjectId, subjectCode);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Deleted "$subjectName" and all active classes.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ErrorHandler.showErrorSnackBar(
                    context,
                    e,
                    customMessage: 'Unable to add subject',
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
  }
}

class _AddSubjectDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _AddSubjectDialog({required this.ref});

  @override
  ConsumerState<_AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends ConsumerState<_AddSubjectDialog> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  String selectedYear = 'First Year';

  final List<String> years = [
    'First Year',
    'Second Year',
    'Third Year',
    'Fourth Year',
  ];

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Catalog'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            decoration: fluentInputDecoration(
              context: context,
              labelText: 'Subject Name',
              hintText: 'e.g., Data Structures',
              prefixIcon: Icons.book_outlined,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            decoration: fluentInputDecoration(
              context: context,
              labelText: 'Subject Code',
              hintText: 'e.g., CS201',
              prefixIcon: Icons.tag,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Year', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedYear,
                isExpanded: true,
                items: years.map((year) {
                  return DropdownMenuItem(value: year, child: Text(year));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedYear = value);
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter subject name')),
              );
              return;
            }

            final auth = widget.ref.read(authControllerProvider);
            if (auth.institutionCode == null && !auth.isSuperAdmin) return;

            try {
              await FirebaseFirestore.instance
                  .collection('subject_catalog')
                  .add({
                    'institutionCode': auth.institutionCode,
                    'name': nameController.text.trim(),
                    'code': codeController.text.trim(),
                    'year': selectedYear,
                    'createdAt': FieldValue.serverTimestamp(),
                  });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subject added to catalog!'),
                    backgroundColor: FluentColors.success,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.showErrorSnackBar(
                  context,
                  e,
                  customMessage: 'Unable to update subject',
                );
              }
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _EditSubjectDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  final Map<String, dynamic> subject;

  const _EditSubjectDialog({required this.ref, required this.subject});

  @override
  ConsumerState<_EditSubjectDialog> createState() => _EditSubjectDialogState();
}

class _EditSubjectDialogState extends ConsumerState<_EditSubjectDialog> {
  late TextEditingController nameController;
  late TextEditingController codeController;
  late String selectedYear;

  final List<String> years = [
    'First Year',
    'Second Year',
    'Third Year',
    'Fourth Year',
  ];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.subject['name']);
    codeController = TextEditingController(text: widget.subject['code']);
    selectedYear = widget.subject['year'] ?? 'First Year';
    if (!years.contains(selectedYear)) {
      selectedYear = 'First Year';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Catalog Subject'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            decoration: fluentInputDecoration(
              context: context,
              labelText: 'Subject Name',
              prefixIcon: Icons.book_outlined,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: codeController,
            decoration: fluentInputDecoration(
              context: context,
              labelText: 'Subject Code',
              prefixIcon: Icons.tag,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Year', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedYear,
                isExpanded: true,
                items: years.map((year) {
                  return DropdownMenuItem(value: year, child: Text(year));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => selectedYear = value);
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) return;

            try {
              await FirebaseFirestore.instance
                  .collection('subject_catalog')
                  .doc(widget.subject['id'])
                  .update({
                    'name': nameController.text.trim(),
                    'code': codeController.text.trim(),
                    'year': selectedYear,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subject updated successfully!'),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.showErrorSnackBar(
                  context,
                  e,
                  customMessage: 'Unable to delete subject',
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SubjectDetailsDialog extends ConsumerWidget {
  final Map<String, dynamic> subject;
  const _SubjectDetailsDialog({required this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectCode = subject['code'];

    // Fetch all instances of this subject being taught
    final instancesAsync = ref.watch(subjectInstancesProvider(subjectCode));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: FluentAcrylicCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: Color(0xFF8B5CF6),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject['name'] ?? 'Unknown',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Code: ${subject['code']} • ${subject['year'] ?? 'Unassigned Year'}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: FluentColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: instancesAsync.when(
                  data: (instances) {
                    if (instances.isEmpty) {
                      return const EmptyState(
                        icon: Icons.class_outlined,
                        title: 'No Active Classes',
                        subtitle:
                            'This subject is not currently assigned to any groups.',
                        color: FluentColors.textSecondary,
                      );
                    }

                    return ListView.separated(
                      itemCount: instances.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final instance = instances[index];
                        return _buildInstanceCard(context, ref, instance);
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorHandler.buildErrorWidget(
                    e,
                    customMessage: 'Unable to load students',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstanceCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> instance,
  ) {
    final teacherUid = instance['teacherUid'];
    final groupName = instance['group'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Group Info
          Expanded(
            flex: 2,
            child: Row(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName ?? 'Unknown Group',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      instance['type'] ?? 'Lecture',
                      style: TextStyle(
                        color: FluentColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Teacher Info
          Expanded(flex: 3, child: _TeacherInfo(teacherUid: teacherUid)),
        ],
      ),
    );
  }
}

class _TeacherInfo extends ConsumerWidget {
  final String? teacherUid;
  const _TeacherInfo({required this.teacherUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (teacherUid == null) return const Text('Unassigned');

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        if (data == null) return const Text('Unknown Teacher');

        return Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              child: Text(
                (data['displayName'] ?? 'T')[0],
                style: const TextStyle(
                  color: Color(0xFF3B82F6),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['displayName'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  data['email'] ?? '',
                  style: TextStyle(
                    color: FluentColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// Provider to get all instances of a subject code
final subjectInstancesProvider = StreamProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, code) {
      final auth = ref.watch(authControllerProvider);

      Query query = FirebaseFirestore.instance
          .collection('subjects')
          .where('code', isEqualTo: code);

      // Filter out archived subjects
      query = query.where('isArchived', isNotEqualTo: true);

      if (!auth.isSuperAdmin && auth.institutionCode != null) {
        query = query.where('institutionCode', isEqualTo: auth.institutionCode);
      }

      return query.snapshots().map((snapshot) {
        final docs = snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {'id': doc.id, ...data};
            })
            .where((doc) => !(doc['isArchived'] == true))
            .toList(); // Client-side filter
        docs.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
        return docs;
      });
    });
