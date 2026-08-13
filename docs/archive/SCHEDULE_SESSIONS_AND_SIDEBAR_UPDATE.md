# Schedule Sessions and Sidebar Update Summary

## Overview
Updated the teacher interface to include scheduled sessions functionality and improved the sidebar navigation with better organization.

## Key Changes

### 1. Sidebar Navigation Enhancement (`teacher_shell.dart`)

**Updated Sections:**
- **Main Section:**
  - Dashboard
  - Generate QR (instant session)
  - **Schedule Session** (NEW - plan future sessions)

- **Manage Section:**
  - **Subjects** (NEW - moved from quick actions only)
  - Students
  - Attendance

- **Reports Section:**
  - Export Data

- **Account Section:**
  - Profile

**Why This Matters:**
- Subjects are now easily accessible from both dashboard quick actions and sidebar
- Schedule Session provides a dedicated interface for planning sessions in advance
- Better organization with clear sections (Main, Manage, Reports, Account)

### 2. Schedule Session Page (`teacher_schedule_page.dart`)

**Features:**
- **Schedule Future Sessions:**
  - Subject/Class Name
  - Location/Room
  - Date Picker
  - Time Picker
  - Duration (minutes)
  - Geolocation Radius (meters)

- **View Scheduled Sessions:**
  - List of upcoming and past sessions
  - Visual indicators for upcoming sessions
  - Date, time, and location display
  - Delete functionality

**Data Structure:**
```dart
scheduled_sessions {
  teacherUid: string
  subject: string
  location: string?
  scheduledFor: Timestamp
  duration: number
  radiusMeters: number
  createdAt: Timestamp
}
```

**UI Features:**
- Fluent Design acrylic cards
- Smooth animations with FadeInDown/FadeInUp
- Responsive form layout
- Empty state when no sessions scheduled
- Color-coded upcoming vs. past sessions

### 3. Firestore Index (`firestore.indexes.json`)

**Added Index:**
```json
{
  "collectionId": "scheduled_sessions",
  "fields": [
    {
      "fieldPath": "teacherUid",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "scheduledFor",
      "order": "ASCENDING"
    }
  ]
}
```

**Purpose:**
Optimizes queries for fetching a teacher's scheduled sessions ordered by date.

### 4. Provider Implementation

**New Provider:**
```dart
final scheduledSessionsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final auth = ref.watch(authControllerProvider);
  final teacherUid = auth.uid;
  
  if (teacherUid == null) return const Stream.empty();
  
  return FirebaseFirestore.instance
      .collection('scheduled_sessions')
      .where('teacherUid', isEqualTo: teacherUid)
      .orderBy('scheduledFor', descending: false)
      .snapshots()
      .map((snap) {
    return snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  });
});
```

## User Experience Improvements

### Before:
- No way to plan sessions in advance
- Subjects only accessible via dashboard quick action
- Teachers had to manually start sessions at class time

### After:
- Teachers can schedule sessions days or weeks in advance
- Subjects accessible from both dashboard and sidebar
- Clear overview of upcoming sessions
- Better sidebar organization with logical sections
- Consistent Fluent Design UI across all pages

## How to Use

### Scheduling a Session:
1. Click "Schedule Session" in the sidebar
2. Fill in session details:
   - Subject name (required)
   - Location (optional)
   - Date (date picker)
   - Time (time picker)
   - Duration in minutes (default: 60)
   - Geolocation radius (default: 50m)
3. Click "Schedule Session"
4. Session appears in the scheduled sessions list

### Managing Scheduled Sessions:
- View all upcoming sessions in the right panel
- Sessions are sorted by date (earliest first)
- Upcoming sessions have a visual indicator
- Delete sessions that are no longer needed

## Database Deployment

To deploy the new Firestore index:

```bash
cd /home/sybar/Attendify
firebase deploy --only firestore:indexes
```

Or use the deploy script:

```bash
./deploy-indexes.sh
```

## Next Steps (Future Enhancements)

1. **Automatic Session Activation:**
   - Cron job or Cloud Function to automatically activate sessions at scheduled time
   - Send notifications to students when sessions are about to start

2. **Recurring Sessions:**
   - Weekly/monthly recurring session templates
   - Bulk scheduling for entire semester

3. **Session Templates:**
   - Save common session configurations
   - Quick scheduling with pre-filled forms

4. **Calendar View:**
   - Month/week view of scheduled sessions
   - Drag-and-drop rescheduling

5. **Integration with Active Sessions:**
   - Quick start from scheduled session
   - Auto-populate QR generation from schedule

## Technical Notes

- Uses `StreamProvider` for real-time updates
- Form validation ensures required fields are filled
- Timestamps stored as Firestore `Timestamp` objects
- Properly handles timezone conversions
- Cleans up form after successful submission
- Error handling with user-friendly messages

## Files Modified

1. `/lib/features/teacher/presentation/teacher_shell.dart`
   - Added Schedule Session to sidebar
   - Added Subjects to Manage section
   - Added Reports section

2. `/lib/features/teacher/presentation/teacher_schedule_page.dart`
   - Completely rebuilt with comprehensive scheduling UI
   - Added form for session details
   - Added list view for scheduled sessions

3. `/firestore.indexes.json`
   - Added composite index for scheduled_sessions

## Summary

This update provides teachers with a professional scheduling system while improving the overall navigation structure. The Fluent Design UI ensures a modern, cohesive look across all pages, and the real-time updates mean teachers always see their current schedule.

