# CLEAN DEVELOPMENT BLUEPRINT  
## AI Meeting Intelligence & Action Management App  
### iOS (Swift) First — Test-Gated, Step-by-Step Execution

> RULE: **Never move forward unless the current step RUNS and is VERIFIED**

---

## CORE DEVELOPMENT PRINCIPLES (MANDATORY)

1. **One feature at a time**
2. **Every step must run successfully**
3. **Manual verification before automation**
4. **No feature stacking**
5. **Backend + iOS validated together**
6. **If something breaks, STOP and fix immediately**

This blueprint is written to **prevent hidden bugs** and **reduce debugging time**.

---

## TECHNOLOGY LOCK (NO CHANGES MIDWAY)

- iOS: Swift (SwiftUI preferred)
- Auth: Firebase Phone Authentication
- Storage: Firebase Storage
- Database: PostgreSQL (Render)
- Backend: API service + Worker service
- AI: Managed AI APIs (transcription + diarization)
- Notifications: Push (APNs via Firebase)

---

# PHASE 0 — PROJECT FOUNDATION (NO FEATURES YET)

### STEP 0.1 — Create Repositories
Create **three clean repositories**:
- `meeting-ai-ios`
- `meeting-ai-backend`
- `meeting-ai-worker`

✅ TEST / VERIFY:
- Each repo builds or runs a default scaffold
- No errors, no warnings

❌ DO NOT PROCEED if any repo does not start cleanly

---

### STEP 0.2 — Environment Configuration (NO SECRETS)
Define environment variables using **placeholders only**.

Backend must start with:
- DATABASE_URL (placeholder)
- FIREBASE_PROJECT_ID
- FIREBASE_CONFIG_PATH

✅ TEST / VERIFY:
- Backend boots without crashing
- Logs show “environment loaded”

---

# PHASE 1 — AUTHENTICATION (FOUNDATION OF EVERYTHING)

## WHY FIRST?
If auth is broken, **everything else is useless**.

---

### STEP 1.1 — iOS Login UI ONLY
Build:
- Phone number input
- OTP input
- Verify button
- Loading + error states

❌ No backend calls yet

✅ TEST / VERIFY:
- UI renders correctly
- Input validation works
- Error messages show properly

---

### STEP 1.2 — Firebase Phone Auth (iOS)
Connect UI to Firebase Phone Auth:
- Send OTP
- Verify OTP
- Receive Firebase ID token

✅ TEST / VERIFY:
- Login succeeds on real device
- Invalid OTP fails correctly
- Token is returned

❌ DO NOT proceed without real-device verification

---

### STEP 1.3 — Backend Auth Verification
Backend:
- Accept Firebase ID token
- Verify token
- Extract firebase_uid

Create `/me` endpoint.

✅ TEST / VERIFY:
- iOS sends token
- Backend validates token
- `/me` returns user identity

🚫 STOP if token verification fails

---

### STEP 1.4 — Auto-Create User in Postgres
On first login:
- Create user record in Postgres
- Map firebase_uid → user_id

✅ TEST / VERIFY:
- First login inserts user row
- Second login does NOT duplicate user
- `/me` returns Postgres user data

---

# PHASE 2 — TASK SYSTEM (NO AI YET)

## WHY?
Tasks are the **core value**, AI is just an accelerator.

---

### STEP 2.1 — Create Task API (MINIMAL)
Backend:
- Create task (title, owner, due date)
- Fetch tasks assigned to user

✅ TEST / VERIFY:
- API creates task
- API fetches task
- Data persists in Postgres

---

### STEP 2.2 — iOS Task List UI
Build:
- Task list screen
- Empty state
- Loading state

❌ No edit, no comments yet

✅ TEST / VERIFY:
- Tasks display correctly
- Refresh works
- App does not crash offline

---

### STEP 2.3 — Assign Task + Status Change
Add:
- Assign task to user
- Change task status

