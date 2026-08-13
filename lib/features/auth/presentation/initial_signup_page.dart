import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers.dart';
import '../../institutions/providers.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/error_dialog.dart';

class InitialSignupPage extends ConsumerStatefulWidget {
  const InitialSignupPage({super.key});

  @override
  ConsumerState<InitialSignupPage> createState() => _InitialSignupPageState();
}

class _InitialSignupPageState extends ConsumerState<InitialSignupPage> {
  String? _selectedInstitutionCode;

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      // Prevent background pages from showing dialogs
      if (ModalRoute.of(context)?.isCurrent != true) return;

      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error) {
        // Check for account-already-exists (handling potential Exception: prefix)
        if (next.error!.contains('account-already-exists')) {
          ErrorDialog.show(
            context,
            title: 'Account Already Exists',
            message:
                'You already have an account with this email. Please log in instead.',
            actionText: 'Log in',
            onAction: () {
              ref.read(authControllerProvider.notifier).clearError();
              context.go('/login');
            },
          ).then((_) {
            ref.read(authControllerProvider.notifier).clearError();
          });
        } else {
          ErrorDialog.showAuthError(context, next.error!).then((_) {
            ref.read(authControllerProvider.notifier).clearError();
          });
        }
      }
    });

    final state = ref.watch(authControllerProvider);

    // Check for errors or navigation immediately on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Check for navigation to onboarding
      if (state.selectedInstitutionForSignup != null &&
          state.selectedInstitutionForSignup!.isNotEmpty) {
        context.go('/onboarding');
        return;
      }

      // Check for errors
      if (state.error != null &&
          state.error!.isNotEmpty &&
          ModalRoute.of(context)?.isCurrent == true) {
        if (state.error!.contains('account-already-exists')) {
          ErrorDialog.show(
            context,
            title: 'Account Already Exists',
            message:
                'You already have an account with this email. Please log in instead.',
            actionText: 'Log in',
            onAction: () {
              ref.read(authControllerProvider.notifier).clearError();
              context.go('/login');
            },
          ).then((_) {
            // Clear error if dialog is dismissed without action
            ref.read(authControllerProvider.notifier).clearError();
          });
        } else {
          ErrorDialog.showAuthError(context, state.error!).then((_) {
            ref.read(authControllerProvider.notifier).clearError();
          });
        }
      }
    });

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
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header with icon and gradient
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(
                                    0xFF10B981,
                                  ).withValues(alpha: 0.2),
                                  const Color(
                                    0xFF059669,
                                  ).withValues(alpha: 0.2),
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
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
                                        Color(0xFF10B981),
                                        Color(0xFF059669),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF10B981,
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
                                const SizedBox(height: 16),
                                Text(
                                  'Create Account',
                                  style: GoogleFonts.outfit(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Join Attendify to streamline your attendance tracking.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          // Form section
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Institution selector
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Your Institution',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Consumer(
                                      builder: (context, ref, child) {
                                        final institutionsAsync = ref.watch(
                                          institutionsStreamProvider,
                                        );
                                        return institutionsAsync.when(
                                          data: (institutions) {
                                            final activeInstitutions =
                                                institutions
                                                    .where(
                                                      (i) =>
                                                          i.status == 'Active',
                                                    )
                                                    .toList();
                                            if (activeInstitutions.isEmpty) {
                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  16,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.orange
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .warning_amber_rounded,
                                                      color: Colors.orange,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        'No institutions available. Please contact support.',
                                                        style:
                                                            GoogleFonts.outfit(
                                                              color:
                                                                  Colors.orange,
                                                              fontSize: 13,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                            return DropdownButtonFormField<
                                              String
                                            >(
                                              initialValue:
                                                  _selectedInstitutionCode,
                                              dropdownColor: const Color(
                                                0xFF1E293B,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Choose your institution',
                                                hintStyle: GoogleFonts.outfit(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3),
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.school_outlined,
                                                  color: Colors.white54,
                                                ),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withValues(alpha: 0.05),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  borderSide: BorderSide(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Color(
                                                              0xFF10B981,
                                                            ),
                                                            width: 2,
                                                          ),
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 16,
                                                    ),
                                              ),
                                              icon: const Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color: Colors.white54,
                                              ),
                                              isExpanded: true,
                                              items: activeInstitutions.map((
                                                institution,
                                              ) {
                                                return DropdownMenuItem<String>(
                                                  value: institution.code,
                                                  child: Text(
                                                    institution.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                setState(() {
                                                  _selectedInstitutionCode =
                                                      value;
                                                });
                                              },
                                            );
                                          },
                                          loading: () => Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.05,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                          error: (e, _) => Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.red.withValues(
                                                  alpha: 0.3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              'Error loading institutions: $e',
                                              style: GoogleFonts.outfit(
                                                color: Colors.red,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // Info note about email domain
                                Consumer(
                                  builder: (context, ref, child) {
                                    final institutionsAsync = ref.watch(
                                      institutionsStreamProvider,
                                    );
                                    return institutionsAsync.when(
                                      data: (institutions) {
                                        if (_selectedInstitutionCode == null) {
                                          return Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF3B82F6,
                                              ).withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFF3B82F6,
                                                ).withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.info_outline,
                                                  color: Color(0xFF3B82F6),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Please select your institution first to continue',
                                                    style: GoogleFonts.outfit(
                                                      color: const Color(
                                                        0xFF3B82F6,
                                                      ),
                                                      fontSize: 13,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }

                                        // Find selected institution to show email domain
                                        final selectedInstitution = institutions
                                            .firstWhere(
                                              (i) =>
                                                  i.code ==
                                                  _selectedInstitutionCode,
                                              orElse: () => institutions.first,
                                            );

                                        final emailDomain =
                                            selectedInstitution
                                                .emailDomain
                                                .isNotEmpty
                                            ? selectedInstitution.emailDomain
                                            : '${_selectedInstitutionCode?.toLowerCase()}.edu';

                                        return Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF3B82F6,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF3B82F6,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.info_outline,
                                                color: Color(0xFF3B82F6),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Use your institutional email',
                                                      style: GoogleFonts.outfit(
                                                        color: const Color(
                                                          0xFF3B82F6,
                                                        ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Please sign in with your $emailDomain email address',
                                                      style: GoogleFonts.outfit(
                                                        color:
                                                            const Color(
                                                              0xFF3B82F6,
                                                            ).withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        fontSize: 12,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Example: student@$emailDomain',
                                                        style:
                                                            GoogleFonts.jetBrainsMono(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      loading: () => const SizedBox.shrink(),
                                      error: (e, _) => const SizedBox.shrink(),
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                // Google sign-in button (Dark theme)
                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: state.loading
                                        ? null
                                        : () async {
                                            if (_selectedInstitutionCode ==
                                                    null ||
                                                _selectedInstitutionCode!
                                                    .isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Please select your institution first',
                                                    style: GoogleFonts.outfit(),
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                              return;
                                            }

                                            try {
                                              await ref
                                                  .read(
                                                    authControllerProvider
                                                        .notifier,
                                                  )
                                                  .onboardingGoogleWithInstitution(
                                                    _selectedInstitutionCode!,
                                                  );

                                              if (context.mounted) {
                                                // If we reach here, no error occurred
                                                context.go('/onboarding');
                                              }
                                            } catch (e) {
                                              // Error occurred, do not navigate.
                                              // The error dialog is handled by the state listener.
                                              // Or if the state listener missed it due to race condition, we can show it here.
                                              if (context.mounted) {
                                                // Check if error dialog is already shown? Hard to know.
                                                // But since we rethrow, the state listener SHOULD have fired.
                                                // If we want to be safe, we can log it.
                                                debugPrint(
                                                  'Onboarding failed: $e',
                                                );
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1F2937),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: state.loading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.1,
                                                ),
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.g_mobiledata_rounded,
                                              size: 20,
                                              color: Color(0xFF4285F4),
                                            ),
                                          ),
                                    label: Text(
                                      'Continue with Google',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Login link
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          context.go('/login');
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Log in',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF10B981),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
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
          if (state.loading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF10B981)),
                    const SizedBox(height: 16),
                    Text(
                      'Processing...',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
