import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'repository.dart';
import 'services/biometric_service.dart';
import '../../core/services/secure_storage_service.dart';

enum UserRole { none, admin, teacher, student }

class AuthState {
  const AuthState({
    required this.role,
    this.displayName,
    this.email,
    this.rollNumber,
    this.uid,
    this.photoUrl,
    this.isAdmin = false,
    this.approved = true,
    this.loading = false,
    this.error,
    this.isSuperAdmin = false,
    this.institutionCode,
    this.selectedInstitutionForSignup,
    this.lectureGroup,
    this.labGroup,
    this.electives,
    this.isVerifyingSignup = false,
    this.createdAt,
    this.originalAdminUid,
  });
  final UserRole role;
  final String? displayName;
  final String? email;
  final String? rollNumber;
  final String? uid;
  final String? photoUrl;
  final bool isAdmin;
  final bool approved;
  final bool loading;
  final String? error;
  final bool isSuperAdmin;
  final String? institutionCode;
  final String? selectedInstitutionForSignup;
  final String? lectureGroup;
  final String? labGroup;
  final List<String>? electives;
  final bool isVerifyingSignup;
  final DateTime? createdAt;
  final String? originalAdminUid; // If set, we are impersonating someone

  AuthState copyWith({
    UserRole? role,
    String? displayName,
    String? email,
    String? rollNumber,
    String? uid,
    String? photoUrl,
    bool? isAdmin,
    bool? approved,
    bool? loading,
    String? error,
    bool? isSuperAdmin,
    String? institutionCode,
    String? selectedInstitutionForSignup,
    String? lectureGroup,
    String? labGroup,
    List<String>? electives,
    bool? isVerifyingSignup,
    DateTime? createdAt,
    String? originalAdminUid,
  }) => AuthState(
    role: role ?? this.role,
    displayName: displayName ?? this.displayName,
    email: email ?? this.email,
    rollNumber: rollNumber ?? this.rollNumber,
    uid: uid ?? this.uid,
    photoUrl: photoUrl ?? this.photoUrl,
    isAdmin: isAdmin ?? this.isAdmin,
    approved: approved ?? this.approved,
    loading: loading ?? this.loading,
    error: error,
    isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
    institutionCode: institutionCode ?? this.institutionCode,
    selectedInstitutionForSignup:
        selectedInstitutionForSignup ?? this.selectedInstitutionForSignup,
    lectureGroup: lectureGroup ?? this.lectureGroup,
    labGroup: labGroup ?? this.labGroup,
    electives: electives ?? this.electives,
    isVerifyingSignup: isVerifyingSignup ?? this.isVerifyingSignup,
    createdAt: createdAt ?? this.createdAt,
    originalAdminUid: originalAdminUid ?? this.originalAdminUid,
  );
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  StreamSubscription? _userDocSub;

  @override
  AuthState build() {
    // Check for redirect result on initialization (web only)
    Future.microtask(() async {
      try {
        final result = await _repo.checkRedirectResult();
        if (result != null) {
          // Redirect successful, user validated
          state = state.copyWith(
            loading: false,
            uid: result.uid,
            email: result.email,
            displayName: result.displayName,
            selectedInstitutionForSignup: result.institutionCode,
            isVerifyingSignup: false,
          );
        }
      } catch (e) {
        state = state.copyWith(
          loading: false,
          error: e.toString(),
          isVerifyingSignup: false,
        );
      }
    });

    // Keep state in sync with Firebase auth
    _repo.authStateChanges().listen((user) async {
      _userDocSub?.cancel(); // Cancel previous subscription

      if (user == null) {
        state = AuthState(
          role: UserRole.none,
          isVerifyingSignup: state.isVerifyingSignup,
        );
      } else {
        final loadingUid = user.uid;

        // Listen for force logout signals and role changes
        _userDocSub = _repo.userDocStream(loadingUid).listen((data) {
          if (data != null) {
            // 1. Check for force logout
            final forceLogoutAt = data['forceLogoutAt'] as Timestamp?;
            if (forceLogoutAt != null) {
              final logoutTime = forceLogoutAt.toDate();
              if (DateTime.now().difference(logoutTime).inSeconds < 10) {
                signOut();
                return;
              }
            }

            // 2. Check for Role/Admin changes
            // We compare the Firestore data with the CURRENT state
            // If there's a mismatch in critical fields, we force a logout to ensure security
            // and correct routing on next login.

            final firestoreRoleName = (data['role'] as String?) ?? 'student';
            final firestoreRole = UserRole.values.firstWhere(
              (r) => r.name == firestoreRoleName,
              orElse: () => UserRole.student,
            );
            final firestoreIsAdmin =
                (data['admin'] as bool?) ?? (firestoreRole == UserRole.admin);

            // Get current effective role from state
            final currentRole = state.role;
            final currentIsAdmin = state.isAdmin;

            // Skip check if state is loading or verifying (initial load)
            if (state.loading ||
                state.isVerifyingSignup ||
                state.role == UserRole.none) {
              return;
            }

            // Skip check if impersonating (state role will differ from Firestore role)
            if (state.originalAdminUid != null) return;

            // If critical permissions changed, force logout
            if (firestoreRole != currentRole ||
                firestoreIsAdmin != currentIsAdmin) {
              // Role changed (e.g. Student -> Teacher, or Admin -> Teacher)
              // User requested: "automatically open the login page"
              signOut();
            }
          }
        });

        final profile = await _repo.loadProfile(user.uid);

        // Check if we are still signed in as the same user
        // This prevents race conditions where signOut() happens while loadProfile is running
        if (_repo.currentUser?.uid != loadingUid) {
          return;
        }

        if (profile == null) {
          // Logged-in but no profile (e.g., Google pre-onboarding)
          state = AuthState(
            role: UserRole.none,
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            photoUrl: user.photoURL,
            isVerifyingSignup: state.isVerifyingSignup,
          );
        } else {
          // If we are verifying signup, DO NOT expose the role yet.
          // This prevents auto-redirect for existing users during the check.
          final effectiveRole = state.isVerifyingSignup
              ? UserRole.none
              : (profile.isAdmin ? UserRole.admin : profile.role);

          state = AuthState(
            role: effectiveRole,
            uid: user.uid,
            email: profile.email,
            displayName: profile.displayName,
            rollNumber: profile.rollNumber,
            photoUrl: user.photoURL,
            isAdmin: profile.isAdmin,
            approved: profile.approved,
            isSuperAdmin: profile.isSuperAdmin,
            institutionCode: profile.institutionCode,
            lectureGroup: profile.lectureGroup,
            labGroup: profile.labGroup,
            electives: profile.electives,
            isVerifyingSignup: state.isVerifyingSignup,
            createdAt: profile.createdAt,
            // If we have a profile, we are definitely not in the signup flow anymore.
            // Clear this to prevent any accidental redirects to onboarding.
            selectedInstitutionForSignup: null,
          );
        }
      }
    });
    return const AuthState(role: UserRole.none);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    // Optionally clear credentials, or keep them for easy re-login
    // For security, we'll keep them but require biometric auth to use them
    state = const AuthState(role: UserRole.none);
  }