✅ TEST / VERIFY:
- Assignment updates DB
- Status changes persist
- UI reflects changes immediately

---

### STEP 2.4 — Push Notifications (TASK ASSIGNED)
Implement:
- Device token registration
- Push notification when task assigned

✅ TEST / VERIFY:
- Assign task
- Assignee receives push notification
- Notification opens correct task

🚫 If notifications fail, STOP and fix

---

# PHASE 3 — MEETING CREATION (NO AI PROCESSING YET)

---

### STEP 3.1 — Create Meeting UI
iOS:
- Create meeting screen
- Title input
- Start / Stop recording button

❌ No upload yet

✅ TEST / VERIFY:
- UI works
- Timer works
- Audio file saved locally

---

### STEP 3.2 — Firebase Storage Upload
Implement:
- Upload recorded audio
- Save storage path

✅ TEST / VERIFY:
- Audio uploads successfully
- File visible in Firebase Storage
- No public access

---

### STEP 3.3 — Backend Meeting Record
Backend:
- Create meeting record
- Attach audio asset reference

✅ TEST / VERIFY:
- Meeting stored in Postgres
- Audio path linked
- Meeting status = UPLOADED

---

# PHASE 4 — AI PROCESSING (CONTROLLED INTRODUCTION)

---

### STEP 4.1 — Transcription ONLY
Worker:
- Pull meeting audio
- Generate transcript
- Store transcript text

❌ No diarization yet

✅ TEST / VERIFY:
- Transcript generated
- Stored correctly
- Visible in iOS

---

### STEP 4.2 — Speaker Diarization
Add:
- Speaker count
- Speaker segments

✅ TEST / VERIFY:
- Multiple speakers detected
- Segments align with transcript

---

### STEP 4.3 — Summary Generation
Add:
- Summary
- Key points
- Decisions

✅ TEST / VERIFY:
- Summary readable
- No hallucinated content
- Confidence score stored

---

### STEP 4.4 — Action Item Suggestions
Generate:
- Suggested tasks (NOT auto-created)

iOS:
- Review screen
- Accept / edit / discard

✅ TEST / VERIFY:
- Suggestions make sense
- Accepted items become real tasks

---

# PHASE 5 — REVIEW → PUBLISH WORKFLOW

---

### STEP 5.1 — Review Gate
Implement:
- Meeting status = READY_FOR_REVIEW
- Creator approval required

✅ TEST / VERIFY:
- Tasks NOT visible until published
- Review edits persist

---

### STEP 5.2 — Publish & Notify
On publish:
- Tasks created
- Assignees notified

✅ TEST / VERIFY:
- Notifications sent
- Tasks appear in assignee list

---

# PHASE 6 — IMPORT SYSTEM (OPTIONAL BUT CONTROLLED)

---

### STEP 6.1 — CSV Import ONLY
Implement:
- Upload CSV
- Preview rows
- Validate columns

✅ TEST / VERIFY:
- Invalid rows rejected
- Valid rows imported

---

### STEP 6.2 — Excel Import
Add Excel → CSV conversion

✅ TEST / VERIFY:
- Same behavior as CSV

---

# PHASE 7 — HARDENING & SAFETY

---

### STEP 7.1 — Error Handling
- Network failures
- Partial AI failures
- Retry logic

---

### STEP 7.2 — Audit Logs
Track:
- Who changed what
- When
- Before/after

✅ TEST / VERIFY:
- Every action logged

---

# FINAL ACCEPTANCE CRITERIA

You can:
- Login reliably
- Create and assign tasks
- Receive push notifications
- Record a meeting
- Get transcript, summary, and action items
- Review before publishing
- Import tasks safely
- Audit all changes

---

## NON-NEGOTIABLE RULE
> **If a step fails, you STOP and fix it before proceeding.**

This is how clean systems are built.

---

END OF CLEAN BLUEPRINT
