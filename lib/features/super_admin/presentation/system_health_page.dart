import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/widgets/glass_card.dart';
import '../providers/system_health_provider.dart';
import 'super_admin_shell.dart';

class SystemHealthPage extends ConsumerWidget {
  const SystemHealthPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(systemHealthProvider);
    final load = ref.watch(serverLoadProvider);

    return SuperAdminShell(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Health Monitor',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                SizedBox(
                  width: 400,
                  child: _HealthCard(
                    title: 'Database Connectivity',
                    statusAsync: health,
                  ),
                ),
                SizedBox(
                  width: 400,
                  child: _LoadCard(title: 'Server Load', loadAsync: load),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.title, required this.statusAsync});
  final String title;
  final AsyncValue<SystemStatus> statusAsync;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          statusAsync.when(
            data: (status) {
              IconData icon;
              Color color;
              String text;
              switch (status) {
                case SystemStatus.healthy:
                  icon = Icons.check_circle_outline_rounded;
                  color = Colors.green;
                  text = 'Operational';
                  break;
                case SystemStatus.degraded:
                  icon = Icons.warning_amber_rounded;
                  color = Colors.orange;
                  text = 'Degraded Performance';
                  break;
                case SystemStatus.down:
                  icon = Icons.error_outline_rounded;
                  color = Colors.red;
                  text = 'System Down';
                  break;
              }
              return Column(
                children: [
                  Icon(icon, size: 64, color: color),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: GoogleFonts.outfit(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) =>
                const Icon(Icons.error, color: Colors.red, size: 64),
          ),
        ],
      ),
    );
  }
}

class _LoadCard extends StatelessWidget {
  const _LoadCard({required this.title, required this.loadAsync});
  final String title;
  final AsyncValue<ServerLoad> loadAsync;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 24),
          loadAsync.when(
            data: (load) {
              IconData icon;
              Color color;
              String text;
              switch (load) {
                case ServerLoad.low:
                  icon = Icons.speed_rounded;
                  color = Colors.green;
                  text = 'Low Traffic';
                  break;
                case ServerLoad.medium:
                  icon = Icons.speed_rounded;
                  color = Colors.orange;
                  text = 'Moderate Traffic';
                  break;
                case ServerLoad.high:
                  icon = Icons.local_fire_department_rounded;
                  color = Colors.red;
                  text = 'High Traffic';
                  break;
              }
              return Column(
                children: [
                  Icon(icon, size: 64, color: color),
                  const SizedBox(height: 16),
                  Text(
                    text,
                    style: GoogleFonts.outfit(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) =>
                const Icon(Icons.error, color: Colors.red, size: 64),
          ),
        ],
      ),
    );
  }
}
