import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../dashboard/providers.dart';
import '../../shared/widgets/glass_card.dart';
import '../providers/system_health_provider.dart';
import 'super_admin_shell.dart';

class SuperAdminDashboardPage extends ConsumerWidget {
  const SuperAdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeInstitutions = ref.watch(activeInstitutionsCountProvider);
    final totalUsers = ref.watch(totalUsersCountProvider);
    final systemHealth = ref.watch(systemHealthProvider);
    final serverLoad = ref.watch(serverLoadProvider);

    return SuperAdminShell(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Super Admin Dashboard',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'System-wide overview and governance.',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats Grid
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 1200
                  ? 4
                  : (MediaQuery.of(context).size.width > 800 ? 2 : 1),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StatCard(
                  title: 'Active Institutions',
                  valueAsync: activeInstitutions,
                  icon: Icons.apartment_rounded,
                  color: Colors.blue,
                ),
                _StatCard(
                  title: 'Total Users',
                  valueAsync: totalUsers,
                  icon: Icons.people_alt_rounded,
                  color: Colors.purple,
                ),
                _SystemHealthCard(healthAsync: systemHealth),
                _ServerLoadCard(loadAsync: serverLoad),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.valueAsync,
    required this.icon,
    required this.color,
  });

  final String title;
  final AsyncValue<int> valueAsync;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          valueAsync.when(
            data: (value) => Text(
              value.toString(),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            loading: () => const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => Text(
              '--',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemHealthCard extends StatelessWidget {
  const _SystemHealthCard({required this.healthAsync});

  final AsyncValue<SystemStatus> healthAsync;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'System Status',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              healthAsync.when(
                data: (status) {
                  Color color;
                  IconData icon;
                  switch (status) {
                    case SystemStatus.healthy:
                      color = Colors.green;
                      icon = Icons.check_circle_rounded;
                      break;
                    case SystemStatus.degraded:
                      color = Colors.orange;
                      icon = Icons.warning_rounded;
                      break;
                    case SystemStatus.down:
                      color = Colors.red;
                      icon = Icons.error_rounded;
                      break;
                  }
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  );
                },
                loading: () => const SizedBox(width: 20, height: 20),
                error: (_, __) => const SizedBox(width: 20, height: 20),
              ),
            ],
          ),
          healthAsync.when(
            data: (status) {
              String text;
              Color color;
              switch (status) {
                case SystemStatus.healthy:
                  text = 'Healthy';
                  color = Colors.green;
                  break;
                case SystemStatus.degraded:
                  text = 'Degraded';
                  color = Colors.orange;
                  break;
                case SystemStatus.down:
                  text = 'Down';
                  color = Colors.red;
                  break;
              }
              return Text(
                text,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
            loading: () => const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => Text(
              'Unknown',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerLoadCard extends StatelessWidget {
  const _ServerLoadCard({required this.loadAsync});

  final AsyncValue<ServerLoad> loadAsync;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Server Load',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              loadAsync.when(
                data: (load) {
                  Color color;
                  IconData icon;
                  switch (load) {
                    case ServerLoad.low:
                      color = Colors.green;
                      icon = Icons.speed_rounded;
                      break;
                    case ServerLoad.medium:
                      color = Colors.orange;
                      icon = Icons.speed_rounded;
                      break;
                    case ServerLoad.high:
                      color = Colors.red;
                      icon = Icons.speed_rounded;
                      break;
                  }
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  );
                },
                loading: () => const SizedBox(width: 20, height: 20),
                error: (_, __) => const SizedBox(width: 20, height: 20),
              ),
            ],
          ),
          loadAsync.when(
            data: (load) {
              String text;
              Color color;
              switch (load) {
                case ServerLoad.low:
                  text = 'Low';
                  color = Colors.green;
                  break;
                case ServerLoad.medium:
                  text = 'Medium';
                  color = Colors.orange;
                  break;
                case ServerLoad.high:
                  text = 'High';
                  color = Colors.red;
                  break;
              }
              return Text(
                text,
                style: GoogleFonts.outfit(
                  color: color,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
            loading: () => const SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => Text(
              'Unknown',
              style: GoogleFonts.outfit(
                color: Colors.grey,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
