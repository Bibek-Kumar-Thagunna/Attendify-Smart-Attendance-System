import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../institutions/models.dart';
import '../../institutions/providers.dart';
import '../../super_admin/presentation/super_admin_shell.dart';

class AdminInstitutionsPage extends ConsumerStatefulWidget {
  const AdminInstitutionsPage({super.key});

  @override
  ConsumerState<AdminInstitutionsPage> createState() =>
      _AdminInstitutionsPageState();
}

class _AdminInstitutionsPageState extends ConsumerState<AdminInstitutionsPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncRows = ref.watch(institutionsStreamProvider);
    return SuperAdminShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search institutions...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _syncCounts(context, ref),
                icon: const Icon(Icons.sync),
                tooltip: 'Sync Student Counts',
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () => _openCreateDialog(context),
                child: MediaQuery.of(context).size.width < 600
                    ? const Icon(Icons.add)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text('Add Institution'),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: asyncRows.when(
              data: (rows) {
                final filtered = rows
                    .where(
                      (e) =>
                          e.name.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList();
                return Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Code')),
                        DataColumn(label: Text('Email Domain')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Students')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: [
                        for (final e in filtered)
                          DataRow(
                            cells: [
                              DataCell(Text(e.name)),
                              DataCell(Text(e.code)),
                              DataCell(
                                Text(
                                  e.emailDomain.isNotEmpty
                                      ? '@${e.emailDomain}'
                                      : 'Not set',
                                ),
                              ),
                              DataCell(_statusChip(e.status)),
                              DataCell(Text(e.students.toString())),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => _editDialog(context, e),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      onPressed: () => context.push(
                                        '/super-admin/institutions/${e.code}',
                                      ),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        color: Colors.blue,
                                      ),
                                      tooltip: 'View Details',
                                    ),
                                    IconButton(
                                      onPressed: () => ref
                                          .read(institutionsActionsProvider)
                                          .removeInstitution(e.code),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Failed to load institutions: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color c;
    switch (status) {
      case 'Active':
        c = Colors.green;
        break;
      case 'Pending':
        c = Colors.orange;
        break;
      default:
        c = Colors.red;
    }
    return Chip(
      label: Text(status),
      backgroundColor: c.withValues(alpha: .12),
      side: BorderSide.none,
      labelStyle: TextStyle(color: c),
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    final name = TextEditingController();
    final code = TextEditingController();
    final emailDomain = TextEditingController();
    String status = 'Active';
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Institution'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: code,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailDomain,
                decoration: const InputDecoration(
                  labelText: 'Email Domain',
                  hintText: 'e.g., thapar.edu',
                  helperText: 'Without @ symbol',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'Suspended',
                    child: Text('Suspended'),
                  ),
                ],
                onChanged: (v) => status = v ?? 'Active',
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty ||
                  code.text.trim().isEmpty ||
                  emailDomain.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All fields are required')),
                );
                return;
              }
              ref
                  .read(institutionsActionsProvider)
                  .addInstitution(
                    Institution(
                      name: name.text.trim(),
                      code: code.text.trim(),
                      status: status,
                      students: 0,
                      emailDomain: emailDomain.text.trim().replaceAll('@', ''),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncCounts(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Syncing student counts...')));

    try {
      final firestore = FirebaseFirestore.instance;
      final institutions = await firestore.collection('institutions').get();
      int updated = 0;

      for (final doc in institutions.docs) {
        final code = doc.data()['code'] as String?;
        if (code == null) continue;

        final countQuery = await firestore
            .collection('users')
            .where('institutionCode', isEqualTo: code)
            .where('role', isEqualTo: 'student')
            .count()
            .get();

        final count = countQuery.count ?? 0;

        if (doc.data()['students'] != count) {
          await doc.reference.update({'students': count});
          updated++;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync complete. Updated $updated institutions.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    }
  }

  Future<void> _editDialog(BuildContext context, Institution i) async {
    final name = TextEditingController(text: i.name);
    final emailDomain = TextEditingController(text: i.emailDomain);
    String status = i.status;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Institution'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailDomain,
                decoration: const InputDecoration(
                  labelText: 'Email Domain',
                  hintText: 'e.g., thapar.edu',
                  helperText: 'Without @ symbol',
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(
                    value: 'Suspended',
                    child: Text('Suspended'),
                  ),
                ],
                onChanged: (v) => status = v ?? 'Active',
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(institutionsActionsProvider)
                  .updateInstitution(
                    i.code,
                    i.copyWith(
                      name: name.text.trim(),
                      status: status,
                      emailDomain: emailDomain.text.trim().replaceAll('@', ''),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
