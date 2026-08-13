import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_shell.dart';
import '../../auth/providers.dart';

class AdminProfilePage extends ConsumerStatefulWidget {
  const AdminProfilePage({super.key});

  @override
  ConsumerState<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends ConsumerState<AdminProfilePage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _photoUrl = TextEditingController();
  final _oldPass = TextEditingController();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();
  bool _oldVerified = false;
  String? _error;

  void _verifyOld() async {
    setState(() => _error = null);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        setState(() => _error = 'User not authenticated');
        return;
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _oldPass.text,
      );
      await user.reauthenticateWithCredential(credential);

      setState(() => _oldVerified = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Old password verified'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Incorrect current password');
    }
  }

  void _changePassword() async {
    setState(() => _error = null);
    if (_newPass.text.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters.');
      return;
    }
    if (_newPass.text != _confirmPass.text) {
      setState(() => _error = 'New password and confirmation do not match.');
      return;
    }
    // Password change via Firebase Auth
    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(_newPass.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() {
      _oldVerified = false;
      _oldPass.clear();
      _newPass.clear();
      _confirmPass.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!.replaceFirst('Exception: ', ''))),
        );
      }
    });
    final state = ref.watch(authControllerProvider);

    if (_name.text.isEmpty && state.displayName != null) {
      _name.text = state.displayName!;
    }
    if (_email.text.isEmpty && state.email != null) _email.text = state.email!;
    if (_photoUrl.text.isEmpty && state.photoUrl != null) {
      _photoUrl.text = state.photoUrl!;
    }

    return AdminShell(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: state.photoUrl != null
                          ? NetworkImage(state.photoUrl!)
                          : null,
                      child: state.photoUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    readOnly: true,
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Role'),
                    child: Text(state.isAdmin ? 'Administrator' : 'User'),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: state.loading
                          ? null
                          : () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .updateProfile(
                                    displayName: _name.text.trim(),
                                    photoUrl: _photoUrl.text.trim().isEmpty
                                        ? null
                                        : _photoUrl.text.trim(),
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Profile updated'),
                                  ),
                                );
                              }
                            },
                      child: state.loading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Password',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (!_oldVerified) ...[
                    TextField(
                      controller: _oldPass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current password',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton(
                          onPressed: _verifyOld,
                          child: const Text('Verify old password'),
                        ),
                      ],
                    ),
                  ] else ...[
                    TextField(
                      controller: _newPass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New password',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPass,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _changePassword,
                      child: const Text('Change Password'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
