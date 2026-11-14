# Student persona review — current UI and workflows

Date: 2026-11-06. Reviewer: an AI agent simulating a university student.
This is a reasoned persona review, not testimony from a real student or a new
usability-test session. It proposes changes for the owner to approve; none has
been implemented by this review.

## Evidence and scope

I read the current [feature matrix](../FEATURE_STATUS.md) and
[refinement report](../UI_REFINEMENT.md), inspected the three screenshots below,
and read the current student-facing Flutter and relevant API source. The
[UI/UX design skill](../../.agent/skills/ui-ux-designer/SKILL.md) guides the
task-oriented recommendations; the
[visual validation skill](../../.agent/skills/ui-visual-validator/SKILL.md)
guides the visual assessment.

- Visual evidence: [student home](../../screenshots/refined/student-home.png),
  [dark home](../../screenshots/refined/student-dark.png), and
  [mobile login](../../screenshots/refined/login-400.png), each at 400×900 pixels.
- Source evidence: current widgets and API behavior cited under each proposal.
  These are code-backed findings, not newly reproduced browser failures.
- Prior verification: the refinement report records role browser checks,
  autosave/lifecycle work, and layout tests. Those checks were not rerun here.
- Assumptions: the preferences below model a student attending lectures and
  taking quizzes on a phone. Real students still need to validate the priorities.

## Visual assessment

From the visual evidence, I observe... a readable Arabic interface with a
university logo, a persistent course/section selector, a brown welcome panel,
outlined action cards, and five labeled navigation destinations. Light and dark
screens preserve the same content order. The home screenshot displays **1**
available quiz in a metric tile, but its actual quiz action is below the first
viewport. The large welcome panel and subsequent action cards occupy that
initial viewport. This is a prioritization preference, not evidence of broken
scrolling or clipping. The welcome details visibly include the English legacy
label **Imported semester 2**.

The goal of a coherent Arabic university identity is achieved in these samples.
The goal of reaching the most urgent timed task immediately is partially
achieved. The screenshots do not establish keyboard focus behavior, screen-reader
announcements, touch comfort on a physical phone, or contrast for every state.
The refinement report records measured contrast and small-screen/text-scaling
checks; this review makes no additional accessibility certification claim.

## What I would keep

- Arabic labels, RTL reading order, the visible course/section selector, and the
  existing visual identity in both themes.
- The direct attendance scanning action and its existing manual-entry fallback.
- Server-confirmed attendance, duplicate receipts, published-only grade totals,
  and the distinction between an incomplete result and a score of zero.
- Existing answer persistence, server-based quiz deadlines, automatic
  finalization, and resuming the same attempt rather than creating another.
- Account-isolated course and theme preferences, labeled bottom navigation,
  password visibility, and input autofill.

## Requested changes

### STU-01 — Make the available quiz immediately actionable

- **Action / priority:** Update / Medium.
- **Current evidence:** The home screenshot shows one available quiz but no quiz
  action in its first 400×900 viewport. In
  [dashboard.dart](../../lib/features/dashboard.dart), lines 90–104 render static
  student metrics; the actionable quiz cards follow later at lines 136–151.
- **Student impact:** I know a quiz exists, but must scroll and look for the
  control while its time window is running.
- **Desired behavior:** Make the available-quiz summary open the quiz list, and
  place an urgent quiz/resume action earlier when one exists. A more compact
  welcome panel is optional; retain branding and the scanner shortcut.
- **Acceptance:** At 400×900, an active quiz has a clearly labeled action in the
  first viewport. Opening that summary must not itself start a timed attempt.

### STU-02 — Remove the raw imported-term label from the student presentation

- **Action / priority:** Remove / Low.
- **Current evidence:** Both home screenshots display **Imported semester 2**.
  [dashboard.dart](../../lib/features/dashboard.dart), lines 60–61, presents the
  stored course term directly.
- **Student impact:** An import label reads like unfinished setup and does not
  clearly identify the actual academic semester.
- **Desired behavior:** Replace the raw display label with an approved Arabic
  semester/year name. If that information is unknown, show a neutral accurate
  label until it is supplied. Preserve the underlying term identifier and
  enrollment history.
- **Acceptance:** The student home and course selector contain a consistent
  accurate Arabic term label; no attendance or grade records are deleted.

### STU-03 — Add a clear readiness step before the quiz clock starts

