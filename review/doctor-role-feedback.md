# Doctor-persona feature testing and feedback

Tested on 2026-11-01 as doctor account doc_rasha01. This is a testing report;
production fixes are pending.

## Execution and scope

The retained checker is [doctor_check.py](../tool/role_checks/doctor_check.py).
Every run creates its own PostgreSQL database and real FastAPI HTTP server, routes
the existing release Flutter web app into that exact database, and uses an
independent headless Chrome context. The test databases and owned servers were
cleaned up. The real university_attendance database and production source were
preserved.

The shared teaching scope is **CS381, course offering 1, course section ID 1 =
SE section 1**. The counterpart student uses university ID 20720236007 (actual
username ahmd_1478, enrollment 31). Student/TA counterpart requests prepared
attendance and quiz results in the isolated environment; they are attributed as
fixture actions, not doctor permissions.

| Layer | Scenarios | Passed | Confirmed failures |
|---|---:|---:|---:|
| Actual HTTP API + PostgreSQL | 75 | 72 | 3 |
| Actual Chrome/Flutter UI | 28 | 26 | 2 |
| Total | 103 | 98 | 5 |

The final matrix combines the complete run with a focused rerun of the excuse
checkbox after allowing Flutter's state update to settle. Final results use
trusted keystrokes, the verified SE1 scope, and actual scrolling to gradebook
footer controls. Earlier harness diagnostics are excluded from product findings.

Raw scenario results: [doctor-api-results.json](doctor-api-results.json).
Despite its original filename, this file contains both API and browser results.

## Login feedback

**Doctor login and session handling passed all tested scenarios.**

The API rejected blank identifiers/passwords, wrong and unknown credentials,
password case/whitespace mismatches, SQL-like identifiers, anonymous requests,
invented/expired tokens, and disabled accounts. Username case and surrounding
whitespace are supported. Repeated failed attempts produced HTTP 429.

Chrome verified required-field messages, wrong-password feedback, a valid
uppercase/whitespace retry, the correct doctor home/navigation, reload restoring
the session, confirmed logout with server revocation, offline login feedback and
successful recovery, and automatic return to login after server session expiry.
No uncaught browser JavaScript errors occurred in the final journeys.

As a doctor I would request **password change/recovery** as an additional account
feature. The current local-demo login works; self-service recovery is absent.

## Confirmed fixes requested by the doctor

| ID | Priority | Problem and reproduction | Evidence | Acceptance |
|---|---|---|---|---|
| DC-F1 | P1 | Two first edits of the same missing grade both submit revision 0 and both succeed, allowing an overwrite | Real HTTP requests, with a test-only barrier immediately after both actual transactions read the missing row, returned 200/200; server/grading.py:228 | Exactly one write succeeds; the other returns conflict, with one authoritative grade/audit sequence |
| DC-F2 | P1 | Typing a roster search replaces the field with loading and loses text/focus | Actual Chrome typing; lib/features/courses.dart:189 and lib/widgets/common.dart:53 | Continuous multi-character typing works; retain the input/controller and debounce requests without removing search controls |
| DC-F3 | P2 | After one reasoned correction changes a published result to draft, a second correction can omit its reason | PATCH expected 422 but returned 200 while the published snapshot still existed; server/grading.py:231 | Every correction of a previously published result requires a reason until and after republication |
| DC-F4 | P2 | An excused student still appears checked as excused after entering a numerical grade | Actual Chrome toggle settled to checked, then numeric entry left the checkbox checked; lib/features/grading.dart:468 | Displayed excuse status immediately matches the recorded/unrecorded state and submitted score |
| DC-F5 | P2 | A shared closed lecture is visible in attendance but omitted from a selected section's report | All-course report counted it; section 1 report did not; server/grading.py:312 | Reports include shared lectures applicable to the selected section, consistently with attendance views and permissions |

## Add/update requests for the combined work plan

These are doctor-persona requests, not failed tests of advertised functionality.

| ID | Type / suggested priority | Doctor request | Completion criteria |
|---|---|---|---|
| DC-A1 | Add / P2 | Useful per-student attendance and grade report/export | Filter by course/section; include student ID, attendance status/totals and published grades; export/print using the same permission scope as the roster |
| DC-A2 | Planned missing workflow / rubric decision | Correct finalized attendance with a reason and audit history | Authorized correction flow preserves old/new statuses, reason, actor and time; reports/attendance totals update consistently |
| DC-A3 | Planned missing workflow / rubric decision | Create a new grading-policy revision after publication | Preserve current published policy/results; draft and validate a subsequent version through an explicit audited workflow |
| DC-A4 | Add / P2 | Change/recover an account password | Provide clear account recovery/change behavior and revoke or manage sessions appropriately |
| DC-A5 | Add / P2 | Edit/archive question-bank questions and prepare/schedule/close quizzes | Correct unused questions; preserve existing quiz snapshots; provide explicit preparation and lifecycle controls |
| DC-U1 | Update / P2 | Clear unsaved-grade and pending-republication indicators | Teacher can see unsaved edits and corrections awaiting publication; publication cannot silently ignore local edits without clear feedback |
| DC-U2 | Update / P3 | Remember selected course/section and theme | Restore a permitted prior teaching scope and chosen theme instead of always returning to the first course and light mode |

