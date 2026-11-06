# Project review and three-role acceptance work plan

Follow-up status: [Phase 4 audit](review/phase4-audit.md) and
[Phase 5 verification](docs/PHASE5_VERIFICATION.md) reflect current changes.
The role matrices below preserve the original acceptance run and its findings.

The later [UI/UX pass](docs/UI_UX_REVIEW.md) adds role dashboards, TA section
workspaces, attendance navigation/review, guarded edits, quiz feedback and
account-specific preferences. Its verification is recorded separately.

This is the shared work plan for the graduation demo. It combines the technical
reviews on 2026-10-31 with active doctor, TA and student acceptance testing on
2026-11-01. Confirmed defects and requested additions are pending implementation.

The role agents exercised real HTTP APIs and the Flutter release web app in
separate Chrome sessions and isolated PostgreSQL databases. TA form checks were
also exercised through retained Flutter component tests. Production source and
real operational records were preserved during this testing phase.

Detailed role coverage and requests:

- [Doctor feedback](review/doctor-role-feedback.md)
- [TA feedback](review/ta-role-feedback.md)
- [Student feedback](review/student-role-feedback.md)
- [Machine-readable scenario summary](review/role-test-summary.json)
- [Reproduction commands and test harness](tool/role_checks/README.md)

## Active role-test results

| Role | API | Chrome | Component / other | Total |
|---|---|---|---|---:|
| Doctor | 72 PASS / 3 FAIL | 26 PASS / 2 FAIL | — | 103 |
| TA | 64 PASS / 3 FAIL | 16 PASS / 1 FAIL / 6 INCOMPLETE | 5 PASS / 1 FAIL; one native-camera item not applicable to the TA role | 97 |
| Student | 77 PASS / 2 FAIL | 44 PASS / 1 FAIL | One full-history percentage comparison failed | 125 |

Across the three matrices: 325 recorded scenarios, 304 PASS, 14 failing
scenarios, six incomplete Chrome checks, and one physical-device item outside
the TA's available features. Failing scenarios overlap across roles and are not
14 different bugs. The student also passed five focused login rechecks and the
same five at 320×640; those overlapping checks are kept separate from this total.

All current role features were exercised through API, browser and/or component
checks. The six TA Chrome form/scroll checks marked INCOMPLETE still need a final
browser walkthrough; their corresponding API/component behavior was tested
separately. Native camera decoding, Android/iOS permissions and secure storage,
physical networking, and native keyboard/lifecycle behavior remain manual checks.

### Login outcome

No confirmed authentication bypass or incorrect valid-credential behavior was
found. All three roles passed valid/invalid/blank login, account/role rejection,
session restoration and expiry, logout/revocation, and offline feedback checks
at the layers recorded in their matrices. Username case and outer whitespace
normalize; password case and whitespace remain significant. The student can use
university ID 20720236007 or actual username ahmd_1478. Password reveal/hide and
student → doctor → student account switching were exercised in Chrome.

Early browser failures were traced to off-screen accessibility activation,
ambiguous locators, and typing before Flutter's editing focus settled. They are
test-harness problems, excluded from confirmed application findings.

## One repair backlog

These eleven items combine the earlier technical review and role feedback. Each
has one ID even when multiple actors observed it. New findings from the role
tests are BUG-09, BUG-10 and the low-impact visibility decision BUG-11.

