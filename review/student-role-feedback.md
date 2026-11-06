# Student persona: active feature testing and feedback

Date: 2026-11-01. Account: university ID `20720236007`, actual imported username
`ahmd_1478`. Both identifiers authenticate using the documented initial password.
Shared test scope: CS381, offering ID 1, course-section ID 1, displayed as
**سكشن 1 (SE)**. Tests also confirmed the student sees six enrolled courses and
one own section in each.

## What was exercised

The retained runner is [student_check.py](../tool/role_checks/student_check.py).
It uses the shared Sandbox helper to create a unique PostgreSQL database,
start an authenticated HTTP API, and serve the real release Flutter web build
in headless Chrome. Every browser API request is forwarded to that exact test
database. Doctor/TA prerequisites were performed through the API inside the
student sandbox. No operational records were added to the real application database.

Time-sensitive cases shortened only sandbox timestamps: session expiry, expired
QRs, quiz deadlines, and the 12-second browser countdown. Login throttling was
tested against the real API and its test-process memory was reset afterward.
The sandbox database, API, browser context, and web server were cleaned up.

There are **125 unique automated scenarios: 121 passed and 4 identified gaps**.
Coverage comprises 79 direct HTTP API scenarios, 45 real Chrome scenarios, and
one comparison between the actual API history response and Flutter's percentage
calculation. The complete scenario matrix is appended below. Details are in
[student-role-results.json](student-role-results.json).

| Layer | Scenarios | Passed | Findings |
|---|---:|---:|---:|
| Actual HTTP API | 79 | 77 | 2 |
| Actual API history compared with Flutter calculation | 1 | 0 | 1 |
| Actual Chrome UI | 45 | 44 | 1 |
| Total unique scenarios | 125 | 121 | 4 |

Five overlapping login UI scenarios were rechecked separately after correcting
driver focus timing; all five passed. These are retained in
[student-login-ui-results.json](student-login-ui-results.json). Early Playwright
fill/locator failures were driver issues, and are excluded from product findings.
The original main-run password-toggle assertion ran before the new label painted;
the focused rerun awaited the label and verified show/hide, failed-login recovery,
valid sign-in and restored session. The matrix uses that successful recheck.
The same five login scenarios also passed in a 320×640 Chrome viewport; results are
in [student-login-narrow-results.json](student-login-narrow-results.json).
No tokens or request passwords are retained in the result files. Raw DOM diagnostics
are kept under ignored `.dart_tool/role-checks`.

## Login feedback

Verified API behavior: correct university ID and username; case-insensitive username;
surrounding identifier whitespace; rejection of unknown/wrong/blank/oversized/SQL-like
inputs; passwords are not silently trimmed; deactivated accounts and forged/expired
sessions are rejected; admins cannot enter the mobile roles; ten failed attempts
trigger throttling; logout revokes the bearer session.

Verified in actual Chrome: blank-field validation, password show/hide, wrong-password
feedback, subsequent successful sign-in, university-ID and username sign-in, secure
session restoration after reload, offline login errors, session expiry returning to
sign-in, logout confirmation/cancellation and actual token revocation, and switching
student → doctor → student without retaining the previous role's navigation.

There was no confirmed authentication bypass. A failed focus probe initially appended
the old wrong password to the new one; the server correctly returned 401. Waiting
for Flutter editing focus before trusted keyboard replacement fixed the driver,
and the focused sequence then passed.

## Confirmed student issues to fix

