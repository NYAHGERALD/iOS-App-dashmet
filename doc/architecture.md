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

Step 10 — Action Selection Confirmation

After supervisor selects an action from Phase 7:

🟦 Action Confirmation Screen
Screen: "Confirm Selected Action"

User sees:

Selected action highlighted (e.g., "Coaching Recommended")

Brief summary of case context

Estimated generation time

Warning: "This will generate official documentation"

Buttons:

👉 Confirm & Generate

← Change Selection

↓

🟦 Generation Progress Screen
Screen: "Generating Documents…"

System behavior:

AI processes case data

Cross-references policy sections

Applies organizational tone guidelines

Generates draft content

User sees:

Progress indicator

Current step label:
- "Analyzing case context…"
- "Matching policy references…"
- "Drafting document…"
- "Applying formatting…"

Estimated time remaining

↓

═══════════════════════════════════════════════════════════
📋 ACTION TYPE A — COACHING SESSION
═══════════════════════════════════════════════════════════

If Coaching Selected:

🟦 Coaching Package Generation Screen
Screen: "Coaching Session Package"

System generates 4 components:

┌─────────────────────────────────────────────────────────┐
│ COMPONENT 1: Discussion Outline                         │
├─────────────────────────────────────────────────────────┤
│ Structure:                                              │
│ • Opening statement (neutral, non-accusatory)           │
│ • Context setting (what triggered the conversation)     │
│ • Key discussion points (from AI analysis)              │
│ • Active listening prompts                              │
│ • Resolution focus areas                                │
│ • Closing summary template                              │
│                                                         │
│ Tone: Supportive, development-focused                   │
│ Length: 1-2 pages                                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ COMPONENT 2: Talking Points Card                        │
├─────────────────────────────────────────────────────────┤
│ Format: Bullet-point quick reference                    │
│                                                         │
│ Includes:                                               │
│ • 5-7 key points to cover                               │
│ • Specific behaviors to address (factual, no judgment)  │
│ • Impact statements (how behavior affected team/work)   │
│ • Expected behavior going forward                       │
│ • Support resources available                           │
│                                                         │
│ Purpose: Printable card for supervisor to hold during   │
│          conversation                                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ COMPONENT 3: Guided Questions                           │
├─────────────────────────────────────────────────────────┤
│ Categories:                                             │
│                                                         │
│ 🔹 Understanding Questions                              │
│   "Can you walk me through what happened from your      │
│    perspective?"                                        │
│   "What were you trying to accomplish?"                 │
│                                                         │
│ 🔹 Reflection Questions                                 │
│   "Looking back, what might you do differently?"        │
│   "How do you think this affected [other party]?"       │
│                                                         │
│ 🔹 Forward-Looking Questions                            │
│   "What support do you need to improve?"                │
│   "How can we prevent this situation in the future?"    │
│                                                         │
│ AI tailors questions based on:                          │
│ • Nature of conflict                                    │
│ • Statements analyzed                                   │
│ • Identified contradictions                             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ COMPONENT 4: Follow-Up Timeline                         │
├─────────────────────────────────────────────────────────┤
│ System suggests:                                        │
│                                                         │
│ Week 1: Initial coaching conversation                   │
│ Week 2: Informal check-in (optional)                    │
│ Week 4: Formal follow-up meeting                        │
│ Week 8: Progress assessment                             │
│                                                         │
│ Supervisor can adjust:                                  │
│ • Timeline duration                                     │
│ • Check-in frequency                                    │
│ • Add calendar reminders                                │
│                                                         │
│ System auto-generates reminder notifications            │
└─────────────────────────────────────────────────────────┘

🟦 Coaching Package Review Screen

User sees:

Tab navigation:
📝 Outline | 💬 Talking Points | ❓ Questions | 📅 Timeline

Each tab displays generated content

Edit buttons on each section

Preview button (full document)

Buttons:

👉 Accept Package

✏️ Edit Section

🔄 Regenerate

↓

═══════════════════════════════════════════════════════════
📋 ACTION TYPE B — DOCUMENTED COUNSELING
═══════════════════════════════════════════════════════════

If Counseling Selected:

🟦 Counseling Documentation Screen
Screen: "Counseling Record Draft"

System generates formal counseling document:

