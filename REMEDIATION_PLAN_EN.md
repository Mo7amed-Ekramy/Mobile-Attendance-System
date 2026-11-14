# Comprehensive Remediation and Enhancement Work Plan
## Smart Attendance System — Assiut National University

This work plan is formulated based on the technical review and three-role acceptance testing (Doctor, TA, Student) recorded in `PROJECT_REVIEW.md`. It provides a prioritized, step-by-step engineering roadmap to resolve all confirmed defects, implement requested enhancements, and verify a production-ready graduation demo.

**Current gate (2026-11-01): Phase 4 is partial.** Password update passes its
focused checks; attendance draft saving, quiz scheduling/cancellation and report
export/printing are unfinished. See [Phase 4 audit](review/phase4-audit.md).
Phase 5 verification and documentation are recorded separately in
[PHASE5_VERIFICATION.md](docs/PHASE5_VERIFICATION.md); passing tests alone does
not mark those missing features complete.
The follow-up completed 19 Flutter tests, 11 backend journeys, six optional seed
tests, clean analysis, a release JavaScript build and a 12-check shared rehearsal.
Native/manual coverage and fully offline cold startup remain open gates.

---

## 1. Prioritized Roadmap and Phases

| Phase | Scope | Objectives & Deliverables |
|---|---|---|
| **Phase 1: Access Scopes & Data Integrity (Backend Core)** | `BUG-01`, `BUG-02`, `BUG-04` | Restrict TA shared lecture access, enforce atomic concurrency on grade writes, and require audit reasons for corrections on published grades. |
| **Phase 2: Role Workflow UI Fixes (Flutter UI)** | `BUG-08`, `BUG-06`, `BUG-07`, `BUG-10` | Synchronize excuse checkbox with numeric entry (fixing test failure), preserve search focus/text, reload policy publication state, and stabilize manual QR card. |
| **Phase 3: Attendance, Reports & Quiz Correctness (System Logic)** | `BUG-09`, `BUG-05`, `BUG-03`, `BUG-11` | Calculate attendance rates from complete session history, include shared lectures in section reports, and auto-finalize expired quiz attempts on server. |
| **Phase 4: Key Graduation Demo Additions (Features)** | `ADD-04`, `ADD-06`, `ADD-07`, `ADD-01` | Saved attendance drafts, explicit quiz scheduling/closing, printable/exportable grade & attendance reports, and password management. |
| **Phase 5: Verification, Documentation & Demo Runbook** | `DOC-01`, `DOC-02`, `DOC-03`, `DOC-04` | Execute automated test suites (`flutter test`, backend unit tests), verify zero analysis warnings, and document the three-role demo runbook. |

---

## 2. Step-by-Step Task Breakdown & Acceptance Criteria

### Phase 1: Access Scopes & Data Integrity (Backend Core)
1. **BUG-01: Restrict TA Access to Shared Lecture Rosters**
   - **Target File**: `server/attendance.py` (lines 21, 93).
   - **Issue**: Direct request for lecture details returns all enrolled students (410+ across other sections), leaking students not assigned to that TA.
   - **Remediation**: Filter shared lecture rosters to return only students enrolled in the sections assigned to the authenticated TA, or return 403 Forbidden if the TA is unassigned.
   - **Acceptance Criterion**: Direct lecture queries by a TA never expose students belonging to other sections.

2. **BUG-02: Enforce Atomic Revision Checking on Initial Grade Writes**
   - **Target File**: `server/grading.py` (line 228).
   - **Issue**: Two simultaneous writes with revision 0 both succeed, leading to silent overwrite and state divergence.
   - **Remediation**: Execute atomic update with explicit revision predicate (`WHERE revision = expected_revision`) returning `409 Conflict` on concurrent collisions.
   - **Acceptance Criterion**: Concurrent writes allow exactly one success while the conflicting writer receives 409 and reloads before editing.

3. **BUG-04: Enforce Mandatory Audit Reasons for Published Grade Corrections**
   - **Target File**: `server/grading.py` (line 231).
   - **Issue**: When an assessment has previous publication history, subsequent draft corrections without a reason were accepted with a null audit entry.
   - **Remediation**: Validate that if publication history exists for the assessment, a non-empty `reason` string is strictly required; return `422 Unprocessable Entity` if missing.
   - **Acceptance Criterion**: No grade edit on published assessments can be saved without an auditable reason recorded in the database.

---

### Phase 2: Role Workflow UI Fixes (Flutter UI)
4. **BUG-08: Synchronize Excuse Checkbox with Numeric Grade Entry**
   - **Target File**: `lib/features/grading.dart` (lines 468, 476).
   - **Issue**: Entering a numeric grade for an excused row saves the numeric state but leaves the checkbox checked; triggers failure in `test/roles/ta_role_test.dart:271`.
   - **Remediation**: In `setState`, when any valid numeric grade is input, explicitly uncheck and reset `excused = false`.
   - **Acceptance Criterion**: `flutter test` achieves 100% pass rate with zero test failures.

