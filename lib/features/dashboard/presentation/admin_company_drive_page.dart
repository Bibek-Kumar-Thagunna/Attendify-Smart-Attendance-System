import 'package:flutter/material.dart';
import 'admin_shell.dart';

class AdminCompanyDrivePage extends StatelessWidget {
  const AdminCompanyDrivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final requests = [
      {'company': 'Acme Corp', 'dept': 'CSE', 'status': 'Pending'},
      {'company': 'Globex', 'dept': 'ECE', 'status': 'Accepted'},
      {'company': 'Initech', 'dept': 'ME', 'status': 'Rejected'},
    ];
    return AdminShell(
      child: Card(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (_, i) {
            final r = requests[i];
            return ListTile(
              leading: const Icon(Icons.business),
              title: Text(r['company']!),
              subtitle: Text('Department: ${r['dept']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(r['status']!),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.check_circle_outline),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const Divider(),
          itemCount: requests.length,
        ),
      ),
    );
  }
}
