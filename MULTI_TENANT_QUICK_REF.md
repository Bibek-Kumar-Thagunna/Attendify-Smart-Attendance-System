# 🚀 Multi-Tenant Quick Reference Card

## 🎭 User Types

| Type | isSuperAdmin | institutionCode | Access |
|------|--------------|-----------------|--------|
| **Super Admin** | `true` | `null` | All institutions |
| **Institution Admin** | `false` | `"TIET"` | Only TIET |
| **Teacher** | `false` | `"TIET"` | Only TIET |
| **Student** | `false` | `"TIET"` | Only TIET |

## 🔑 Core Functions (Firestore Rules)

```javascript
// Check if user is super admin
isSuperAdmin()
  → Returns true if user.isSuperAdmin == true

// Check if user is institution admin
isInstitutionAdmin()
  → Returns true if user.admin == true && !isSuperAdmin

// Get user's institution code
getUserInstitution()
  → Returns user.institutionCode
```

## 📝 Common Queries

### Super Admin (See All)
```dart
// No filter - see everything
FirebaseFirestore.instance
  .collection('users')
  .snapshots();

// Optional: Filter by institution
if (selectedInstitution != 'ALL') {
  query = query.where(
    'institutionCode',
    isEqualTo: selectedInstitution
  );
}
```

### Institution Admin (Filtered)
```dart
// MUST filter by institution
FirebaseFirestore.instance
  .collection('users')
  .where('institutionCode', isEqualTo: authState.institutionCode)
  .snapshots();
```

## 🔒 Security Checklist

### On Create
- ✅ Cannot set `isSuperAdmin: true`
- ✅ Must set `institutionCode` (except super admin)
- ✅ Email must match institution domain

### On Update
- ✅ Cannot change `isSuperAdmin` field
- ✅ Cannot change `institutionCode`
- ✅ Can only approve users in same institution

### On Read
- ✅ Super admin: Read all
- ✅ Institution admin: Read only own institution
- ✅ Teachers/Students: Read only own institution

## 📊 Data Model

### Institution Document
```dart
{
  "name": "Thapar Institute",
  "code": "TIET",
  "emailDomain": "thapar.edu",  // NEW
  "status": "Active",
  "createdAt": timestamp
}
```

### User Document
```dart
{
  "uid": "abc123",
  "email": "admin@thapar.edu",
  "role": "admin",
  "admin": true,
  "isSuperAdmin": false,  // NEW - only true for owner
  "institutionCode": "TIET",  // NEW - null for super admin
  "approved": true
}
```

### Resource Document (Class/Subject/Session)
```dart
{
  "name": "COE-22",
  "institutionCode": "TIET",  // NEW - required
  // ... other fields
}
```

## 🎨 UI Patterns

### Check User Role
```dart
final authState = ref.watch(authControllerProvider);

if (authState.isSuperAdmin) {
  // Show institution selector
  // Can see all data
} else {
  // Hide institution selector
  // Filter by authState.institutionCode
}
```

### Institution Dropdown (Super Admin Only)
```dart
if (authState.isSuperAdmin) {
  DropdownButton<String>(
    value: _selectedInstitution,
    items: [
      DropdownMenuItem(value: 'ALL', child: Text('All Institutions')),
      ...institutions.map((inst) => 
        DropdownMenuItem(value: inst.code, child: Text(inst.name))
      ),
    ],
    onChanged: (code) {
      setState(() => _selectedInstitution = code);
      _reloadData();
    },
  )
}
```

## 🔐 Email Validation

```dart
// On signup
Future<bool> validateEmailDomain(String email, String institutionCode) async {
  final instDoc = await FirebaseFirestore.instance
    .collection('institutions')
    .where('code', isEqualTo: institutionCode)
    .limit(1)
    .get();

  if (instDoc.docs.isEmpty) return false;

  final emailDomain = instDoc.docs.first.data()['emailDomain'];
  final userDomain = email.split('@').last.toLowerCase();
  
  return userDomain == emailDomain.toLowerCase();
}

// Usage in signup
if (!await validateEmailDomain(email, selectedInstitution)) {
  throw Exception('Email domain does not match institution');
}
```

## 🛠️ Common Tasks

### Create Institution
```dart
await FirebaseFirestore.instance.collection('institutions').add({
  'name': 'Test University',
  'code': 'TEST',
  'emailDomain': 'testuniv.edu',
  'status': 'Active',
  'createdAt': FieldValue.serverTimestamp(),
});
```

### Make User Super Admin (Manual)
```javascript
// In Firestore Console
{
  "isSuperAdmin": true,
  "institutionCode": null
}
```

### Filter Query by Institution
```dart
Query query = FirebaseFirestore.instance.collection('sessions');

// Add institution filter if not super admin
if (!authState.isSuperAdmin) {
  query = query.where('institutionCode', isEqualTo: authState.institutionCode);
}

// Continue building query
query = query.where('active', isEqualTo: true);
```

## 🧪 Testing Scenarios

### Test 1: Super Admin Access
```
1. Login as super admin
2. Should see dropdown with institutions
3. Select "All" → see data from all institutions
4. Select "TIET" → see only TIET data
```

### Test 2: Institution Admin Restriction
```
1. Login as TIET admin
2. Should NOT see institution dropdown
3. Should only see TIET data
4. Try accessing TEST data → should fail
```

### Test 3: Email Validation
```
1. Select TIET institution
2. Try signing in with @gmail.com
3. Should show error
4. Sign in with @thapar.edu
5. Should succeed
```

## ⚠️ Common Pitfalls

❌ **Mistake**: Forgetting to add `institutionCode` when creating resources
✅ **Fix**: Always set `institutionCode` = `authState.institutionCode`

❌ **Mistake**: Hard-coding institution filters in UI
✅ **Fix**: Check `authState.isSuperAdmin` first

❌ **Mistake**: Allowing users to select `isSuperAdmin` in signup
✅ **Fix**: Never expose this field in UI

❌ **Mistake**: Using wrong email domain validation
✅ **Fix**: Fetch from institution document, don't hard-code

## 📌 Quick Commands

### Deploy Security Rules
```bash
firebase deploy --only firestore:rules
```

### Deploy Indexes
```bash
firebase deploy --only firestore:indexes
```

### Run App
```bash
flutter run -d chrome
```

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| "Insufficient permissions" | Check security rules deployed |
| Not seeing all data | Verify `isSuperAdmin` field set |
| Email validation fails | Check `emailDomain` in institution |
| Cannot create resource | Add `institutionCode` field |
| Cross-institution access | Check query filters |

## 📚 Documentation Files

- `DEPLOYMENT_SUMMARY.md` - Current status & next steps
- `MULTI_TENANT_IMPLEMENTATION.md` - Full implementation guide
- `MULTI_TENANT_ARCHITECTURE_DIAGRAM.md` - Visual reference
- `QUICK_SETUP_SUPER_ADMIN.md` - Initial setup steps

---

**Keep this card handy for daily development!**
