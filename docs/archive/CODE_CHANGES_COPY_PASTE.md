# 📝 Code Changes Required - Copy & Paste Ready

## 1️⃣ Update Institution Model

**File**: `lib/features/institutions/models/institution.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@immutable
class Institution {
  final String id;
  final String name;
  final String code;
  final String emailDomain;  // ← NEW FIELD
  final String status;
  final int students;
  final DateTime? createdAt;

  const Institution({
    required this.id,
    required this.name,
    required this.code,
    required this.emailDomain,  // ← NEW PARAMETER
    required this.status,
    this.students = 0,
    this.createdAt,
  });

  factory Institution.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Institution(
      id: doc.id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      emailDomain: data['emailDomain'] ?? '',  // ← NEW
      status: data['status'] ?? 'Pending',
      students: data['students'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'code': code,
        'emailDomain': emailDomain,  // ← NEW
        'status': status,
        'students': students,
        'createdAt': createdAt != null
            ? Timestamp.fromDate(createdAt!)
            : FieldValue.serverTimestamp(),
      };

  Institution copyWith({
    String? id,
    String? name,
    String? code,
    String? emailDomain,  // ← NEW
    String? status,
    int? students,
    DateTime? createdAt,
  }) {
    return Institution(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      emailDomain: emailDomain ?? this.emailDomain,  // ← NEW
      status: status ?? this.status,
      students: students ?? this.students,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
```

---

## 2️⃣ Add Email Validation to AuthRepository

**File**: `lib/features/auth/repository.dart`

Add this method after the existing methods:

```dart
  /// Validate email domain against institution's allowed domain
  Future<bool> validateEmailDomain(String email, String institutionCode) async {
    try {
      final institutionQuery = await FirebaseFirestore.instance
          .collection('institutions')
          .where('code', isEqualTo: institutionCode)
          .limit(1)
          .get();

      if (institutionQuery.docs.isEmpty) {
        throw Exception('Institution not found');
      }

      final institutionData = institutionQuery.docs.first.data();
      final emailDomain = institutionData['emailDomain'] as String;

      // Extract domain from user email
      final userDomain = email.split('@').last.toLowerCase();

      return userDomain == emailDomain.toLowerCase();
    } catch (e) {
      throw Exception('Email validation failed: $e');
    }
  }

  /// Continue with Google sign-in with institution validation
  Future<({String email, String uid, String displayName})>
      continueWithGoogleForInstitution(String institutionCode) async {
    try {
      final result = await _googleSignIn.signIn();
      if (result == null) {
        throw Exception('Sign in cancelled');
      }

      final email = result.email;

      // Validate email domain against institution
      final isValid = await validateEmailDomain(email, institutionCode);
      if (!isValid) {
        await _googleSignIn.signOut();
        throw Exception(
            'Your email domain does not match the selected institution. Please use the correct institutional email.');
      }

      // Continue with authentication
      final googleAuth = await result.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Authentication failed');
      }

      return (
        email: email,
        uid: user.uid,
        displayName: user.displayName ?? email.split('@')[0],
      );
    } catch (e) {
      await _googleSignIn.signOut();
      rethrow;
    }
  }
```

---

## 3️⃣ Update Signup Page to Use Validation

**File**: `lib/features/auth/presentation/signup_page.dart`

Find the method that handles Google sign-in (likely `_handleContinueWithGoogle`) and replace it with:

```dart
  Future<void> _handleContinueWithGoogle() async {
    if (_selectedInstitution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an institution first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Use the new method with institution validation
      final result = await ref
          .read(authRepositoryProvider)
          .continueWithGoogleForInstitution(_selectedInstitution!);

      if (!mounted) return;

      // Show role selection dialog
      final role = await _showRoleSelectionDialog();
      if (role == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Continue with existing profile completion flow...
      // (Keep your existing code for showing profile dialog)
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
```

---

## 4️⃣ Update AuthState to Include Super Admin Flag