The original PROJECT_REVIEW.md also contains the externally refreshed policy-state
bug, TA isolation, and abandoned quiz expiry. Merge those with these requests,
rather than dropping existing findings because a fresh doctor page passed.

## Feature coverage and practical limits

All current doctor feature areas were exercised: login/session, home/navigation,
course/section selection, courses/search/creation, rosters/search/pagination,
teaching assignments, lecture creation/QR/closure, grading policies, assessments,
grades/corrections/publication, question bank, quizzes/results, notifications,
reports, theme, logout and persistence.

The browser created/closed a lecture, saved/published a policy draft, saved an
explicit zero grade, published assessment results, and saved a question.
Successful course, assessment, and quiz creation were tested through the real
HTTP API; their browser forms and required-field validation were exercised.
Policy publication used an API-created prerequisite shared assessment in the
isolated fixture. These layer distinctions are retained in the matrix.

Physical Android/iOS behavior and projecting/scanning the QR with real devices
were not tested by this doctor agent. Successful QR token generation, rotation,
student counterpart check-in, closure, and late rejection were tested against
the actual API; the QR controls were exercised in Chrome. The existing app does
not expose course editing, TA reassignment, policy revisions, attendance
corrections, question editing, quiz scheduling/cancellation or exports, so those
are proposed additions or original-plan gaps rather than executable current
features.

## Complete scenario matrix