| ID | Priority | Finding and reproduction | Source | Requested behavior |
|---|---|---|---|---|
| STU-F1 | High | Student attendance percentages use only the latest 100 sessions. After API-created history contained 103 eligible lectures, the API-derived UI percentage was 100%, while complete finalized attendance was 99.0291% (rounded 99%). Earlier records cannot be reached through the current student history screen. | `server/attendance.py:79`; `lib/features/attendance.dart:19,36`; `lib/data/models.dart:94`; full-history grading at `server/grading.py:279` | Add complete-history pagination and server-calculated attendance summaries; use the same eligible denominator for the display and grade calculation. |
| STU-F2 | Medium | Start a quiz, save an answer, close the app, and let its deadline expire. Staff listing reads leave its attempt in progress with no grade result. Reopening/submitting as the student is currently needed to finalize it. | `server/quizzes.py:164,202`; `server/grading.py:291` | Finalize expired attempts on the server even when the student does not reopen the app; score only answers saved before the deadline. |
| STU-F3 | Medium | Expand manual QR entry, submit an invalid code, and wait for the error. The panel collapses and its textbox disappears. The busy progress indicator is inserted before the unkeyed ExpansionTile. Valid, duplicate, and closed-code flows passed after explicitly reopening the panel. | `lib/features/attendance.dart:427,428` | Preserve the manual panel's expansion and text/focus through loading, error, and retry. Keep the progress indicator in a stable position or preserve widget identity. |
| STU-F4 | Low / visibility decision | The student list hides draft section sessions, but directly requesting a known own draft session ID returns 200 with draft title/time and an empty own record. No staff roster or other student's result was exposed. | `server/attendance.py:63,83`; `session_scope` at line 13 | Apply a consistent publication rule to session details, or explicitly define that students can access their own draft metadata. |

STU-F2 reconfirms the earlier backend review's abandoned-attempt finding. STU-F1
and STU-F3 are new user-facing issues. STU-F4 has limited impact and should not be
treated as a cross-student data leak.

## Features that worked from the student perspective

- Correct five-tab navigation, course search, course details, selected CS381 home,
  and scope chooser showing only the student's own section.
- Manual QR validation, real attendance receipts and persistence, duplicate handling,
  expired/closed/wrong-section protection, camera-unavailable fallback, present/absent/
  excused details, and percentages for ordinary short histories.
- Published policy/grades, explicit zero versus missing, incomplete totals, excused
  results, previous published scores retained during correction, and republication.
  Staff rosters, question keys, grade editing, assignments, and reports were denied.
- Own-section quizzes, hidden answer keys, actual browser autosave, stable resumed
  options/deadlines/answers, question navigation, confirmation and immutable submission,
  server scoring, results after publication, and real countdown auto-submission.
- Quiz/publication notifications, recipient isolation, browser mark-as-read persistence,
  student profile, theme switching, refresh, offline errors, and account switching.

## Student requests to add or update

These are persona requests, separate from confirmed bugs:

| Request | Type | Priority for the work plan | Reason |
|---|---|---|---|
| Password change and recovery | Add | Medium; graduation rubric dependent | Provide a way to replace initial credentials and recover an account without editing the database. Current login is functional, but these workflows are absent. |
| Pending-grade explanation | Update | Medium | Tell the student which applicable assessment is awaiting submission, marking, or publication and preventing a final total. The current category-level incomplete message is broad. |
| Refresh completed quiz results | Update | Medium | A result published while the completed attempt is open currently appears after leaving and reopening it. Add an explicit refresh or automatic result update. |
| Closed/expired quiz presentation | Update | Medium | Clearly distinguish an expired never-started quiz from an active one; avoid presenting a permanently expired attempt as something a retry can reopen. The server correctly rejects starting it. |
| Remember selected course and theme | Update | Low | Preserve student preferences across restarts. The current session is restored, but app preferences are local AppState defaults. |
| Attendance correction/excuse request | Add | Rubric dependent | Let students request review of an absence through an auditable staff approval flow. Keep grade/attendance editing restricted to staff. |
| Login account examples | Documentation | Low | Label `20720236007` as a university ID and `ahmd_1478` as its actual username. Both are accepted; this makes the first demo sign-in clearer. |

## Checks requiring a physical device

| Area | Status | What remains |
|---|---|---|
| Native camera QR decoding | Manual-only | Scan a displayed rotating QR with a real Android camera; test focus, lighting, repeated detection, camera pause/resume and app lifecycle. Browser manual entry and unavailable-camera fallback were exercised. |
| Android permissions | Manual-only | Validate initial camera denial, later re-grant, app settings changes, and reinstall behavior. |
| Physical network and secure storage | Manual-only | Test the PC LAN address, firewall/device connectivity, Android release HTTPS configuration, storage after app restart/reinstall, and real offline transitions. Chrome session storage/reload and simulated transport failures passed. |
| On-screen keyboard and device sizing | Manual-only | Test native keyboard overlap, accessibility scaling, rotation and device back behavior. The 320×640 Chrome login pass and existing narrow-screen widget coverage do not replace native device checks. |