**File**: `lib/features/auth/providers.dart`

Update the `AuthState` class:

```dart
@immutable
class AuthState {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? institutionCode;
  final bool approved;
  final bool admin;
  final bool isSuperAdmin;  // ← NEW FIELD

  const AuthState({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.institutionCode,
    this.approved = true,
    this.admin = false,
    this.isSuperAdmin = false,  // ← NEW PARAMETER
  });

  factory AuthState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuthState(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.student,
      ),
      institutionCode: data['institutionCode'],
      approved: data['approved'] ?? true,
      admin: data['admin'] ?? false,
      isSuperAdmin: data['isSuperAdmin'] ?? false,  // ← NEW
    );
  }

  AuthState copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? institutionCode,
    bool? approved,
    bool? admin,
    bool? isSuperAdmin,  // ← NEW
  }) {
    return AuthState(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      institutionCode: institutionCode ?? this.institutionCode,
      approved: approved ?? this.approved,
      admin: admin ?? this.admin,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,  // ← NEW
    );
  }
}
```

---

## 5️⃣ Add Institution Filter to Admin Providers

**File**: `lib/features/dashboard/providers.dart` (or wherever your admin providers are)

Update providers to filter by institution:

```dart
// Example: Pending Teachers Provider
final pendingTeachersListProvider = StreamProvider<List<User>>((ref) async* {
  final authState = ref.watch(authControllerProvider);

  Query query = FirebaseFirestore.instance.collection('users');

  // Add institution filter if not super admin
  if (!authState.isSuperAdmin && authState.institutionCode != null) {
    query = query.where('institutionCode', isEqualTo: authState.institutionCode);
  }

  // Continue with existing filters
  query = query
      .where('role', isEqualTo: 'teacher')
      .where('approved', isEqualTo: false);

  yield* query.snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => User.fromFirestore(doc)).toList());
});

// Example: All Users Provider
final allUsersProvider = StreamProvider<List<User>>((ref) async* {
  final authState = ref.watch(authControllerProvider);

  Query query = FirebaseFirestore.instance.collection('users');

  // Add institution filter if not super admin
  if (!authState.isSuperAdmin && authState.institutionCode != null) {
    query = query.where('institutionCode', isEqualTo: authState.institutionCode);
  }

  yield* query.snapshots().map((snapshot) =>
      snapshot.docs.map((doc) => User.fromFirestore(doc)).toList());
});

// Apply same pattern to:
// - studentsProvider
// - teachersProvider
// - subjectsProvider
// - classGroupsProvider
// - sessionsProvider
// - scheduledSessionsProvider
```

---

## 6️⃣ Add Institution Selector to Admin Dashboard (Optional)

**File**: `lib/features/dashboard/presentation/admin_dashboard_page.dart`

Add institution dropdown for super admin:

```dart
class _AdminDashboardPageState extends State<AdminDashboardPage> {
  String? _selectedInstitution = 'ALL';  // ← NEW STATE

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    
    return Scaffold(
      body: Column(
        children: [
          // Top bar
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Text(
                  'Admin Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                
                // ← NEW: Institution selector for super admin
                if (authState.isSuperAdmin)
                  _buildInstitutionSelector(),
              ],
            ),
          ),
          
          // Existing content...
        ],
      ),
    );
  }

  // ← NEW METHOD
  Widget _buildInstitutionSelector() {
    final institutionsAsync = ref.watch(institutionsProvider);

    return institutionsAsync.when(
      data: (institutions) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButton<String>(
          value: _selectedInstitution,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down),
          items: [
            const DropdownMenuItem(
              value: 'ALL',
              child: Row(
                children: [
                  Icon(Icons.public, size: 20),
                  SizedBox(width: 8),
                  Text('All Institutions'),
                ],
              ),
            ),
            ...institutions.map((inst) => DropdownMenuItem(
                  value: inst.code,
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, size: 20),
                      const SizedBox(width: 8),
                      Text(inst.name),
                    ],
                  ),
                )),
          ],
          onChanged: (value) {
            setState(() => _selectedInstitution = value);
            // Reload data with selected institution filter
          },
        ),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (_, __) => const Icon(Icons.error),
    );
  }
}
```

