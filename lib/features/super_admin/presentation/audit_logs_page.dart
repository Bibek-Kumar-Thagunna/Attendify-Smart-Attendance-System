import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/glass_card.dart';
import 'super_admin_shell.dart';

class AuditLogsPage extends ConsumerWidget {
  const AuditLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SuperAdminShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audit Logs',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track all critical actions performed in the system.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('audit_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_edu_rounded,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No logs found',
                          style: GoogleFonts.outfit(color: Colors.white38),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 30),
                      child: _AuditLogItem(data: data),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogItem extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AuditLogItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final action = data['action'] ?? 'Unknown Action';
    final details = data['details'] ?? '';
    final actorName = data['actorName'] ?? 'Unknown';
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = timestamp != null
        ? DateFormat('MMM dd, HH:mm').format(timestamp)
        : 'N/A';

    Color actionColor = Colors.blue;
    IconData icon = Icons.info_outline;

    if (action.contains('DELETE') ||
        action.contains('BAN') ||
        action.contains('REMOVE')) {
      actionColor = Colors.redAccent;
      icon = Icons.delete_outline;
    } else if (action.contains('CREATE') ||
        action.contains('ADD') ||
        action.contains('APPROVE')) {
      actionColor = Colors.greenAccent;
      icon = Icons.add_circle_outline;
    } else if (action.contains('UPDATE') || action.contains('EDIT')) {
      actionColor = Colors.orangeAccent;
      icon = Icons.edit_outlined;
    } else if (action.contains('LOGIN') || action.contains('IMPERSONATE')) {
      actionColor = Colors.purpleAccent;
      icon = Icons.login;
    }

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: actionColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: actionColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      action,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: actionColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'by $actorName',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            timeStr,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