┌─────────────────────────────────────────────────────────┐
│ COUNSELING DOCUMENTATION STRUCTURE                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ HEADER SECTION:                                         │
│ ───────────────                                         │
│ • Document type: "Employee Counseling Record"           │
│ • Date of counseling                                    │
│ • Employee name                                         │
│ • Department / Position                                 │
│ • Supervisor name                                       │
│ • Case reference number (auto-generated)                │
│                                                         │
│ INCIDENT SUMMARY:                                       │
│ ─────────────────                                       │
│ • Date(s) of incident                                   │
│ • Location                                              │
│ • Factual description (AI-generated, neutral language)  │
│ • No accusations or assumptions                         │
│ • Based on documented statements only                   │
│                                                         │
│ POLICY REFERENCE:                                       │
│ ─────────────────                                       │
│ • Relevant policy section(s) cited                      │
│ • Brief excerpt from policy                             │
│ • Explanation of relevance                              │
│                                                         │
│ EXPECTATIONS:                                           │
│ ─────────────────                                       │
│ • Specific behaviors expected going forward             │
│ • Measurable objectives (if applicable)                 │
│ • Support available to employee                         │
│                                                         │
│ CONSEQUENCES:                                           │
│ ─────────────────                                       │
│ • Statement of potential escalation if behavior         │
│   continues                                             │
│ • Next step in progressive discipline                   │
│                                                         │
│ ACKNOWLEDGMENT:                                         │
│ ─────────────────                                       │
│ • Signature line: Employee                              │
│ • Signature line: Supervisor                            │
│ • Date line                                             │
│ • Statement: "Signature acknowledges receipt, not       │
│   agreement"                                            │
│                                                         │
└─────────────────────────────────────────────────────────┘

🟦 Counseling Document Editor Screen

User sees:

Live document preview

Editable fields highlighted in blue

Section-by-section editing mode

Tone indicator:
🟢 Neutral | 🟡 Caution | 🔴 Review needed

AI suggestions panel (right side):
• Alternative phrasing options
• Policy reference suggestions
• Tone adjustments

Buttons:

💾 Save Draft

👁️ Preview PDF

✅ Finalize

↓

═══════════════════════════════════════════════════════════
📋 ACTION TYPE C — WRITTEN WARNING
═══════════════════════════════════════════════════════════

If Warning Selected:

🟦 Warning Document Generation Screen
Screen: "Written Warning Draft"

System generates formal warning:

┌─────────────────────────────────────────────────────────┐
│ WRITTEN WARNING STRUCTURE                               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ OFFICIAL HEADER:                                        │
│ ────────────────                                        │
│ • Company letterhead (auto-applied)                     │
│ • Document type: "Written Warning"                      │
│ • Warning level: [First / Second / Final]               │
│ • Confidential marking                                  │
│                                                         │
│ EMPLOYEE INFORMATION:                                   │
│ ─────────────────────                                   │
│ • Employee name                                         │
│ • Employee ID                                           │
│ • Department                                            │
│ • Position                                              │
│ • Hire date                                             │
│ • Direct supervisor                                     │
│                                                         │
│ REASON FOR WARNING:                                     │
│ ───────────────────                                     │
│ • Clear statement of violation/issue                    │
│ • Specific dates and incidents                          │
│ • Factual description only                              │
│ • Reference to previous counseling (if any)             │
│                                                         │
│ POLICY VIOLATIONS:                                      │
│ ──────────────────                                      │
│ • Policy name and section number                        │
│ • Direct quote from policy                              │
│ • How behavior relates to policy                        │
│                                                         │
│ CORRECTIVE ACTION REQUIRED:                             │
│ ───────────────────────────                             │
│ • Specific steps employee must take                     │
│ • Timeline for improvement                              │
│ • Success criteria                                      │
│ • Resources/support provided                            │
│                                                         │
│ CONSEQUENCES OF NON-COMPLIANCE:                         │
│ ───────────────────────────────                         │
│ • Clear statement of next steps if behavior continues   │
│ • May include: suspension, demotion, termination        │
│ • Timeline for review                                   │
│                                                         │
│ ACKNOWLEDGMENT SECTION:                                 │
│ ───────────────────────                                 │
│ • Employee signature line                               │
│ • Supervisor signature line                             │
│ • HR representative signature line (if applicable)      │
│ • Date                                                  │
│ • Copy distribution list                                │
│                                                         │
│ EMPLOYEE RESPONSE SECTION:                              │
│ ──────────────────────────                              │
│ • Optional: Space for employee written response         │
│ • Deadline for response submission                      │
│                                                         │
└─────────────────────────────────────────────────────────┘

🟦 Warning Level Selection Modal

Before finalizing, system prompts:

"Select Warning Level"

Options:

⚪ First Written Warning
   - Initial formal documentation
   - Sets baseline for progressive discipline

⚪ Second Written Warning
   - Follow-up to previous warning
   - System auto-links to prior warning record

⚪ Final Written Warning
   - Last step before termination consideration
   - Requires HR review before issuance

System auto-detects if prior warnings exist and suggests appropriate level.

🟦 Warning Document Review Screen

Features:

Legal compliance checker
• Scans for potentially problematic language
• Flags vague or subjective statements
• Suggests specific, measurable language

Policy alignment verification
• Confirms cited policies are current
• Validates section references

Previous action history panel
• Shows timeline of prior actions with this employee
• Links to related case documents

Buttons:

⚖️ Legal Review Mode

📤 Send to HR for Review

✅ Approve and Finalize