---

## 7️⃣ Update Institution Form (Add Email Domain Field)

**File**: `lib/features/institutions/presentation/institution_form.dart` (or wherever you create institutions)

Add email domain field to the form:

```dart
TextFormField(
  controller: _emailDomainController,
  decoration: const InputDecoration(
    labelText: 'Email Domain',
    hintText: 'e.g., thapar.edu',
    helperText: 'Students/teachers must use this domain',
  ),
  validator: (value) {
    if (value == null || value.isEmpty) {
      return 'Email domain is required';
    }
    // Validate domain format (no @ symbol)
    if (value.contains('@')) {
      return 'Enter domain only (without @)';
    }
    return null;
  },
),
```

When saving:

```dart
await FirebaseFirestore.instance.collection('institutions').add({
  'name': _nameController.text,
  'code': _codeController.text,
  'emailDomain': _emailDomainController.text,  // ← NEW
  'status': 'Active',
  'students': 0,
  'createdAt': FieldValue.serverTimestamp(),
});
```

---

## 8️⃣ Update Resource Creation (Add institutionCode)

Apply this pattern to all resource creation:

**Class Groups**:
```dart
await FirebaseFirestore.instance.collection('class_groups').add({
  'name': name,
  'institutionCode': authState.institutionCode,  // ← ADD THIS
  // ... other fields
});
```

**Subjects**:
```dart
await FirebaseFirestore.instance.collection('subjects').add({
  'name': name,
  'code': code,
  'type': type,
  'institutionCode': authState.institutionCode,  // ← ADD THIS
  // ... other fields
});
```

**Sessions**:
```dart
await FirebaseFirestore.instance.collection('sessions').add({
  'subjectId': subjectId,
  'teacherUid': uid,
  'institutionCode': authState.institutionCode,  // ← ADD THIS
  // ... other fields
});
```

---

## 9️⃣ Testing Checklist

After making all changes:

```dart
// 1. Test Super Admin
// - Login with super admin account
// - Verify you see institution dropdown
// - Select "All" → should see all data
// - Select specific institution → should see filtered data

// 2. Test Institution Admin
// - Login with institution admin
// - Should NOT see institution dropdown
// - Should only see their institution's data
// - Try accessing other institution's data → should fail

// 3. Test Email Validation
// - Select TIET institution
// - Try signing in with @gmail.com → should show error
// - Sign in with @thapar.edu → should succeed

// 4. Test Data Creation
// - Create class group → should have institutionCode
// - Create subject → should have institutionCode
// - Create session → should have institutionCode

// 5. Test Queries
// - Verify all queries filter by institution
// - Verify super admin sees all data
// - Verify institution admin sees only their data
```

---

## 🎯 Summary of Changes

1. ✅ **Institution Model**: Added `emailDomain` field
2. ✅ **AuthRepository**: Added email validation method
3. ✅ **Signup Page**: Updated to use validation
4. ✅ **AuthState**: Added `isSuperAdmin` flag
5. ✅ **Admin Providers**: Added institution filtering
6. ✅ **Dashboard UI**: Added institution selector for super admin
7. ✅ **Institution Form**: Added email domain field
8. ✅ **Resource Creation**: Added `institutionCode` to all resources

---

## 🚀 Deploy Sequence

```bash
# 1. Deploy security rules (already done)
firebase deploy --only firestore:rules

# 2. Update code (above changes)
# 3. Test locally
flutter run -d chrome

# 4. Manual Firestore updates:
#    - Add emailDomain to institutions
#    - Set isSuperAdmin for your account
#    - Add institutionCode to existing resources

# 5. Test thoroughly
# 6. Deploy to production
```

---

**Copy and paste each section into the respective files, then test!**
