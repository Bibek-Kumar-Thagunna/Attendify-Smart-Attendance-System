import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/device_service.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             scopes: const ['email'],
             clientId: kIsWeb
                 ? '582817926495-05pkje57gk3lmd8aijl5p8c55sf3jd3c.apps.googleusercontent.com'
                 : null,
           );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<({String email, String uid, String displayName})>
  continueWithGoogleThaparOnly() async {
    if (kIsWeb) {
      // On web, prefer Firebase popup provider to avoid third-party cookies issues
      final provider = GoogleAuthProvider();
      final result = await _auth.signInWithPopup(provider);
      final user = result.user;
      if (user == null) {
        throw Exception('Sign-in cancelled');
      }
      final email = user.email ?? '';
      if (!_isThaparEmail(email)) {
        await signOut();
        throw Exception('Only @thapar.edu emails are allowed');
      }
      return (email: email, uid: user.uid, displayName: user.displayName ?? '');
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Sign-in cancelled');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw Exception('Sign-in failed');
      }
      final email = user.email ?? '';
      if (!_isThaparEmail(email)) {
        await signOut();
        throw Exception('Only @thapar.edu emails are allowed');
      }
      return (email: email, uid: user.uid, displayName: user.displayName ?? '');
    }
  }

  bool _isThaparEmail(String email) =>
      email.toLowerCase().endsWith('@thapar.edu');

  /// Validate email domain against institution's allowed domain
  Future<bool> validateEmailDomain(String email, String institutionCode) async {
    try {
      final institutionQuery = await _firestore
          .collection('institutions')
          .where('code', isEqualTo: institutionCode)
          .limit(1)
          .get();

      if (institutionQuery.docs.isEmpty) {
        throw Exception('Institution not found');
      }

      final institutionData = institutionQuery.docs.first.data();
      final emailDomain = institutionData['emailDomain'] as String?;

      if (emailDomain == null || emailDomain.isEmpty) {
        throw Exception('Institution email domain not configured');
      }

      // Extract domain from user email
      final userDomain = email.split('@').last.toLowerCase();

      return userDomain == emailDomain.toLowerCase();
    } catch (e) {
      throw Exception('Email validation failed: $e');
    }
  }

  Future<void> _logDebug(String message) async {
    debugPrint('AuthDebug: $message');
    try {
      final prefs = await SharedPreferences.getInstance();
      final logs = prefs.getStringList('auth_debug_logs') ?? [];
      logs.add('${DateTime.now().toIso8601String()}: $message');
      if (logs.length > 50) logs.removeAt(0); // Keep last 50 logs
      await prefs.setStringList('auth_debug_logs', logs);
    } catch (e) {
      debugPrint('Failed to write debug log: $e');
    }
  }

  /// Continue with Google sign-in with institution validation
  Future<({String email, String uid, String displayName})?>
  continueWithGoogleForInstitution(String institutionCode) async {
    await _logDebug(
      'Starting continueWithGoogleForInstitution: $institutionCode',
    );
    // Sign out first to force account selection
    await signOut();

    if (kIsWeb) {
      try {
        // On web, prefer Firebase popup provider with account selection
        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        final result = await _auth.signInWithPopup(provider);
        final user = result.user;
        if (user == null) {
          throw Exception('Sign-in cancelled');
        }
        return await _validateAndReturnUser(user, institutionCode);
      } catch (e) {
        // Check for popup blocked or closed by user
        if (e.toString().contains('popup_closed_by_user')) {
          await _logDebug('Popup closed by user');
          throw Exception('Sign-in cancelled');
        }

        // Check for validation errors - DO NOT fallback to redirect for these
        if (e.toString().contains('invalid-institution-email') ||
            e.toString().contains('account-already-exists')) {
          await _logDebug('Validation error in popup: $e');
          rethrow;
        }

        // Fallback to redirect for blocked popups or other issues
        await _logDebug('Popup failed ($e), falling back to redirect');

        // Save institution code to persist across redirect
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('pending_signup_institution', institutionCode);
        await _logDebug('Saved pending_signup_institution: $institutionCode');

        final provider = GoogleAuthProvider();
        provider.setCustomParameters({'prompt': 'select_account'});
        await _auth.signInWithRedirect(provider);
        await _logDebug('Called signInWithRedirect');
        return null; // Redirecting...
      }
    } else {
      // Mobile: sign out to force account selection
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Sign-in cancelled');
      }
      final email = googleUser.email;

      // Validate email domain against institution
      final isValid = await validateEmailDomain(email, institutionCode);
      if (!isValid) {
        await signOut();
        throw Exception('invalid-institution-email');
      }

      // Check if user already exists
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      final user = result.user!;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        await signOut();
        throw Exception('account-already-exists');
      }
      return (
        email: user.email!,
        uid: user.uid,
        displayName: user.displayName ?? '',
      );
    }
  }

  /// Check if we are returning from a redirect sign-in
  Future<
    ({String email, String uid, String displayName, String institutionCode})?
  >
  checkRedirectResult() async {
    if (!kIsWeb) return null;

    await _logDebug('Checking redirect result');
    try {
      final result = await _auth.getRedirectResult();
      final user = result.user;

      if (user != null) {
        await _logDebug('Redirect result found user: ${user.uid}');
        final prefs = await SharedPreferences.getInstance();
        final institutionCode = prefs.getString('pending_signup_institution');
        await _logDebug('Pending institution code: $institutionCode');

        if (institutionCode != null) {
          await prefs.remove('pending_signup_institution');

          // Validate user
          final validatedUser = await _validateAndReturnUser(
            user,
            institutionCode,
          );
          await _logDebug('User validated successfully');
          return (
            email: validatedUser.email,
            uid: validatedUser.uid,
            displayName: validatedUser.displayName,
            institutionCode: institutionCode,
          );
        } else {
          await _logDebug('No pending institution code found');
        }
      } else {
        await _logDebug('No user in redirect result');
      }
    } catch (e) {
      await _logDebug('Redirect result error: $e');
      debugPrint('Redirect result error: $e');
      // Clear pending institution on error
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_signup_institution');
      rethrow;
    }
    return null;
  }

  Future<({String email, String uid, String displayName})>
  _validateAndReturnUser(User user, String institutionCode) async {
    final email = user.email ?? '';

    // Validate email domain against institution
    final isValid = await validateEmailDomain(email, institutionCode);

    if (!isValid) {
      await signOut();
      throw Exception('invalid-institution-email');
    }

    // Check if user already exists
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      await signOut();
      throw Exception('account-already-exists');
    }

    return (email: email, uid: user.uid, displayName: user.displayName ?? '');
  }

  Future<void> completeOnboarding({
    required String uid,
    required String email,
    required String rollNumber,
    required String password,
    required UserRole role,
    String? lectureGroupId,
    String? labGroupId,
    String? institutionCode,
  }) async {
    debugPrint(
      '🚀 completeOnboarding started for $uid, email: $email, roll: $rollNumber',
    );

    // Validate roll number format: exactly 9 digits
    final rollOk = RegExp(r'^\d{9}$').hasMatch(rollNumber);
    if (!rollOk) {
      throw Exception('Roll number must be 9 digits (e.g., 102367009)');
    }
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters');
    }
    // Validate institution selection
    if (institutionCode == null || institutionCode.isEmpty) {
      throw Exception('Please select your institution');
    }

    // Check if ID is already in use by another user (legacy check)
    // This is needed because id_index might not have all legacy users

    debugPrint('🔍 Checking for duplicate ID: $rollNumber');

    // 1. Check idNumber as String
    final idStringQuery = await _firestore
        .collection('users')
        .where('idNumber', isEqualTo: rollNumber)
        .limit(1)
        .get();

    if (idStringQuery.docs.isNotEmpty) {
      debugPrint(
        '❌ Duplicate found in idNumber (String): ${idStringQuery.docs.first.id}',
      );
      throw Exception(
        'This ID Number is already registered to another account.',
      );
    }

    // 2. Check idNumber as Number (if parseable)
    final rollInt = int.tryParse(rollNumber);
    if (rollInt != null) {
      final idNumQuery = await _firestore
          .collection('users')
          .where('idNumber', isEqualTo: rollInt)
          .limit(1)
          .get();

      if (idNumQuery.docs.isNotEmpty) {
        debugPrint(
          '❌ Duplicate found in idNumber (Number): ${idNumQuery.docs.first.id}',
        );
        throw Exception(
          'This ID Number is already registered to another account.',
        );
      }
    }

    // 3. Check legacy rollNumber as String
    final rollStringQuery = await _firestore
        .collection('users')
        .where('rollNumber', isEqualTo: rollNumber)
        .limit(1)
        .get();

    if (rollStringQuery.docs.isNotEmpty) {
      debugPrint(
        '❌ Duplicate found in rollNumber (String): ${rollStringQuery.docs.first.id}',
      );
      throw Exception(
        'This ID Number is already registered to another account.',
      );
    }

    // 4. Check legacy rollNumber as Number
    if (rollInt != null) {
      final rollNumQuery = await _firestore
          .collection('users')
          .where('rollNumber', isEqualTo: rollInt)
          .limit(1)
          .get();

      if (rollNumQuery.docs.isNotEmpty) {
        debugPrint(
          '❌ Duplicate found in rollNumber (Number): ${rollNumQuery.docs.first.id}',
        );
        throw Exception(
          'This ID Number is already registered to another account.',
        );
      }
    }

    debugPrint('✅ No duplicates found for ID: $rollNumber');

    // Ensure unique roll number via id_index gate (atomic, rule-enforced)
    bool indexCreated = false;
    try {
      debugPrint('🔒 Creating id_index lock...');
      await _firestore.collection('id_index').doc(rollNumber).set({
        'uid': uid,
        'institutionCode': institutionCode,
        'createdAt': FieldValue.serverTimestamp(),
      });
      indexCreated = true;
      debugPrint('✅ id_index lock created');
    } on FirebaseException catch (e) {
      debugPrint('❌ Failed to create id_index lock: ${e.code}');
      if (e.code == 'permission-denied' || e.code == 'already-exists') {
        throw Exception('Roll number already in use');
      }
      rethrow;
    }
    // Link email/password to current Google account to allow roll+password login mapped to email
    final current = _auth.currentUser;
    if (current == null || current.uid != uid) {
      throw Exception('No authenticated user for onboarding');
    }
    // Try to link email/password credential
    try {
      debugPrint('🔗 Linking credential...');
      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await current.linkWithCredential(cred);
      debugPrint('✅ Credential linked');
    } on FirebaseAuthException catch (e) {
      debugPrint('⚠️ Link credential failed: ${e.code} - ${e.message}');
      if (e.code == 'credential-already-in-use') {
        // Already linked: update password to the newly set one
        debugPrint('🔄 Credential already in use, updating password...');
        await current.updatePassword(password);
        debugPrint('✅ Password updated');
      } else if (e.code == 'weak-password') {
        throw Exception('Password must be at least 6 characters');
      } else if (e.code == 'requires-recent-login') {
        throw Exception(
          'For security, please sign in again with Google and retry.',
        );
      } else if (e.code == 'operation-not-allowed') {
        throw Exception('Enable Email/Password sign-in in Firebase Console.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception(
          'This Thapar email is already registered. Use roll login or reset password.',
        );
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('❌ Unexpected error linking credential: $e');
      rethrow;
    }

    // Persist profile
    final now = DateTime.now();
    try {
      debugPrint('💾 Saving user profile...');
      final userDoc = <String, dynamic>{
        'email': email.toLowerCase().trim(),
        // Store as idNumber; keep rollNumber for back-compat reads if needed elsewhere
        'idNumber': rollNumber.trim(),
        'displayName': current.displayName ?? '',
        'role': role.name,
        'admin': role == UserRole.admin,
        'approved': role == UserRole.teacher ? false : true,
        'institutionCode': institutionCode,
        // Enable limited unauthenticated lookup for roll-number sign-in
        'loginEnabled': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      if (role == UserRole.student) {
        if (lectureGroupId != null) userDoc['lectureGroup'] = lectureGroupId;
        if (labGroupId != null) userDoc['labGroup'] = labGroupId;
      }

      await _firestore
          .collection('users')
          .doc(uid)
          .set(userDoc, SetOptions(merge: true));
      debugPrint('✅ User profile saved');

      // If student selected class groups, add them to it
      if (role == UserRole.student) {
        debugPrint('👥 Adding student to groups...');
        final batch = _firestore.batch();
        bool batchHasOps = false;

        if (lectureGroupId != null && lectureGroupId.isNotEmpty) {
          final lectureRef = _firestore
              .collection('class_groups')
              .doc(lectureGroupId);
          batch.update(lectureRef, {
            'studentUids': FieldValue.arrayUnion([uid]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          batchHasOps = true;
        }

        if (labGroupId != null && labGroupId.isNotEmpty) {
          final labRef = _firestore.collection('class_groups').doc(labGroupId);
          batch.update(labRef, {
            'studentUids': FieldValue.arrayUnion([uid]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          batchHasOps = true;
        }

        if (batchHasOps) {
          try {
            await batch.commit();
            debugPrint('✅ Added to groups via batch');
          } on FirebaseException catch (e) {
            debugPrint(
              '⚠️ Batch failed: ${e.code}, trying individual updates...',
            );
            // Fallback for permission errors (e.g. missing institutionCode on group)
            if (e.code == 'permission-denied') {
              if (lectureGroupId != null) {
                await _firestore
                    .collection('class_groups')
                    .doc(lectureGroupId)
                    .update({
                      'studentUids': FieldValue.arrayUnion([uid]),
                      'institutionCode': institutionCode,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
              }
              if (labGroupId != null) {
                await _firestore
                    .collection('class_groups')
                    .doc(labGroupId)
                    .update({
                      'studentUids': FieldValue.arrayUnion([uid]),
                      'institutionCode': institutionCode,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
              }
              debugPrint('✅ Added to groups individually');
            } else {
              rethrow;
            }
          }
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('❌ Firestore error saving profile: ${e.code} - ${e.message}');
      if (e.code == 'permission-denied') {
        throw Exception(
          'Firestore permission denied. Allow authenticated users to write users/{uid}.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('❌ Unexpected error saving profile: $e');
      rethrow;
    } finally {
      // If user doc wasn't created successfully and we created the id_index lock, attempt cleanup
      if (indexCreated) {
        try {
          final userDoc = await _firestore.collection('users').doc(uid).get();
          if (!userDoc.exists) {
            debugPrint('🧹 Cleaning up id_index lock...');
            await _firestore.collection('id_index').doc(rollNumber).delete();
          }
        } catch (_) {
          // Ignore; rules allow same uid to delete when profile not created yet.
        }
      }
    }
  }

  Future<({String uid, String email, UserRole role, String displayName})>
  signInWithRollAndPassword({
    required String rollNumber,
    required String password,
  }) async {
    // First try idNumber, then fallback to legacy rollNumber field
    QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('users')
        .where('idNumber', isEqualTo: rollNumber)
        .where('loginEnabled', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      snap = await _firestore
          .collection('users')
          .where('rollNumber', isEqualTo: rollNumber)
          .where('loginEnabled', isEqualTo: true)
          .limit(1)
          .get();
    }
    if (snap.docs.isEmpty) {
      throw Exception('Account not found for this roll number');
    }
    final data = snap.docs.first.data();
    final email = (data['email'] as String?) ?? '';
    if (email.isEmpty) {
      throw Exception('No email mapped for this roll number');
    }
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw Exception('Invalid credentials');
    }
    final roleName = (data['role'] as String?) ?? 'student';
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => UserRole.student,
    );
    // Check if user is admin - admins should get admin role regardless of their role field
    final isAdmin = (data['admin'] as bool?) ?? false;
    final finalRole = isAdmin ? UserRole.admin : role;
    final displayName =
        (data['displayName'] as String?) ?? (user.displayName ?? '');
    return (
      uid: user.uid,
      email: email,
      role: finalRole,
      displayName: displayName,
    );
  }

  Future<void> _verifyDeviceLock(
    String uid,
    UserRole role,
    Map<String, dynamic> data,
  ) async {
    // Only enforce for students
    if (role != UserRole.student) return;

    final deviceId = await DeviceService.getDeviceId();
    if (deviceId == null) return; // Could not determine device ID

    final registeredDeviceId = data['registeredDeviceId'] as String?;

    if (registeredDeviceId == null) {
      // First login from a device: Register it
      await _firestore.collection('users').doc(uid).update({
        'registeredDeviceId': deviceId,
        'lastDeviceLoginAt': FieldValue.serverTimestamp(),
      });
    } else if (registeredDeviceId != deviceId) {
      // Mismatch: Deny access
      await signOut();
      throw Exception(
        'Access Denied: This account is linked to another device.\n'
        'You can only log in from one registered device.\n'
        'Please contact the administrator to reset your device lock.',
      );
    } else {
      // Match: Update last login
      await _firestore.collection('users').doc(uid).update({
        'lastDeviceLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<
    ({
      UserRole role,
      String email,
      String displayName,
      String rollNumber,
      bool isAdmin,
      bool approved,
      bool isSuperAdmin,
      String? institutionCode,
      String? lectureGroup,
      String? labGroup,
      List<String>? electives,
      DateTime? createdAt,
    })?
  >
  loadProfile(String uid, {bool isImpersonating = false}) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    final roleName = (data['role'] as String?) ?? 'student';
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => UserRole.student,
    );

    // Enforce Device Lock for Students
    // SKIP if we are impersonating
    if (role == UserRole.student && !isImpersonating) {
      // We call this *after* getting the role, but *before* returning the profile.
      // If it fails, it throws, effectively blocking the login/load.
      await _verifyDeviceLock(uid, role, data);
    }

    return (
      role: role,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      rollNumber:
          (data['idNumber'] as String?) ??
          (data['rollNumber'] as String?) ??
          '',
      isAdmin: (data['admin'] as bool?) ?? (role == UserRole.admin),
      approved:
          (data['approved'] as bool?) ??
          (role == UserRole.teacher ? false : true),
      isSuperAdmin: (data['isSuperAdmin'] as bool?) ?? false,
      institutionCode: (data['institutionCode'] as String?),
      lectureGroup:
          (data['lectureGroup'] as String?) ?? (data['group'] as String?),
      labGroup: (data['labGroup'] as String?) ?? (data['group'] as String?),
      electives: (data['electives'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      createdAt: (data['createdAt'] as String?) != null
          ? DateTime.tryParse(data['createdAt'] as String)
          : null,
    );
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? photoUrl,
  }) async {
    final current = _auth.currentUser;
    if (current == null || current.uid != uid) {
      throw Exception('Not authenticated');
    }
    // Update FirebaseAuth profile
    try {
      if (displayName != null && displayName.trim().isNotEmpty) {
        await current.updateDisplayName(displayName.trim());
      }
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        await current.updatePhotoURL(photoUrl.trim());
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please sign in again to update profile.');
      }
      rethrow;
    }
    // Update Firestore doc (do not touch 'admin' or other fields)
    final now = DateTime.now().toIso8601String();
    final update = <String, dynamic>{'updatedAt': now};
    if (displayName != null && displayName.trim().isNotEmpty) {
      update['displayName'] = displayName.trim();
    }
    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      update['photoUrl'] = photoUrl.trim();
    }
    await _firestore
        .collection('users')
        .doc(uid)
        .set(update, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> userDocStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data());
  }
}
