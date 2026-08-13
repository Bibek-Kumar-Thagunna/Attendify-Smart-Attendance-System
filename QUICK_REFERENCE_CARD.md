# Quick Reference Card - Scheduled Sessions

## ⚡ At a Glance

### What's New?
✅ Scheduled sessions appear in "Upcoming Sessions" card  
✅ One-click "Start Now" button (±30 min window)  
✅ GPS captured automatically when starting  
✅ Conflict prevention for overlapping sessions  

---

## 🎯 Key Rules

| Rule | Description |
|------|-------------|
| **Start Window** | 30 min before → 30 min after scheduled time |
| **GPS Capture** | Always at session start, never during scheduling |
| **Max Active** | Only 1 active session at a time |
| **Conflicts** | Cannot start manual session during scheduled time |
| **Auto-Delete** | Scheduled session deleted after starting |

---

## 📱 User Interface

### Session Badges

| Badge | Meaning |
|-------|---------|
| 🔵 **Active** | Session running, QR available |
| 🟡 **Scheduled** | Waiting to start |
| 🟢 **Ready** | Within 30-min window, can start |
| 🔴 **Overdue** | Too late to start |

### Time Display

| Format | Meaning | Example |
|--------|---------|---------|
| "In Xm" | Until scheduled time | "In 15m" |
| "Xm left" | Active session remaining | "45m left" |
| "Ready to start" | Within start window | "Ready to start" |
| "Overdue" | Past start window | "Overdue" |

---

## 🚀 Quick Actions

### Schedule a Session
```
Sidebar → Schedule Session
→ Fill form (no location!)
→ Schedule Session button
```

### Start Scheduled Session
```
Dashboard → Upcoming Sessions
→ Find your session
→ Click "Start Now" (if within 30 min)
→ Allow GPS → Done!
```

### Start Manual Session
```
Sidebar → Generate QR
→ Fill form
→ Start Session
(Checks for conflicts automatically)
```

---

## ⏰ Timeline

```
Scheduled for 2:00 PM

1:29 PM  ❌  Too early
1:30 PM  ✅  Button appears
2:00 PM  ✅  Ideal time
2:30 PM  ✅  Last chance
2:31 PM  ❌  Too late
```

---

## ❌ Common Errors

### "Conflict with scheduled session"
**Cause:** Trying to start manual session during scheduled time  
**Fix:** Start the scheduled session or delete it

### "You already have an active session"
**Cause:** Only one session allowed at a time  
**Fix:** End current session first

### "Location permission denied"
**Cause:** GPS permission not granted  
**Fix:** Allow location access in settings

---

## 📊 Session Flow

```
Schedule → Wait → Start → QR → Attend → End
   ↓        ↓      ↓      ↓      ↓       ↓
Created  Pending Active Students Teacher Completed
```

---

## 🎨 Color Guide

| Color | Use Case |
|-------|----------|
| 🔵 Blue | Active sessions |
| 🟡 Orange | Scheduled (waiting) |
| 🟢 Green | Ready to start |
| 🔴 Red | Errors/Overdue |

---

## 💡 Pro Tips

✅ **Plan Ahead** - Schedule entire week on Sunday  
✅ **Start Early** - Use full 30-min window  
✅ **Check Dashboard** - Monitor all sessions  
✅ **Delete Cancelled** - Remove unused schedules  
✅ **Trust GPS** - Location always accurate  

---

## 📞 Troubleshooting

| Issue | Solution |
|-------|----------|
| Button doesn't appear | Wait until 30 min before |
| GPS not working | Check location settings |
| Can't start session | Check for conflicts |
| Session won't end | Click "End Session" button |
| Schedule disappeared | It started or was deleted |

---

## 🔧 Technical

**Collections:**
- `scheduled_sessions` - Future sessions
- `sessions` - Active sessions

**Start Window:** ±30 minutes  
**QR Refresh:** Every 5 seconds  
**Max Visible:** 5 sessions  
**Sort Order:** Chronological  

---

## ✅ Checklist

Before Starting Session:
- [ ] GPS enabled
- [ ] Location permission granted
- [ ] Within 30-min window
- [ ] No active session
- [ ] No conflicts

After Starting Session:
- [ ] QR code visible
- [ ] Timer counting down
- [ ] Location verified
- [ ] Students can scan

---

## 📚 Documentation Files

Detailed guides available:
1. `FINAL_SUMMARY_SCHEDULED_INTEGRATION.md` - Complete overview
2. `VISUAL_FLOW_SCHEDULED_SESSIONS.md` - Visual guide
3. `SCHEDULED_SESSIONS_INTEGRATION.md` - Technical details

---

**Version:** 1.0  
**Last Updated:** Nov 11, 2025  
**Status:** ✅ Production Ready

