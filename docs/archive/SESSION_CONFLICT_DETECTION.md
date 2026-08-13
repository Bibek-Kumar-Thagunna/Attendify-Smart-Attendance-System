# Session Conflict Detection - Prevent Overlapping Sessions

## ✅ Feature Implemented

**User Request:**
> "When there is already a session started in that time slot, no any session should be scheduled. It should hint when user tries to schedule the session in active session time slot."

**Solution:** Added comprehensive conflict detection to prevent overlapping sessions.

---

## 🎯 Problem Statement

### The Issue:
Teachers could schedule sessions that overlapped with:
1. **Active sessions** - Currently running sessions
2. **Other scheduled sessions** - Previously scheduled future sessions

### Example Conflict:
```
Active Session: 5:21 PM - 5:35 PM (Math class)
User tries to schedule: 5:25 PM - 6:25 PM (SE class)
                        ↑
                   OVERLAP! ❌
```

**Result:** Two sessions would overlap from 5:25 PM to 5:35 PM, causing confusion.

---

## 🔍 Solution: Two-Layer Conflict Detection

### Layer 1: Active Session Detection
**Checks when:** User tries to schedule a new session  
**Looks for:** Any currently running active sessions  
**Action:** Blocks scheduling if there's any time overlap

### Layer 2: Scheduled Session Detection
**Checks when:** User tries to schedule a new session  
**Looks for:** Any previously scheduled sessions  
**Action:** Blocks scheduling if there's any time overlap

---

## 📊 How It Works

### Conflict Detection Algorithm:

```
User Submits Schedule Form
        ↓
Calculate Time Range
  scheduledFor → scheduledEnd
        ↓
┌─────────────────────────────┐
│ CHECK 1: Active Sessions    │
├─────────────────────────────┤
│ Query: active = true        │
│ For each active session:    │
│   Get expiresAt             │
│   Check overlap             │
│   If overlap → BLOCK ⚠️     │
└─────────────────────────────┘
        ↓
┌─────────────────────────────┐
│ CHECK 2: Scheduled Sessions │
├─────────────────────────────┤
│ Query: all scheduled        │
│ For each scheduled:         │
│   Get scheduledFor + end    │
│   Check overlap             │
│   If overlap → BLOCK ⚠️     │
└─────────────────────────────┘
        ↓
    NO CONFLICTS?
        ↓
   CREATE SESSION ✅
```

### Overlap Detection Logic:

Two time ranges overlap if:
```dart
(scheduledStart < otherEnd) && (scheduledEnd > otherStart)
```

**Visual Example:**

```
No Overlap (OK):
Session A: |-------|
Session B:           |-------|
           ✅ No intersection

Overlap (CONFLICT):
Session A: |-----------|
Session B:      |-----------|
           ❌ They intersect!

Overlap (CONFLICT):
Session A: |-----------|
Session B:   |-----|
           ❌ B is inside A

Overlap (CONFLICT):
Session A:   |-----|
Session B: |-----------|
           ❌ A is inside B
```

---

## 💻 Implementation Details

### File Modified: `lib/features/teacher/presentation/teacher_schedule_page.dart`

#### Before (No Conflict Detection):
```dart
Future<void> _scheduleSession() async {
  // Basic validation
  if (_subjectController.text.trim().isEmpty) {
    // Show error
    return;
  }
  
  // Create scheduled session immediately
  await FirebaseFirestore.instance
      .collection('scheduled_sessions')
      .add({ ... });
}
```

#### After (With Conflict Detection):
```dart
Future<void> _scheduleSession() async {
  // Basic validation
  if (_subjectController.text.trim().isEmpty) {
    return;
  }
  
  final scheduledFor = /* calculate start time */;
  final scheduledEnd = /* calculate end time */;
  
  // ✅ CHECK 1: Active Sessions
  final activeSessions = await FirebaseFirestore.instance
      .collection('sessions')
      .where('teacherUid', isEqualTo: auth.uid)
      .where('active', isEqualTo: true)
      .get();
  
  for (final doc in activeSessions.docs) {
    final expiresAt = /* parse timestamp */;
    final now = DateTime.now();
    
    // Check overlap: active session is (now → expiresAt)
    if (scheduledFor.isBefore(expiresAt) && 
        scheduledEnd.isAfter(now)) {
      // CONFLICT!
      _showConflictWarning(/* details */);
      return;
    }
  }
  
  // ✅ CHECK 2: Scheduled Sessions
  final scheduledSessions = await FirebaseFirestore.instance
      .collection('scheduled_sessions')
      .where('teacherUid', isEqualTo: auth.uid)
      .get();
  
  for (final doc in scheduledSessions.docs) {
    final otherStart = /* parse timestamp */;
    final otherEnd = /* calculate end */;
    
    // Check overlap
    if (scheduledFor.isBefore(otherEnd) && 
        scheduledEnd.isAfter(otherStart)) {
      // CONFLICT!
      _showConflictWarning(/* details */);
      return;
    }
  }
  
  // ✅ NO CONFLICTS - Create session
  await FirebaseFirestore.instance
      .collection('scheduled_sessions')
      .add({ ... });
}
```

