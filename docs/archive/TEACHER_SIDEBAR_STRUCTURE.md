# Teacher Sidebar Structure

## New Organization

```
┌─────────────────────────────┐
│   ATTENDIFY                 │
├─────────────────────────────┤
│                             │
│   📊 MAIN                   │
│   • Dashboard               │
│   • Generate QR             │
│   • Schedule Session  🆕    │
│                             │
│   ─────────────────────     │
│                             │
│   📁 MANAGE                 │
│   • Subjects          🆕    │
│   • Students                │
│   • Attendance              │
│                             │
│   ─────────────────────     │
│                             │
│   📈 REPORTS                │
│   • Export Data             │
│                             │
│   ─────────────────────     │
│                             │
│   👤 ACCOUNT                │
│   • Profile                 │
│                             │
├─────────────────────────────┤
│   [Logout]                  │
└─────────────────────────────┘
```

## Key Changes

### 1. Schedule Session (NEW)
**Location:** Main Section
**Path:** `/teacher/schedule`
**Icon:** `event_available_rounded`

**Features:**
- Plan future attendance sessions
- Set date, time, duration
- Define location and radius
- View upcoming scheduled sessions

### 2. Subjects (ADDED to Sidebar)
**Location:** Manage Section (first item)
**Path:** `/teacher/subjects`
**Icon:** `book_outlined`

**Note:** Previously only accessible via dashboard quick action, now also in sidebar for easy access.

## Page Comparison

### Schedule Session Page

```
┌──────────────────────────────────────────────────────────────┐
│  📅 Schedule Session                                         │
│  Plan your attendance sessions in advance                    │
└──────────────────────────────────────────────────────────────┘

┌─────────────────────────────┐  ┌─────────────────────────────┐
│  Session Details            │  │  Scheduled Sessions         │
│                             │  │                             │
│  Subject: [___________]     │  │  ◉ Mathematics 101          │
│  Location: [__________]     │  │     📅 Nov 15, 2:00 PM      │
│  Date: [___] Time: [___]    │  │     📍 Room 204             │
│  Duration: [__] Radius: [_] │  │     [Delete]                │
│                             │  │                             │
│  [Schedule Session]         │  │  ◉ Physics Lab              │
│                             │  │     📅 Nov 16, 10:00 AM     │
│                             │  │     📍 Lab 3B               │
│                             │  │     [Delete]                │
└─────────────────────────────┘  └─────────────────────────────┘
```

## Dashboard Quick Actions (Unchanged)

The dashboard still shows quick action cards for:
- ✅ Students
- ✅ Subjects
- ✅ Attendance
- ✅ Reports

**Note:** Subjects are now accessible from BOTH dashboard and sidebar.

## Navigation Flow

### Before:
```
Dashboard → Generate QR → Start Session Immediately
```

### After:
```
Option 1: Dashboard → Generate QR → Start Session Immediately
Option 2: Dashboard → Schedule Session → Plan for Future
```

## User Benefits

1. **Better Organization:** Clear separation of Main, Manage, Reports, and Account sections
2. **Quick Access:** Subjects now in sidebar for faster navigation
3. **Planning Ahead:** Schedule sessions days or weeks in advance
4. **Flexibility:** Choose between immediate QR generation or scheduled sessions
5. **Professional:** Modern, organized interface matching Fluent Design standards

## Database Structure

### New Collection: `scheduled_sessions`

```javascript
{
  teacherUid: "abc123",
  subject: "Mathematics 101",
  location: "Room 204",
  scheduledFor: Timestamp(2025-11-15 14:00:00),
  duration: 60,        // minutes
  radiusMeters: 50,    // meters
  createdAt: Timestamp
}
```

### Required Index

```json
{
  "collectionId": "scheduled_sessions",
  "fields": [
    {"fieldPath": "teacherUid", "order": "ASCENDING"},
    {"fieldPath": "scheduledFor", "order": "ASCENDING"}
  ]
}
```

## Deployment Steps

1. **Deploy Firestore Indexes:**
   ```bash
   cd /home/sybar/Attendify
   firebase deploy --only firestore:indexes
   ```

2. **Test the App:**
   - Navigate to Schedule Session
   - Create a test scheduled session
   - Verify it appears in the list
   - Test delete functionality

3. **Verify Subjects Access:**
   - Click Subjects in sidebar
   - Verify page loads correctly
   - Check that it matches the dashboard quick action

## Next Enhancement Ideas

- 📅 Calendar view for scheduled sessions
- 🔔 Push notifications before session starts
- 🔄 Recurring session templates
- 📋 Bulk import from CSV
- 🎨 Color coding by subject
- 📊 Analytics on scheduled vs. actual sessions