- **Action / priority:** Add / High.
- **Current evidence:** Tapping an available quiz in
  [quizzes.dart](../../lib/features/quizzes.dart), lines 134–151, opens its runner;
  runner initialization calls `POST /quizzes/{id}/start` at lines 500–502 and
  537–543. [server/quizzes.py](../../server/quizzes.py), lines 327–332, creates the
  first attempt and its deadline. There is no intervening readiness screen.
- **Student impact:** A tap to inspect a quiz starts the attempt. A late starter
  may also have less time than the advertised duration because the server uses
  the earlier of the global closing time and the personal duration.
- **Desired behavior:** Present title, course/section, duration, closing time,
  actual available time, and a clear **ابدأ المحاولة الآن** action before starting
  a new attempt. Resume and published-result viewing should remain direct.
- **Acceptance:** Viewing or cancelling the readiness screen creates no attempt.
  Confirming creates one attempt and displays its server deadline, including a
  truthful short-time warning when the global window closes sooner.

### STU-04 — Explain answer-saving status and make failure recovery explicit

- **Action / priority:** Update / High.
- **Current evidence:** [quizzes.dart](../../lib/features/quizzes.dart), lines
  557–577, updates the selected answer after the autosave request succeeds.
  During any request the runner shows a generic progress bar (line 640); errors
  use a generic panel (line 623). There is no persistent per-answer saved/pending
  label or dedicated failed-save retry control.
- **Student impact:** On a slow connection I cannot easily distinguish a click
  that is still saving from an answer already acknowledged by the server.
- **Desired behavior:** Show **جارٍ حفظ الإجابة** / **تم الحفظ** / **تعذر الحفظ**
  alongside the answer, identify the failed choice, and offer a safe retry before
  the deadline. Keep confirmed and pending answers distinct. Do not promise
  offline delivery or extend the academic deadline.
- **Acceptance:** Under simulated latency and one failed save, confirmed status
  appears only after acknowledgement; the failed choice can be retried without
  silently replacing a confirmed answer. Expiry clearly states which saved
  answers were finalized. Also distinguish manual submission from timeout in
  the result status; currently both read **تم التسليم** (lines 23 and 624–628).

### STU-05 — Add an unanswered-question overview before submission

- **Action / priority:** Add / Medium.
- **Current evidence:** [quizzes.dart](../../lib/features/quizzes.dart), lines
  641–672, provides the current question and previous/next controls. The
  submission confirmation at lines 582–585 does not identify unanswered items.
- **Student impact:** I must revisit questions sequentially to find a missed
  answer and can submit without noticing an accidental omission.
- **Desired behavior:** Add a compact answered/unanswered overview with direct
  question navigation and include the unanswered count in manual submission
  confirmation. This is a usability improvement, not a scoring defect.
- **Acceptance:** For a five-question attempt with two saved answers, the overview
  reports three unanswered questions, opens each correctly, and warns before
  manual submission. Automatic expiry still finalizes without requiring a tap.

### STU-06 — Make the attendance receipt useful after the confirmation closes

- **Action / priority:** Update / High.
- **Current evidence:** [attendance.dart](../../lib/features/attendance.dart),
  lines 589–601, shows session ID, recording time, and receipt ID in a dialog.
  Student session detail at lines 267–271 shows status and session starting time
  only. [server/attendance.py](../../server/attendance.py), line 133, returns the
  student's record status/time but not its receipt ID; check-in at line 208
  returns the receipt ID and actual offering ID.
- **Student impact:** Once I close the confirmation, I cannot reopen the same
  proof in the UI. A numeric session ID also provides little reassurance about
  the lecture/course I actually registered in.
- **Desired behavior:** Show the actual course, session title, recorded time,
  status, and receipt ID in confirmation and in my attendance detail; allow
  copying the receipt. Use the QR's authorized offering as the source of truth,
  since it need not match the course currently selected on the home screen.
- **Acceptance:** After reload, I can reopen my own receipt with the same ID and
  time. Scanning twice returns the same receipt, other students' receipts remain
  inaccessible, and actual course context is unambiguous.

### STU-07 — Surface unread notifications and open their relevant task

- **Action / priority:** Update / Medium.
- **Current evidence:** [settings.dart](../../lib/features/settings.dart), lines
  23–48, places notifications inside **المزيد**. Selecting a notice marks it read
  and reloads the list; it does not open the related quiz/result. The inspected
  home screenshots have no unread indicator.
- **Student impact:** A newly opened quiz or published result can be easy to
  miss, and reading its notification still requires finding the corresponding
  course and page.
