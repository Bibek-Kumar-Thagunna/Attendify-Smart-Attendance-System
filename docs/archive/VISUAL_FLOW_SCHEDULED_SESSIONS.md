# Visual Flow - Scheduled Sessions with Upcoming Sessions

## Complete User Journey

### Step 1: Schedule a Session (Monday Morning)

```
┌─────────────────────────────────────────────────┐
│  📅 Schedule Session                            │
│  Location will be captured when you start       │
└─────────────────────────────────────────────────┘

Teacher Plans:
  📚 Subject: Math 101
  📅 Date: Nov 11, 2025
  ⏰ Time: 2:00 PM
  ⏱️  Duration: 60 minutes
  📡 Radius: 50 meters
  
  [ Schedule Session ] ← Click

Result: Saved to scheduled_sessions collection
```

### Step 2: View in Dashboard (1:45 PM - 15 minutes before)

```
┌─────────────────────────────────────────────────┐
│  📊 TEACHER DASHBOARD                           │
├─────────────────────────────────────────────────┤
│                                                 │
│  📅 Upcoming Sessions                           │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │ 🟡 Math 101                  Scheduled │   │
│  │ Nov 11 • 2:00 PM                       │   │
│  │ In 15m                                 │   │
│  │                                        │   │
│  │ ❌ Start button NOT yet shown          │   │
│  │    (must be within 30 minutes)        │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘

⏰ Teacher must wait until 1:30 PM for button
```

### Step 3: Ready to Start (1:50 PM - 10 minutes before)

```
┌─────────────────────────────────────────────────┐
│  📊 TEACHER DASHBOARD                           │
├─────────────────────────────────────────────────┤
│                                                 │
│  📅 Upcoming Sessions                           │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │ 🟡 Math 101                  Scheduled │   │
│  │ Nov 11 • 2:00 PM                       │   │
│  │ In 10m                                 │   │
│  │                                        │   │
│  │ ┌───────────────────────────────────┐ │   │
│  │ │  ▶ Start Now                      │ │   │
│  │ └───────────────────────────────────┘ │   │
│  │      ↑ Button appears!                │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘

✅ Within 30-minute window (1:30 PM - 2:30 PM)
```

### Step 4: Teacher Clicks "Start Now"

```
┌─────────────────────────────────────────────────┐
│  🔄 STARTING SESSION...                         │
└─────────────────────────────────────────────────┘

Process:
  1. ✅ Request GPS permission
  2. ✅ Get current location: 40.7128° N, 74.0060° W
  3. ✅ Create active session with:
     - Subject: Math 101
     - Duration: 60 minutes
     - Radius: 50 meters
     - Location: GPS coordinates
  4. ✅ Delete scheduled session
  5. ✅ Redirect to Generate QR page

⏱️ Total time: ~2-3 seconds
```

### Step 5: Active Session with QR Code

```
┌─────────────────────────────────────────────────┐
│  📲 Generate Attendance QR                      │
│  Active Session - Math 101                      │
├─────────────────────────────────────────────────┤
│                                                 │
│            ┌─────────────┐                      │
│            │   QR CODE   │                      │
│            │  █▀▀▀█ ▄▄▀  │                      │
│            │  █   █ ▀ █  │                      │
│            │  █▄▄▄█ █▀█  │                      │
│            └─────────────┘                      │
│                                                 │
│  ⏱️  Time Remaining: 59:45                      │
│  📍 Location: Verified                          │
│  👥 0 students attended                         │
│                                                 │
│  [ End Session ]                                │
│                                                 │
└─────────────────────────────────────────────────┘

✅ Students can now scan!
```

### Step 6: Updated Dashboard (Active Session)

```
┌─────────────────────────────────────────────────┐
│  📊 TEACHER DASHBOARD                           │
├─────────────────────────────────────────────────┤
│                                                 │
│  📅 Upcoming Sessions                           │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │ 🔵 Math 101                     Active │   │
│  │ Nov 11 • 3:00 PM (expires)             │   │
│  │ 59m left                               │   │
│  │                                        │   │
│  │ ✅ Session running                     │   │
│  │ ✅ QR code available                   │   │
│  │ ✅ Students can attend                 │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │ 🟡 Physics Lab               Scheduled │   │
│  │ Nov 11 • 4:00 PM                       │   │
│  │ In 2h                                  │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
└─────────────────────────────────────────────────┘

Notes:
- Math 101 changed from Scheduled to Active
- Badge changed from 🟡 to 🔵
- Time shows "left" instead of "in"
- Start button removed (already active)
```