| ID | Priority | Fix / decision | Acceptance criterion | Evidence |
|---|---|---|---|---|
| BUG-01 | High | Restrict TA access to shared lecture rosters | Direct lecture detail returns only the TA's assigned students or rejects the request; other-section students never appear | server/attendance.py:21,93; API and TA review |
| BUG-02 | High | Make initial grade writes respect revisions atomically | Two simultaneous revision-0 writes produce one success and one 409; no silent overwrite | server/grading.py:228; doctor API |
| BUG-03 | Medium | Finalize abandoned expired quiz attempts on the server | Leaving the app after autosave still produces a timed-out attempt and grade result; only pre-deadline answers are scored | server/quizzes.py:164,202; all role feedback |
| BUG-04 | Medium | Require a reason for every correction to a previously published grade | First correction and later draft corrections without a reason return 422 while publication history exists | server/grading.py:231; doctor/TA APIs |
| BUG-05 | Medium | Include applicable shared lectures in section reports | Selected-section report and attendance list agree about a closed shared lecture | server/grading.py:312; doctor API |
| BUG-06 | High | Preserve roster search input and focus during loading | Continuous multi-character typing and retry retain search text/focus and return the correct scoped results | lib/features/courses.dart:189,198; doctor/TA Chrome |
| BUG-07 | Medium | Apply fresh policy publication state after refresh | A remotely published draft becomes read-only after refreshing the already-open editor | lib/features/grading.dart:162; earlier Flutter reproduction |
| BUG-08 | Medium | Make excuse checkbox match numeric grade entry | Typing a recorded grade into an excused row clears the displayed excuse and saves the same state | lib/features/grading.dart:468,476; TA component acceptance |
| BUG-09 | High | Calculate attendance from complete eligible history | More than 100 sessions remain reachable, and displayed percentages use the same full eligible denominator as grades | server/attendance.py:79; lib/features/attendance.dart:19,36; student API/history comparison |
| BUG-10 | Medium | Preserve the manual QR panel through loading/error/retry | Invalid/expired submissions leave manual entry expanded with its text available; valid and duplicate retries remain usable | lib/features/attendance.dart:427,428; student Chrome |
| BUG-11 | Low / visibility decision | Align student draft-session detail visibility with listing rules | Hide own draft details consistently, or explicitly define and display an allowed draft-preview state; never expose staff rosters | server/attendance.py:13,63,83; student API |

BUG-11 exposed only an enrolled student's own draft title/time and an empty own
record. It was not a cross-student roster/result leak. BUG-07 remains from the
earlier technical reproduction; a newly opened published-policy screen passing
does not exercise refreshing an editor that was already open as a draft.

## Added student findings: reproduction details

Student history contained 103 eligible lectures. The latest-100 response made
the UI calculation 100%, while complete finalized attendance was 99.0291%.
Add paginated history and a server-derived summary shared with the grading
calculation; do not calculate the overall rate from one page of rows.

For manual QR entry, expand the panel, submit an invalid payload, and wait for
the error. The busy indicator inserted before the unkeyed ExpansionTile changes
its identity and collapses the panel. The text controller survives, and valid,
duplicate and closed-code checks succeeded after reopening. Preserve expansion,
widget identity and focus through submission rather than requiring that step.

## Shared demo identifiers

| Item | Value |
|---|---|
| Course / offering | CS381 / 1 |
| Course-section ID / exact label | 1 / سكشن 1 (SE) |
| Doctor | doc_rasha01 |
| TA | ta_nehad00 |
| Student university ID / actual username | 20720236007 / ahmd_1478 |
| Student enrollment | 31 |
| Displayed term / stored term code | Imported semester 2 / legacy-semester-2 |

Default scopes differ: the TA initially opens AI section 5, and the doctor's and
student's first courses also differ. Select CS381 and the exact SE section before
the shared demo; repeated section numbers across departments are ambiguous.

## Requested additions and updates

These are role-agent requests and original-plan gaps, separate from failed
implementation tests. They are merged here so common requests become one task.
Priorities below are suggestions for the graduation demo; rubric-dependent
features should be selected before implementing the larger additions.