↓

═══════════════════════════════════════════════════════════
📋 ACTION TYPE D — HR ESCALATION
═══════════════════════════════════════════════════════════

If Escalate to HR Selected:

🟦 HR Escalation Package Screen
Screen: "HR Escalation Summary"

System compiles comprehensive package:

┌─────────────────────────────────────────────────────────┐
│ HR ESCALATION PACKAGE CONTENTS                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 1. EXECUTIVE SUMMARY (1 page)                           │
│    ────────────────────────────                         │
│    • Case overview                                      │
│    • Key parties involved                               │
│    • Primary concerns                                   │
│    • Reason for escalation                              │
│    • Recommended urgency level                          │
│                                                         │
│ 2. FULL CASE TIMELINE                                   │
│    ────────────────────                                 │
│    • Chronological event list                           │
│    • Date/time stamps                                   │
│    • Source of each data point                          │
│    • Visual timeline graphic                            │
│                                                         │
│ 3. STATEMENT COMPARISON REPORT                          │
│    ─────────────────────────────                        │
│    • Side-by-side statement analysis                    │
│    • Highlighted agreements                             │
│    • Highlighted contradictions                         │
│    • Neutral observations                               │
│                                                         │
│ 4. ATTACHED DOCUMENTS                                   │
│    ────────────────────                                 │
│    • Original scanned complaints                        │
│    • Processed/cleaned versions                         │
│    • Witness statements                                 │
│    • Previous related records                           │
│    • Supporting evidence                                │
│                                                         │
│ 5. POLICY REFERENCE REPORT                              │
│    ─────────────────────────                            │
│    • All potentially relevant policies                  │
│    • Relevance explanations                             │
│    • Full policy excerpts                               │
│                                                         │
│ 6. SUPERVISOR NOTES                                     │
│    ─────────────────                                    │
│    • Observations                                       │
│    • Context not captured in documents                  │
│    • Previous interactions with parties                 │
│    • Recommended actions considered                     │
│                                                         │
│ 7. AI ANALYSIS SUMMARY                                  │
│    ────────────────────                                 │
│    • Risk assessment                                    │
│    • Pattern detection results                          │
│    • Suggested investigation areas                      │
│    • Confidence levels                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘

🟦 Escalation Priority Selection

System prompts:

"Select Escalation Priority"

🔴 Critical — Immediate HR attention required
   Use for: Safety concerns, harassment, discrimination,
            potential legal exposure

🟠 High — Review within 24-48 hours
   Use for: Repeated violations, multiple parties,
            complex situations

🟡 Standard — Review within 1 week
   Use for: Routine escalations, policy clarification
            needed, supervisor guidance requested

🟢 Informational — For HR awareness only
   Use for: Documentation purposes, pattern tracking,
            no immediate action required

🟦 HR Recipient Selection Screen

User selects:

□ Direct HR Business Partner
□ HR Manager
□ Employee Relations Specialist
□ Legal/Compliance (if applicable)
□ Department Head
□ Other (specify)

System behavior:
• Auto-suggests recipients based on case type
• Shows recipient availability status
• Allows adding custom message

🟦 Escalation Confirmation Screen

User sees:

Package summary:
• Document count
• Total pages
• Attachments list
• Selected priority
• Selected recipients

Supervisor attestation:
☑️ "I confirm this information is accurate to the best
    of my knowledge"
☑️ "I understand this case will be transferred to HR
    for further action"

Buttons:

📤 Submit to HR

💾 Save as Draft

← Return to Edit

↓

═══════════════════════════════════════════════════════════
🔄 COMMON POST-GENERATION FEATURES
═══════════════════════════════════════════════════════════

After any action type is generated:

🟦 Document Customization Panel

Available on all generated documents:

Tone Adjustment Slider:
|──────●────────| 
Formal ←→ Conversational

Length Preference:
⚫ Concise  ○ Standard  ○ Detailed

Language Options:
• Simplify language
• Add more context
• Include examples
• Remove technical jargon

🟦 Template Override Option

User can:

• Use AI-generated content (default)
• Select from organizational templates
• Apply custom template
• Merge AI content with template

🟦 AI Regeneration Options

If supervisor is unsatisfied:

🔄 Regenerate Section
   - Keeps other sections
   - Targets specific area

🔄 Regenerate All
   - Fresh generation
   - Can adjust parameters

💡 Suggest Alternative
   - AI provides 2-3 variations
   - User picks preferred version

🟦 Export Options (Available for all actions)

Export formats:
• PDF (print-ready)
• Word document (editable)
• Plain text
• Email-ready format

Export destinations:
• Download to device
• Send via email
• Save to case file
• Integration with HRIS (if connected)

🟦 Audit Trail Entry

System automatically logs:

• Action type selected
• Generation timestamp
• All AI parameters used
• Supervisor ID
• Any edits made
• Final version snapshot
• Export/send actions

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