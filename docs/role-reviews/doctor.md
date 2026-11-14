# Doctor persona review — current UI and workflows

Reviewed: 2026-11-06. This is an **AI-simulated university doctor review**, not an interview with a real doctor. It covers the current refined version and proposes work for the project owner to accept, reject, or defer. No application changes are requested to run automatically.

> “I like the clear university identity and the direct lecture and grading actions. Before adding more decoration, I want to know exactly which section I am acting on, what I am publishing, and how attendance mistakes can be reviewed. I also need to see the questions that students will receive.”

## Evidence and limits

- **Visual observations:** inspected the actual [doctor dashboard](../../screenshots/refined/doctor-home.png), [student report on mobile](../../screenshots/refined/student-report.png), [quiz preparation on mobile](../../screenshots/refined/quiz-preparation.png), and [desktop login](../../screenshots/refined/login-1440.png).
- **Source-backed observations:** current Flutter screens and backend routes linked below. These establish available controls and behavior, but are not new browser execution results.
- **Earlier verification:** [UI_REFINEMENT.md](../UI_REFINEMENT.md) and [FEATURE_STATUS.md](../FEATURE_STATUS.md) document passing checks and distinguish implemented and deferred features. This review did not rerun them.
- **Untested:** real lecture projection, phone scanning, printer output, screen-reader speech, keyboard focus, reduced motion, and new users finding each task. No claim of a measured usability score or complete accessibility compliance is made.
- Proposal IDs `DOC-01`–`DOC-12` belong to this doctor review; they are separate from the historic remediation IDs.

## Visual assessment

From the visual evidence, I observe a brown welcome panel, ivory background, outlined white cards, Arabic headings, and a selected course/section in a prominent top bar. The desktop screenshot shows an RTL navigation rail with the home entry selected. The lecture-opening and grading cards are prominent; saved section attendance also appears under follow-up work. The mobile report shows searchable student cards and a pinned PDF/print footer. The preparation screen visibly distinguishes immediate opening, scheduling, and a hidden draft.

The visible hierarchy and university branding are achieved for these recorded states. Overall doctor usability is **partially assessed**: the provided dashboard is desktop, while the report and preparation screenshots cover mobile subpages. The generous card spacing supports reading, but a long report will require substantial scrolling. The dashboard draft card does not visibly identify the responsible TA or clarify that a doctor is viewing it rather than editing it. This is a clarity issue, not evidence of an authorization defect.

The current refinement report records measured text contrast and 150% mobile text scaling checks. Those are useful existing results, not new measurements from this review. Contrast in every status state, focus visibility, screen-reader announcements, and a doctor's complete mobile journey still need direct verification.

## Keep these existing choices

- Keep Arabic/RTL navigation, the university identity, the restrained palette, and bundled Arabic/Latin fonts.
- Keep the selected scope visible, role-specific actions, and the desktop rail/mobile navigation adaptation.
- Keep saved attendance drafts, all-student finalization checks, revision checks, and exclusion of drafts from official totals.
- Keep quiz preparation, scheduling, cancellation before attempts, and preservation of saved answers on closure.
- Keep separation between saved grades and published results, required reasons for published-grade corrections, and doctor-only publication.
- Keep complete scoped PDF export, repeated PDF headers, the distinction between incomplete results and zero, and pinned save/export actions.

## Proposed updates, additions, and removals

### DOC-01 — Make follow-up cards explain responsibility and permitted action

