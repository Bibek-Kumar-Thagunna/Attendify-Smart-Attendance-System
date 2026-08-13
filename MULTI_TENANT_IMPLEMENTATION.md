# Multi-Tenant Implementation Guide

## 🏗️ Architecture Overview

This system supports **multiple institutions** with proper data isolation:
- **Super Admin** (Owner) - Can access ALL institutions
- **Institution Admin** - Can only access their own institution's data
- **Teachers/Students** - Restricted to their institution

## 📊 Database Schema Updates

### 1. Add `emailDomain` to Institutions

```dart
// Example institution document
{
  "name": "Thapar Institute of Engineering",
  "code": "TIET",
  "emailDomain": "thapar.edu",  // NEW FIELD
  "status": "Active",
  "createdAt": timestamp
}
```

### 2. Add `isSuperAdmin` to Users

```dart
// Example user document
{
  "email": "owner@attendify.com",
  "role": "admin",
  "admin": true,
  "isSuperAdmin": true,  // NEW FIELD - Only for owner
  "institutionCode": null,  // Super admin has no institution
  // ... other fields
}
```

### 3. Add `institutionCode` to All Resources

Add `institutionCode` field to:
- `class_groups`
- `subjects`
- `sessions`
- `scheduled_sessions`

## 🔐 Implementation Steps

### Step 1: Update Institution Model

```dart
// lib/features/institutions/models/institution.dart
@immutable
class Institution {
  final String id;
  final String name;
  final String code;
  final String emailDomain;  // NEW
  final String status;
  final DateTime? createdAt;

  const Institution({
    required this.id,
    required this.name,
    required this.code,
    required this.emailDomain,  // NEW
    required this.status,
    this.createdAt,
  });

  factory Institution.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Institution(
      id: doc.id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      emailDomain: data['emailDomain'] ?? '',  // NEW
      status: data['status'] ?? 'Pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'code': code,
        'emailDomain': emailDomain,  // NEW
        'status': status,
        'createdAt': createdAt != null 
            ? Timestamp.fromDate(createdAt!) 
            : FieldValue.serverTimestamp(),
      };
}
```

### Step 2: Update Signup Email Validation

```dart
// lib/features/auth/repository.dart

Future<bool> validateEmailDomain(String email, String institutionCode) async {
  try {
    final institutionDoc = await FirebaseFirestore.instance
        .collection('institutions')
        .where('code', isEqualTo: institutionCode)
        .limit(1)
        .get();

    if (institutionDoc.docs.isEmpty) {
      throw Exception('Institution not found');
    }

    final institution = institutionDoc.docs.first.data();
    final emailDomain = institution['emailDomain'] as String;
    
    // Extract domain from email
    final userDomain = email.split('@').last.toLowerCase();
    
    return userDomain == emailDomain.toLowerCase();
  } catch (e) {
    throw Exception('Email validation failed: $e');
  }
}

// Update continueWithGoogleThaparOnly method
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
      throw Exception('Email domain does not match selected institution');
    }

    // Continue with authentication...
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

### Step 3: Update Signup Page

```dart
// lib/features/auth/presentation/signup_page.dart

// Before calling continueWithGoogle, validate:
Future<void> _handleGoogleSignIn() async {
  if (_selectedInstitution == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select an institution first')),
    );
    return;
  }

  try {
    setState(() => _isLoading = true);
    
    final result = await ref.read(authRepositoryProvider)
        .continueWithGoogleForInstitution(_selectedInstitution!);
    
    // Show role selection dialog...
    
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### Step 4: Create Super Admin

Manually create the super admin in Firestore console:

```javascript
// Firestore Console > users collection > Add document
{
  "uid": "YOUR_UID_FROM_FIREBASE_AUTH",
  "email": "your@email.com",
  "displayName": "Super Admin",
  "role": "admin",
  "admin": true,
  "isSuperAdmin": true,  // This makes you the owner
  "institutionCode": null,
  "approved": true,
  "createdAt": new Date()
}
```

### Step 5: Update Institution Admin Pages

```dart
// Filter users/sessions/etc by institution

// For Institution Admins - only show their institution's data
final usersProvider = StreamProvider<List<User>>((ref) async* {
  final authState = ref.watch(authControllerProvider);
  
  Query query = FirebaseFirestore.instance.collection('users');
  
  // If not super admin, filter by institution
  if (!authState.isSuperAdmin) {
    query = query.where('institutionCode', isEqualTo: authState.institutionCode);
  }
  
  yield* query.snapshots().map((snapshot) => 
    snapshot.docs.map((doc) => User.fromFirestore(doc)).toList()
  );
});
```

### Step 6: Update Router Guards

```dart
// lib/core/router.dart

redirect: (context, state) {
  final authState = ref.read(authControllerProvider);
  
  // Super admin can access everything
  if (authState.isSuperAdmin) {
    return null;
  }
  
  // Institution admin can only access their institution's routes
  if (authState.role == UserRole.admin) {
    // Check if trying to access different institution's data
    // Redirect if necessary
  }
  
  // Regular users
  if (!authState.approved && authState.role == UserRole.teacher) {
    return '/teacher/pending';
  }
  
  return null;
}
```

## 🎨 UI Updates

### Super Admin Dashboard

Show institution selector dropdown:

```dart
// Add institution filter dropdown in app bar
DropdownButton<String>(
  value: selectedInstitution,
  items: [
    DropdownMenuItem(value: 'ALL', child: Text('All Institutions')),
    ...institutions.map((inst) => 
      DropdownMenuItem(value: inst.code, child: Text(inst.name))
    ),
  ],
  onChanged: (value) {
    setState(() => selectedInstitution = value);
    // Reload data filtered by institution
  },
)
```

### Institution Admin Dashboard

- No institution selector
- Automatically filtered to their institution
- Cannot see other institutions' data

## 📝 Testing Checklist

- [ ] Super admin can view all institutions
- [ ] Super admin can create/edit/delete institutions
- [ ] Institution admin can only see their institution's data
- [ ] Email validation works for each institution's domain
- [ ] Teachers can only access their institution's classes/sessions
- [ ] Students can only mark attendance in their institution
- [ ] Security rules prevent cross-institution data access
- [ ] Class groups are institution-specific
- [ ] Subjects are institution-specific
- [ ] Sessions are institution-specific

## 🚀 Deployment Steps

1. **Deploy Security Rules**:
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Update Existing Data**:
   - Add `emailDomain` to all institutions
   - Add `institutionCode` to all class_groups, subjects, sessions
   - Set `isSuperAdmin: true` for your owner account

3. **Test Thoroughly**:
   - Test with multiple institution accounts
   - Verify data isolation
   - Check permissions

4. **Update Documentation**:
   - Update user manual
   - Document new admin features

## 🔒 Security Considerations

1. **Never allow users to set `isSuperAdmin` themselves**
2. **Always validate email domains on signup**
3. **Filter all queries by institution** (except super admin)
4. **Use Firestore security rules** as the primary defense
5. **Log all super admin actions** for audit trail

## 📌 Notes

- Super admin has NO institution code (`institutionCode: null`)
- Regular admins have `admin: true` AND `institutionCode: "XXXX"`
- All resources (sessions, subjects, etc.) must have `institutionCode`
- Email domain validation happens at signup, not at login