---

## ⚠️ Warning Messages

### Active Session Conflict:
```
⚠️ Conflict: You have an active session "Mathematics" 
running until 5:35 PM. Please end it first or 
schedule after 5:35 PM.
```

**Color:** Orange (`#F59E0B`)  
**Duration:** 5 seconds  
**Action Required:** Teacher must either:
1. End the active session first, OR
2. Schedule after the active session ends

### Scheduled Session Conflict:
```
⚠️ Conflict: You already have a scheduled session 
"Physics Lab" at 2:00 PM. Please choose a 
different time.
```

**Color:** Orange (`#F59E0B`)  
**Duration:** 5 seconds  
**Action Required:** Teacher must:
1. Choose a different time, OR
2. Delete the conflicting scheduled session

---

## 🎨 UI/UX Design

### Warning Appearance:

```
┌─────────────────────────────────────────┐
│  ⚠️  Conflict: You have an active      │
│      session "Math" running until       │
│      5:35 PM. Please end it first...    │
└─────────────────────────────────────────┘
         Orange Background
        5-second display
```

### Why Orange (Not Red)?
- **Red** = Error (something broke)
- **Orange** = Warning (preventable conflict)
- **Green** = Success

Since this is a **preventable user action** (not a system error), orange is more appropriate.

---

## 🧪 Test Scenarios

### Scenario 1: Active Session Conflict

**Setup:**
1. Start a session: Now - 5:35 PM (10 min duration)
2. Go to "Schedule Session"
3. Try to schedule: 5:25 PM - 6:25 PM (60 min duration)

**Expected Result:**
- ⚠️ Orange warning appears
- Message: "You have an active session... running until 5:35 PM"
- Session is NOT created
- User remains on schedule form

**Actual Overlap:**
```
Active:    [5:21 PM ────────── 5:35 PM]
Scheduled:            [5:25 PM ────────── 6:25 PM]
Overlap:              [5:25 PM ─ 5:35 PM]  ❌
```

### Scenario 2: Scheduled Session Conflict

**Setup:**
1. Schedule session A: 2:00 PM - 3:00 PM
2. Try to schedule session B: 2:30 PM - 3:30 PM

**Expected Result:**
- ⚠️ Orange warning appears
- Message: "You already have a scheduled session... at 2:00 PM"
- Session B is NOT created

**Actual Overlap:**
```
Session A: [2:00 PM ─── 3:00 PM]
Session B:        [2:30 PM ─── 3:30 PM]
Overlap:          [2:30 PM ─ 3:00 PM]  ❌
```

### Scenario 3: No Conflict (Back-to-Back)

**Setup:**
1. Have session: 2:00 PM - 3:00 PM
2. Schedule: 3:00 PM - 4:00 PM (starts exactly when first ends)

**Expected Result:**
- ✅ No warning
- Session created successfully
- Both sessions can coexist

**No Overlap:**
```
Session A: [2:00 PM ─── 3:00 PM]
Session B:                [3:00 PM ─── 4:00 PM]
No overlap!  ✅
```

### Scenario 4: No Conflict (Gap Between)

**Setup:**
1. Have session: 2:00 PM - 3:00 PM
2. Schedule: 4:00 PM - 5:00 PM (1 hour gap)

**Expected Result:**
- ✅ No warning
- Session created successfully

**No Overlap:**
```
Session A: [2:00 PM ─── 3:00 PM]
                             [GAP]
Session B:                           [4:00 PM ─── 5:00 PM]
No overlap!  ✅
```

---

## 🔄 Integration with Existing Features

### Works With:

#### 1. Start Session (Manual)
Already has conflict detection for scheduled sessions:
```dart
// In providers.dart - startSession()
if (scheduledSessionId == null) {
  // Check for conflicting scheduled sessions
  // Throws exception if conflict found
}
```

