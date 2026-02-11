📌 FEATURE FLOW
Policy-Aware Conflict Resolution Assistant (Supervisor Module)
🔵 PHASE 1 — POLICY FOUNDATION (One-Time or Update)
Step 1 — Upload Workplace Policy

Supervisor/HR uploads policy document (PDF/DOC).

System extracts text.

System divides into structured sections.

System stores sections in database.

✅ Output:

Policy is now searchable and referenceable.

Policy becomes “active” for all future cases.

🔵 PHASE 2 — CREATE NEW CASE
Step 2 — Start Case

Supervisor taps:

“Create New Conflict Case”

System asks:

Case type (Conflict / Conduct / Safety / Other)

Date of incident

Location / Department / Shift

Names of involved employees

Case status = Draft

🔵 PHASE 3 — SCAN COMPLAINTS
Step 3 — Scan Complaint A

Supervisor scans handwritten or printed complaint.

Scan Entry Screen
Screen: “Scan Document”

Options:

📷 Scan with Camera

📁 Upload Existing File

If user taps Scan with Camera →

↓

🟦 Live Edge Detection Screen (Real-Time Tracking)
Screen: Live Camera Scanner

Behavior:

Camera opens full screen.

System detects rectangular document in view.

Edges are outlined with animated border.

Corners snap into alignment automatically.

Real-time perspective correction preview.

Auto-capture when stable.

User sees:

Blue outline when detected

Green outline when ready to auto-capture

Manual capture button (backup option)

Flash toggle

Cancel button

System behavior:

If document is shaky → no capture.

If edges unclear → prompt: “Adjust lighting or flatten paper.”

This is the Adobe Scan-style experience.

🟦 Auto-Capture + Processing Screen

After auto snap:

System:

Applies perspective correction

Auto-crops

Straightens

Enhances contrast (document mode)

Removes shadow

Smooths edges

User sees:

Before / After toggle (optional)

Option to manually adjust corners (drag control points)

Retake button

Add Page button

Multi-page scanning allowed.

Button:
👉 Continue

↓

🟦 Document Review Screen

User sees:

Thumbnail list of all scanned pages

Ability to:

Reorder pages

Delete page

Re-scan page

Preview full PDF

Button:
👉 Confirm & Process

↓

🟦 Background Processing Screen

System now:

Runs OCR

Detects handwriting vs typed

Detects language

Translates if needed

Corrects spelling

Adjusts sentences

Stores original image + processed image + raw text

User sees:

“Processing Document…”

Estimated time indicator

When done:

↓

🟦 Text Review Screen

Tabs:

📄 Original Text (raw OCR)

🌍 Translated (if needed)

✍ Cleaned & Structured

User confirms:
👉 Accept Document

Now document becomes part of the case.

🔁 This Scan Flow Repeats For:

Policy upload

Complaint A

Complaint B

Witness statements

Prior records


System extracts text (OCR).

Detect language.

Translate to English (if needed).

Correct spelling and grammar.

Adjust sentences for clarity (context-based).

Preserve original text separately.

System stores:

Original

Translated

Cleaned version

Step 4 — Scan Complaint B

Same process as Complaint A.

🔵 PHASE 4 — INITIAL AI COMPARISON
Step 5 — Compare Both Statements

AI analyzes:

Timeline differences

Agreement points

Contradictions

Emotional escalation language

Missing details (date/time/location)

System displays:

Side-by-side comparison

Highlighted inconsistencies

Neutral summary of incident
f
AI does NOT accuse.
It only identifies differences.

🔵 PHASE 5 — EVIDENCE EXPANSION
Step 6 — Ask for Witness Statements

System asks:

“Are there any witnesses?”

If yes:

Scan witness statements

Process same as complaints

If no:

Continue

Step 7 — Ask for Previous History (Optional)

System asks:

Any prior complaints between these employees?

Any prior counseling records?

Any previous warnings?

Supervisor can:

Upload documents

Or select from past cases in system

AI updates context.

🔵 PHASE 6 — POLICY ALIGNMENT
Step 8 — Policy Matching

AI checks:

Do statements potentially align with any policy sections?

If yes, which section(s)?

System shows:

Policy section reference

Short explanation of why it may be relevant

No accusations.
Only relevance suggestions.

🔵 PHASE 7 — DECISION SUPPORT
Step 9 — AI Recommendation Layer

AI presents structured options:

Option A — Coaching Recommended
Option B — Documented Counseling
Option C — Written Warning Draft
Option D — Escalate to HR

Each option includes:

Why this option is suggested

Risk level assessment

Suggested next step

Supervisor must choose.
AI does not decide.

🔵 PHASE 8 — ACTION GENERATION

Depending on selection:

If Coaching Selected:

System generates:

Neutral discussion outline

Talking points

Questions to ask

Behavioral focus areas

Follow-up timeline suggestion

If Counseling Selected:

System generates:

Counseling documentation draft

Objective language

Policy references (if applicable)

If Warning Selected:

System generates:

Professional warning draft

Policy-aligned language

Neutral tone

Structured format ready for HR review

If Escalate to HR:

System generates:

Full case summary

Attached statements

Timeline

Policy references

Supervisor notes

🔵 PHASE 9 — SUPERVISOR REVIEW

Supervisor:

Reviews AI outputs

Edits if needed

Approves final version

System logs:

All edits

Final selected action

🔵 PHASE 10 — FINALIZATION

Supervisor taps:

“Finalize Case”

System:

Locks case record

Stores full audit trail

Generates exportable PDF package

Option to send to HR

Case status = Closed

🔁 Optional Enhancements (Later Phase)

Push notification when case ready

Supervisor reflection notes

Risk scoring over time

Pattern detection (repeat conflicts)

🔄 Complete Flow Summary (Simple View)

Upload policy

Create case

Scan complaint A

Scan complaint B

AI compare

Add witnesses

Add history

Policy match

AI suggests actions

Supervisor selects action

Draft generated

Supervisor edits

Finalize + export