- **Action / priority:** Update / High.
- **Current behavior and evidence:** The [doctor dashboard screenshot](../../screenshots/refined/doctor-home.png) lists a saved section-attendance draft beside an open lecture. [dashboard.dart:153](../../lib/features/dashboard.dart#L153) gives draft cards generic descriptions and opens the draft with `editable: false` for doctors. [CreateSessionPage:173](../../lib/features/attendance.dart#L173) shows the selected scope before creation, but does not explicitly explain the recipients.
- **Doctor impact:** I may read “follow-up work” as work I should finalize myself, or open a lecture for one section when I intended the whole course.
- **Desired behavior:** Show session type, section/department, responsible TA where applicable, and “view only” or the permitted next action on each card. In lecture creation, explicitly state whether attendance will include one selected section or all course sections, with the eligible-student count before opening.
- **Acceptance:** A doctor can distinguish an editable lecture from a TA-owned draft before tapping; creating a section-specific or whole-course lecture clearly names its recipients. TA-only finalization remains enforced.

### DOC-02 — Protect policy edits and explain allocation choices

- **Action / priority:** Update / High.
- **Current behavior and evidence:** [PolicyPage:158](../../lib/features/grading.dart#L158) contains draft fields, save, and publication, but has no policy dirty-state exit guard like the attendance and gradebook editors. [grading.dart:245](../../lib/features/grading.dart#L245) offers “fixed grades” and “normalized aggregation” without a worked example; published policies are visibly locked and the backend rejects direct editing at [grading.py:63](../../server/grading.py#L63).
- **Doctor impact:** Unsaved policy work can be abandoned without the same warning other editors provide. The two allocation modes are easy to misunderstand when questions have different points or sections have different assessments.
- **Desired behavior:** Add save/discard/cancel handling for unsaved policy changes and short numerical examples beside the allocation modes. Retain the explicit publication lock and explain its consequence before confirmation.
- **Acceptance:** Leaving a changed draft requires a deliberate choice, cancel retains edits, and a small example shows how the same assessment results produce a category total under each mode. A published policy remains protected.

### DOC-03 — Preview the full publication scope and readiness

- **Action / priority:** Update / High.
- **Current behavior and evidence:** The gradebook saves 50-row pages, and the publication prompt at [grading.dart:562](../../lib/features/grading.dart#L562) only says saved results will be published. [grading.py:257](../../server/grading.py#L257) publishes every stored result for the assessment, not just the visible page. Current unsaved-change and pending-republication notices are already implemented.
- **Doctor impact:** I need to know whether I am publishing one page, one section, or all sections, and whether some students still lack results.
- **Desired behavior:** Before publishing, show the assessment, course/section scope, total eligible students, recorded/excused/unrecorded counts, saved changes awaiting republication, and whether this is an initial publication or correction. Use whole-assessment counts, not current-page counts.
- **Acceptance:** Preview totals match the full authorized assessment roster even on page two. Incomplete results are visible before the doctor confirms; already implemented save guards and old published snapshots remain intact.

### DOC-04 — Add an audited attendance correction and excuse review process

- **Action / priority:** Add / High.
- **Current behavior and evidence:** Finalized section attendance is immutable in the ordinary workflow at [attendance.py:252](../../server/attendance.py#L252); closing a lecture creates absences for remaining eligible students at [attendance.py:281](../../server/attendance.py#L281). [FEATURE_STATUS.md](../FEATURE_STATUS.md) explicitly defers finalized-attendance correction and student excuse requests.
- **Doctor impact:** A legitimate attendance mistake or accepted excuse currently has no in-app review process after closure/finalization.
- **Desired behavior:** Introduce a separate correction request with student/session, old status, requested status, reason, requester, and doctor decision. State who may approve each session type as a project-owner policy choice. Preserve the original history and explain effects on attendance and grades.
- **Acceptance:** A permitted request can be approved or rejected with a recorded reason; unauthorized users cannot approve it; repeated processing cannot apply it twice; report/grade effects follow the agreed policy. Finalization does not become unrestricted editing.

### DOC-05 — Add a scoped staff audit-history viewer

- **Action / priority:** Add / Medium.
- **Current behavior and evidence:** [core.py:89](../../server/core.py#L89) writes audit records, including before/after values and reasons where supplied; grade corrections use this at [grading.py:246](../../server/grading.py#L246). The viewer is deferred in [FEATURE_STATUS.md](../FEATURE_STATUS.md).
- **Doctor impact:** I cannot inspect who saved, finalized, corrected, or published a record from the app when resolving an academic dispute.
- **Desired behavior:** Provide a doctor-authorized history view filtered by course, student, date, action, and staff member. Explain entries in Arabic and show reasons and before/after values when available. Keep it read-only.
- **Acceptance:** Only permitted records are visible; an existing published-grade correction can be traced to its actor, time, reason, and values. Users cannot delete or rewrite audit entries.

### DOC-06 — Add question editing and archiving with preserved quiz snapshots

- **Action / priority:** Add / Medium.
- **Current behavior and evidence:** [QuestionBankPage:229](../../lib/features/quizzes.dart#L229) supports viewing and adding questions, including correct answers, but no edit/archive controls. The backend copies question and option snapshots into a quiz at [quizzes.py:107](../../server/quizzes.py#L107). Editing/archive is explicitly deferred.
- **Doctor impact:** A typo or outdated question cannot be corrected or removed from future selection through the UI; adding replacements leaves the old item available.
- **Desired behavior:** Let authorized staff revise future bank content or archive a question, with a reason and clear warning that existing quizzes retain their saved versions. Prefer archive to destructive deletion.
- **Acceptance:** An archived question is excluded from new quiz selection. Updating a bank question never changes an existing quiz, submitted answer, score, or audit history.

### DOC-07 — Correct wording that implies manual question selection

- **Action / priority:** Update / High.
- **Current behavior and evidence:** The [preparation screenshot](../../screenshots/refined/quiz-preparation.png) says to choose the section and questions, but [QuizCreatorPage:389](../../lib/features/quizzes.dart#L389) only asks for a question count. The backend randomly samples the bank at [quizzes.py:101](../../server/quizzes.py#L101). The staff quiz list opens a gradebook; it does not offer a staff preview of the quiz's saved questions.
- **Doctor impact:** “Choose questions” suggests a control that is not available; I could assume I have selected the assessment content when I have only selected its size.
- **Desired behavior:** Make the current behavior explicit: the doctor selects a count, and the system randomly selects that many questions from the bank. This copy correction does not require a new quiz-selection workflow. Optional preview and manual selection are separate in `DOC-12`.
- **Acceptance:** The screen states random selection before saving/opening and never implies that the current count field chooses specific questions. Existing draft/scheduled/immediate behavior is preserved.

### DOC-08 — Add a compact report view and spreadsheet export

- **Action / priority:** Add / Medium.
- **Current behavior and evidence:** The mobile [student report](../../screenshots/refined/student-report.png) has readable cards, search, and PDF/print actions. [reports.dart:99](../../lib/features/reports.dart#L99) renders the same per-student card approach and supports 25-row UI pages. CSV export is explicitly deferred; complete scoped PDF export already works.
- **Doctor impact:** Cards are useful on a phone, but comparing many students and preparing departmental spreadsheets requires more effort.
- **Desired behavior:** Keep mobile cards; add a compact desktop table with sorting and meaningful filters such as incomplete results or low attendance. Add CSV or an agreed spreadsheet format with clearly labelled scope and export semantics.
- **Acceptance:** Sorting/filtering never changes official values. Spreadsheet export matches the authorized roster and current published totals, preserves Arabic names and full university IDs, and distinguishes missing results from zero. The UI states whether export includes all scoped rows or only filtered rows.

### DOC-09 — Add controlled course metadata editing and TA reassignment

- **Action / priority:** Add / Medium.
- **Current behavior and evidence:** [courses.dart:42](../../lib/features/courses.dart#L42) permits doctor course creation, while course details and [settings.dart:57](../../lib/features/settings.dart#L57) show existing assignments without editing. [courses.py:69](../../server/courses.py#L69) implements creation; editing/reassignment remains deferred in the current status matrix.
- **Doctor impact:** Fixing a course label or replacing an assigned TA needs an external process, and staff may continue seeing an outdated assignment.
- **Desired behavior:** Add permitted metadata edits and a controlled reassignment flow with a before/after summary. The owner must decide whether the doctor or an administrator owns assignment approval. Preserve records and their original actors.
- **Acceptance:** After an authorized reassignment, the new TA sees the intended section and the previous TA loses that permission; existing attendance, quizzes, grades, and audit attribution remain unchanged. No account or historical record is deleted.

### DOC-10 — Make notifications lead to work and include useful staff events

- **Action / priority:** Update and Add / Medium.
- **Current behavior and evidence:** [settings.dart:23](../../lib/features/settings.dart#L23) places notifications under account/more actions. Clicking an item only marks it read at line 44. Current events focus on quizzes and published grades; TA action notifications are deferred in [FEATURE_STATUS.md](../FEATURE_STATUS.md).
- **Doctor impact:** I need a visible queue for saved grading work awaiting publication or other agreed staff review tasks, and a notification should take me to the relevant item.
- **Desired behavior:** Add an unread indicator and authorized deep links. Define a small staff event set, such as grades ready for doctor publication and correction requests awaiting decision, rather than notifying every save. Recheck scope when opening an old notification.
- **Acceptance:** A notification opens its permitted target and identifies the course/section. Revoked or outdated targets show a useful message, and repeated saves do not flood the doctor's queue.

### DOC-11 — Remove imported-data placeholder labels from user-facing academic copy

- **Action / priority:** Remove / Low.
- **Current behavior and evidence:** The [doctor dashboard](../../screenshots/refined/doctor-home.png) visibly displays `Imported semester 2` in the welcome panel, sourced directly from `course.term` at [dashboard.dart:60](../../lib/features/dashboard.dart#L60).
- **Doctor impact:** The import label feels like setup information and does not clearly identify the academic term.
- **Desired behavior:** Replace the displayed placeholder with an approved Arabic academic-term label, optionally with the year when known. Preserve stored legacy identifiers and genuine course codes/names. Do not invent a year that is absent from the data.
- **Acceptance:** User-facing screens and reports show the agreed term label; existing imports, course IDs, and relationships continue to resolve. This removes obsolete copy, not academic data or useful features.

### DOC-12 — Optionally add staff preview of saved quiz content

- **Action / priority:** Add / Medium; separate owner decision from the `DOC-07` copy correction.
- **Current behavior and evidence:** Quiz creation fixes question/option snapshots at [quizzes.py:107](../../server/quizzes.py#L107). The staff list opens the gradebook at [quizzes.dart:151](../../lib/features/quizzes.dart#L151), while the creator offers a count rather than selecting individual bank questions.
- **Doctor impact:** I cannot inspect the specific questions, keys, and total points that a prepared quiz will deliver before launch.
- **Desired behavior:** If selected, provide a staff preview of the saved draft snapshot. Explicit manual bank-question selection is a further optional capability; the owner can approve preview while retaining random selection.
- **Acceptance:** A preview shows exactly the saved prompts/options/keys/points that students will receive, never creates a student attempt, and does not expose answer keys to students. If manual selection is also approved, selected IDs and ordering are preserved in the snapshot.

## What I want first

“First, clarify my responsibility and lecture recipients (`DOC-01`), show a full publication preview (`DOC-03`), and correct the question-selection wording (`DOC-07`). Protecting policy edits (`DOC-02`) belongs in the same short usability pass. I would like saved-quiz preview (`DOC-12`) next if the owner approves it. Attendance corrections (`DOC-04`) matter for real operations but require an agreed approval policy. The remaining additions can follow after the owner chooses their scope.”

These are proposals awaiting the project owner's selection. They are not instructions to implement all twelve, and the review does not recommend deleting student records, attendance history, published results, or audit evidence.
