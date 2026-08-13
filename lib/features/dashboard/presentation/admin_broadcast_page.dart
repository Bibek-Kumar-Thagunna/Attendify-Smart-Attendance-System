import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';
import '../../auth/providers.dart';
import '../../super_admin/services/global_notification_service.dart';
import 'admin_shell.dart';

class AdminBroadcastPage extends ConsumerStatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  ConsumerState<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends ConsumerState<AdminBroadcastPage> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _targetRole = 'all'; // all, student, teacher
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final authState = ref.read(authControllerProvider);
    final institutionCode = authState.institutionCode;

    if (institutionCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Institution code not found')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await ref
          .read(globalNotificationServiceProvider)
          .sendGlobalNotification(
            title: _titleController.text.trim(),
            message: _messageController.text.trim(),
            targetRole: _targetRole,
            institutionId: institutionCode,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Broadcast sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _titleController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInDown(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Institution Broadcast',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send notifications to all users in your institution.',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FadeInUp(
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compose Message',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Target Selection
                    Text(
                      'Target Audience',
                      style: GoogleFonts.outfit(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TargetChip(
                            label: 'All Users',
                            selected: _targetRole == 'all',
                            onTap: () => setState(() => _targetRole = 'all'),
                          ),
                          const SizedBox(width: 12),
                          _TargetChip(
                            label: 'Students',
                            selected: _targetRole == 'student',
                            onTap: () =>
                                setState(() => _targetRole = 'student'),
                          ),
                          const SizedBox(width: 12),
                          _TargetChip(
                            label: 'Teachers',
                            selected: _targetRole == 'teacher',
                            onTap: () =>
                                setState(() => _targetRole = 'teacher'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    GlassTextField(
                      controller: _titleController,
                      label: 'Title',
                      hintText: 'e.g., Important Announcement',
                      prefixIcon: Icons.title,
                    ),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: _messageController,
                      label: 'Message',
                      hintText: 'Enter your message here...',
                      prefixIcon: Icons.message,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_sending ? 'Sending...' : 'Send Broadcast'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          textStyle: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B5CF6)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? const Color(0xFF8B5CF6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