5. **BUG-06: Preserve Search Input and Focus during Roster Loading**
   - **Target File**: `lib/features/courses.dart` (lines 189, 198).
   - **Issue**: Continuous typing in student roster search loses input text and focus when the loading indicator remounts the subtree.
   - **Remediation**: Position the search `TextField` outside the rebuilding loading subtree, retain a persistent `TextEditingController`, and debounce queries.
   - **Acceptance Criterion**: Typing rapidly continuously filters results without losing focus or dropping keystrokes.

6. **BUG-07: Apply Fresh Policy State upon Editor Refresh**
   - **Target File**: `lib/features/grading.dart` (line 162).
   - **Issue**: An already-open policy editor remains editable as a draft even after remote publication because `_initialized` prevents re-initialization.
   - **Remediation**: Re-evaluate publication status on reload/pull-to-refresh and convert form controls to read-only when published.
   - **Acceptance Criterion**: Refreshing an open draft editor immediately transitions it to a locked, read-only published view.

7. **BUG-10: Preserve Manual QR Input Card across Error and Retry**
   - **Target File**: `lib/features/attendance.dart` (lines 427, 428).
   - **Issue**: Submitting an invalid or expired code collapses the manual input `ExpansionTile`.
   - **Remediation**: Provide a stable `GlobalKey` or maintain explicit expanded state across submission and retry states.
   - **Acceptance Criterion**: Erroneous submissions display the error while keeping the manual input field expanded and focused.

---

### Phase 3: Attendance, Reports & Quiz Correctness (System Logic)
8. **BUG-09: Compute Attendance Rates from Complete Historical Record**
   - **Target Files**: `server/attendance.py` & `lib/features/attendance.dart`.
   - **Issue**: Sessions exceeding 100 entries caused page-1 calculations to report skewed percentages (e.g., 100% instead of 99.029%).
   - **Remediation**: Return a server-derived cumulative summary for overall course attendance alongside paginated session rows.
   - **Acceptance Criterion**: Displayed student attendance rates match full historical records and grading calculations exactly.

9. **BUG-05: Include Applicable Shared Lectures in Section Reports**
   - **Target File**: `server/grading.py` (line 312).
   - **Issue**: Section reports omitted shared lectures attended by the section, causing discrepancy with the attendance log.
   - **Remediation**: Query all eligible lecture sessions enrolling students of the selected section and include them in section statistics.
   - **Acceptance Criterion**: Section attendance logs and aggregated section reports show identical session counts.

10. **BUG-03: Finalize Abandoned Expired Quiz Attempts on the Server**
    - **Target File**: `server/quizzes.py` (lines 164, 202).
    - **Issue**: Closing the app without clicking submit leaves expired attempts in an indefinite in-progress state.
    - **Remediation**: Automatically close and evaluate expired attempts during queries or background checks, scoring answers submitted before the deadline.
    - **Acceptance Criterion**: Expired quizzes automatically record final scores without requiring manual student action.

11. **BUG-11: Align Student Draft Session Visibility Rules**
    - **Target File**: `server/attendance.py`.
    - **Remediation**: Hide draft attendance sessions from students until officially opened by the instructor.

---

### Phase 4: Key Graduation Demo Additions (Features)
12. **ADD-04**: Draft saving for attendance and grades with unsaved-change prompts before navigating away.
13. **ADD-06**: Active quiz controls (schedule, early close, cancel) with live countdowns.
14. **ADD-07**: Printable and exportable attendance/grades reports per section.
15. **ADD-01**: Secure in-app password update and credential verification.

---

### Phase 5: Verification, Documentation & Demo Runbook
16. **DOC-01**: Comprehensive standalone setup guide with `.env` configuration and PostgreSQL database initialization.
17. **DOC-02**: Exact three-role demonstration runbook for graduation defense using course `CS381` and section `SE 1`.
    - [Runbook and offline preparation](docs/DEMO_RUNBOOK.md).
    - **DOC-03**: [Implemented/deferred feature matrix](docs/FEATURE_STATUS.md).
    - **DOC-04**: Verify renderer/font availability before the demo; fully offline cold startup remains a separate gate.
18. **Final Full Suite Validation**:
    - `flutter test` (100% passing tests).
    - `.\server\.venv\Scripts\python.exe -m unittest discover -s server -p 'test_*.py' -v` (run from project root).
    - `flutter analyze` (Zero errors, zero warnings).


2026-11-06 follow-up: attendance draft persistence, quiz scheduling/preparation/
cancellation, independent attempt expiry and PDF student reports are implemented.
Current validation and remaining manual/deferred scope are recorded in
[UI_REFINEMENT.md](docs/UI_REFINEMENT.md).
