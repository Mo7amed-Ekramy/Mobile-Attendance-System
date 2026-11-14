# Teaching assistant review — current UI and workflows

Date: 2026-11-06. **Simulated TA persona**, not an interview with a real teaching assistant. This review makes recommendations for the owner to choose; no application, database, or account changes were made.

I used the [UI/UX design skill](../../.agent/skills/ui-ux-designer/SKILL.md) and [visual validation skill](../../.agent/skills/ui-visual-validator/SKILL.md). I inspected the saved screenshots and current source, and read [current refinement evidence](../UI_REFINEMENT.md) and [feature status](../FEATURE_STATUS.md). Historical role reviews were not treated as the current implementation.

## Visual assessment

From the visual evidence, I observe... an Arabic RTL mobile dashboard with a persistent course/section selector, an ivory background, a brown welcome panel, two prominent action cards, and readable student/session metrics. The [TA home screenshot](../../screenshots/refined/ta-home.png) shows `CS381 · سكشن 1 (SE)` and a third metric beginning below the visible area. Actual follow-up work sits farther down the page. This is ordinary scrolling, not proof of a broken layout; as a TA, I would prefer my unfinished roster ahead of decorative welcome content.

The [attendance draft](../../screenshots/refined/attendance-draft.png) visibly distinguishes present, absent, excused, and unmarked counts, offers search and an unmarked-only filter, and shows that one saved present mark can coexist with 22 unmarked students. The saved-state notice and disabled save button explain why another save is unnecessary. A temporary snackbar overlaps the bottom action area in this captured frame; the frame alone does not prove that finalization is persistently inaccessible.

The [quiz preparation](../../screenshots/refined/quiz-preparation.png) clearly separates opening now, scheduling, and saving a hidden draft. The [student report](../../screenshots/refined/student-report.png) distinguishes incomplete results from zero and gives PDF/print actions a pinned footer. The [mobile login](../../screenshots/refined/login-400.png) has clear labels and a visible password toggle.

**Judgment:** visual hierarchy and Arabic task labels are largely achieved in these captured states; daily-work prioritization is only partially achieved for this persona. Dynamic error states, keyboard/screen-reader interaction, and physical-device operation were not tested in this review. The compact attendance chips warrant actual touch-target and focus testing; appearance alone does not establish accessibility compliance.

## What I want first, as the TA

> “Help me finish the correct section's roster without overwriting marks I already entered. Before approval, show me exactly what becomes official. If another staff member changed the same grades, preserve my work and explain the conflict. Let me control the questions students receive, and clearly tell the doctor when my grading is ready.”

Priority means **High** for academic-record correctness or assessment control, **Medium** for recurring task efficiency, and **Low** for optional copy/presentation cleanup. Source-backed risks below were found by reading the implementation, not by running a new live failure test.

## Requested updates, additions, and removals

### TA-01 — Update · High — Make bulk absence marking preserve existing decisions

