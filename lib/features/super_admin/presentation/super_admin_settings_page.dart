import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../shared/widgets/glass_card.dart';
import '../services/system_settings_service.dart';
import 'super_admin_shell.dart';

class SuperAdminSettingsPage extends ConsumerStatefulWidget {
  const SuperAdminSettingsPage({super.key});

  @override
  ConsumerState<SuperAdminSettingsPage> createState() =>
      _SuperAdminSettingsPageState();
}

class _SuperAdminSettingsPageState
    extends ConsumerState<SuperAdminSettingsPage> {
  final _announcementController = TextEditingController();

  @override
  void dispose() {
    _announcementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(systemSettingsStreamProvider);

    return SuperAdminShell(
      child: settingsAsync.when(
        data: (settings) {
          // Update local state if needed, or just use settings directly
          // Using settings directly is better for streams
          final maintenanceMode = settings['maintenanceMode'] ?? false;
          final allowNewRegistrations =
              settings['allowNewRegistrations'] ?? true;
          final globalAnnouncement = settings['globalAnnouncement'] ?? '';

          // Only update controller if text is empty (initial load) to avoid overwriting user input
          if (_announcementController.text.isEmpty &&
              globalAnnouncement.isNotEmpty) {
            _announcementController.text = globalAnnouncement;
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'System Settings',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Configure global system behavior and flags.',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // System Control
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Control',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SwitchListTile(
                          title: Text(
                            'Maintenance Mode',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Prevent non-admin users from logging in',
                            style: GoogleFonts.outfit(color: Colors.white54),
                          ),
                          value: maintenanceMode,
                          onChanged: (value) {
                            ref
                                .read(systemSettingsServiceProvider)
                                .updateMaintenanceMode(value);
                          },
                          activeThumbColor: Colors.redAccent,
                        ),
                        const Divider(color: Colors.white10),
                        SwitchListTile(
                          title: Text(
                            'Allow New Registrations',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                          subtitle: Text(
                            'Enable or disable new user signups globally',
                            style: GoogleFonts.outfit(color: Colors.white54),
                          ),
                          value: allowNewRegistrations,
                          onChanged: (value) {
                            ref
                                .read(systemSettingsServiceProvider)
                                .updateAllowNewRegistrations(value);
                          },
                          activeThumbColor: const Color(0xFF8B5CF6),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Global Announcement
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Global Announcement',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This message will be displayed to all users on their dashboard.',
                          style: GoogleFonts.outfit(color: Colors.white54),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _announcementController,
                          style: GoogleFonts.outfit(color: Colors.white),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter announcement message...',
                            hintStyle: GoogleFonts.outfit(
                              color: Colors.white30,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () async {
                              await ref
                                  .read(systemSettingsServiceProvider)
                                  .updateGlobalAnnouncement(
                                    _announcementController.text,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Announcement updated'),
                                  ),
                                );
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                            ),
                            child: const Text('Update Announcement'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }
}