| ID | Type / priority | Requested change | Roles / source requests | Completion criterion |
|---|---|---|---|---|
| ADD-01 | Add / Medium | Password change and account recovery | All three roles; doctor DC-A4, TA request 6, student password request | Users can change/recover credentials through an authorized flow, with appropriate session revocation and clear errors |
| ADD-02 | Add / rubric-dependent | Audited finalized-attendance correction and student excuse/review requests | Doctor DC-A2, TA request 2, student attendance-review request | Staff correction requires a reason and preserves actor/time/old/new values; student requests require approval and never permit direct editing |
| ADD-03 | Add / rubric-dependent | Explicit grading-policy revisions after publication | Doctor DC-A3; original planned workflow | Preserve published policy/results while a new version is drafted, validated, previewed and approved |
| ADD-04 | Add + update / Medium | Saved attendance drafts, unsaved-change warnings, and pending-republication indicators | TA request 1, doctor DC-U1 | Draft attendance survives leaving/reloading; teacher sees unsaved grades and pending corrections; publication clearly handles saved versus unsaved values |
| ADD-05 | Add + update / Medium | Question editing/archive and flexible two-to-six option counts | Doctor DC-A5, TA request 3 | Editing unused questions is possible, archived items do not feed new quizzes, and existing quiz snapshots remain unchanged |
| ADD-06 | Add / Medium | Prepare, schedule and explicitly close/cancel quizzes | Doctor DC-A5 | Teachers can manage quiz lifecycle with enforced server times, clear student availability, stable snapshots and correct notifications |
| ADD-07 | Add / Medium | Useful attendance/grade reports, export/print and audit-history view | Doctor DC-A1, TA request 5; original report gaps | Per-student reports include IDs, attendance totals/statuses and appropriate grades; exports/history enforce the same role/section scope as UI |
| ADD-08 | Update / Low | Remember permitted course/section and theme; add direct TA section shortcuts | Doctor DC-U2, TA request 4, student preference request | Restore only a scope still allowed for the signed-in user, preserve theme, and provide section attendance/grade shortcuts |
| ADD-09 | Update / Medium | Explain incomplete grades and pending publication | Student pending-grade request, doctor DC-U1 | Show which permitted workflow is pending, with clear saved/published state; do not expose unpublished answer keys or other students' data |
| ADD-10 | Update / Medium | Refresh completed quiz results and clarify expired/closed quiz cards | Student completed-result and expired-quiz requests | Publication while a result screen is open can be refreshed; expired never-started quizzes have a clear closed state instead of futile retry |
| ADD-11 | Add / rubric-dependent | Relevant TA workflow notifications | TA request 6 | Notify assigned TAs of agreed review/action events, with recipient isolation and appropriate navigation |
| PLAN-01 | Add / rubric-dependent | Course editing and TA reassignment | Original requirements; doctor noted these are absent | Update authorized assignments through an audited flow, preserve historical actors, and apply current permissions correctly |

The seven doctor requests, seven TA requests, and seven student requests are
preserved in their linked reports. Documentation requests are included below.
A fresh published-policy page passing is expected; ADD-03 introduces a new
workflow and does not replace fixing the stale editor refresh in BUG-07.

## Setup, documentation and scope gaps

| ID | Work | Acceptance |
|---|---|---|
| DOC-01 | Make a standalone checkout reproducible | Document copying database/.env.example to ignored .env, configuring local credentials, importing the checked-in seed without the legacy project, applying API migrations, and starting the app. Regeneration is optional. Record supported SDK requirements and explain that seed fingerprint verification is an initial snapshot check |
| DOC-02 | Write the exact shared three-role runbook | Use CS381 / section ID 1 / SE1; distinguish ahmd_1478 from alternate ID20720236007 and term display name from code. Use separate sessions and verify persisted results after restart |
| DOC-03 | Publish an implemented/deferred rubric matrix | Track reassignment, policy revisions, attendance corrections, audit viewing, exports and account recovery explicitly. Existing assignments are read-only, policies locked, finalized attendance immutable and reports currently counts |
| DOC-04 | Establish a reliable cold-start offline demo | Decide whether to bundle renderer/font assets or rehearse an alternative with the required assets already available. API-offline error tests do not prove first-load offline Arabic rendering; Chrome fetched Google font assets |

Original planning evidence is the sibling legacy project's
docs/02-product-requirements.md:9. The initial academic term has no sourced
year/dates, and the SQL Server backup history is still not imported. Do not
invent academic dates, GPA values or operational history to fill empty screens.

## One coordinated implementation plan

