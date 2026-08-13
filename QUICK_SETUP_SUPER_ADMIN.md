# Quick Setup: Super Admin Configuration

## ✅ Security Rules Deployed Successfully!

The multi-tenant security rules are now active in Firebase.

## 🎯 Next Steps

### Step 1: Make Yourself Super Admin

1. **Go to Firebase Console**:
   - Visit: https://console.firebase.google.com/project/attendiify/firestore

2. **Sign in to your app once** (if not already):
   - This creates your user document in Firestore

3. **Update your user document**:
   - Navigate to: `users` collection
   - Find your document (your UID)
   - Click "Edit Document"
   - Add these fields:
   
   ```json
   {
     "isSuperAdmin": true,
     "institutionCode": null
   }
   ```

4. **Save changes**

### Step 2: Add Email Domain to Existing Institution

1. **Navigate to**: `institutions` collection in Firestore

2. **For each institution**, add the `emailDomain` field:

   **Example for Thapar Institute**:
   ```json
   {
     "name": "Thapar Institute of Engineering",
     "code": "TIET",
     "emailDomain": "thapar.edu",  ← ADD THIS
     "status": "Active"
   }
   ```

### Step 3: Update Existing Resources (Optional for Testing)

Add `institutionCode` to existing documents:

**Class Groups**:
```json
{
  "name": "COE-22",
  "institutionCode": "TIET",  ← ADD THIS
  // ... other fields
}
```

**Subjects**:
```json
{
  "name": "Data Structures",
  "institutionCode": "TIET",  ← ADD THIS
  // ... other fields
}
```

**Sessions** (if any exist):
```json
{
  "subjectId": "...",
  "institutionCode": "TIET",  ← ADD THIS
  // ... other fields
}
```

## 🧪 Test Multi-Tenant System

### Test 1: Super Admin Access

1. Login with your super admin account
2. You should see data from ALL institutions
3. You can create/edit institutions

### Test 2: Institution Admin Access

1. Create a test institution:
   ```json
   {
     "name": "Test University",
     "code": "TEST",
     "emailDomain": "testuniv.edu",
     "status": "Active"
   }
   ```

2. Create a test admin user:
   ```json
   {
     "uid": "test-uid",
     "email": "admin@testuniv.edu",
     "role": "admin",
     "admin": true,
     "isSuperAdmin": false,
     "institutionCode": "TEST",
     "approved": true
   }
   ```

3. Login with test admin
4. Should ONLY see "TEST" institution data
5. Should NOT see "TIET" data

### Test 3: Email Validation (After Code Update)

After implementing the email validation code:

1. Try signing up with wrong email domain
2. Should show error: "Email domain does not match selected institution"

## 📋 Code Changes Required

Refer to `MULTI_TENANT_IMPLEMENTATION.md` for:

1. **Institution Model Update**: Add `emailDomain` field
2. **Email Validation**: Update `AuthRepository`
3. **Signup Page**: Add domain validation
4. **Admin Dashboard**: Add institution filtering
5. **Router Guards**: Update for super admin

## 🎨 UI Enhancements for Super Admin

Add institution selector in super admin dashboard:

```dart
// Show dropdown only for super admin
if (authState.isSuperAdmin) {
  DropdownButton<String>(
    value: _selectedInstitution,
    hint: Text('All Institutions'),
    items: [
      DropdownMenuItem(
        value: 'ALL',
        child: Text('🌐 All Institutions'),
      ),
      ...institutions.map((inst) => 
        DropdownMenuItem(
          value: inst.code,
          child: Text('🏛️ ${inst.name}'),
        )
      ),
    ],
    onChanged: (code) {
      setState(() => _selectedInstitution = code);
      // Reload data with filter
    },
  )
}
```

## 🔐 Current Security Status

✅ **Active Protections**:
- Super admin can access all institutions
- Institution admins restricted to their own data
- Students/teachers can't access other institutions
- Users cannot set themselves as super admin
- Institution admins can only approve teachers in their institution

⚠️ **Still Needs Implementation**:
- Dynamic email domain validation in signup
- Institution filtering in UI (currently shows all)
- Super admin institution management page

## 🚨 Important Notes

1. **Never commit super admin credentials** to version control
2. **Keep isSuperAdmin flag private** - only set manually in Firestore
3. **Test thoroughly** before deploying to production
4. **Backup your database** before making bulk updates
5. **Monitor audit logs** for super admin actions

## 📞 Need Help?

If you encounter issues:
1. Check browser console for errors
2. Verify Firestore rules are deployed
3. Confirm user document has correct fields
4. Check institution has `emailDomain` field
5. Verify `institutionCode` on resources

---

**Current Status**: 🟢 Security Rules Deployed
**Next Action**: Configure your super admin account in Firestore Console
