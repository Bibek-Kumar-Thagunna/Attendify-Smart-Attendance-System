# Institution Selection Feature

## Overview
Added mandatory institution selection during teacher and student account creation to enable institution-based user organization and filtering.

## Changes Made

### 1. Signup Page (`lib/features/auth/presentation/signup_page.dart`)
- **Added institution dropdown**: Displays all active institutions from Firestore
- **Required field**: Users must select an institution before completing onboarding
- **Validation**: Shows error if institution is not selected
- **Reset behavior**: Institution selection resets when user changes role
- **Integration**: Uses `institutionsStreamProvider` from `lib/features/institutions/providers.dart`

```dart
// Institution dropdown added before class group selection
Consumer(
  builder: (context, ref, child) {
    final institutionsAsync = ref.watch(institutionsStreamProvider);
    return institutionsAsync.when(
      data: (institutions) {
        final activeInstitutions = institutions.where((i) => i.status == 'Active').toList();
        return DropdownButtonFormField<String>(
          value: _selectedInstitutionCode,
          decoration: InputDecoration(
            labelText: 'Institution',
            hintText: 'Select your institution',
            helperText: 'Required for ${_role == UserRole.student ? 'students' : 'teachers'}',
          ),
          items: activeInstitutions.map((institution) {
            return DropdownMenuItem<String>(
              value: institution.code,
              child: Text(institution.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedInstitutionCode = value;
            });
          },
        );
      },
      ...
    );
  },
)
```

### 2. Auth Repository (`lib/features/auth/repository.dart`)
- **Added `institutionCode` parameter**: Required parameter for `completeOnboarding` method
- **Validation**: Throws exception if institutionCode is null or empty
- **Firestore storage**: Saves `institutionCode` field in user document

```dart
Future<void> completeOnboarding({
  required String uid,
  required String email,
  required String rollNumber,
  required String password,
  required UserRole role,
  String? classGroupId,
  String? institutionCode,  // NEW PARAMETER
}) async {
  // Validate institution selection
  if (institutionCode == null || institutionCode.isEmpty) {
    throw Exception('Please select your institution');
  }
  
  // Store in Firestore
  await _firestore.collection('users').doc(uid).set({
    ...
    'institutionCode': institutionCode,  // NEW FIELD
    ...
  }, SetOptions(merge: true));
}
```

### 3. Auth Controller (`lib/features/auth/providers.dart`)
- **Updated method signature**: Added `institutionCode` parameter to `completeOnboarding`
- **Pass-through**: Forwards institutionCode to repository layer

### 4. Dashboard Providers (`lib/features/dashboard/providers.dart`)
- **Added `institutionNameProvider`**: FutureProvider.family that fetches institution name by code
- **Caching**: Riverpod automatically caches results per institution code
- **Error handling**: Returns institution code if name cannot be fetched

```dart
final institutionNameProvider = FutureProvider.family<String, String?>((ref, institutionCode) async {
  if (institutionCode == null || institutionCode.isEmpty) {
    return 'No Institution';
  }
  
  try {
    final doc = await FirebaseFirestore.instance
        .collection('institutions')
        .doc(institutionCode)
        .get();
    
    if (doc.exists) {
      return (doc.data()?['name'] as String?) ?? institutionCode;
    }
    return institutionCode;
  } catch (e) {
    return institutionCode;
  }
});
```

### 5. Admin Users Page (`lib/features/dashboard/presentation/admin_users_page.dart`)
- **Added Institution column**: Shows institution name in user table
- **Horizontal scroll**: DataTable now scrollable to accommodate new column
- **Dynamic loading**: Uses `institutionNameProvider` to fetch names asynchronously
- **Null handling**: Shows "Not Set" for users without institution

```dart
// Institution column added to DataTable
DataColumn(label: Text('Institution')),

// Institution cell with async loading
Widget _buildInstitutionCell(String? institutionCode) {
  if (institutionCode == null || institutionCode.isEmpty) {
    return const Text('Not Set', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic));
  }
  
  final institutionAsync = ref.watch(institutionNameProvider(institutionCode));
  return institutionAsync.when(
    data: (name) => Text(name),
    loading: () => const CircularProgressIndicator(strokeWidth: 2),
    error: (_, __) => Text(institutionCode),
  );
}
```

### 6. Teacher Approval Page (`lib/features/dashboard/presentation/admin_teacher_approval_page.dart`)
- **Changed to ConsumerWidget**: `_TeacherCard` now has access to WidgetRef
- **Added institution display**: Shows institution name below ID number
- **Inline loading**: Displays small spinner while fetching institution name
- **Compact layout**: Institution info integrated into existing card design