#### 2. Auto-Start Scheduled Sessions
The auto-start feature checks for active sessions before starting:
```dart
// In auto_start_scheduled_sessions.dart
final activeSession = ref.read(activeSessionProvider);
if (activeSession != null) return; // Don't auto-start if active
```

#### 3. Upcoming Sessions Display
Shows both active and scheduled sessions with proper badges:
- Active: Green "Active" badge
- Scheduled: Orange "Scheduled" badge

---

## 📊 Complete Conflict Matrix

| Action | Checks Against | Conflict Type | Result |
|--------|----------------|---------------|--------|
| Schedule Session | Active Sessions | Time Overlap | ⚠️ Block with warning |
| Schedule Session | Scheduled Sessions | Time Overlap | ⚠️ Block with warning |
| Start Session (Manual) | Active Sessions | Existence | ❌ Block with error |
| Start Session (Manual) | Scheduled Sessions | Time Overlap | ❌ Block with error |
| Auto-Start Scheduled | Active Sessions | Existence | ⏸️ Skip auto-start |

---

## 💡 Edge Cases Handled

### Edge Case 1: Same Start/End Time
```
Session A: 2:00 PM - 3:00 PM
Session B: 2:00 PM - 3:00 PM
Result: CONFLICT ❌ (identical times)
```

### Edge Case 2: One Session Inside Another
```
Session A: 2:00 PM - 5:00 PM (long)
Session B: 3:00 PM - 4:00 PM (short, inside A)
Result: CONFLICT ❌ (B completely inside A)
```

### Edge Case 3: Partial Overlap (Start)
```
Session A: 2:00 PM - 3:00 PM
Session B: 1:00 PM - 2:30 PM
Result: CONFLICT ❌ (overlaps at start)
```

### Edge Case 4: Partial Overlap (End)
```
Session A: 2:00 PM - 3:00 PM
Session B: 2:30 PM - 4:00 PM
Result: CONFLICT ❌ (overlaps at end)
```

### Edge Case 5: Active Session Expiring Soon
```
Active: Now (5:30 PM) - 5:32 PM (2 min left)
Schedule: 5:31 PM - 6:31 PM
Result: CONFLICT ❌ (1 min overlap)
Reason: Active session might auto-extend or be manually extended
```

---

## 🎓 Technical Learnings

### 1. Time Range Overlap Detection

**Formula:**
```dart
bool overlaps(
  DateTime start1, DateTime end1,
  DateTime start2, DateTime end2
) {
  return (start1.isBefore(end2)) && (end1.isAfter(start2));
}
```

**Why This Works:**
- Two ranges DON'T overlap if:
  - One ends before the other starts
  - i.e., `end1 <= start2` OR `end2 <= start1`
- Therefore, they DO overlap if:
  - NOT (one ends before other starts)
  - i.e., `start1 < end2` AND `end1 > start2`

### 2. Firestore Query Optimization

**Approach:**
- Fetch all relevant sessions once
- Check conflicts in memory (client-side)

**Why Not Server-Side:**
- Complex range queries are hard in Firestore
- Would require composite indexes for each range
- Client-side is simpler and more flexible

### 3. User Feedback Design

**Key Principles:**
- **Specific:** Name the conflicting session
- **Actionable:** Tell user what to do ("end it first", "choose different time")
- **Time-bound:** Show exact conflict time (5:35 PM)
- **Appropriate Color:** Orange for preventable warnings, not red errors

---

## 📚 Related Files

- `lib/features/teacher/presentation/teacher_schedule_page.dart` - Schedule form with conflict detection
- `lib/features/teacher/providers.dart` - Start session with conflict detection
- `lib/features/teacher/presentation/auto_start_scheduled_sessions.dart` - Auto-start logic
- `lib/features/shared/widgets/upcoming_sessions_card.dart` - Display all sessions

---

## ✅ Summary

### Problem:
Teachers could schedule sessions that overlapped with active or scheduled sessions, causing confusion.

### Solution:
Added two-layer conflict detection:
1. Check active sessions
2. Check scheduled sessions

### Features:
- ✅ Prevents overlapping sessions
- ✅ Clear warning messages
- ✅ Shows conflict details (session name, time)
- ✅ Actionable guidance
- ✅ Professional orange warning UI
- ✅ 5-second display duration

### Result:
- **No more overlapping sessions**
- **Clear user feedback**
- **Professional UX**
- **Prevents scheduling conflicts**

### Status:
🚀 **Complete and Ready for Testing**

---

**Hot reload and try to schedule during your active session (5:35 PM) - you'll see the warning!** 🎉

