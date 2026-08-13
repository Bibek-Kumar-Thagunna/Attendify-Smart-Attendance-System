import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';
import '../../shared/widgets/glass_dropdown.dart';
import '../../auth/providers.dart';
import '../providers/user_management_provider.dart';
import '../services/user_management_service.dart';
import '../../dashboard/providers.dart'; // For activeInstitutionsProvider (need to create or verify)
import 'super_admin_shell.dart';

class SuperAdminUsersPage extends ConsumerStatefulWidget {
  const SuperAdminUsersPage({super.key});

  @override
  ConsumerState<SuperAdminUsersPage> createState() =>
      _SuperAdminUsersPageState();
}

class _SuperAdminUsersPageState extends ConsumerState<SuperAdminUsersPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String? _selectedInstitution;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query, String? institutionCode) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref
          .read(superAdminUserSearchProvider.notifier)
          .searchUsers(query, institutionCode: institutionCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(superAdminUserSearchProvider);

    return SuperAdminShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global User Search',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find and manage any user across all institutions.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: GlassTextField(
                  controller: _searchController,
                  label: 'Search Users',
                  hintText: 'Search by name or email...',
                  prefixIcon: Icons.search,
                  onChanged: (val) =>
                      _onSearchChanged(val, _selectedInstitution),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: ref
                    .watch(activeInstitutionsProvider)
                    .when(
                      data: (institutions) => GlassDropdown<String>(
                        value: _selectedInstitution,
                        hint: 'All Institutions',
                        icon: const Icon(Icons.business, color: Colors.white54),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Institutions'),
                          ),
                          ...institutions.map(
                            (inst) => DropdownMenuItem(
                              value: inst['code'],
                              child: Text(inst['name'] ?? inst['code']),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedInstitution = val);
                          _onSearchChanged(_searchController.text, val);
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => const SizedBox(),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: searchResults.when(
              data: (users) {
                if (users.isEmpty && _searchController.text.isNotEmpty) {
                  return Center(
                    child: Text(
                      'No users found matching "${_searchController.text}"',
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  );
                }
                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start typing to search users',
                          style: GoogleFonts.outfit(color: Colors.white38),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50),
                      child: _UserListItem(user: user, ref: ref),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final WidgetRef ref;

  const _UserListItem({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final role = user['role'] ?? 'unknown';
    final institutionCode = user['institutionCode'] ?? 'N/A';
    final isActive =
        user['active'] ?? true; // Assuming active by default if field missing

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            child: Text(
              (user['displayName'] as String? ?? 'U')[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF8B5CF6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['displayName'] ?? 'Unknown User',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  user['email'] ?? '',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _RoleChip(role: role),
                    const SizedBox(width: 8),
                    Text(
                      '•  $institutionCode',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'impersonate',
                child: Row(
                  children: [
                    Icon(Icons.login, color: Colors.purpleAccent, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Login As',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Edit User',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'toggle_active',
                child: Row(
                  children: [
                    Icon(
                      isActive ? Icons.block : Icons.check_circle,
                      color: isActive ? Colors.redAccent : Colors.greenAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isActive ? 'Deactivate' : 'Activate',
                      style: GoogleFonts.outfit(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'impersonate') {
                _confirmImpersonation(context, ref, user);
              } else if (value == 'edit') {
                _showEditDialog(context, ref, user);
              } else if (value == 'toggle_active') {
                _confirmToggleActive(context, ref, user, isActive);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmImpersonation(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Impersonate User?',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          'You are about to log in as ${user['displayName']}. You will see exactly what they see.\n\nTo return, click the "Stop Impersonation" banner.',
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
            style: FilledButton.styleFrom(backgroundColor: Colors.purpleAccent),
            child: Text(
              'Login As User',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Perform impersonation
      await ref
          .read(authControllerProvider.notifier)
          .impersonateUser(user['id']);
      // Router will automatically redirect based on new role
    }
  }

  Future<void> _confirmToggleActive(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
    bool isActive,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          isActive ? 'Deactivate User?' : 'Activate User?',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          isActive
              ? 'This will prevent ${user['displayName']} from logging in.'
              : 'This will allow ${user['displayName']} to log in again.',
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
            style: FilledButton.styleFrom(
              backgroundColor: isActive ? Colors.redAccent : Colors.greenAccent,
            ),
            child: Text(
              isActive ? 'Deactivate' : 'Activate',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(userManagementServiceProvider)
          .toggleUserActive(user['id'], !isActive);
      // Refresh search results
      ref.invalidate(superAdminUserSearchProvider);
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> user,
  ) async {
    final nameController = TextEditingController(text: user['displayName']);
    final emailController = TextEditingController(text: user['email']);
    final rollController = TextEditingController(
      text: user['rollNumber'] ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Edit User',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassTextField(
                controller: nameController,
                label: 'Display Name',
                prefixIcon: Icons.person,
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: emailController,
                label: 'Email',
                prefixIcon: Icons.email,
              ),
              const SizedBox(height: 16),
              GlassTextField(
                controller: rollController,
                label: 'Roll Number (Optional)',
                prefixIcon: Icons.numbers,
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
              final updates = {
                'displayName': nameController.text.trim(),
                'email': emailController.text.trim(),
                'rollNumber': rollController.text.trim(),
              };
              await ref
                  .read(userManagementServiceProvider)
                  .updateUser(user['id'], updates);
              if (context.mounted) Navigator.pop(context);
              ref.invalidate(superAdminUserSearchProvider);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
            ),
            child: Text(
              'Save Changes',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;

  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (role) {
      case 'admin':
        color = Colors.redAccent;
        break;
      case 'teacher':
        color = Colors.orangeAccent;
        break;
      case 'student':
        color = Colors.blueAccent;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        role.toUpperCase(),
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