| ID | Layer | Feature | Scenario | Result | Evidence |
|---|---|---|---|---|---|
| D001 | Real HTTP API | Login | Valid doctor credentials select doctor role | PASS | Verified |
| D002 | Real HTTP API | Login | Username case and surrounding whitespace | PASS | Verified |
| D003 | Real HTTP API | Login | Blank username rejected | PASS | HTTP 422 |
| D004 | Real HTTP API | Login | Blank password rejected | PASS | HTTP 422 |
| D005 | Real HTTP API | Login | Wrong password rejected | PASS | HTTP 401 |
| D006 | Real HTTP API | Login | Unknown username rejected | PASS | HTTP 401 |
| D007 | Real HTTP API | Login | Password case matters | PASS | HTTP 401 |
| D008 | Real HTTP API | Login | Password whitespace is not silently removed | PASS | HTTP 401 |
| D009 | Real HTTP API | Login | SQL-like username is rejected | PASS | HTTP 401 |
| D010 | Real HTTP API | Session | Anonymous profile request rejected | PASS | HTTP 401 |
| D011 | Real HTTP API | Session | Invented bearer token rejected | PASS | HTTP 401 |
| D012 | Real HTTP API | Session | Restore existing bearer session/profile | PASS | Verified |
| D013 | Real HTTP API | Session | Server session expiry enforced | PASS | Expired token rejected with HTTP 401 |
| D014 | Real HTTP API | Login | Disabled doctor account cannot sign in or use a session | PASS | Disabled login and existing token both rejected |
| D015 | Real HTTP API | Login | Repeated failed attempts are throttled | PASS | First 10 failures reject credentials; next attempt returns HTTP 429 |
| D016 | Real HTTP API | Courses | Assigned courses loaded with actual sections | PASS | Verified |
| D017 | Real HTTP API | Permissions | Other doctor course cannot be read | PASS | HTTP 403 |
| D018 | Real HTTP API | Rosters | Full assigned course roster is paginated | PASS | Verified |
| D019 | Real HTTP API | Rosters | Next page has different enrollment rows | PASS | Verified |
| D020 | Real HTTP API | Rosters | University ID search finds exact student | PASS | Verified |
| D021 | Real HTTP API | Rosters | Section selection constrains eligible students | PASS | Verified |
| D022 | Real HTTP API | Rosters | Out-of-scope section rejected | PASS | HTTP 403 |
| D023 | Real HTTP API | Course creation | Actual department sections and active TAs loaded | PASS | Verified |
| D024 | Real HTTP API | Course creation | New offering, assignment, and enrollments persist | PASS | Verified |
| D025 | Real HTTP API | Course creation | Duplicate code rejected | PASS | HTTP 409 |
| D026 | Real HTTP API | Course creation | Invalid section rejected | PASS | HTTP 422 |
| D027 | Real HTTP API | Course creation | Invalid TA rejected | PASS | HTTP 422 |
| D028 | Real HTTP API | Course creation | TA cannot create a course | PASS | HTTP 403 |
| D029 | Real HTTP API | Assignments | Doctor views all assigned course sections | PASS | Verified |
| D030 | Real HTTP API | Policy | Fixed allocation cannot publish an underfilled budget | PASS | HTTP 422 |
| D031 | Real HTTP API | Policy | Fixed allocation cannot exceed budget | PASS | HTTP 422 |
| D032 | Real HTTP API | Policy | Fully allocated fixed policy can publish | PASS | Verified |
| D033 | Real HTTP API | Lecture attendance | Opening a lecture saves eligible roster | PASS | Verified |
| D034 | Real HTTP API | Lecture attendance | QR credentials rotate with an expiry | PASS | Verified |
| D035 | Real HTTP API | Permissions | Doctor cannot check in as a student | PASS | HTTP 403 |
| D036 | Real HTTP API | Lecture attendance | Counterpart student check-in appears in doctor roster | PASS | Verified |
| D037 | Real HTTP API | Lecture attendance | Close materializes absences without overwriting presence | PASS | Verified |
| D038 | Real HTTP API | Lecture attendance | Closing again is safe | PASS | HTTP 200 |
| D039 | Real HTTP API | Lecture attendance | QR is unavailable after closing | PASS | HTTP 409 |
| D040 | Real HTTP API | Lecture attendance | Late student check-in rejected | PASS | HTTP 409 |
| D041 | Real HTTP API | Reports | Shared closed lecture counted for selected section | FAIL | AssertionError: Shared lecture shown in attendance but omitted from section report |
| D042 | Real HTTP API | Reports | All-course report counts closed lecture | PASS | Verified |
| D043 | Real HTTP API | Policy | Publishing incomplete total is rejected | PASS | HTTP 422 |
| D044 | Real HTTP API | Policy | Saved draft categories returned with stable IDs | PASS | Verified |
| D045 | Real HTTP API | Policy | TA cannot modify doctor policy | PASS | HTTP 403 |
| D046 | Real HTTP API | Policy | Publish requires an assessment in normalized category | PASS | HTTP 422 |
| D047 | Real HTTP API | Assessment | Created assessment returns selected section only | PASS | Verified |
| D048 | Real HTTP API | Policy | Used category cannot change to attendance kind | PASS | HTTP 422 |
| D049 | Real HTTP API | Policy | Published policy is visible to student and locked | PASS | Verified |
| D050 | Real HTTP API | Policy | Direct editing of published policy rejected | PASS | HTTP 409 |
| D051 | Real HTTP API | Grades | Zero and unrecorded states are stored differently | PASS | Verified |
| D052 | Real HTTP API | Grades | Draft results hidden from student | PASS | Verified |
| D053 | Real HTTP API | Grades | Published zero remains official zero | PASS | Verified |
| D054 | Real HTTP API | Grades | Score above maximum rejected | PASS | HTTP 422 |
| D055 | Real HTTP API | Grades | Negative score rejected | PASS | HTTP 422 |
| D056 | Real HTTP API | Grades | Existing stale revision rejected | PASS | HTTP 409 |
| D057 | Real HTTP API | Grades | Published correction requires a reason | PASS | HTTP 422 |
| D058 | Real HTTP API | Grades | Previous published snapshot retained during correction | PASS | Verified |
| D059 | Real HTTP API | Grades | Every follow-up correction still requires a reason | FAIL | AssertionError: PATCH /courses/1/assessments/3/results: expected HTTP 422, got 200 |
| D060 | Real HTTP API | Grades | Reasoned correction audit persists | PASS | Verified |
| D061 | Real HTTP API | Grades | Concurrent initial edits do not silently overwrite | FAIL | AssertionError: Two initial revision-0 writes returned [200, 200], expected one success and one conflict |
| D062 | Real HTTP API | Question bank | Invalid correct-answer index rejected | PASS | HTTP 422 |
| D063 | Real HTTP API | Question bank | Blank option rejected | PASS | HTTP 422 |
| D064 | Real HTTP API | Question bank | Questions and marked answers persist for staff | PASS | Verified |
| D065 | Real HTTP API | Permissions | Student cannot fetch bank answer keys | PASS | HTTP 403 |
| D066 | Real HTTP API | Quiz creation | Request exceeding question bank rejected | PASS | HTTP 422 |
| D067 | Real HTTP API | Quiz creation | Doctor-created quiz appears with result link | PASS | Verified |
| D068 | Real HTTP API | Permissions | Doctor cannot start a student attempt | PASS | HTTP 403 |
| D069 | Real HTTP API | Quiz results | Counterpart student sees questions without answer keys | PASS | Verified |
| D070 | Real HTTP API | Quiz results | Server-scored quiz appears in doctor gradebook | PASS | Verified |
| D071 | Real HTTP API | Quiz results | Publishing exposes score to counterpart student | PASS | Verified |
| D072 | Real HTTP API | Notifications | Workflow creates student notifications | PASS | Verified |
| D073 | Real HTTP API | Notifications | Doctor cannot mark another user notification read | PASS | HTTP 404 |
| D074 | Real HTTP API | Notifications | Own empty notification inbox loads | PASS | Verified |
| D075 | Real HTTP API | Persistence | Records survive doctor logout and sign-in | PASS | Logout revoked old token; questions, sessions, and assessments persisted |
| D076 | Chrome UI | Login | Blank form displays both required-field messages | PASS | Required-field messages visible |
| D077 | Chrome UI | Login | Wrong password shows credential error and remains signed out | PASS | Credential rejection visible |
| D078 | Chrome UI | Login | Valid uppercase/whitespace doctor username reaches actual home | PASS | POST login, assigned courses, and home succeeded |
| D079 | Chrome UI | Home | Doctor navigation shows all five destinations | PASS | Verified |
| D080 | Chrome UI | Session | Reload restores the authenticated doctor session | PASS | Session restored without credential entry |
| D081 | Chrome UI | Courses | Course list and local course search retain typed text | PASS | Course search retained |
| D082 | Chrome UI | Rosters | Typing a roster search preserves text and focus | FAIL | AssertionError: Roster search resets its text during loading |
| D083 | Chrome UI | Scope | Doctor can select CS381 section 1 explicitly | PASS | Shared scope selectable |
| D084 | Chrome UI | Course creation | Creation form opens and rejects incomplete input | PASS | Course creation form and required validation exercised; successful write tested through HTTP |
| D085 | Chrome UI | Lecture attendance | Validate, open lecture, and display QR controls | PASS | Lecture created through browser and QR/close screen rendered |
| D086 | Chrome UI | Lecture attendance | Doctor closes lecture through confirmation | PASS | لا يوجد رمز نشط |
| D087 | Chrome UI | Policy | Published policy screen is read-only | PASS | Published policy displayed with disabled fields |
| D088 | Chrome UI | Policy | Create/save policy draft and publish it through browser | PASS | Doctor created/saved draft and published it through UI after API setup of the required shared assessment |
| D089 | Chrome UI | Assessment | Assessment form opens and validates required fields | PASS | اكتب عنواناً واختر بنداً |
| D090 | Chrome UI | Grades | Save explicit zero from browser with correction reason | PASS | تم حفظ الدرجات |
| D091 | Chrome UI | Grades | Excused checkbox updates when entering a numeric grade | FAIL | AssertionError: Excused remains visually checked after entering a recorded score |
| D092 | Chrome UI | Grades | Publish saved assessment results through confirmation | PASS | تم نشر النتائج |
| D093 | Chrome UI | Question bank | Read questions, validate editor, and save a question | PASS | Doctor browser question |
| D094 | Chrome UI | Quiz creation | Quiz creation form opens and validates input | PASS | راجع عنوان الكويز والسكشن |
| D095 | Chrome UI | Quiz results | Submitted quiz opens the staff gradebook | PASS | الدرجة العظمى |
| D096 | Chrome UI | Assignments | Teaching-assignment view loads real sections/TAs | PASS | سكشن |
| D097 | Chrome UI | Reports | Report view loads student/session counts | PASS | عدد الطلاب |
| D098 | Chrome UI | Notifications | Own empty inbox displays its empty state | PASS | لا توجد إشعارات |
| D099 | Chrome UI | Theme | Doctor can switch to dark mode | PASS | Dark mode switch changes current session theme |
| D100 | Chrome UI | Logout | Confirmed logout returns to login and revokes token | PASS | Logged out and revoked |
| D101 | Chrome UI | Login | Offline login error and retry are handled | PASS | Connection error shown; retry after connection recovery succeeds |
| D102 | Chrome UI | Session | Expired session exits doctor screens and returns to login | PASS | Expired session returned to sign-in |
| D103 | Chrome UI | Runtime | No uncaught browser page errors during journeys | PASS | Verified |

## Re-run

~~~powershell
.\server\.venv\Scripts\python.exe tool/role_checks/doctor_check.py
~~~

Requires the coordinator's support.py, installed Playwright/Chrome, the existing
web build, and local PostgreSQL administrator settings. It uses isolated
databases. The concurrency barrier changes only the test process's timing and
is restored afterward; it does not edit production files.