  Future<void> onboardingGoogleThaparOnly() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _repo.continueWithGoogleThaparOnly();
      // After this, navigation should move to /signup to complete onboarding
      state = state.copyWith(
        loading: false,
        uid: res.uid,
        email: res.email,
        displayName: res.displayName,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> onboardingGoogleWithInstitution(String institutionCode) async {
    state = state.copyWith(loading: true, error: null, isVerifyingSignup: true);
    try {
      final res = await _repo.continueWithGoogleForInstitution(institutionCode);

      if (res == null) {
        // Redirecting...
        return;
      }

      // After this, navigation should move to /signup to complete onboarding
      // Store the selected institution for use during onboarding
      state = state.copyWith(
        loading: false,
        uid: res.uid,
        email: res.email,
        displayName: res.displayName,
        selectedInstitutionForSignup: institutionCode,
        isVerifyingSignup: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString(),
        isVerifyingSignup: false,
      );
      rethrow; // Rethrow to allow UI to handle it
    }
  }

  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final uid = state.uid;
      if (uid == null) throw Exception('Not authenticated');
      await _repo.updateProfile(
        uid: uid,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      // Refresh local state
      final user = FirebaseAuth.instance.currentUser;
      state = state.copyWith(
        loading: false,
        displayName: displayName ?? state.displayName,
        photoUrl: photoUrl ?? user?.photoURL ?? state.photoUrl,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> completeOnboarding({
    required String rollNumber,
    required String password,
    required UserRole role,
    String? lectureGroupId,
    String? labGroupId,
    String? institutionCode,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final uid = state.uid;
      final email = state.email;
      if (uid == null || email == null) {
        throw Exception('Not authenticated');
      }
      await _repo.completeOnboarding(
        uid: uid,
        email: email,
        rollNumber: rollNumber,
        password: password,
        role: role,
        lectureGroupId: lectureGroupId,
        labGroupId: labGroupId,
        institutionCode: institutionCode,
      );

      // We DO NOT clear selectedInstitutionForSignup here yet.
      // We wait for the UI to show the success dialog.
      // The UI will call finalizeOnboarding() after the dialog is closed.
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> finalizeOnboarding() async {
    state = state.copyWith(loading: true, error: null);
    try {
      // Clear this to allow router to redirect away from onboarding
      state = state.copyWith(selectedInstitutionForSignup: null);

      final uid = state.uid;
      if (uid != null) {
        // Reload profile to get the new role and data
        final profile = await _repo.loadProfile(
          uid,
          isImpersonating: state.originalAdminUid != null,
        );
        if (profile != null) {
          state = state.copyWith(
            loading: false,
            role: profile.isAdmin ? UserRole.admin : profile.role,
            displayName: profile.displayName,
            rollNumber: profile.rollNumber,
            isAdmin: profile.isAdmin,
            isSuperAdmin: profile.isSuperAdmin,
            institutionCode: profile.institutionCode,
            lectureGroup: profile.lectureGroup,
            labGroup: profile.labGroup,
            electives: profile.electives,
            createdAt: profile.createdAt,
            approved: profile.approved,
            // Ensure this is cleared in the final state update as well
            selectedInstitutionForSignup: null,
          );
        } else {
          state = state.copyWith(loading: false);
        }
      } else {
        state = state.copyWith(loading: false);
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> signInWithRollAndPassword({
    required String rollNumber,
    required String password,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _repo.signInWithRollAndPassword(
        rollNumber: rollNumber,
        password: password,
      );

      // Save credentials for biometric login
      await ref
          .read(secureStorageServiceProvider)
          .saveCredentials(rollNumber: rollNumber, password: password);

      // Reload profile to get admin status
      final profile = await _repo.loadProfile(result.uid);
      final finalRole = (profile?.isAdmin ?? false)
          ? UserRole.admin
          : result.role;
      state = state.copyWith(
        loading: false,
        role: finalRole,
        uid: result.uid,
        email: result.email,
        displayName: result.displayName,
        rollNumber: rollNumber,
        isAdmin: profile?.isAdmin ?? false,
        isSuperAdmin: profile?.isSuperAdmin ?? false,
        institutionCode: profile?.institutionCode,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> signInWithBiometrics() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final biometricService = ref.read(biometricServiceProvider);
      final secureStorage = ref.read(secureStorageServiceProvider);

      // Check availability
      if (!await biometricService.isAvailable()) {
        throw Exception('Biometrics not available');
      }

      // Authenticate user
      if (!await biometricService.authenticate()) {
        throw Exception('Biometric authentication failed');
      }

      // Get credentials
      final credentials = await secureStorage.getCredentials();
      if (credentials == null) {
        throw Exception(
          'No saved credentials. Please login with password first.',
        );
      }

      // Login
      await signInWithRollAndPassword(
        rollNumber: credentials['rollNumber']!,
        password: credentials['password']!,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> checkApprovalStatus() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final uid = state.uid;
      if (uid != null) {
        final profile = await _repo.loadProfile(
          uid,
          isImpersonating: state.originalAdminUid != null,
        );
        if (profile != null) {
          state = state.copyWith(
            loading: false,
            role: profile.isAdmin ? UserRole.admin : profile.role,
            approved: profile.approved,
            isAdmin: profile.isAdmin,
            isSuperAdmin: profile.isSuperAdmin,
            displayName: profile.displayName,
            rollNumber: profile.rollNumber,
            institutionCode: profile.institutionCode,
            lectureGroup: profile.lectureGroup,
            labGroup: profile.labGroup,
            electives: profile.electives,
          );
        } else {
          state = state.copyWith(loading: false);
        }
      } else {
        state = state.copyWith(loading: false);
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> impersonateUser(String targetUid) async {
    if (!state.isSuperAdmin) return;

    final originalUid = state.uid;
    state = state.copyWith(loading: true, error: null);

    try {
      final profile = await _repo.loadProfile(targetUid, isImpersonating: true);
      if (profile == null) throw Exception('User not found');

      state = state.copyWith(
        loading: false,
        role: profile.isAdmin ? UserRole.admin : profile.role,
        uid: targetUid,
        email: profile.email,
        displayName: profile.displayName,
        rollNumber: profile.rollNumber,
        isAdmin: profile.isAdmin,
        isSuperAdmin: false, // Impersonated user is not super admin (usually)
        institutionCode: profile.institutionCode,
        lectureGroup: profile.lectureGroup,
        labGroup: profile.labGroup,
        electives: profile.electives,
        approved: profile.approved,
        originalAdminUid: originalUid, // Store original admin UID
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> stopImpersonation() async {
    final originalUid = state.originalAdminUid;
    if (originalUid == null) return;

    state = state.copyWith(loading: true, error: null);

    try {
      // Reload original admin profile
      final profile = await _repo.loadProfile(originalUid);
      if (profile == null) throw Exception('Original admin profile not found');

      state = state.copyWith(
        loading: false,
        role: profile
            .role, // Should be admin/none depending on implementation, but usually admin
        uid: originalUid,
        email: profile.email,
        displayName: profile.displayName,
        rollNumber: profile.rollNumber,
        isAdmin: profile.isAdmin,
        isSuperAdmin: profile.isSuperAdmin,
        institutionCode: profile.institutionCode,
        originalAdminUid: null, // Clear impersonation flag
      );

      // Force state update to remove originalAdminUid effectively if copyWith has issues with null
      // (copyWith usually ignores nulls if not handled, but here we want to set it to null.
      // Our copyWith implementation: originalAdminUid: originalAdminUid ?? this.originalAdminUid
      // So passing null will NOT clear it. We need to fix copyWith or recreate state.)

      // Re-creating state to ensure null is set
      state = AuthState(
        role: profile.isAdmin ? UserRole.admin : profile.role,
        uid: originalUid,
        email: profile.email,
        displayName: profile.displayName,
        rollNumber: profile.rollNumber,
        isAdmin: profile.isAdmin,
        isSuperAdmin: profile.isSuperAdmin,
        institutionCode: profile.institutionCode,
        approved: profile.approved,
        originalAdminUid: null,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);
