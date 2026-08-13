# Multi-Tenant Setup Guide

## ✅ What's Done

1. **Security Rules Deployed** - Comprehensive role-based Firestore security rules are now active
2. **Institution Selection Flow** - Users select institution BEFORE Google sign-in (no duplicate selection)
3. **Email Validation** - User emails validated against institution's `emailDomain` field
4. **Code Updates** - All session/subject/class group creation now includes `institutionCode`

## 🚀 Setup Steps (Do These Now)

### Step 1: Create Your Super Admin Account

1. Sign in to the app with your owner email (the email you want to be super admin)
2. Go to [Firebase Console](https://console.firebase.google.com/project/attendiify/firestore)
3. Navigate to: **Firestore Database → users collection**
4. Find your user document (your UID)
5. Click "Add field" and add:
   - **Field:** `isSuperAdmin`
   - **Type:** boolean
   - **Value:** `true`
6. Log out of the app and log back in

### Step 2: Add Email Domains to Institutions

Your institutions need an `emailDomain` field for email validation to work.

**Option A: Via Admin UI (Recommended)**
1. Login as super admin
2. Go to **Admin → Institutions**
3. Click "Edit" on each institution
4. Add the email domain (e.g., `thapar.edu` without the @)
5. Save

**Option B: Via Firebase Console**
1. Go to Firestore → `institutions` collection
2. For each institution document, add field:
   - **Field:** `emailDomain`
   - **Type:** string
   - **Value:** `thapar.edu` (or your domain, without @)

### Step 3: Update Existing Data with institutionCode

Your existing data needs the `institutionCode` field. Go to Firebase Console and add it manually:

**A. Update Subjects**
1. Firestore → `subjects` collection
2. For each subject document, add field:
   - **Field:** `institutionCode`
   - **Type:** string
   - **Value:** Your institution code (e.g., `thapar-001`)

**B. Update Class Groups**
1. Firestore → `class_groups` collection
2. For each class group document:
   - If it has `institutionId`, rename it to `institutionCode` OR
   - Add new field: `institutionCode` with the value matching your institution code

**C. Update Sessions (if any exist)**
1. Firestore → `sessions` collection
2. Firestore → `scheduled_sessions` collection
3. For each session document, add field:
   - **Field:** `institutionCode`
   - **Type:** string
   - **Value:** Your institution code

### Step 4: Test the System

**Test as Super Admin:**
1. Login with your super admin account
2. Go to Admin → Institutions
3. Verify you can see ALL institutions
4. Go to Admin → Class Groups
5. Try creating a new class group - should work
6. Go to Admin → Subjects
7. Verify you can see subjects from all institutions

**Test as Institution Admin:**
1. Create a test admin account for one institution
2. Login as that admin
3. Verify you can ONLY see data from your institution
4. Try to access `/admin/institutions` - should redirect or show only own institution

**Test as Teacher:**
1. Create/approve a teacher account
2. Login and start a session
3. Verify session is created with `institutionCode`
4. Check Firestore to confirm the field is present

**Test as Student:**
1. Create a student account
2. Login and scan QR code
3. Mark attendance
4. Verify attendance is recorded correctly

## 🔒 Security Rules Explained

### Role Hierarchy
- **Super Admin** (`isSuperAdmin: true`)
  - Can access ALL institutions
  - Can manage institutions (create/update/delete)
  - Can see all users, sessions, attendance
  
- **Institution Admin** (`admin: true`, `isSuperAdmin: false`)
  - Can only access data from their `institutionCode`
  - Can approve teachers in their institution
  - Can manage subjects and class groups in their institution
  - **Cannot see other institutions**

- **Teacher** (`role: 'teacher'`, `approved: true`)
  - Can create sessions in their institution
  - Can view attendance in their sessions
  - Can manage subjects in their institution
  - Must be approved by institution admin

- **Student** (`role: 'student'`)
  - Can mark their own attendance
  - Can view sessions from their institution

### Public Read Access
These collections allow **unauthenticated read** (needed for signup dropdowns):
- `institutions` - Anyone can read (for login page dropdown)
- `class_groups` - Anyone can read (for student signup dropdown)
- `subjects` - Anyone can read (for session creation dropdown)

### Write Protection
All write operations require:
1. Authentication
2. Matching `institutionCode` (except super admin)
3. Specific role permissions

## 🛠️ Troubleshooting

### "Permission Denied" Errors

**During Signup:**
- Institution must have `emailDomain` field
- User email must match institution's domain
- Ensure institutions collection allows public read

**During Session Creation:**
- Teacher must have `approved: true`
- Teacher must have `institutionCode` in profile
- Session must include `institutionCode` field

**During Attendance:**
- Student must be authenticated
- Session must exist and have matching `institutionCode`
- Student must have same `institutionCode` as session

### Email Validation Fails

Check:
1. Institution has `emailDomain` field in Firestore
2. Email domain matches exactly (case-insensitive)
3. User is selecting correct institution at login

### Admin Can't See Data

Check:
1. User has `admin: true` in Firestore
2. User has `institutionCode` matching the data
3. Data has `institutionCode` field
4. If super admin, must have `isSuperAdmin: true`

### Teacher Can't Create Sessions

Check:
1. Teacher has `approved: true` in Firestore
2. Teacher has `institutionCode` in profile
3. Teacher is passing `institutionCode` to `createSession()`

## 📊 Data Migration Script (Optional)

If you have lots of existing data, you can use this script to bulk update:

```javascript
// Run in Firebase Console → Firestore → Indexes → Rules → Playground

const admin = require('firebase-admin');
const db = admin.firestore();

async function migrateData() {
  const INSTITUTION_CODE = 'thapar-001'; // Change this
  
  // Update subjects
  const subjects = await db.collection('subjects').get();
  for (const doc of subjects.docs) {
    await doc.ref.update({ institutionCode: INSTITUTION_CODE });
  }
  
  // Update class_groups
  const groups = await db.collection('class_groups').get();
  for (const doc of groups.docs) {
    await doc.ref.update({ institutionCode: INSTITUTION_CODE });
  }
  
  // Update sessions
  const sessions = await db.collection('sessions').get();
  for (const doc of sessions.docs) {
    await doc.ref.update({ institutionCode: INSTITUTION_CODE });
  }
  
  console.log('Migration complete!');
}

migrateData();
```

## 🎯 Next Features to Implement

1. **Institution Admin Dashboard**
   - Show stats for own institution only
   - Teacher approval workflow
   - Student management

2. **Super Admin Dashboard**
   - Cross-institution analytics
   - Institution management
   - System-wide monitoring

3. **Institution Switching**
   - Allow super admin to impersonate institution view
   - "View as" feature for testing

4. **Audit Logs**
   - Track who accessed what data
   - Security monitoring
   - Compliance reporting

## 📝 Important Notes

- **Test thoroughly** before deploying to production
- **Backup your Firestore data** before migration
- **Super admin email** should be kept secure
- **Institution codes** should be unique and immutable
- **Email domains** determine who can join which institution
- All new data automatically includes `institutionCode` from user's profile

## 🆘 Need Help?

If you encounter issues:
1. Check Firebase Console for error messages
2. Verify security rules are deployed: `firebase deploy --only firestore:rules`
3. Check that all required fields exist in Firestore
4. Test with fresh user accounts
5. Review the security rules in `firestore.rules`

---

**Last Updated:** After deploying comprehensive security rules
**Status:** ✅ Security rules active, code updated, ready for data migration
