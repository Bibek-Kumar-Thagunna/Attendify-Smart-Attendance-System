import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../shared/widgets/glass_card.dart';
import 'super_admin_shell.dart';

class SuperAdminAboutPage extends StatelessWidget {
  const SuperAdminAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperAdminShell(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 900;

                return Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 48),
                    if (isDesktop)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildProjectInfo(context)),
                            const SizedBox(width: 24),
                            Expanded(child: _buildTeamSection(context)),
                          ],
                        ),
                      )
                    else ...[
                      _buildProjectInfo(context),
                      const SizedBox(height: 24),
                      _buildTeamSection(context),
                    ],
                    const SizedBox(height: 48),
                    _buildFooter(context),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.school_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Attendify',
          style: GoogleFonts.outfit(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Smart Attendance Management System',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 18,
            color: Colors.white70,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Text(
            'Version 1.0.0',
            style: GoogleFonts.outfit(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectInfo(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'About the Project',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Attendify is a comprehensive attendance management solution designed to streamline the process for educational institutions. Built as part of our Software Engineering curriculum, it demonstrates modern development practices and user-centric design.',
            style: GoogleFonts.outfit(
              fontSize: 16,
              height: 1.6,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_outlined, color: Colors.purpleAccent),
              const SizedBox(width: 12),
              Text(
                'Development Team',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTeamMember(context, 'Lead Developers', 'Om, Bibek, Suyogya'),
          const SizedBox(height: 16),
          _buildTeamMember(context, 'UI/UX Designers', 'Om, Bibek, Priam'),
          const SizedBox(height: 16),
          _buildTeamMember(
            context,
            'Backend Engineers',
            'Bibek, Priam, Nimish',
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMember(
    BuildContext context,
    String role,
    String description,
  ) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                description,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        Text(
          '© 2025 Attendify. All rights reserved.',
          style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: Text(
                'Privacy Policy',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
              ),
            ),
            Text('•', style: TextStyle(color: Colors.white24)),
            TextButton(
              onPressed: () {},
              child: Text(
                'Terms of Service',
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