- **Current behavior/evidence:** [attendance.dart](../../lib/features/attendance.dart#L393) confirms “تحديد الجميع غائب” and then sets **every row** to absent, including previously present/excused students and rows hidden by search or the unmarked-only filter. A confirmation exists, but it says that present students can be adjusted afterward.
- **Impact:** a TA who already marked attendance can accidentally overwrite correct decisions while trying to finish the remaining students. This is a source-backed overwrite risk, not a claim that stored official records were corrupted.
- **Wanted behavior:** default to “تحديد غير المحدد غائب”; preserve existing decisions. Show the number and scope of affected students, and provide undo before saving. If replacement of all marks is retained, place it in a separate explicit action with clear wording.
- **Acceptance:** with one present, one excused, and three unmarked students, bulk completion changes only those three; filtering does not silently change the action's scope; undo restores the previous draft marks.

### TA-02 — Update · High — Make final roster approval an explicit review

- **Current behavior/evidence:** [attendance.dart](../../lib/features/attendance.dart#L335) enables approval after every eligible student is marked, but its confirmation only says all statuses will be saved. The detail header shows session title and student count at [line 369](../../lib/features/attendance.dart#L369), without repeating course/section/term. The backend makes the finalized roster immutable in the current workflow; correction is deferred in [feature status](../FEATURE_STATUS.md).
- **Impact:** I need to verify the academic scope, counts, and consequences immediately before an irreversible daily operation, particularly when multiple sections have similar session names.
- **Wanted behavior:** show course code, section and department, date/session title, present/absent/excused totals, and the fact that later corrections require an approved correction process. Keep the existing complete-roster requirement.
- **Acceptance:** approval from a searched/filtered list still reviews the entire eligible roster; counts match submitted rows; cancel preserves the draft; the dialog identifies the exact section and states the current correction limitation.

### TA-03 — Update · High — Preserve local attendance/grade edits on revision conflicts

- **Current behavior/evidence:** attendance revision checks correctly reject stale writes at [attendance.py](../../server/attendance.py#L230), but recovery tells the user to refresh. Grade saving explicitly calls `reload()` on HTTP 409 at [grading.dart](../../lib/features/grading.dart#L553); newly loaded rows reset the input controllers at [line 495](../../lib/features/grading.dart#L495). [RemotePage.reload](../../lib/widgets/common.dart#L94) itself does not call the discard guard. Ordinary navigation/refresh guards already exist and should be retained.
- **Impact:** a concurrency rejection protects server records but can replace my unsaved grade entries with loaded values without a conflict review. For attendance, a refresh requires abandoning or manually reconstructing conflicting work.
- **Wanted behavior:** preserve a local copy after a conflict; show affected students and local/server values; let me reload after an explicit choice or reapply nonconflicting changes against the latest revision. Never silently overwrite the newer server record.
- **Acceptance:** two sessions editing the same student produce a clear conflict; the stale session retains its input, exposes both values, and requires a decision before discard or resubmission. Unrelated edits remain recoverable.

### TA-04 — Update · Medium — Put unfinished work earlier on the TA dashboard

- **Current behavior/evidence:** [ta-home.png](../../screenshots/refined/ta-home.png) spends the first mobile viewport on welcome content, two actions, and metrics. [dashboard.dart](../../lib/features/dashboard.dart#L136) places “متابعة العمل” after those sections and limits its recent session cards to three.
- **Impact:** as a returning TA, continuing yesterday's saved roster is often more useful than starting a new one. This is a persona preference, not measured evidence of a time-saving benefit.
- **Wanted behavior:** surface a compact “استكمال كشف محفوظ” action and unfinished roster list above secondary metrics; retain the new-roster shortcut and course selector. If the list is limited, label it as recent and offer “عرض كل الكشوف غير المعتمدة”.
- **Acceptance:** at 400×900, a TA with a saved roster can identify a continuation action immediately; an older pending roster remains discoverable through the full list; empty-state content does not imply a pending roster exists.

### TA-05 — Add · High — Request an audited attendance correction

- **Current behavior/evidence:** finalized attendance corrections and student excuse requests are explicitly deferred in [feature status](../FEATURE_STATUS.md). Finalization at [attendance.py](../../server/attendance.py#L252) stores the complete official roster; the current UI becomes read-only afterward.
- **Impact:** legitimate mistakes or approved excuses need a defined route without recreating a session or asking for direct database changes.
- **Wanted behavior:** let the assigned TA request a correction for a specific student/session with a reason; the doctor reviews the proposed before/after status. Preserve the original record and an audit trail; recalculate official totals only after approval. This needs the owner's agreement on academic policy.
- **Acceptance:** unauthorized TAs cannot request another section's correction; rejected requests leave attendance unchanged; approved corrections show actor, reason, time, and old/new status; students see the updated official outcome.

### TA-06 — Add · High — Choose and preview quiz questions deliberately

- **Current behavior/evidence:** the creator says “اختر السكشن والأسئلة” at [quizzes.dart](../../lib/features/quizzes.dart#L365), but collects only a question count. [quizzes.py](../../server/quizzes.py#L98) samples that count randomly from the whole course bank. The current draft snapshots are correctly preserved.
- **Impact:** I cannot ensure the quiz covers the intended lesson, exclude an unsuitable question, or verify the maximum score before exposing it to students.
- **Wanted behavior:** offer explicit manual selection and an explicitly labeled random mode; preview chosen questions, answers, total points, section, and launch time before opening. Preserve immutable snapshots for quizzes that have started.
- **Acceptance:** manually selected question IDs match the delivered snapshot and displayed total; random mode says it is random; previewing does not open the quiz or notify students; questions cannot change beneath an active attempt.

### TA-07 — Update · Medium — Make the question bank maintainable

- **Current behavior/evidence:** [QuestionBankPage](../../lib/features/quizzes.dart#L229) lists all questions/options with an add button, without search or edit/archive controls. [QuestionEditorPage](../../lib/features/quizzes.dart#L277) uses four fixed choices. Editing/archive is deferred and the API's two-to-six-choice support is documented in [feature status](../FEATURE_STATUS.md).
- **Impact:** finding a reusable question and correcting a typo become difficult as the bank grows. Removing an old bank question must not alter a previous quiz.
- **Wanted behavior:** search, course-scoped edit and archive, and optional two-to-six choices. Keep archived questions out of future selection while retaining past quiz snapshots. Decide any doctor-review requirement before allowing shared-bank changes.
- **Acceptance:** a typo can be corrected for future quizzes without changing an existing snapshot; archived questions remain historically attributable; search finds a question in a larger bank; correct-answer selection stays valid when options are added/removed.

### TA-08 — Add · Medium — Find students directly inside the gradebook

- **Current behavior/evidence:** [GradebookPage](../../lib/features/grading.dart#L486) loads 50-row pages and renders score fields for every row, with no student search or unrecorded-only filter. A separate roster search already works and should not be rebuilt as a substitute for gradebook search.
- **Impact:** checking a student's score while they stand beside me requires paging through cards; incomplete grading is harder to locate.
- **Wanted behavior:** search by name or university ID and filter unrecorded/excused results inside the gradebook; keep explicit save and unsaved-change protection across search/filter/page transitions.
- **Acceptance:** search locates an authorized student beyond the first 50 rows; clearing a search restores the correct list; a transition cannot discard edits without a decision; blank and zero remain distinct.

### TA-09 — Add · Medium — Hand grading to the doctor with a visible status

- **Current behavior/evidence:** [grading.dart](../../lib/features/grading.dart#L100) correctly allows the TA to enter grades while only the doctor receives the publish control. In-app quiz/publication notifications exist, but TA action notifications and an agreed handoff flow are deferred in [feature status](../FEATURE_STATUS.md).
- **Impact:** after saving my section's grades, I still need another channel to tell the doctor that they are ready. “Saved” alone does not explain whether review/publication is pending.
- **Wanted behavior:** an explicit “جاهز لمراجعة الدكتور” handoff, scope and completion counts, doctor notification, and visible saved/awaiting-review/published status. Keep final publication with the doctor and let changes after handoff visibly require another review.
- **Acceptance:** handoff is allowed only after intended rows are saved; the doctor sees the exact assessment/section and incomplete counts; a TA cannot publish through the UI or API; revised grades are marked pending review again.

### TA-10 — Add · Medium — Extend reports with spreadsheet export

- **Current behavior/evidence:** [reports.dart](../../lib/features/reports.dart#L71) already implements PDF export and printing, with full-scope semantics explained in its notice. CSV export remains deferred in [feature status](../FEATURE_STATUS.md).
- **Impact:** a PDF is suitable for review/printing, but departmental spreadsheet reconciliation still needs manual copying.
- **Wanted behavior:** add UTF-8 CSV or an agreed spreadsheet format containing authorized students, stable identifiers, official attendance, and published grades. Explain whether export includes the whole section or a chosen filtered subset; keep PDF.
- **Acceptance:** Arabic names and university IDs open correctly in the target spreadsheet tool; export cannot include another TA's students; unrecorded/incomplete values stay distinct from zero; the exported row count matches the announced scope.

### TA-11 — Remove · Low — Replace raw legacy and misleading copy

- **Current behavior/evidence:** [ta-home.png](../../screenshots/refined/ta-home.png) visibly shows “Imported semester 2”. The quiz form's “اختر ... الأسئلة” wording implies selection that the current count/random flow does not provide, as detailed in TA-06.
- **Impact:** import terminology and inaccurate instruction distract from academic tasks and can mislead a new TA.
- **Wanted behavior:** remove raw import wording from normal UI and display the verified academic term in Arabic while preserving its stable stored code. Until TA-06 is selected for implementation, replace the quiz instruction with an accurate explanation of random selection by count.
- **Acceptance:** Arabic screens show a truthful academic term or neutral label, with no fabricated academic year; the quiz wording matches its actual mode. **No courses, questions, attendance, grades, or historical records are proposed for deletion.**

## Keep these parts

- Arabic/RTL navigation, university branding, ivory/brown palette, theme preference, and persistent scoped navigation.
- Saved partial attendance drafts, reload recovery, revision validation, and the complete-roster finalization requirement.
- Explicit present/absent/excused choices, search, unmarked-only filtering, counts, and pinned save/approval actions.
- Doctor-controlled publication, scoped TA permissions, published snapshots, and the distinction between unrecorded and zero.
- Quiz preparation/scheduling/cancellation and immutable question snapshots; these are implemented already.
- Complete authorized PDF reports and Arabic/Latin fonts; CSV would extend this feature, not replace it.

## Evidence limits and owner decisions

The earlier refinement report records 32 Flutter tests, 16 backend tests, and seven browser checks. Those are **past verification evidence**, not tests rerun by this reviewer. I did not log in, submit attendance, alter grades, or create a quiz during this review.

This review does not establish native camera, printer, mobile keyboard, screen-reader, or network-failure behavior. Test the actual target devices and assistive interaction before treating those areas as verified. Neither screenshots nor a persona simulation can prove how real TAs will perform; task ordering and added institutional workflows should be checked with a real TA after the owner chooses scope.

Suggested first selection: TA-01, TA-02, TA-03, and TA-06. TA-05 and TA-09 require agreement on approval responsibilities. The owner can approve, reject, or defer every item; this document authorizes no implementation.
