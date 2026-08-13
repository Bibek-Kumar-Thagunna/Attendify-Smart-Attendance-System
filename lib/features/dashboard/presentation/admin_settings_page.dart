import 'package:flutter/material.dart';
import 'admin_shell.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final org = TextEditingController(text: 'Attendify HQ');
    final email = TextEditingController(text: 'admin@attendify.app');
    return AdminShell(
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: org,
                    decoration: const InputDecoration(
                      labelText: 'Organization name',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: email,
                    decoration: const InputDecoration(
                      labelText: 'Contact email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () {}, child: const Text('Save')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
