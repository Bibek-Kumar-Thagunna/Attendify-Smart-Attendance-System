# Attendify - AI Coding Agent Instructions

## Project Overview
Flutter attendance management system with Web + Android support. Uses Firebase (Auth, Firestore) with role-based UIs (Admin, Teacher, Student). Core feature: time-bound, geo-locked QR code attendance sessions.

## Architecture Patterns

### State Management (Riverpod)
- **Notifier pattern**: Use `NotifierProvider` for complex stateful logic (see `ActiveSessionController` in `lib/features/teacher/providers.dart`)
- **StreamProviders**: Auto-sync Firestore real-time data (see `scheduledSessionsProvider`, `studentsProvider`, `subjectsProvider`)
- **Auth state**: Global `authControllerProvider` drives role-based routing
- **Provider location**: Domain-specific providers live in feature folders (e.g., `lib/features/teacher/providers.dart`)

### Feature Structure
```
lib/features/<feature>/
  models/          # Immutable data classes (use @immutable)
  presentation/    # Pages + feature-specific providers
  repository.dart  # Firestore/Firebase interactions (single file per feature)
  providers.dart   # Riverpod state management
  services/        # Business logic (e.g., export_service.dart)
  
lib/features/shared/
  models/          # Shared models (e.g., class_group.dart)
  providers.dart   # Shared Riverpod providers
  <feature>_repository.dart  # Shared repositories (e.g., class_group_repository.dart)
  widgets/         # Reusable UI components
```

### Navigation (GoRouter)
- Role-based redirects in `lib/core/router.dart`
- Admin override: Admins accessing `/teacher` routes redirect to `/admin`
- Shell pattern: `TeacherShell` wraps pages with sidebar (see `teacher_shell.dart`)

### Firestore Patterns
1. **Session persistence**: Active sessions restore from Firestore on app refresh (`_restoreActiveSession()` in `ActiveSessionController`)
2. **Dual collections**: 
   - `sessions` = active sessions
   - `scheduled_sessions` = future sessions
   - Merge both in UI (see `scheduledSessionsProvider` combining queries)
3. **Subcollections**: Attendance stored as `sessions/{sessionId}/attendance/{uid}`
4. **CollectionGroup queries**: Use for cross-session data (e.g., student attendance history across all sessions)
5. **Class Groups**: 
   - `class_groups` collection stores groups with `teacherUids`, `studentUids`, `subjectIds`
   - Students self-assign during onboarding (`signup_page.dart`)
   - Admins manage via `/admin/class-groups` page
   - Use `ClassGroupRepository` for CRUD operations
6. **Institutions**:
   - `institutions` collection stores institution metadata (`name`, `code`, `status`, `students`)
   - All users must select institution during signup (stored in `institutionCode` field)
   - Active institutions displayed in signup dropdown
   - Admins manage via `/admin/institutions` page
   - Use `InstitutionsRepository` for CRUD operations

### Critical Firestore Indexes
**Must create manually via Firebase Console** (see `lib/core/firestore_init.dart`):
- Collection Group `attendance`: `timestamp (Desc)` 
- Collection Group `attendance`: `uid (Asc), timestamp (Desc)`
- Collection `sessions`: `active (Asc), createdAt (Desc)`
- Collection `sessions`: `teacherUid (Asc), createdAt (Desc)`

Deploy indexes: `./deploy-indexes.sh` or `firebase deploy --only firestore:indexes`

## Key Workflows

### Teacher Approval
1. **Registration**: Teacher signs up with Google (@thapar.edu) → selects institution → profile created with `approved: false` and `institutionCode`
2. **Redirect**: Unapproved teachers redirected to `/teacher/pending` on login
3. **Admin Review**: Admin views pending teachers at `/admin/approve-teachers` (can see institution affiliation)
4. **Approval**: Admin approves → sets `approved: true` → teacher can access dashboard
5. **Check**: Router checks `authState.approved` field to enforce approval requirement