```dart
class _TeacherCard extends ConsumerWidget {  // Changed from StatelessWidget
  ...
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institutionCode = teacher['institutionCode'] as String?;
    
    return FluentAcrylicCard(
      child: Row(
        children: [
          ...
          if (institutionCode != null && institutionCode.isNotEmpty) ...[
            Icon(Icons.school, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            _buildInstitutionText(ref, institutionCode),
          ],
          ...
        ],
      ),
    );
  }
  
  Widget _buildInstitutionText(WidgetRef ref, String institutionCode) {
    final institutionAsync = ref.watch(institutionNameProvider(institutionCode));
    return institutionAsync.when(
      data: (name) => Text(name, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      loading: () => const CircularProgressIndicator(strokeWidth: 1.5),
      error: (_, __) => Text(institutionCode, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
    );
  }
}
```

### 7. Copilot Instructions (`.github/copilot-instructions.md`)
- **Updated Firestore Patterns**: Documented institutions collection
- **Updated Teacher Approval workflow**: Mentions institution selection
- **Added Student/Teacher Onboarding workflow**: Complete onboarding steps with institution selection

## Database Schema

### User Document (`users/{uid}`)
```javascript
{
  email: string,
  idNumber: string,
  displayName: string,
  role: 'student' | 'teacher' | 'admin',
  admin: boolean,
  approved: boolean,
  institutionCode: string,  // NEW FIELD
  createdAt: string,
  updatedAt: string
}
```

### Institution Document (`institutions/{code}`)
```javascript
{
  name: string,
  code: string,
  status: 'Active' | 'Pending' | 'Suspended',
  students: number,
  createdAt: timestamp
}
```

## User Experience Flow

### For Teachers
1. Click "Continue with Google" on login page
2. Authenticate with @thapar.edu email
3. Redirected to signup page
4. Enter ID number and password
5. Select "Teacher" role
6. **Select institution from dropdown** (NEW STEP)
7. Click "Finish onboarding"
8. Redirected to pending approval page
9. Admin sees teacher's institution in approval dashboard
10. After approval, teacher can access full dashboard

### For Students
1. Click "Continue with Google" on login page
2. Authenticate with @thapar.edu email
3. Redirected to signup page
4. Enter ID number and password
5. Select "Student" role
6. **Select institution from dropdown** (NEW STEP)
7. Optionally select class group (if available)
8. Click "Finish onboarding"
9. Immediately access student dashboard

### For Admins
**Viewing Users:**
- Open `/admin/users` page
- See "Institution" column in users table
- Institution names load dynamically from Firestore
- Can identify users by their institutional affiliation

**Reviewing Teacher Applications:**
- Open `/admin/approve-teachers` page
- Each teacher card shows institution with school icon
- Can filter/sort teachers by institution (future enhancement)

## Benefits

1. **Organization**: Users grouped by institution for better management
2. **Filtering**: Foundation for institution-based filtering in reports and analytics
3. **Identification**: Admins can quickly identify user affiliations
4. **Validation**: Ensures all users are properly associated with an institution
5. **Scalability**: Supports multi-institution deployments
6. **Audit trail**: Institution association stored from signup for compliance

## Future Enhancements

### Potential Improvements
1. **Institution Filtering**: Add dropdown to filter users by institution
2. **Institution Analytics**: Dashboard showing stats per institution
3. **Institution Dashboard**: Dedicated page for institution management
4. **Bulk Operations**: Assign teachers/students to institutions in bulk
5. **Institution Admins**: Role-based access for institution-level administrators
6. **Cross-institution Sessions**: Enable collaborative sessions between institutions
7. **Institution Reports**: Export attendance data filtered by institution

### Index Optimization
If filtering by institution becomes frequent, create composite indexes:
```
Collection: users
Fields: institutionCode (Asc), role (Asc), createdAt (Desc)
```

## Testing Checklist

- [x] Institution dropdown shows only active institutions
- [x] Validation prevents signup without institution selection
- [x] Teacher approval page displays institution correctly
- [x] Admin users page shows institution column
- [x] Institution names load asynchronously without blocking UI
- [x] Error handling for missing/invalid institution codes
- [x] No compilation errors in modified files
- [ ] Test with multiple institutions in database
- [ ] Test with users having no institution (legacy data)
- [ ] Test institution name loading with slow network
- [ ] Verify Firestore security rules allow reading institutions

## Security Considerations

### Firestore Rules
Current rules allow authenticated users to read institutions:
```
match /institutions/{institutionId} {
  allow read: if isAuthenticated();
  allow create, update, delete: if isAdmin();
}
```

### User Privacy
- Institution affiliation is visible to admins only
- Students/teachers can only see their own institution in profile
- Institution codes are non-sensitive identifiers

## Migration Notes

### Existing Users
- Users created before this feature will have `institutionCode: null`
- UI displays "Not Set" for these users
- Admins can manually update via Firestore Console or future admin tools
- No automatic migration needed (soft rollout)

### Backward Compatibility
- Code handles null institutionCode gracefully
- No breaking changes to existing functionality
- Institution field is additive, not replacing existing fields
