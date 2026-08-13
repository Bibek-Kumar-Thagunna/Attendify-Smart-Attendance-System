import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/utils/error_handler.dart';
import '../../auth/providers.dart';
import '../../shared/providers.dart';
import '../../shared/widgets/empty_state.dart';
import 'teacher_shell.dart';
import '../../../core/responsive_utils.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';

// Provider for subjects grouped by type (Lecture/Lab), then by class/group
final subjectsProvider =
    StreamProvider.autoDispose<
      Map<String, Map<String, List<Map<String, dynamic>>>>
    >((ref) {
      final auth = ref.watch(authControllerProvider);
      final teacherUid = auth.uid;
      if (teacherUid == null) return const Stream.empty();

      return FirebaseFirestore.instance
          .collection('subjects')
          .where('teacherUid', isEqualTo: teacherUid)
          .snapshots()
          .map((snapshot) {
            final Map<String, Map<String, List<Map<String, dynamic>>>> grouped =
                {'Lecture': {}, 'Lab': {}};
            for (final doc in snapshot.docs) {
              final data = {'id': doc.id, ...doc.data()};
              final type = data['type'] as String? ?? 'Lecture';
              final group = data['group'] as String? ?? 'No Group';
              grouped.putIfAbsent(type, () => {});
              grouped[type]!.putIfAbsent(group, () => []);
              grouped[type]![group]!.add(data);
            }
            final sortedGrouped =
                <String, Map<String, List<Map<String, dynamic>>>>{};
            for (final typeEntry in grouped.entries) {
              if (typeEntry.value.isNotEmpty) {
                sortedGrouped[typeEntry.key] = Map.fromEntries(
                  typeEntry.value.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key)),
                );
              }
            }
            return sortedGrouped;
          });
    });