| Batch | Backend / database work | Flutter work | Documentation / validation | Finish condition |
|---|---|---|---|---|
| 1: access and grade integrity | BUG-01, BUG-02, BUG-04 | Preserve explicit scope and show conflicts/reasons consistently | Retain negative-scope and concurrent-write regressions | No unauthorized TA roster; one authoritative initial grade write; all published corrections audited |
| 2: role workflow UI | Support any required response contracts | BUG-06, BUG-07, BUG-08, BUG-10 | Re-run browser/component regressions and complete the six TA automation gaps | Search and QR retry retain input; policy refresh and excuse state match server/submission |
| 3: attendance and quiz correctness | BUG-03, BUG-05, BUG-09; resolve BUG-11 policy | Consume full-history summaries/pagination and correct workflow states | Test more than 100 sessions, abandoned deadlines and selected-section reports | Display, grades and reports agree; leaving the app cannot leave a timed-out attempt unresolved |
| 4: selected demo additions | Agreed ADD/PLAN items with additive migrations where needed | Corresponding approved user flows | Update the rubric matrix and role acceptance criteria | Selected graduation requirements are implemented without losing published history or permissions |
| 5: package and rehearse | Reproducible setup, service/database persistence | Real browser/device walkthrough and release configuration | DOC-01 through DOC-04; manual checks below | Another checkout and the shared demo run succeed using documented settings |

Use one coordinated change set with three technical workstreams: API/database,
Flutter, and documentation/demo verification. Keep file ownership separate,
agree changed API contracts, then integrate and test the complete result before
calling the repair batch finished. This report is preparation for that work;
production fixes/additions have not been applied during the role-test phase.

## Shared demonstration sequence

Each role was tested against its own isolated database with counterpart actions.
The sequence below is the final shared rehearsal to perform after the repair
batch; it is not a claim that three simultaneous browser actors have already
rehearsed one shared production database.

1. Sign in separately as doctor, TA and student. Select CS381 and SE section 1.
2. Doctor saves a grading-policy draft with a normalized quiz category.
3. TA adds questions and creates the section quiz.
4. Doctor publishes the policy and opens a lecture.
5. Student checks in and completes the quiz with autosaved answers.
6. Doctor closes the lecture; TA finalizes section attendance.
7. Doctor publishes results; student verifies attendance, grades and notifications.
8. Restart the API and sign in again to verify persistence.
9. Repeat invalid login, session expiry, forbidden role actions, duplicate QR,
   stale grade edits and a failed-network retry to demonstrate actual safeguards.

Normalized allocation is appropriate for a single-section demo. Fixed budgets
must be allocated for every applicable course section before publication.

## Remaining manual and browser checks

- Finish the six TA browser form/scroll checks; retain their API/component results
  separately instead of describing them as a completed Chrome walkthrough.
- Scan the rotating QR using a real camera, with permission denial/re-grant,
  repeated detection, lighting/focus and app pause/resume.
- Exercise native Android/iOS storage, restart/reinstall, keyboard overlap,
  rotation, accessibility scaling, device back behavior and network changes.
- Verify actual PC-LAN/emulator addressing, firewall access, and release HTTPS
  configuration. The 320×640 Chrome login tests do not replace device testing.
- Rehearse all three roles in separate sessions against one shared demo database.

The final connected-device check found Windows, Chrome and Edge, with no mobile
device or emulator available. Camera and native mobile checks therefore remain
pending.

## Regression state and evidence preservation

The pre-existing database conversion and backend integration tests passed before
this acceptance phase. The new role checks uncovered the defects listed above.
The retained TA component test deliberately asserts the desired checkbox
behavior and fails until BUG-08 is repaired.

Final Flutter verification in this phase: analysis is clean; the full suite has
14 passes and one failure at test/roles/ta_role_test.dart:271 (the known excuse
checkbox mismatch). Do not describe the acceptance suite as fully green.

Reproduction commands and the sandbox's local renderer override are documented
in tool/role_checks/README.md. Reports keep safe result metadata; raw diagnostics
are under ignored .dart_tool/role-checks. Passwords/tokens are not retained in
scenario results. The role databases were temporary, and the main application's
operational records were preserved.

The final isolated Chrome smoke test passed after the helper teardown update.
The [read-only cleanup audit](review/cleanup-audit.json) confirms no role-test or
API-test databases remain and the main API is healthy.
