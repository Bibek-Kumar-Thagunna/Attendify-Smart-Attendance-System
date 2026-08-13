# Multi-Tenant Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ATTENDIFY MULTI-TENANT SYSTEM                    │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                              USER HIERARCHY                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  SUPER ADMIN (Owner)                                              │  │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │  │
│  │  • isSuperAdmin: true                                             │  │
│  │  • institutionCode: null                                          │  │
│  │  • Can access ALL institutions                                    │  │
│  │  • Manage institutions (create/edit/delete)                       │  │
│  │  • View aggregated data                                           │  │
│  │  • Approve institution admins                                     │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                  │                                       │
│                                  │                                       │
│         ┌────────────────────────┴───────────────────────┐              │
│         │                                                 │              │
│         ▼                                                 ▼              │
│  ┌──────────────────┐                            ┌──────────────────┐   │
│  │ INSTITUTION A    │                            │ INSTITUTION B    │   │
│  │ (TIET)           │                            │ (TEST)           │   │
│  └──────────────────┘                            └──────────────────┘   │
│         │                                                 │              │
│         ▼                                                 ▼              │
│  ┌──────────────────┐                            ┌──────────────────┐   │
│  │ Institution      │                            │ Institution      │   │
│  │ Admin            │                            │ Admin            │   │
│  │ ━━━━━━━━━━━━━━  │                            │ ━━━━━━━━━━━━━━  │   │
│  │ • admin: true    │                            │ • admin: true    │   │
│  │ • isSuperAdmin:  │                            │ • isSuperAdmin:  │   │
│  │   false          │                            │   false          │   │
│  │ • institution    │                            │ • institution    │   │
│  │   Code: "TIET"   │                            │   Code: "TEST"   │   │
│  │ • Can only see   │                            │ • Can only see   │   │
│  │   TIET data      │                            │   TEST data      │   │
│  └──────────────────┘                            └──────────────────┘   │
│         │                                                 │              │
│         ▼                                                 ▼              │
│  ┌──────────────────┐                            ┌──────────────────┐   │
│  │ Teachers         │                            │ Teachers         │   │
│  │ ━━━━━━━━━━━━━━  │                            │ ━━━━━━━━━━━━━━  │   │
│  │ • role: teacher  │                            │ • role: teacher  │   │
│  │ • institution    │                            │ • institution    │   │
│  │   Code: "TIET"   │                            │   Code: "TEST"   │   │
│  └──────────────────┘                            └──────────────────┘   │
│         │                                                 │              │
│         ▼                                                 ▼              │
│  ┌──────────────────┐                            ┌──────────────────┐   │
│  │ Students         │                            │ Students         │   │
│  │ ━━━━━━━━━━━━━━  │                            │ ━━━━━━━━━━━━━━  │   │
│  │ • role: student  │                            │ • role: student  │   │
│  │ • institution    │                            │ • institution    │   │
│  │   Code: "TIET"   │                            │   Code: "TEST"   │   │
│  └──────────────────┘                            └──────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                           DATA ISOLATION                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  FIRESTORE COLLECTIONS                                          │    │
│  ├────────────────────────────────────────────────────────────────┤    │
│  │                                                                 │    │
│  │  institutions                                                   │    │
│  │  ├─ TIET { emailDomain: "thapar.edu" }                         │    │
│  │  └─ TEST { emailDomain: "testuniv.edu" }                       │    │
│  │                                                                 │    │
│  │  users                                                          │    │
│  │  ├─ uid1 { institutionCode: "TIET", ... }                      │    │
│  │  ├─ uid2 { institutionCode: "TEST", ... }                      │    │
│  │  └─ uid3 { isSuperAdmin: true, institutionCode: null }         │    │
│  │                                                                 │    │
│  │  class_groups                                                   │    │
│  │  ├─ group1 { institutionCode: "TIET", ... }                    │    │
│  │  └─ group2 { institutionCode: "TEST", ... }                    │    │
│  │                                                                 │    │
│  │  subjects                                                       │    │
│  │  ├─ sub1 { institutionCode: "TIET", ... }                      │    │
│  │  └─ sub2 { institutionCode: "TEST", ... }                      │    │
│  │                                                                 │    │
│  │  sessions                                                       │    │
│  │  ├─ sess1 { institutionCode: "TIET", ... }                     │    │
│  │  │   └─ attendance/                                             │    │
│  │  └─ sess2 { institutionCode: "TEST", ... }                     │    │
│  │      └─ attendance/                                             │    │
│  │                                                                 │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         SIGNUP FLOW WITH VALIDATION                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. User lands on signup page                                           │
│     │                                                                    │
│     ▼                                                                    │
│  2. Select Institution from dropdown                                    │
│     ├─ TIET (Thapar Institute)                                          │
│     └─ TEST (Test University)                                           │
│     │                                                                    │
│     ▼                                                                    │
│  3. Click "Sign in with Google"                                         │
│     │                                                                    │
│     ▼                                                                    │
│  4. Google OAuth (get email)                                            │
│     │                                                                    │
│     ▼                                                                    │
│  5. VALIDATE EMAIL DOMAIN                                               │
│     ├─ Fetch institution.emailDomain from Firestore                     │
│     │  • TIET → "thapar.edu"                                            │
│     │  • TEST → "testuniv.edu"                                          │
│     │                                                                    │
│     ├─ Extract domain from user email                                   │
│     │  • admin@thapar.edu → "thapar.edu"                                │
│     │  • teacher@testuniv.edu → "testuniv.edu"                          │
│     │                                                                    │
│     └─ Compare domains                                                  │
│        │                                                                 │
│        ├─ MATCH ✅                                                      │
│        │  └─► Continue to role selection                                │
│        │                                                                 │
│        └─ NO MATCH ❌                                                   │
│           └─► Show error: "Email domain does not match institution"     │
│              Sign out user                                              │
│                                                                          │
│  6. Complete profile (ID, role, etc.)                                   │
│     │                                                                    │
│     ▼                                                                    │
│  7. Store user document with institutionCode                            │
│     {                                                                    │
│       uid: "...",                                                        │
│       email: "admin@thapar.edu",                                        │
│       institutionCode: "TIET",  ← FROM SELECTED INSTITUTION             │
│       role: "admin",                                                     │
│       admin: true,                                                       │
│       isSuperAdmin: false  ← NEVER TRUE FROM SIGNUP                     │
│     }                                                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                      QUERY FILTERING LOGIC                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ╔════════════════════════════════════════════════════════════════╗    │
│  ║  SUPER ADMIN QUERIES                                            ║    │
│  ╠════════════════════════════════════════════════════════════════╣    │
│  ║                                                                 ║    │
│  ║  // No filter - see everything                                 ║    │
│  ║  FirebaseFirestore.instance.collection('users')                ║    │
│  ║    .snapshots()                                                 ║    │
│  ║                                                                 ║    │
│  ║  // Can optionally filter by institution                       ║    │
│  ║  if (selectedInstitution != 'ALL') {                           ║    │
│  ║    query = query.where('institutionCode',                      ║    │
│  ║                        isEqualTo: selectedInstitution);        ║    │
│  ║  }                                                              ║    │
│  ║                                                                 ║    │
│  ╚════════════════════════════════════════════════════════════════╝    │
│                                                                          │
│  ╔════════════════════════════════════════════════════════════════╗    │
│  ║  INSTITUTION ADMIN QUERIES                                      ║    │
│  ╠════════════════════════════════════════════════════════════════╣    │
│  ║                                                                 ║    │
│  ║  // MUST filter by institution                                 ║    │
│  ║  FirebaseFirestore.instance.collection('users')                ║    │
│  ║    .where('institutionCode',                                   ║    │
│  ║           isEqualTo: authState.institutionCode)                ║    │
│  ║    .snapshots()                                                 ║    │
│  ║                                                                 ║    │
│  ║  // Same for all collections:                                  ║    │
│  ║  • class_groups                                                 ║    │
│  ║  • subjects                                                     ║    │
│  ║  • sessions                                                     ║    │
│  ║  • scheduled_sessions                                           ║    │
│  ║                                                                 ║    │
│  ╚════════════════════════════════════════════════════════════════╝    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                        SECURITY RULES LOGIC                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  function isSuperAdmin() {                                              │
│    return request.auth.uid != null &&                                   │
│           get(/databases/$(database)/documents/users/$(request.auth.uid))│
│           .data.isSuperAdmin == true;                                   │
│  }                                                                       │
│                                                                          │
│  function isInstitutionAdmin() {                                        │
│    return request.auth.uid != null &&                                   │
│           get(/databases/$(database)/documents/users/$(request.auth.uid))│
│           .data.admin == true &&                                        │
│           get(/databases/$(database)/documents/users/$(request.auth.uid))│
│           .data.isSuperAdmin != true;                                   │
│  }                                                                       │
│                                                                          │
│  function getUserInstitution() {                                        │
│    return get(/databases/$(database)/documents/users/$(request.auth.uid))│
│           .data.institutionCode;                                        │
│  }                                                                       │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  READ ACCESS                                                │        │
│  ├────────────────────────────────────────────────────────────┤        │
│  │                                                             │        │
│  │  Super Admin:                                               │        │
│  │    ✅ Read all documents in all collections                │        │
│  │                                                             │        │
│  │  Institution Admin:                                         │        │
│  │    ✅ Read documents WHERE                                 │        │
│  │       document.data.institutionCode == user.institutionCode│        │
│  │    ❌ Cannot read other institutions' data                 │        │
│  │                                                             │        │
│  │  Teachers/Students:                                         │        │
│  │    ✅ Read own institution's data (subjects, sessions)     │        │
│  │    ❌ Cannot read other institutions' data                 │        │
│  │                                                             │        │
│  └────────────────────────────────────────────────────────────┘        │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────┐        │
│  │  WRITE ACCESS                                               │        │
│  ├────────────────────────────────────────────────────────────┤        │
│  │                                                             │        │
│  │  Super Admin:                                               │        │
│  │    ✅ Create/Update/Delete institutions                    │        │
│  │    ✅ Approve institution admins                           │        │
│  │    ✅ Access all data                                      │        │
│  │                                                             │        │
│  │  Institution Admin:                                         │        │
│  │    ✅ Create/Update own institution's resources            │        │
│  │    ✅ Approve teachers in own institution                  │        │
│  │    ❌ Cannot modify other institutions' data               │        │
│  │    ❌ Cannot create/edit institutions                      │        │
│  │    ❌ Cannot set isSuperAdmin on any user                  │        │
│  │                                                             │        │
│  └────────────────────────────────────────────────────────────┘        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                          EXAMPLE SCENARIOS                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  📌 Scenario 1: Super Admin Views Dashboard                             │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. Login as super admin (isSuperAdmin: true)                           │
│  2. Dashboard shows institution dropdown                                │
│  3. Select "All Institutions" (default)                                 │
│  4. See aggregated data:                                                │
│     • Total users: 1500 (TIET) + 800 (TEST) = 2300                      │
│     • Total sessions: 245 (TIET) + 120 (TEST) = 365                     │
│  5. Select "TIET" from dropdown                                         │
│  6. Now see only TIET data:                                             │
│     • Total users: 1500                                                 │
│     • Total sessions: 245                                               │
│                                                                          │
│  📌 Scenario 2: TIET Admin Tries to Access TEST Data                    │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. Login as TIET admin (institutionCode: "TIET")                       │
│  2. Dashboard shows only TIET data automatically                        │
│  3. No institution dropdown (hardcoded to TIET)                         │
│  4. Try to manually query TEST data:                                    │
│     FirebaseFirestore.instance.collection('users')                      │
│       .where('institutionCode', isEqualTo: 'TEST')                      │
│       .get()                                                             │
│  5. ❌ Security rules DENY - returns empty                              │
│  6. Console error: "Insufficient permissions"                           │
│                                                                          │
│  📌 Scenario 3: Student Signup with Wrong Email                         │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. Student selects "TIET" institution                                  │
│  2. Clicks "Sign in with Google"                                        │
│  3. Uses email: student@gmail.com                                       │
│  4. System checks:                                                      │
│     • Fetch TIET.emailDomain → "thapar.edu"                             │
│     • Extract domain from email → "gmail.com"                           │
│     • Compare: "gmail.com" != "thapar.edu"                              │
│  5. ❌ Validation fails                                                 │
│  6. Google sign out automatically                                       │
│  7. Show error: "Email must end with @thapar.edu"                       │
│                                                                          │
│  📌 Scenario 4: Institution Admin Approves Teacher                      │
│  ─────────────────────────────────────────────────────────────────────  │
│  1. TIET admin reviews pending teachers                                 │
│  2. See only teachers with institutionCode: "TIET"                      │
│  3. Click "Approve" on teacher                                          │
│  4. Security rule checks:                                               │
│     • Is user institution admin? ✅ Yes                                 │
│     • Is teacher in same institution? ✅ Yes (both TIET)                │
│     • Is trying to set isSuperAdmin? ✅ No                              │
│  5. Update allowed:                                                     │
│     teacher.approved = true                                             │
│  6. Teacher can now access dashboard                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                              KEY POINTS                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ✅ Super admin has isSuperAdmin: true + institutionCode: null          │
│  ✅ Institution admin has admin: true + institutionCode: "XXX"          │
│  ✅ All resources must have institutionCode field                       │
│  ✅ Email domains stored in institution documents                       │
│  ✅ Security rules enforce institution isolation                        │
│  ✅ UI filters data based on user role                                  │
│  ❌ Users cannot set isSuperAdmin themselves                            │
│  ❌ Institution admins cannot access other institutions                 │
│  ❌ Wrong email domain blocks signup                                    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```
