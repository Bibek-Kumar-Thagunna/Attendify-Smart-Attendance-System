import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'teacher_shell.dart';
import '../../auth/providers.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';

class TeacherSettingsPage extends ConsumerStatefulWidget {
  const TeacherSettingsPage({super.key});

  @override
  ConsumerState<TeacherSettingsPage> createState() =>
      _TeacherSettingsPageState();
}

class _TeacherSettingsPageState extends ConsumerState<TeacherSettingsPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _rollNumber = TextEditingController();
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
            backgroundColor: Color(0xFF10B981),
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

    try {
      await FirebaseAuth.instance.currentUser?.updatePassword(_newPass.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
      setState(() {
        _oldVerified = false;
        _oldPass.clear();
        _newPass.clear();
        _confirmPass.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change password: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
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
    if (_rollNumber.text.isEmpty && state.rollNumber != null) {
      _rollNumber.text = state.rollNumber!;
    }

    return TeacherShell(
      child: BackgroundPattern(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: Text(
                'Settings',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 100),
              child: Text(
                'Manage your profile and account security.',
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 32),

            // Profile Section
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 200),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Information',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              backgroundImage: state.photoUrl != null
                                  ? NetworkImage(state.photoUrl!)
                                  : null,
                              child: state.photoUrl == null
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 50,
                                      color: Colors.white70,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    GlassTextField(
                      controller: _name,
                      label: 'Full Name',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: _email,
                      label: 'Email Address',
                      readOnly: true,
                      prefixIcon: Icons.email_outlined,
                    ),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: _rollNumber,
                      label: 'ID Number',
                      readOnly: true,
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: state.loading
                            ? null
                            : () async {
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .updateProfile(
                                      displayName: _name.text.trim(),
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Profile updated successfully',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: state.loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Save Changes',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Security Section
            FadeInUp(
              duration: const Duration(milliseconds: 600),
              delay: const Duration(milliseconds: 300),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Security',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_oldVerified) ...[
                      GlassTextField(
                        controller: _oldPass,
                        label: 'Current Password',
                        obscureText: true,
                        prefixIcon: Icons.lock_outline_rounded,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _verifyOld,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Verify Current Password',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      GlassTextField(
                        controller: _newPass,
                        label: 'New Password',
                        obscureText: true,
                        prefixIcon: Icons.lock_reset_rounded,
                      ),
                      const SizedBox(height: 16),
                      GlassTextField(
                        controller: _confirmPass,
                        label: 'Confirm New Password',
                        obscureText: true,
                        prefixIcon: Icons.check_circle_outline_rounded,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Update Password',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