## Complete automated scenario matrix

The status of an expected authorization/error rejection is PASS when the rejection
matches the rules. FAIL marks the four outstanding behaviors above. Counterpart
doctor/TA actions are setup for student observations, not claims that the student
can perform staff actions.

| Scenario | Layer | Result |
|---|---|---|
| login: correct student credentials | API | PASS |
| login: wrong password rejected | API | PASS |
| login: unknown identifier rejected | API | PASS |
| login: blank identifier rejected | API | PASS |
| login: blank password rejected | API | PASS |
| login: whitespace identifier rejected | API | PASS |
| login: whitespace password rejected | API | PASS |
| login: identifier surrounding whitespace accepted | API | PASS |
| login: password surrounding whitespace not silently trimmed | API | PASS |
| login: oversized identifier rejected | API | PASS |
| login: oversized password rejected | API | PASS |
| login: SQL-like identifier is not accepted | API | PASS |
| login: another role password is rejected | API | PASS |
| login: username alias/case and university ID both work | API | PASS |
| login: actual imported username works separately from university ID | API | PASS |
| login: imported admin blocked from mobile roles | API | PASS |
| login: unauthenticated request rejected | API | PASS |
| login: forged bearer rejected | API | PASS |
| login: deactivated account cannot sign in or keep session | API | PASS |
| login: expired session rejected | API | PASS |
| login: logout revokes token and relogin works | API | PASS |
| login: repeated failures are throttled | API | PASS |
| profile: university ID/department/section present | API | PASS |
| courses: actual enrollment and section isolation | API | PASS |
| permissions: student denied /courses/1/roster | API | PASS |
| permissions: student denied /courses/1/questions | API | PASS |
| permissions: student denied /courses/1/assignments | API | PASS |
| permissions: student denied /courses/1/report | API | PASS |
| permissions: student denied /catalog-options | API | PASS |
| permissions: student cannot write /courses/1/sessions | API | PASS |
| permissions: student cannot write /courses/1/questions | API | PASS |
| permissions: student cannot write /courses | API | PASS |
| permissions: student cannot write /courses/1/policy/publish | API | PASS |
| grades: no policy gives explicit empty state | API | PASS |
| attendance: no sessions gives empty list | API | PASS |
| quizzes: no quizzes gives empty list | API | PASS |
| notifications: no events gives empty list | API | PASS |
| attendance: valid QR records own attendance | API | PASS |
| attendance: duplicate QR returns original receipt | API | PASS |
| attendance: invalid QR format/session invalid_token | API | PASS |
| attendance: invalid QR format/session v2 | API | PASS |
| attendance: invalid QR format/session v1 | API | PASS |
| attendance: invalid QR format/session v1 | API | PASS |
| attendance: staff QR endpoint forbidden to student | API | PASS |
| attendance: own detail contains no roster | API | PASS |
| attendance: QR for another section rejected | API | PASS |
| attendance: another section detail rejected | API | PASS |
| attendance: expired QR rejected | API | PASS |
| attendance: closed session QR rejected | API | PASS |
| attendance: closed lecture materializes own absence | API | PASS |
| attendance: draft section excluded from own list | API | PASS |
| attendance: guessed draft section detail is hidden | API | FAIL |
| attendance: finalized excuse shown to student | API | PASS |
| grades: counterpart grading setup | API | PASS |
| grades: draft policy and assessments hidden | API | PASS |
| grades: student cannot see staff gradebook | API | PASS |
| grades: student cannot edit grades | API | PASS |
| grades: missing score leaves official total incomplete | API | PASS |
| grades: saved unpublished score remains hidden | API | PASS |
| grades: published zero remains distinct from missing | API | PASS |
| grades: closed lecture attendance gives 50 percent of category | API | PASS |
| grades: pending correction retains published zero | API | PASS |
| grades: republished correction updates own grade | API | PASS |
| grades: published excuse is explicit and has no score | API | PASS |
| quizzes: only own section appears | API | PASS |
| quizzes: another section start forbidden | API | PASS |
| quizzes: student response excludes answer keys | API | PASS |
| quizzes: autosave/resume preserves answers/deadline/option order | API | PASS |
| quizzes: unrelated option rejected | API | PASS |
| quizzes: submit locks attempt and hides score until publication | API | PASS |
| quizzes: saved answers immutable after submission | API | PASS |
| quizzes: repeated submit returns same completed attempt | API | PASS |
| quizzes: published score visible to own student | API | PASS |
| quizzes: expired autosave rejected | API | PASS |
| quizzes: late submit cannot add answers after deadline | API | PASS |
| quizzes: abandoned expired attempt finalizes without reopening | API | FAIL |
| quizzes: never-started expired quiz rejected | API | PASS |
| notifications: scoped events/read state/recipient isolation | API | PASS |
| persistence: logout/login retains own published results | API | PASS |
| login UI: blank fields display validation | Chrome | PASS |
| login UI: password show/hide controls work | Chrome | PASS |
| login UI: wrong password shows error and remains signed out | Chrome | PASS |
| login UI: university-ID login reaches student tabs | Chrome | PASS |
| login UI: refresh restores secure session | Chrome | PASS |
| navigation UI: student has five correct destinations | Chrome | PASS |
| navigation UI: course search retains text and own records | Chrome | PASS |
| navigation UI: open CS381 course and its own section details | Chrome | PASS |
| navigation UI: home respects selected CS381 | Chrome | PASS |
| navigation UI: scope chooser offers only own section | Chrome | PASS |
| navigation UI: refresh reloads records without signing out | Chrome | PASS |
| scanner UI: open scan screen/manual fallback | Chrome | PASS |
| scanner UI: unavailable camera gives clear fallback | Chrome | PASS |
| scanner UI: invalid manual payload displays server error | Chrome | PASS |
| scanner UI: failed submission keeps manual form expanded | Chrome | FAIL |
| scanner UI: valid manual QR persists attendance receipt | Chrome | PASS |
| scanner UI: duplicate shows already-recorded receipt | Chrome | PASS |
| scanner UI: closed QR rejects with useful error | Chrome | PASS |
| attendance UI: attendance log percentages and excuses shown | Chrome | PASS |
| attendance UI: own lecture detail excludes staff roster | Chrome | PASS |
| grades UI: published grades and incomplete total visible | Chrome | PASS |
| grades UI: no student assessment editor or publication controls | Chrome | PASS |
| quizzes UI: own section quiz listing hides other section | Chrome | PASS |
| quizzes UI: start real attempt and show question timer | Chrome | PASS |
| quizzes UI: answer selection autosaves on server | Chrome | PASS |
| quizzes UI: next/previous navigation retains attempt | Chrome | PASS |
| quizzes UI: second answer autosaves | Chrome | PASS |
| quizzes UI: submit confirmation and hidden result state | Chrome | PASS |
| quizzes UI: publication makes server-scored result visible | Chrome | PASS |
| quizzes UI: completed attempt has no submit button | Chrome | PASS |
| quizzes UI: reopening completed quiz preserves result | Chrome | PASS |
| quizzes UI: countdown automatically submits saved answers | Chrome | PASS |
| notifications UI: open events and mark published result read | Chrome | PASS |
| profile UI: student university ID shown | Chrome | PASS |
| settings UI: dark mode toggles and resets | Chrome | PASS |
| logout UI: cancel keeps authenticated student | Chrome | PASS |
| network UI: offline refresh displays error without invented data | Chrome | PASS |
| logout UI: confirm clears student UI and revokes bearer | Chrome | PASS |
| login UI: offline failure stays on sign-in with useful error | Chrome | PASS |
| login UI: actual imported username ahmd_1478 works | Chrome | PASS |
| session UI: server expiry clears authenticated navigation | Chrome | PASS |
| session UI: login succeeds after expiry | Chrome | PASS |
| session UI: reload restores after fresh login | Chrome | PASS |
| login UI: switching accounts cannot retain previous role tabs | Chrome | PASS |
| browser UI: no uncaught application exceptions | Chrome | PASS |
| attendance history: percentage covers more than 100 sessions | API/Flutter calculation | FAIL |