### Student/Teacher Onboarding
1. **Google Sign-In**: User authenticates with @thapar.edu email
2. **Institution Selection**: User selects their institution from dropdown (only active institutions shown)
3. **Profile Completion**: User enters ID number and password, selects role
4. **Class Group (Students only)**: Students optionally select class group for self-enrollment
5. **Data Persistence**: User profile stored with `institutionCode`, `idNumber`, `role`, and `approved` status
6. **Institution Field**: Required for both teachers and students to enable institution-based filtering

### Session Lifecycle
1. **Create**: Teacher starts session → captures GPS → stores in `sessions` collection with `active: true`
2. **Restore**: On app refresh, `ActiveSessionController._restoreActiveSession()` queries active sessions by `teacherUid`
3. **Timer**: 1-second ticker in `ActiveSessionController` updates UI and auto-ends expired sessions
4. **QR Payload**: `sessionId:latitude:longitude` (refreshes every 5s in UI, payload stays constant)
5. **End**: Set `active: false` in Firestore

### Scheduled Sessions
- Stored in `scheduled_sessions` collection
- "Start Now" button appears 30 min before scheduled time
- Starting deletes scheduled entry and creates active session in `sessions` collection
- Conflict detection prevents overlapping sessions (see `_checkScheduleConflict()` logic)

### Running the App
```bash
flutter pub get
flutter run -d chrome              # Web
flutter run -d <android-device>    # Android
```

## UI Conventions

### Theme (shadcn-inspired)
- Primary: `#10B981` (emerald-500)
- Surfaces: White cards with hairline borders (`outline: #E2E8F0`)
- Scaffold: `#F6F7F9` (warm neutral)
- Font: Google Fonts Inter
- See `lib/core/theme.dart` and `lib/core/fluent_theme.dart`

### Widget Patterns
- **Fluent Design**: `FluentAcrylicCard`, `FluentButton` (from `fluent_theme.dart`)
- **Animations**: `animate_do` package (FadeInUp, FadeInDown with 500ms duration)
- **Responsive grids**: Use `LayoutBuilder` for column counts (see dashboard quick actions)
- **Shared widgets**: Reusable components in `lib/features/shared/widgets/`
- **Empty states**: Use `empty_state.dart` widget for no-data scenarios

### Error Handling
- Show errors via `ScaffoldMessenger.of(context).showSnackBar()`
- Format: `SnackBar(content: Text(error.replaceFirst('Exception: ', '')))`

## Development Notes

### Firebase Setup
- Initialize in `main.dart` with `FirestoreInitService().initializeDatabase()`
- Security rules in `firestore.rules` enforce role-based access
- Collection placeholders auto-created on first run

### Permissions
- Android: Camera + Location in `android/app/src/main/AndroidManifest.xml`
- Web: Requires HTTPS for camera/geolocation APIs

### Common Pitfalls
1. **Auth timing**: Providers may run before auth ready → add 500ms delay in `build()` or check `uid != null`
2. **Index errors**: Missing collectionGroup indexes cause queries to fail → check console errors
3. **Session conflicts**: Always validate scheduled session times before manual session creation
4. **Role redirects**: Admin users bypass teacher routes → test with non-admin accounts

## File References
- **Router**: `lib/core/router.dart` (role redirects, route structure)
- **Auth flow**: `lib/features/auth/providers.dart` (AuthController, AuthState)
- **Session state**: `lib/features/teacher/providers.dart` (ActiveSessionController)
- **Data layer**: `lib/features/attendance/repository.dart` (Firestore operations)
- **Theme**: `lib/core/theme.dart`, `lib/core/fluent_theme.dart`
- **Security**: `firestore.rules` (role-based access control)

## Additional Context
Multiple markdown docs in root capture feature evolution (`SESSION_PERSISTENCE_FIX.md`, `SCHEDULED_SESSIONS_INTEGRATION.md`, etc.) - reference for understanding "why" behind architectural decisions.
