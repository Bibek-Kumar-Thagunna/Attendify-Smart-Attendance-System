# Scheduled Sessions Integration - Complete Guide

## ✅ Features Implemented

### 1. Scheduled Sessions in Upcoming Sessions Card
- Scheduled sessions now appear alongside active sessions
- Combined view shows both types in chronological order
- Real-time updates via StreamProvider

### 2. One-Click Session Start
- "Start Now" button appears when scheduled time is within 30 minutes
- Automatically captures GPS location
- Uses scheduled parameters (subject, duration, radius)
- Deletes scheduled session after starting

### 3. Conflict Prevention
- Prevents starting sessions during scheduled times
- Shows clear error message with conflicting session details
- Validates overlapping time windows
- Ensures only one session active at a time

## How It Works

### Upcoming Sessions Display

The "Upcoming Sessions" card now shows:

```
┌─────────────────────────────────────┐
│  📅 Upcoming Sessions               │
├─────────────────────────────────────┤
│                                     │
│  🔵 Math 101 (Active)              │
│  Nov 11 • 4:07 PM                  │
│  "15m left" | Active                │
│                                     │
│  🟡 Physics Lab (Scheduled)        │
│  Nov 11 • 5:00 PM                  │
│  "In 45m" | Scheduled               │
│  [ ▶ Start Now ]  ← appears when   │
│                      within 30min   │
│                                     │
│  🟢 Chemistry (Scheduled)          │
│  Nov 12 • 10:00 AM                 │
│  "In 18h" | Scheduled               │
│                                     │
└─────────────────────────────────────┘
```

### Session Types

#### Active Session (🔵)
- Currently running
- Students can scan QR
- Shows time remaining
- Blue/colored badge

#### Scheduled Session (🟡)
- Planned for future
- Countdown to start time
- Orange "Scheduled" badge
- "Start Now" button when within 30min

### Starting a Scheduled Session

**Automatic Process:**
1. Teacher sees "Start Now" button (within 30 min of scheduled time)
2. Clicks button
3. System requests GPS permission
4. Captures current location
5. Creates active session with:
   - Scheduled subject
   - Scheduled duration
   - Scheduled radius
   - **Real-time GPS coordinates**
6. Deletes scheduled session entry
7. Redirects to Generate QR page
8. QR code ready for students

**Example:**
```
Scheduled: Math 101 at 2:00 PM, 60 min, 50m radius

At 1:50 PM:
✅ "Start Now" button appears
✅ Teacher clicks
✅ GPS: 40.7128° N, 74.0060° W (captured)
✅ Session starts with location verification
✅ Students can now scan within 50m radius
```

### Conflict Prevention

**Scenario 1: Starting Manual Session During Scheduled Time**
```
Teacher has:
- Scheduled: Math 101 at 2:00 PM (60 min)

At 1:45 PM, tries to start random session via Generate QR:
❌ ERROR: "Conflict with scheduled session 'Math 101' at 14:00. 
          Please start that session or delete it first."
```

**Scenario 2: Multiple Scheduled Sessions**
```
Teacher has:
- Scheduled: Math 101 at 2:00 PM (60 min)
- Scheduled: Physics at 4:00 PM (90 min)

At 1:50 PM, starts Math 101:
✅ SUCCESS - no overlap

At 2:30 PM, tries to start another session:
❌ ERROR: Math 101 still active

At 3:00 PM (Math ended), tries to start random session:
❌ ERROR: "Conflict with scheduled session 'Physics' at 16:00"

At 3:50 PM, starts Physics via "Start Now":
✅ SUCCESS - legitimate scheduled session start
```

## Technical Implementation

### Updated Provider

```dart
final upcomingSessionsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  // Combines:
  // 1. Active sessions from 'sessions' collection
  // 2. Scheduled sessions from 'scheduled_sessions' collection
  
  // Filters:
  // - Active: only unexpired sessions
  // - Scheduled: future or within last 30 min
  
  // Sorts by time (earliest first)
  // Returns top 5
});
```

### Session Structure

**Scheduled Session:**
```javascript
scheduled_sessions/{id} {
  teacherUid: "abc123",
  subject: "Math 101",
  scheduledFor: Timestamp("2025-11-11 14:00"),
  duration: 60,          // minutes
  radiusMeters: 50,
  createdAt: Timestamp,
  type: "scheduled"      // added in provider
}
```

**Active Session:**
```javascript
sessions/{id} {
  teacherUid: "abc123",
  subject: "Math 101",
  latitude: 40.7128,     // GPS captured
  longitude: -74.0060,   // GPS captured
  radiusMeters: 50,
  active: true,
  createdAt: Timestamp,
  expiresAt: Timestamp,
  type: "active"         // added in provider
}
```

### Conflict Detection Algorithm

```dart
Future<void> startSession({
  required double latitude,
  required double longitude,
  required Duration duration,
  required double radiusMeters,
  String? subject,
  String? scheduledSessionId,  // null = manual start
}) async {
  // 1. Check for active session
  if (hasActiveSession) {
    throw Exception('End current session first');
  }
  
  // 2. Check for scheduled conflicts (only if manual start)
  if (scheduledSessionId == null) {
    final now = DateTime.now();
    final endTime = now.add(duration);
    
    for (scheduled in scheduledSessions) {
      final scheduledStart = scheduled.scheduledFor;
      final scheduledEnd = scheduledStart.add(scheduled.duration);
      
      // Check overlap
      if (hasOverlap(now, endTime, scheduledStart, scheduledEnd)) {
        throw Exception('Conflict with scheduled session');
      }
    }
  }
  
  // 3. Create session
  await createSession(...);
}
```