## Conflict Prevention Examples

### Example 1: Cannot Start Random Session During Scheduled Time

```
Situation:
  📅 Scheduled: Math 101 at 2:00 PM (60 min)
  ⏰ Current time: 1:55 PM
  
Teacher tries to start random session via Generate QR:

┌─────────────────────────────────────────────────┐
│  📲 Generate Attendance QR                      │
├─────────────────────────────────────────────────┤
│                                                 │
│  📚 Subject: [Random Class]                     │
│  ⏱️  Duration: [30] minutes                     │
│  📡 Radius: [50] meters                         │
│                                                 │
│  [ Start Session ] ← Click                      │
│                                                 │
└─────────────────────────────────────────────────┘

❌ ERROR MESSAGE:
┌─────────────────────────────────────────────────┐
│  ⚠️  Conflict Detected                          │
│                                                 │
│  Conflict with scheduled session "Math 101"    │
│  at 14:00.                                     │
│                                                 │
│  Please start that session or delete it first. │
│                                                 │
│  [ OK ]                                         │
└─────────────────────────────────────────────────┘

Options:
1. Go to dashboard and click "Start Now" for Math 101
2. Go to Schedule Session page and delete Math 101
3. Wait until 3:00 PM (after Math ends)
```

### Example 2: Can Start Scheduled Session Itself

```
Situation:
  📅 Scheduled: Math 101 at 2:00 PM (60 min)
  ⏰ Current time: 1:55 PM
  
Teacher clicks "Start Now" from Upcoming Sessions:

✅ SUCCESS!

Why? The system knows this IS the scheduled session,
so it bypasses conflict check.

Process:
  scheduledSessionId: "abc123" ← passed to startSession()
  System: "This is the scheduled session, allow it"
  Result: Session starts successfully
```

### Example 3: Overlapping Scheduled Sessions

```
Situation:
  📅 Scheduled: Math 101 at 2:00 PM (60 min)
  📅 Scheduled: Physics at 2:30 PM (60 min)  ← OVERLAP!
  
At 1:55 PM, teacher starts Math 101:

✅ Math 101 starts (2:00 PM - 3:00 PM)

At 2:25 PM, teacher tries to start Physics:

❌ ERROR: "You already have an active session"

Teacher must:
1. End Math 101 session first
2. Then start Physics
   
Or better: Don't schedule overlapping sessions!
```

## Timeline Visualization

```
Time:     1:00    1:30    2:00    2:30    3:00    3:30
          |       |       |       |       |       |

Scheduled Session Created (any time before)
───────────────────────────────────────────────────────

Start Window Opens (30 min before)
                    |───────────────────|

Start Button Shows
                    ◄─────────────────►

Scheduled Time
                            ▼

Start Window Closes (30 min after)
                    |───────────────────|

Session Duration (if started at 2:00)
                            |──────────►

Timeline Events:
├─ 1:00 PM: ❌ Too early to start
├─ 1:30 PM: ✅ Start button appears
├─ 1:55 PM: ✅ Can start
├─ 2:00 PM: ✅ Scheduled time (ideal)
├─ 2:15 PM: ✅ Can start (late but within window)
├─ 2:30 PM: ⚠️  Last chance to start
├─ 2:31 PM: ❌ Start button disappears
└─ 3:00 PM: 🏁 Session would end (if started at 2:00)
```

## Status Indicators

### Scheduled Session States

