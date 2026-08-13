import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers.dart';
import '../../auth/services/biometric_service.dart';
import '../../shared/widgets/background_pattern.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/glass_text_field.dart';
import '../../shared/widgets/error_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _idNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _idNumberController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showDebugLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList('auth_debug_logs') ?? ['No logs found'];

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        child: Container(
          width: double.infinity,
          height: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Debug Logs',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      logs[index],
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await prefs.remove('auth_debug_logs');
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: const Text('Clear Logs'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (next.error != null &&
          next.error!.isNotEmpty &&
          next.error != prev?.error) {
        ErrorDialog.showAuthError(context, next.error!).then((_) {
          ref.read(authControllerProvider.notifier).clearError();
        });
      }
      if (prev?.role != next.role || prev?.isAdmin != next.isAdmin) {
        if (next.isAdmin || next.role == UserRole.admin) {
          context.go('/admin');
        } else {
          switch (next.role) {
            case UserRole.teacher:
              context.go('/teacher');
              break;
            case UserRole.student:
              context.go('/student');
              break;
            case UserRole.none:
              break;
            case UserRole.admin:
              context.go('/admin');
              break;
          }
        }
      }
    });

    final state = ref.watch(authControllerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.error != null &&
          state.error!.isNotEmpty &&
          ModalRoute.of(context)?.isCurrent == true) {
        ErrorDialog.showAuthError(context, state.error!).then((_) {
          ref.read(authControllerProvider.notifier).clearError();
        });
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
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF8B5CF6),
                                        Color(0xFF6366F1),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
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
                                    Icons.login_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                GestureDetector(
                                  onLongPress: _showDebugLogs,
                                  child: Text(
                                    'Attendify',
                                    style: GoogleFonts.outfit(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Welcome back! Please login to continue.',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 16,
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
                                  controller: _idNumberController,
                                  label: 'ID Number',
                                  hintText: '102367001',
                                  prefixIcon: Icons.badge_outlined,
                                ),
                                const SizedBox(height: 20),
                                GlassTextField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  hintText: '••••••••',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: _obscurePassword,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),

                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      context.push('/forgot-password');
                                    },
                                    child: Text(
                                      'Forgot password?',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF8B5CF6),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: state.loading
                                        ? null
                                        : () async {
                                            final idNumber = _idNumberController
                                                .text
                                                .trim();
                                            final password =
                                                _passwordController.text;

                                            if (idNumber.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please enter your ID Number',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                              return;
                                            }

                                            if (idNumber.length < 3) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'ID Number must be at least 3 characters',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                              return;
                                            }

                                            if (password.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Please enter your password',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                              return;
                                            }

                                            if (password.length < 6) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Password must be at least 6 characters',
                                                  ),
                                                  backgroundColor:
                                                      Colors.orange,
                                                ),
                                              );
                                              return;
                                            }
                                            await ref
                                                .read(
                                                  authControllerProvider
                                                      .notifier,
                                                )
                                                .signInWithRollAndPassword(
                                                  rollNumber:
                                                      _idNumberController.text
                                                          .trim(),
                                                  password:
                                                      _passwordController.text,
                                                );
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
                                            'Log In',
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),

                                Consumer(
                                  builder: (context, ref, _) {
                                    return FutureBuilder<bool>(
                                      future: ref
                                          .watch(biometricServiceProvider)
                                          .isAvailable(),
                                      builder: (context, snapshot) {
                                        if (snapshot.data == true) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              top: 16,
                                            ),
                                            child: SizedBox(
                                              height: 56,
                                              child: OutlinedButton.icon(
                                                onPressed: state.loading
                                                    ? null
                                                    : () => ref
                                                          .read(
                                                            authControllerProvider
                                                                .notifier,
                                                          )
                                                          .signInWithBiometrics(),
                                                icon: const Icon(
                                                  Icons.fingerprint_rounded,
                                                ),
                                                label: Text(
                                                  'Login with Biometrics',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: BorderSide(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                    );
                                  },
                                ),

                                const SizedBox(height: 24),

                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFF59E0B,
                                      ).withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Color(0xFFF59E0B),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Note: Your account will be locked to this device. You cannot log in from another device once logged in.',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFFFDE68A),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 32),

                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: GoogleFonts.outfit(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          context.push('/signup');
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 0),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Sign up',
                                          style: GoogleFonts.outfit(
                                            color: const Color(0xFF8B5CF6),
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
                child: GlassCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                      const SizedBox(height: 24),
                      Text(
                        'Authenticating...',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