### Overlap Detection

```
Timeline:
|-------- Proposed Session --------|
    ^now                    ^endTime

Case 1: Overlap (ERROR)
   |---- Scheduled ----|
   
Case 2: Overlap (ERROR)
       |---- Scheduled ----|
       
Case 3: No Overlap (OK)
                            |---- Scheduled ----|
                            
Case 4: No Overlap (OK)
|---- Scheduled ----|
```

## User Experience

### Teacher Dashboard

**Morning (8:00 AM):**
```
Upcoming Sessions:
🟡 Math 101 - In 2h (10:00 AM) | Scheduled
🟡 Physics - In 6h (2:00 PM) | Scheduled
```

**Before Class (9:50 AM):**
```
Upcoming Sessions:
🟡 Math 101 - In 10m (10:00 AM) | Scheduled
   [ ▶ Start Now ]  ← Button appears!
🟡 Physics - In 4h (2:00 PM) | Scheduled
```

**During Class (10:15 AM):**
```
Upcoming Sessions:
🔵 Math 101 - 45m left | Active  ← Now active!
🟡 Physics - In 3h 45m (2:00 PM) | Scheduled
```

**After Class (11:00 AM):**
```
Upcoming Sessions:
🟡 Physics - In 3h (2:00 PM) | Scheduled
(Math 101 ended and removed from list)
```

### Student Experience

**Before Scheduled Time:**
- No QR code available
- Cannot mark attendance
- Waits for teacher to start

**Teacher Starts Session:**
- QR code generated with GPS
- Students can scan
- Attendance verified by location

**During Active Session:**
- QR code changes every 5 seconds
- Students within radius can attend
- Real-time validation

## Key Benefits

### 1. Unified View
- See all sessions (active + scheduled) in one place
- Clear visual distinction
- Chronological ordering

### 2. Seamless Start
- One button to start scheduled sessions
- Auto-fills all parameters
- GPS captured automatically
- No manual entry needed

### 3. Conflict Prevention
- Cannot start competing sessions
- Clear error messages
- Forces teacher to follow schedule
- Prevents accidental double-booking

### 4. Accurate Location
- GPS always captured at session start
- Never uses old/scheduled location
- Students verified against real coordinates
- Geofence always accurate

## Edge Cases Handled

### 1. Late Teacher
```
Scheduled: 2:00 PM
Teacher arrives: 2:15 PM

✅ "Start Now" still available (within 30 min)
✅ Can start late session
✅ GPS captures actual location
```

### 2. Early Start
```
Scheduled: 2:00 PM
Teacher ready: 1:55 PM

❌ "Start Now" not available yet
⏰ Must wait until 1:30 PM (30 min before)
```

### 3. Forgotten Schedule
```
Scheduled: 2:00 PM
Teacher at 2:30 PM: "I forgot!"

✅ "Start Now" no longer available
⚠️ Shows "Overdue" status
🗑️ Can delete and start new session
```

### 4. Schedule Change
```
Scheduled: 2:00 PM
Teacher: "Need to start at 3:00 PM instead"

Option 1: Delete scheduled, create new
Option 2: Wait until 2:30 PM, delete, manual start
```

## Files Modified

### 1. `lib/features/shared/widgets/upcoming_sessions_card.dart`
**Changes:**
- Updated `upcomingSessionsProvider` to combine active + scheduled
- Added `_startScheduledSession()` method
- Updated UI to show both session types
- Added "Start Now" button for scheduled sessions
- Enhanced time display logic

### 2. `lib/features/teacher/providers.dart`
**Changes:**
- Added `scheduledSessionId` parameter to `startSession()`
- Implemented conflict detection
- Added `_formatTime()` helper
- Validates against scheduled sessions

### 3. No Firestore Index Required
- Uses in-memory sorting
- Works immediately
- No deployment needed

## Testing Checklist

### ✅ Display Tests
- [ ] Scheduled sessions appear in upcoming sessions
- [ ] Active sessions appear in upcoming sessions
- [ ] Sessions sorted by time (earliest first)
- [ ] Max 5 sessions shown
- [ ] Correct icons (schedule vs active)
- [ ] Correct badges (Scheduled vs Active)

### ✅ Start Button Tests
- [ ] "Start Now" appears within 30 min of scheduled time
- [ ] "Start Now" disappears if too early
- [ ] "Start Now" disappears if too late (>30 min past)
- [ ] Button captures GPS when clicked
- [ ] Session starts successfully
- [ ] Scheduled session deleted after start
- [ ] Redirects to Generate QR page

### ✅ Conflict Tests
- [ ] Cannot start manual session during scheduled time
- [ ] Error message shows conflicting session details
- [ ] Can start scheduled session itself
- [ ] Can start manual session after scheduled one ends
- [ ] Cannot have two active sessions

### ✅ Edge Cases
- [ ] GPS permission denied handled gracefully
- [ ] Location services disabled shown as error
- [ ] Late start (within 30 min) works
- [ ] Very late start (>30 min) doesn't show button
- [ ] Deleted scheduled session removed from list

## Summary

This implementation provides:

✅ **Unified Dashboard** - All sessions in one view  
✅ **Smart Starting** - One-click with GPS capture  
✅ **Conflict Prevention** - No scheduling conflicts  
✅ **Location Accuracy** - Always real-time GPS  
✅ **Better UX** - Clear visual feedback  
✅ **Time Windows** - 30-minute start window  
✅ **Auto-Cleanup** - Scheduled sessions auto-delete  
✅ **Error Handling** - Clear, actionable messages  

**Result:** Teachers can plan ahead while ensuring accurate, conflict-free attendance tracking with real-time location verification.