```
┌────────────────────────────────────────────────┐
│  STATE: FAR FUTURE                             │
│  Time until start: > 24 hours                  │
├────────────────────────────────────────────────┤
│  🟡 Chemistry Lab              Scheduled       │
│  Nov 15 • 10:00 AM                             │
│  In 4d                                         │
│                                                │
│  ❌ No start button                            │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│  STATE: COMING SOON                            │
│  Time until start: 30min - 24 hours            │
├────────────────────────────────────────────────┤
│  🟡 Physics Lab                Scheduled       │
│  Nov 11 • 4:00 PM                              │
│  In 2h                                         │
│                                                │
│  ❌ No start button yet                        │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│  STATE: READY TO START                         │
│  Time until start: 0-30 minutes                │
├────────────────────────────────────────────────┤
│  🟢 Math 101                   Scheduled       │
│  Nov 11 • 2:00 PM                              │
│  In 10m                                        │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  ▶ Start Now                             │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ✅ GPS ready to capture                       │
│  ✅ Click to start session                     │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│  STATE: LATE START (Still Available)           │
│  Time past scheduled: 0-30 minutes             │
├────────────────────────────────────────────────┤
│  🟠 Math 101                   Scheduled       │
│  Nov 11 • 2:00 PM                              │
│  Ready to start                                │
│                                                │
│  ┌──────────────────────────────────────────┐ │
│  │  ▶ Start Now                             │ │
│  └──────────────────────────────────────────┘ │
│                                                │
│  ⚠️  Late but can still start                  │
└────────────────────────────────────────────────┘

┌────────────────────────────────────────────────┐
│  STATE: OVERDUE (Cannot Start)                 │
│  Time past scheduled: > 30 minutes             │
├────────────────────────────────────────────────┤
│  🔴 Math 101                   Scheduled       │
│  Nov 11 • 2:00 PM                              │
│  Overdue                                       │
│                                                │
│  ❌ Too late to start                          │
│  💡 Delete and create new session             │
└────────────────────────────────────────────────┘
```

### Active Session State

```
┌────────────────────────────────────────────────┐
│  STATE: ACTIVE                                 │
│  Session running with QR code                  │
├────────────────────────────────────────────────┤
│  🔵 Math 101                     Active        │
│  Nov 11 • 3:00 PM (expires)                    │
│  45m left                                      │
│                                                │
│  ✅ QR code available                          │
│  ✅ Students can scan                          │
│  ✅ Location verified                          │
└────────────────────────────────────────────────┘
```

## Decision Flow for Teachers

```
                    START
                      │
                      ▼
        ┌─────────────────────────┐
        │  Need to take           │
        │  attendance?            │
        └─────────┬───────────────┘
                  │
         ┌────────┴────────┐
         │                 │
         ▼                 ▼
    [Planned]        [Impromptu]
         │                 │
         ▼                 ▼
    Schedule          Generate QR
    Session           (Direct)
         │                 │
         ▼                 │
    Dashboard             │
    View                  │
         │                 │
         ▼                 │
    Within 30min?         │
         │                 │
    Yes  │  No            │
         ▼                 │
    "Start Now"           │
    Button                │
         │                 │
         ▼◄────────────────┘
    Capture GPS
         │
         ▼
    Check Conflicts
         │
    No conflicts?
         │
         ▼
    Create Active
    Session
         │
         ▼
    Show QR Code
         │
         ▼
    Students Scan
         │
         ▼
    END
```

## Summary

### Key Points

1. **Schedule Anywhere** - Create sessions from anywhere, anytime
2. **See Everything** - All sessions (scheduled + active) in one view
3. **Start Window** - 30 minutes before to 30 minutes after scheduled time
4. **One-Click Start** - GPS captured automatically
5. **Conflict Prevention** - Can't start competing sessions
6. **Auto-Cleanup** - Scheduled sessions deleted after starting
7. **Clear Status** - Color-coded badges and time indicators

### Color Coding

- 🔵 **Blue** - Active session (currently running)
- 🟡 **Orange** - Scheduled session (waiting to start)
- 🟢 **Green** - Ready to start (within 30 min)
- 🔴 **Red** - Overdue (too late to start)

### Time Indicators

- **"In Xm/h/d"** - Scheduled session countdown
- **"Xm left"** - Active session remaining time
- **"Ready to start"** - Within start window
- **"Overdue"** - Past start window

### Workflow Benefits

✅ Plan ahead without being at location  
✅ See all sessions at a glance  
✅ Start sessions with one click  
✅ GPS always accurate (captured at start)  
✅ No scheduling conflicts  
✅ Clear visual feedback  
✅ Students get reliable location verification  