- **Desired behavior:** Add a labeled unread indicator on home or **المزيد** and
  route an actionable notification to its authorized course and relevant quiz
  or grade screen. In-app improvement comes before deciding on external push.
- **Acceptance:** A new notification changes the unread count, opens the correct
  permitted task, and updates the count after reading. Quiz notification opening
  uses the readiness step in STU-03 for a new attempt. Invalid or expired targets
  display an explanation rather than starting an unrelated action.

### STU-08 — Explain how grades are calculated and what is still missing

- **Action / priority:** Update / Medium.
- **Current evidence:** [grading.dart](../../lib/features/grading.dart), lines
  35–44, displays achieved totals and category values followed by **غير مكتمل**.
  [server/grading.py](../../server/grading.py), lines 284–314, calculates weighted
  attendance/assessment categories but returns category completeness as a boolean
  without a student-facing explanation of missing requirements.
- **Student impact:** An incomplete category does not tell me whether I should
  take a quiz, wait for publication, or ask about a missing record. A weighted
  contribution is also hard to relate to my raw quiz score or attendance ratio.
- **Desired behavior:** Add a compact explanation of each category's allocation,
  raw result and contribution, with truthful reasons such as awaiting publication
  or no finalized attendance yet. Continue hiding unpublished results.
- **Acceptance:** A worked published-score example shows the correct contribution;
  an incomplete example explains the missing condition without exposing draft
  marks. Zero, excused, unrecorded, and unpublished outcomes remain distinct.

### STU-09 — Add an attendance correction/excuse request with a visible outcome

- **Action / priority:** Add / Medium; requires an agreed academic policy.
- **Current evidence:** The [feature matrix](../FEATURE_STATUS.md) explicitly
  defers student excuse requests and audited finalized-attendance corrections.
  Current student attendance detail provides read-only status, not a request.
- **Student impact:** If a network problem or legitimate absence produces a
  disputed record, the app gives me no traceable path to ask for review.
- **Desired behavior:** Let me submit a reason for a specific session, see
  pending/accepted/rejected status, and receive a decision. Staff approval and
  audit history must govern any change; a request must not change my grade
  immediately. Deadlines, attachments, and approver ownership need the owner's
  decision before implementation.
- **Acceptance:** A request remains separate from official attendance until an
  authorized decision, duplicates are controlled, and the student can see the
  outcome and decision reason without viewing other students' requests.

### STU-10 — Turn the login support instruction into an actionable contact

- **Action / priority:** Add / Medium.
- **Current evidence:** The [mobile login screenshot](../../screenshots/refined/login-400.png)
  tells the user to contact the administrator, but
  [auth.dart](../../lib/features/auth.dart), lines 129–148, supplies only that
  instruction. The [feature matrix](../FEATURE_STATUS.md) defers password recovery;
  changing a known password is already implemented.
- **Student impact:** When locked out, I do not know who the administrator is or
  how to reach support from this screen.
- **Desired behavior:** Add the institution-approved support contact or a clear
  recovery-request action with truthful response expectations. Full self-service
  recovery is a separate policy decision; avoid adding a decorative **نسيت كلمة
  المرور** link before a working process exists.
- **Acceptance:** A logged-out student can reach the approved help channel without
  supplying a password. Any recovery response preserves account privacy and the
  existing login flow remains usable.

## My first-person priorities

> "Keep this Arabic look. Before a quiz starts, tell me exactly how much time I
> have and let me choose to start. While I answer, show me what is really saved.
> After attendance, let me reopen a receipt that names the right lecture. Then
> help me reach urgent quizzes, notifications, and understandable grade details
> with fewer taps. I would remove the imported-term wording, not academic data."

Start with **STU-03**, **STU-04**, and **STU-06** for confidence in timed work and
attendance proof. STU-01 improves daily access; STU-09 and STU-10 need approved
institutional processes. This ordering is a persona recommendation, not owner
approval to build.

## Remaining validation

No physical camera, native storage/sharing, printer, screen reader, or weak-network
session was operated for this review. The existing scanner already has a
camera-error instruction and manual-entry fallback
([attendance.dart](../../lib/features/attendance.dart), lines 618–643); it should
not be described as missing. Test denial/re-grant, QR expiry, foreground/background
resume, slow saves and deadline crossing on a real phone before claiming those
experiences are reliable. Validate notification discovery and quiz navigation
with real students, including text scaling and assistive technology users.
