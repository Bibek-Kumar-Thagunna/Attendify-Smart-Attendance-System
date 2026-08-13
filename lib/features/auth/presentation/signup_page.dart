import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../auth/providers.dart';
import '../../shared/providers.dart';
import '../../shared/widgets/error_dialog.dart';
import '../../shared/widgets/success_dialog.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';
import '../../shared/widgets/glass_dropdown.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _roll = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  UserRole _role = UserRole.student;
  String? _selectedLectureGroupId;
  String? _selectedLabGroupId;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _roll.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error) {
        ErrorDialog.showAuthError(context, next.error!);
      }
    });
    final state = ref.watch(authControllerProvider);
    final email = state.email ?? '';

    return Scaffold(
      body: Stack(
        children: [
          BackgroundPattern(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeInUp(
                  duration: const Duration(milliseconds: 800),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: GlassCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(
                                    0xFF8B5CF6,
                                  ).withValues(alpha: 0.2),
                                  const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.2),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF6366F1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF8B5CF6,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person_add_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Complete Onboarding',
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  email.isEmpty
                                      ? 'You must continue with Google (@thapar.edu) first.'
                                      : 'Signed in as $email',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          // Form
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                GlassTextField(
                                  controller: _roll,
                                  label: 'ID Number',
                                  hintText: 'e.g., 102367009',
                                  prefixIcon: Icons.badge_outlined,
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 20),
                                GlassTextField(
                                  controller: _password,
                                  label: 'Set Password',
                                  hintText: 'Minimum 6 characters',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                GlassTextField(
                                  controller: _confirmPassword,
                                  label: 'Confirm Password',
                                  hintText: 'Re-enter your password',
                                  prefixIcon: Icons.lock_clock_outlined,
                                  obscureText: _obscureConfirmPassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Role Dropdown
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Role',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    GlassDropdown<UserRole>(
                                      value: _role,
                                      hint: 'Select Role',
                                      items: const [
                                        DropdownMenuItem(
                                          value: UserRole.student,
                                          child: Text('Student'),
                                        ),
                                        DropdownMenuItem(
                                          value: UserRole.teacher,
                                          child: Text(
                                            'Teacher (requires approval)',
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) => setState(() {
                                        _role = v ?? UserRole.student;
                                        _selectedLectureGroupId = null;
                                        _selectedLabGroupId = null;
                                      }),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                // Class group selection for students
                                if (_role == UserRole.student)
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final classGroupsAsync = ref.watch(
                                        allClassGroupsListProvider,
                                      );
                                      return classGroupsAsync.when(
                                        data: (groups) {
                                          if (groups.isEmpty) {
                                            return Text(
                                              'No class groups available yet. Contact admin.',
                                              style: GoogleFonts.outfit(
                                                color: Colors.orange,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            );
                                          }

                                          final lectureGroups = groups
                                              .where((g) => g.type == 'Lecture')
                                              .toList();
                                          final labGroups = groups
                                              .where((g) => g.type == 'Lab')
                                              .toList();

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildGroupDropdown(
                                                'Lecture Group',
                                                lectureGroups,
                                                _selectedLectureGroupId,
                                                (val) => setState(
                                                  () =>
                                                      _selectedLectureGroupId =
                                                          val,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              _buildGroupDropdown(
                                                'Lab Group',
                                                labGroups,
                                                _selectedLabGroupId,
                                                (val) => setState(
                                                  () =>
                                                      _selectedLabGroupId = val,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                        loading: () =>
                                            const LinearProgressIndicator(
                                              color: Color(0xFF8B5CF6),
                                            ),
                                        error: (e, _) => Text(
                                          'Error loading groups: $e',
                                          style: GoogleFonts.outfit(
                                            color: Colors.red,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                const SizedBox(height: 32),

                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: state.loading
                                        ? null
                                        : () async {
                                            final institutionCode = state
                                                .selectedInstitutionForSignup;

                                            if (institutionCode == null ||
                                                institutionCode.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Institution not selected. Please go back and sign in again.',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            if (_roll.text.trim().isEmpty) {
                                              ErrorDialog.show(
                                                context,
                                                title: 'ID Number Required',
                                                message:
                                                    'Please enter your ID Number to continue.',
                                              );
                                              return;
                                            }

                                            if (_roll.text.trim().length < 3) {
                                              ErrorDialog.show(
                                                context,
                                                title: 'Invalid ID Number',
                                                message:
                                                    'ID Number must be at least 3 characters long.',
                                              );
                                              return;
                                            }

                                            if (_role == UserRole.student) {
                                              if (_selectedLectureGroupId ==
                                                      null ||
                                                  _selectedLabGroupId == null) {
                                                ErrorDialog.show(
                                                  context,
                                                  title:
                                                      'Class Groups Required',
                                                  message:
                                                      'Please select both a Lecture Group and a Lab Group.',
                                                );
                                                return;
                                              }
                                            }

                                            if (_password.text.length < 6) {
                                              ErrorDialog.show(
                                                context,
                                                title: 'Password Too Short',
                                                message:
                                                    'Your password must be at least 6 characters long.',
                                              );
                                              return;
                                            }

                                            if (_password.text !=
                                                _confirmPassword.text) {
                                              ErrorDialog.showAuthError(
                                                context,
                                                'password-mismatch',
                                              );
                                              return;
                                            }

                                            if (email.isNotEmpty &&
                                                !RegExp(
                                                  r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                                                ).hasMatch(email)) {
                                              ErrorDialog.showAuthError(
                                                context,
                                                'invalid-email',
                                              );
                                              return;
                                            }

                                            await ref
                                                .read(
                                                  authControllerProvider
                                                      .notifier,
                                                )
                                                .completeOnboarding(
                                                  rollNumber: _roll.text.trim(),
                                                  password: _password.text,
                                                  role: _role,
                                                  lectureGroupId:
                                                      _selectedLectureGroupId,
                                                  labGroupId:
                                                      _selectedLabGroupId,
                                                  institutionCode:
                                                      institutionCode,
                                                );

                                            if (!context.mounted) return;

                                            await SuccessDialog.show(
                                              context,
                                              title: 'Account Created!',
                                              message:
                                                  'Your account has been successfully set up. You will now be redirected to your dashboard.',
                                              actionText: 'Continue',
                                            );

                                            if (!context.mounted) return;

                                            await ref
                                                .read(
                                                  authControllerProvider
                                                      .notifier,
                                                )
                                                .finalizeOnboarding();
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5CF6),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      shadowColor: const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.5),
                                    ),
                                    child: state.loading
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Finish Onboarding',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                Text(
                                  'Account creation requires a Thapar Google account. Teachers may require admin approval before full access.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 16),

                                Center(
                                  child: TextButton(
                                    onPressed: () => context.go('/login'),
                                    child: Text(
                                      'Back to login',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF8B5CF6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDropdown(
    String label,
    List<dynamic> groups,
    String? selectedValue,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GlassDropdown<String>(
          value: selectedValue,
          hint: 'Select $label',
          items: groups.map<DropdownMenuItem<String>>((group) {
            return DropdownMenuItem<String>(
              value: group.id,
              child: Text(group.name),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