class TeacherSubjectsPage extends ConsumerWidget {
  const TeacherSubjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return TeacherShell(
      child: BackgroundPattern(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHeader(context, ref),
            const SizedBox(height: 24),
            subjectsAsync.when(
              data: (groupedSubjects) {
                // Check if there are any subjects at all
                final hasSubjects = groupedSubjects.values.any(
                  (groups) => groups.isNotEmpty,
                );

                if (!hasSubjects) {
                  return FadeInUp(
                    duration: const Duration(milliseconds: 500),
                    child: GlassCard(
                      padding: const EdgeInsets.all(48),
                      child: const EmptyState(
                        icon: Icons.book_outlined,
                        title: 'No Subjects Added',
                        subtitle: 'Add your first subject to get started',
                        color: Colors.white54,
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Iterate through types (Lecture/Lab)
                    ...groupedSubjects.entries
                        .where((typeEntry) => typeEntry.value.isNotEmpty)
                        .expand((typeEntry) {
                          final type = typeEntry.key;
                          final groups = typeEntry.value;

                          return [
                            _buildTypeSection(context, ref, type, groups),
                            const SizedBox(height: 24),
                          ];
                        }),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, _) => Center(
                child: GlassCard(
                  padding: const EdgeInsets.all(32),
                  child: ErrorHandler.buildErrorWidget(
                    error,
                    customMessage: 'Unable to load subjects',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final isMobile = context.isMobile;

    return FadeInDown(
      duration: const Duration(milliseconds: 500),
      child: GlassCard(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: isMobile
            ? Column(
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Subjects',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your teaching subjects',
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddSubjectDialog(context, ref),
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Add Subject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                          'My Subjects',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your teaching subjects and classes',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddSubjectDialog(context, ref),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Subject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTypeSection(
    BuildContext context,
    WidgetRef ref,
    String type,
    Map<String, List<Map<String, dynamic>>> groups,
  ) {
    final isLab = type == 'Lab';
    final typeColor = isLab ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final typeIcon = isLab ? Icons.science_outlined : Icons.school_outlined;

    // Count total subjects in this type
    final totalSubjects = groups.values.fold<int>(
      0,
      (prev, subjects) => prev + subjects.length,
    );

    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type header (Lectures or Labs)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  typeColor.withValues(alpha: 0.15),
                  typeColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: typeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  '${type}s',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: typeColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalSubjects subject${totalSubjects != 1 ? 's' : ''}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: typeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Groups within this type
          ...groups.entries.map((groupEntry) {
            return Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 16),
              child: _buildGroupSection(
                context,
                ref,
                groupEntry.key,
                groupEntry.value,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    WidgetRef ref,
    String group,
    List<Map<String, dynamic>> subjects,
  ) {
    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.class_,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          group,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8B5CF6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${subjects.length} subject${subjects.length != 1 ? 's' : ''}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return _buildSubjectCard(context, ref, subject);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> subject,
  ) {
    final colors = [
      const Color(0xFF10B981), // emerald
      const Color(0xFF3B82F6), // blue
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEC4899), // pink
    ];
    final color = colors[subject['name'].toString().length % colors.length];

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 40 : 48,
            height: isMobile ? 40 : 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.book_outlined,
              color: color,
              size: isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject['name'] ?? 'Untitled',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTypeBadge(subject['type'] ?? 'Lecture'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subject['code'] ?? 'No Code',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (isMobile)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF1F2937),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditSubjectDialog(context, ref, subject);
                } else if (value == 'delete') {
                  _confirmDeleteSubject(
                    context,
                    ref,
                    subject['id'],
                    subject['name'],
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Text('Edit', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            IconButton(
              onPressed: () => _showEditSubjectDialog(context, ref, subject),
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF10B981)),
              tooltip: 'Edit Subject',
            ),
            IconButton(
              onPressed: () => _confirmDeleteSubject(
                context,
                ref,
                subject['id'],
                subject['name'],
              ),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Subject',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    final isLab = type == 'Lab';
    final color = isLab ? const Color(0xFF10B981) : const Color(0xFF3B82F6);
    final icon = isLab ? Icons.science_outlined : Icons.school_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            type,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
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
      builder: (context) => _EditSubjectDialog(subject: subject),
    );
  }

  void _confirmDeleteSubject(
    BuildContext context,
    WidgetRef ref,
    String subjectId,
    String subjectName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: Text(
          'Delete Subject',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$subjectName"?',
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
            onPressed: () async {
              try {
                final repo = ref.read(subjectRepositoryProvider);
                await repo.deleteSubject(subjectId);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subject deleted successfully!'),
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
                    customMessage: 'Unable to delete subject',
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Delete',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// Provider for subject catalog (teacher view)
final subjectCatalogProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final auth = ref.watch(authControllerProvider);

      Query query = FirebaseFirestore.instance.collection('subject_catalog');

      if (auth.institutionCode != null) {
        query = query.where('institutionCode', isEqualTo: auth.institutionCode);
      }

      return query.snapshots().map((snapshot) {
        final docs = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
        docs.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );
        return docs;
      });
    });

class _AddSubjectDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _AddSubjectDialog({required this.ref});

  @override
  ConsumerState<_AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends ConsumerState<_AddSubjectDialog> {
  final nameController = TextEditingController();
  final codeController = TextEditingController();
  final LayerLink _layerLink = LayerLink();
  String? selectedGroup; // Stores Group Name
  String? selectedGroupId; // Stores Group ID
  String selectedType = 'Lecture';

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(allClassGroupsListProvider);
    final catalogAsync = ref.watch(subjectCatalogProvider);

    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      title: Text(
        'Add New Subject',
        style: GoogleFonts.outfit(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subject Name with Autocomplete
            catalogAsync.when(
              data: (catalog) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (catalog.isNotEmpty) ...[
                      Text(
                        'Subject Name',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    RawAutocomplete<Map<String, dynamic>>(
                      textEditingController: nameController,
                      focusNode: FocusNode(),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return const Iterable<Map<String, dynamic>>.empty();
                        }
                        final matches = catalog.where((
                          Map<String, dynamic> option,
                        ) {
                          return option['name']
                              .toString()
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });

                        if (matches.isEmpty) {
                          return [
                            {
                              'name': 'No subject found',
                              'code': '',
                              'id': 'NO_MATCH',
                            },
                          ];
                        }
                        return matches;
                      },
                      displayStringForOption: (Map<String, dynamic> option) =>
                          option['name'],
                      onSelected: (Map<String, dynamic> selection) {
                        if (selection['id'] == 'NO_MATCH') return;
                        codeController.text = selection['code'];
                      },
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return CompositedTransformTarget(
                              link: _layerLink,
                              child: GlassTextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                label: 'Subject Name',
                                hintText: 'Search from catalog...',
                                prefixIcon: Icons.search,
                              ),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: CompositedTransformFollower(
                            link: _layerLink,
                            showWhenUnlinked: false,
                            targetAnchor: Alignment.bottomLeft,
                            followerAnchor: Alignment.topLeft,
                            offset: const Offset(0, 4),
                            child: Material(
                              elevation: 8.0,
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFF1F2937),
                              clipBehavior: Clip.antiAlias,
                              child: SizedBox(
                                width: 300, // Fixed safe width for dialog
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 250,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          final option = options.elementAt(
                                            index,
                                          );

                                          if (option['id'] == 'NO_MATCH') {
                                            return ListTile(
                                              leading: const Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange,
                                              ),
                                              title: Text(
                                                option['name'],
                                                style: const TextStyle(
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            );
                                          }

                                          return ListTile(
                                            leading: const Icon(
                                              Icons.book_outlined,
                                              size: 20,
                                              color: Colors.white70,
                                            ),
                                            title: Text(
                                              option['name'],
                                              style: GoogleFonts.outfit(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            subtitle: Text(
                                              option['code'],
                                              style: GoogleFonts.outfit(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                            onTap: () => onSelected(option),
                                          );
                                        },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const TextField(
                enabled: false,
                decoration: InputDecoration(labelText: 'Error loading catalog'),
              ),
            ),

            const SizedBox(height: 16),
            GlassTextField(
              controller: codeController,
              label: 'Subject Code',
              hintText: 'e.g., CS201',
              prefixIcon: Icons.tag,
            ),
            const SizedBox(height: 16),

            // Type Selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedType,
                  dropdownColor: const Color(0xFF1F2937),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Lecture',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.school_outlined,
                              color: Color(0xFF3B82F6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Lecture',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Lab',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.science_outlined,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Lab',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Group Selection
            groupsAsync.when(
              data: (groups) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedGroupId,
                      hint: Text(
                        'Select Class Group',
                        style: GoogleFonts.outfit(color: Colors.white54),
                      ),
                      dropdownColor: const Color(0xFF1F2937),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      items: groups.map((group) {
                        return DropdownMenuItem<String>(
                          value: group.id,
                          child: Text(
                            group.name,
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGroupId = value;
                          selectedGroup = groups
                              .firstWhere((g) => g.id == value)
                              .name;
                        });
                      },
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text(
                'Error loading groups',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
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
            if (nameController.text.isEmpty || selectedGroupId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all fields')),
              );
              return;
            }

            try {
              final auth = ref.read(authControllerProvider);
              if (auth.uid == null || auth.institutionCode == null) {
                throw Exception('User not authenticated');
              }

              final repo = ref.read(subjectRepositoryProvider);
              await repo.addSubject(
                teacherUid: auth.uid!,
                institutionCode: auth.institutionCode!,
                name: nameController.text,
                code: codeController.text,
                type: selectedType,
                groupName: selectedGroup!,
                groupId: selectedGroupId!,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subject added successfully!'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ErrorHandler.showErrorSnackBar(
                  context,
                  e,
                  customMessage: 'Unable to add subject',
                );
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Add Subject',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _EditSubjectDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> subject;

  const _EditSubjectDialog({required this.subject});

  @override
  ConsumerState<_EditSubjectDialog> createState() => _EditSubjectDialogState();
}

class _EditSubjectDialogState extends ConsumerState<_EditSubjectDialog> {
  late TextEditingController nameController;
  late TextEditingController codeController;
  late String selectedType;
  String? selectedGroup;
  String? selectedGroupId;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.subject['name']);
    codeController = TextEditingController(text: widget.subject['code']);
    selectedType = widget.subject['type'] ?? 'Lecture';
    selectedGroup = widget.subject['group'];
    selectedGroupId = widget.subject['groupId'];
  }

  @override
  void dispose() {
    nameController.dispose();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(allClassGroupsListProvider);

    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      title: Text(
        'Edit Subject',
        style: GoogleFonts.outfit(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassTextField(
              controller: nameController,
              label: 'Subject Name',
              prefixIcon: Icons.book,
            ),
            const SizedBox(height: 16),
            GlassTextField(
              controller: codeController,
              label: 'Subject Code',
              prefixIcon: Icons.tag,
            ),
            const SizedBox(height: 16),

            // Type Selection
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selectedType,
                  dropdownColor: const Color(0xFF1F2937),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white70,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'Lecture',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF3B82F6,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.school_outlined,
                              color: Color(0xFF3B82F6),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Lecture',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Lab',
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.science_outlined,
                              color: Color(0xFF10B981),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Lab',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Group Selection
            groupsAsync.when(
              data: (groups) {
                // Ensure selectedGroupId is valid, otherwise reset
                if (selectedGroupId != null &&
                    !groups.any((g) => g.id == selectedGroupId)) {
                  selectedGroupId = null;
                  selectedGroup = null;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedGroupId,
                      hint: Text(
                        'Select Class Group',
                        style: GoogleFonts.outfit(color: Colors.white54),
                      ),
                      dropdownColor: const Color(0xFF1F2937),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                      items: groups.map((group) {
                        return DropdownMenuItem<String>(
                          value: group.id,
                          child: Text(
                            group.name,
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedGroupId = value;
                          selectedGroup = groups
                              .firstWhere((g) => g.id == value)
                              .name;
                        });
                      },
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text(
                'Error loading groups',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
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
            if (nameController.text.isEmpty || selectedGroupId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill all fields')),
              );
              return;
            }

            try {
              final auth = ref.read(authControllerProvider);
              final repo = ref.read(subjectRepositoryProvider);

              await repo.updateSubject(
                subjectId: widget.subject['id'],
                name: nameController.text,
                code: codeController.text,
                type: selectedType,
                groupName: selectedGroup,
                groupId: selectedGroupId,
                oldGroupId: widget.subject['groupId'],
                teacherUid: auth.uid,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Subject updated successfully!'),
                    backgroundColor: Color(0xFF10B981),
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
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Save Changes',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
