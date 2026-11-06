# TA role acceptance test and feedback

Date: 2026-11-01.

Acted as TA `ta_nehad00` against isolated PostgreSQL, live FastAPI HTTP, and
a separate headless Chrome context. Counterpart doctor/student actions were
fixture actions inside the isolated database. No real operational records
or production source files were changed. A separate read-only academic
directory query verified the shared section and student login identifiers.

Every current TA feature was exercised at the API layer. Browser checks
covered actual login/session handling, navigation, roster behavior, section
attendance finalization, policy viewing, assignments, notifications, reports
and settings. Component acceptance checks supplemented form writes whose
Chrome automation did not complete reliably. These layers are distinguished
below; incomplete automation is not claimed as a product failure.

## Summary

| Layer | PASS | Confirmed FAIL | Incomplete / N/A |
|---|---:|---:|---:|
| API | 64 | 3 | 0 |
| Chrome UI | 16 | 1 | 6 |
| Flutter component | 5 | 1 | 0 |
| Physical device | 0 | 0 | 1 |

There are five unique confirmed TA-relevant defects: three API issues,
roster search, and the excuse/grade display mismatch. Login did not reveal
a confirmed TA authentication defect. Expected permission denials count as PASS.

## Evidence and reproduction commands

~~~powershell
.\server\.venv\Scripts\python.exe tool/role_checks/ta_check.py
flutter test --no-pub test/roles/ta_role_test.dart
~~~

The six component acceptance checks returned five passes and one known
failure. The failing checkbox expectation is retained for the repair batch;
these additional acceptance tests are not claimed to be fully green.

Chrome needed allowed access to web fonts. Bootstrap/semantics activation,
trusted keyboard input, duplicated live announcements, and lazy scrolling
were automation concerns; their earlier failed attempts were not added as
application defects.

## Login and shared scope

- Valid TA credentials returned role TA; blanks, unknown/prefixed names,
  incorrect/case-changed/space-padded passwords, missing/invalid tokens,
  inactive accounts and expired sessions were rejected.
- Username case/outer whitespace normalization worked. Password whitespace
  remained significant. Admin mobile login was denied. Ten failed attempts
  produced a server throttle, including for subsequently correct credentials.
- Real Chrome verified blank-field messages, password reveal/hide, incorrect
  password feedback, successful role navigation, restore after reload, expiry
  returning to login, logout cancel/confirm, and offline login feedback.
- Shared course is CS381, offering 1, **section ID 1 = `سكشن 1 (SE)`**.
  TA default scope instead opens `سكشن 5 (AI)`. Select the exact SE label.
- Student university ID `20720236007` is an alternate identifier; its actual
  username is `ahmd_1478`. The displayed term is `Imported semester 2`;
  the database term code is `legacy-semester-2`.

## Confirmed fixes requested by the TA

| Priority | Fix | Reproduction / impact | Source |
|---|---|---|---|
| High | Restrict shared lecture detail rosters to assigned sections | TA opens a doctor shared lecture through the direct detail API and receives students assigned to other TAs; normal cross-section roster access is denied | server/attendance.py:21,93 |
| High | Preserve roster search field and focus | Type a multi-character student ID in Chrome; remote loading removes/recreates the field and its text disappears, while the API search itself works | lib/features/courses.dart:189,198; lib/widgets/common.dart:53 |
| Medium | Resolve abandoned quiz attempts on the server | Student starts quiz and leaves; advance the isolated deadline, then TA reads quiz/gradebook. Attempt remains in_progress without a grading result | server/quizzes.py:164,202 |
| Medium | Require a reason for every correction to a previously published result | First reasoned correction moves current result to draft; next correction with no reason returns 200 despite published snapshot/history | server/grading.py:231 |
| Medium | Make displayed excuse status match numeric grade entry | Start with an excused row; enter score 3. Submission state changes to recorded, but the checkbox stays checked. Component acceptance reproduced it | lib/features/grading.dart:468,476; test/roles/ta_role_test.dart:271 |

These defects overlap the earlier PROJECT_REVIEW.md findings and should be
deduplicated into its repair list, rather than counted as five new bugs.

## Requested additions and updates

These are TA-persona product requests, not confirmed implementation defects.

1. **Add saved attendance drafts and an unsaved-change warning.** Marking
   currently lives in the page-local map until finalization
   (`lib/features/attendance.dart:154`). I need to pause a long roster or
   recover after an accidental back/refresh without re-entering it.
2. **Add audited attendance correction after finalization.** Preserve the
   old record and require a reason/appropriate approval. This also aligns
   with the original planned correction workflow.
3. **Add question edit/archive and flexible option counts.** Current UI
   only creates four-option questions (`lib/features/quizzes.dart:151`),
   while the API accepts two to six. Keep existing quiz snapshots stable.
4. **Update the TA sections view with direct attendance/grade shortcuts**
   and remember the selected course/department/section. Exact department
   labels matter because section numbers repeat across departments.
5. **Add useful TA reporting/export and an audit-history view.** Current
   reports are counts. A roster attendance breakdown and assessment results
   export would support the daily workflow and graduation demonstration.
6. **Add password change/recovery and relevant TA notifications.** Login
   itself works; there is no TA self-service recovery flow. Current event
   notifications mainly target students. Notify TAs when attempts need
   review or a course workflow requires their action if that is in scope.
7. **Update setup/demo wording and bundle appropriate web fonts for an
   offline demo.** Distinguish student username from university-ID login,
   term display name from code, and exact SE1 from the default AI5 scope.
   Chrome attempted Google Roboto/Noto font downloads; first-load offline
   Arabic rendering was not established by the API-offline login check.

## Full feature/scenario matrix

| Feature/scenario | Layer | Result | Evidence |
|---|---|---|---|
| Login: valid TA credentials and actual role | API | PASS | Expected behavior observed. |
| Login: blank identifier rejected | API | PASS | Expected behavior observed. |
| Login: blank password rejected | API | PASS | Expected behavior observed. |
| Login: wrong password rejected | API | PASS | Expected behavior observed. |
| Login: unknown account rejected | API | PASS | Expected behavior observed. |
| Login: prefixed identifier rejected | API | PASS | Expected behavior observed. |
| Login: surrounding identifier whitespace and uppercase accepted | API | PASS | Expected behavior observed. |
| Login: password is case sensitive | API | PASS | Expected behavior observed. |
| Login: password whitespace remains significant | API | PASS | Expected behavior observed. |
| Login: admin account is excluded from mobile roles | API | PASS | Expected behavior observed. |
| Authentication: no-token requests rejected | API | PASS | Expected behavior observed. |
| Authentication: invalid token rejected | API | PASS | Expected behavior observed. |
| Profile: TA identity reflects authenticated account | API | PASS | Expected behavior observed. |
| Authentication: deactivated account rejected | API | PASS | Expected behavior observed. |
| Authentication: server expiry rejects session | API | PASS | Expected behavior observed. |
| Logout: revokes session and relogin restores identity | API | PASS | Expected behavior observed. |
| Courses: only assigned courses and sections are returned | API | PASS | Expected behavior observed. |
| Courses: unrelated course roster denied | API | PASS | Expected behavior observed. |
| Sections: other TA section denied | API | PASS | Expected behavior observed. |
| Roster: exact assigned section and count | API | PASS | Expected behavior observed. |
| Roster: pagination has no repeated records | API | PASS | Expected behavior observed. |
| Roster: university ID search returns matching student | API | PASS | Expected behavior observed. |
| Roster: no-match search returns empty | API | PASS | Expected behavior observed. |
| Course creation and catalog admin options denied to TA | API | PASS | Expected behavior observed. |
| Assignments: only own five sections returned | API | PASS | Expected behavior observed. |
| Report: assigned student count and initially empty attendance | API | PASS | Expected behavior observed. |
| Lecture: TA cannot open or close doctor lecture | API | PASS | Expected behavior observed. |
| Lecture QR: TA cannot request credential | API | PASS | Expected behavior observed. |
| Student QR check-in: forbidden to TA | API | PASS | Expected behavior observed. |
| Lecture details: no other-TA roster exposure | API | FAIL | AssertionError: TA received shared lecture roster containing other TAs' students (known access gap) |
| Attendance: cannot create another TA section | API | PASS | Expected behavior observed. |
| Attendance: section selection required | API | PASS | Expected behavior observed. |
| Attendance: unresolved roster cannot be finalized | API | PASS | Expected behavior observed. |
| Attendance: cross-section row cannot be finalized | API | PASS | Expected behavior observed. |
| Attendance: all students marked present/absent/excused and finalized | API | PASS | Expected behavior observed. |
| Attendance: duplicate finalization rejected | API | PASS | Expected behavior observed. |
| Attendance: finalized statuses persist after logout | API | PASS | Expected behavior observed. |
| Report: finalized TA section counted | API | PASS | Expected behavior observed. |
| Policy: no initial policy shown as null | API | PASS | Expected behavior observed. |
| Policy: TA can inspect doctor draft | API | PASS | Expected behavior observed. |
| Policy: TA edits/publication denied | API | PASS | Expected behavior observed. |
| Assessments: section-specific creation persists | API | PASS | Expected behavior observed. |
| Assessments: TA must select a section | API | PASS | Expected behavior observed. |
| Assessments: other TA section denied | API | PASS | Expected behavior observed. |
| Gradebook: save explicit zero, missing and excused values | API | PASS | Expected behavior observed. |
| Gradebook: saved states and zero remain distinct | API | PASS | Expected behavior observed. |
| Gradebook: out-of-range score rejected | API | PASS | Expected behavior observed. |
| Gradebook: cross-section student rejected | API | PASS | Expected behavior observed. |
| Gradebook: stale existing revision rejected | API | PASS | Expected behavior observed. |
| Gradebook: publication is doctor-only | API | PASS | Expected behavior observed. |
| Gradebook: published correction needs a reason | API | PASS | Expected behavior observed. |
| Gradebook: reasoned correction saves and preserves old student snapshot | API | PASS | Expected behavior observed. |
| Gradebook: repeated correction still requires audit reason | API | FAIL | AssertionError: PATCH /courses/1/assessments/1/results: expected 422, got 200 |
| Questions: initially empty bank | API | PASS | Expected behavior observed. |
| Questions: invalid correct option rejected | API | PASS | Expected behavior observed. |
| Questions: blank option rejected | API | PASS | Expected behavior observed. |
| Questions: bank persists options and answer keys for authorized TA | API | PASS | Expected behavior observed. |
| Quizzes: question count above bank rejected | API | PASS | Expected behavior observed. |
| Quizzes: other TA section denied | API | PASS | Expected behavior observed. |
| Quizzes: random subset/snapshots and student notification persist | API | PASS | Expected behavior observed. |
| Quizzes: TA cannot take student attempt | API | PASS | Expected behavior observed. |
| Quizzes: TA sees submitted attempt and server score | API | PASS | Expected behavior observed. |
| Quizzes: doctor publishes TA quiz and student sees score | API | PASS | Expected behavior observed. |
| Quizzes: abandoned expired attempt is resolved for TA grading | API | FAIL | AssertionError: Expired abandoned attempt remains in_progress after staff reads (known gap) |
| Notifications: TA cannot mark student notification read | API | PASS | Expected behavior observed. |
| Notifications: TA can read and mark own notification | API | PASS | Expected behavior observed. |
| Browser login: blank form validation | Chrome UI | PASS | Expected behavior observed. |
| Browser login: show/hide password toggle | Chrome UI | PASS | Expected behavior observed. |
| Browser login: wrong password has visible error | Chrome UI | PASS | Expected behavior observed. |
| Browser login: correct TA opens role home | Chrome UI | PASS | Expected behavior observed. |
| Browser session: reload restores TA without login | Chrome UI | PASS | Expected behavior observed. |
| Browser navigation: TA has no doctor/student-only tabs | Chrome UI | PASS | Expected behavior observed. |
| Browser course/section chooser: assigned scope only | Chrome UI | PASS | Expected behavior observed. |
| Browser courses: assigned course search and detail | Chrome UI | PASS | Expected behavior observed. |
| Browser roster: multi-character search preserves input | Chrome UI | FAIL | AssertionError: Roster search field reset after request (confirmed prior issue) |
| Browser attendance: create, mark all, present/excused, finalize | Chrome UI | PASS | Expected behavior observed. |
| Browser grades: policy is read-only for TA | Chrome UI | PASS | Expected behavior observed. |
| Browser assessment: create section assignment | Chrome UI | INCOMPLETE | Dropdown/menu navigation did not complete reliably in Chrome; component acceptance passed. Raw automation result: TimeoutError: Locator.click: Timeout 15000ms exceeded. Call log:   - waiting for get_by_role("button", name=re.compile(r"إنشاء\ التقييم")).first     - locator resolved to <flt-semantics tabindex="0" role="button" flt-tappable="" id="flt-semantic-node-108">إنشاء التقييم</flt-semantics>   - attempting click action     - waiting for element to be visible, enabled and stable   - element was detached from the DOM, retrying  |
| Browser gradebook: explicit zero saves | Chrome UI | INCOMPLETE | Blocked by incomplete browser assessment creation; live API and component acceptance passed. Raw automation result: TimeoutError: Locator.click: Timeout 15000ms exceeded. Call log:   - waiting for get_by_role("button", name=re.compile(r"TA\ Browser\ Assessment")).first  |
| Browser gradebook: typing score clears displayed excused status | Chrome UI | INCOMPLETE | Blocked by incomplete browser assessment creation; the mismatch was independently reproduced by a failing component acceptance check. Raw automation result: IndexError: list index out of range |
| Browser question bank: create four-option question | Chrome UI | INCOMPLETE | New question was not reliably located after browser form submission/scroll; live API and component acceptance passed. Raw automation result: TimeoutError: Locator.wait_for: Timeout 15000ms exceeded. Call log:   - waiting for locator("flt-semantics").get_by_text("TA browser question").last to be visible  |
| Browser quiz creator: target section and random questions | Chrome UI | INCOMPLETE | Dropdown/menu navigation did not complete reliably in Chrome; live API and component acceptance passed. Raw automation result: TimeoutError: Locator.click: Timeout 15000ms exceeded. Call log:   - waiting for get_by_role("button", name=re.compile(r"فتح\ الكويز\ وإشعار\ الطلاب")).first     - locator resolved to <flt-semantics tabindex="0" role="button" flt-tappable="" id="flt-semantic-node-134">فتح الكويز وإشعار الطلاب</flt-semantics>   - attempting click action     - waiting for element to be visible, enabled and stable   - element was detached from the DOM, retrying  |
| Browser notifications: view and mark owned notification read | Chrome UI | PASS | Expected behavior observed. |
| Browser assignments: only assigned sections visible | Chrome UI | PASS | Expected behavior observed. |
| Browser report: TA student/session/finalized counts visible | Chrome UI | PASS | Expected behavior observed. |
| Browser settings: theme toggles | Chrome UI | INCOMPLETE | Immediate browser checked-state assertion was timing-sensitive; theme passed earlier browser runs and a separate component acceptance check. Raw automation result: AssertionError: Theme switch did not toggle |
| Browser session: expiry returns to login | Chrome UI | PASS | Expected behavior observed. |
| Browser logout: cancel stays signed in; confirm clears session | Chrome UI | PASS | Expected behavior observed. |
| Browser login: offline request shows error without bypass | Chrome UI | PASS | Expected behavior observed. |
| Native camera/QR scanner | Physical device | NOT TESTABLE | TA cannot check in by QR; physical scanner belongs to student role/device testing. |
| Login: ten failures cause throttling including correct password | API | PASS | Expected behavior observed. |
| TA theme setting updates displayed switch | Flutter component | PASS | test/roles/ta_role_test.dart; state and rendered switch became true after tap/rebuild. |
| TA selects category/kind and creates section assignment | Flutter component | PASS | The submitted request contained section_id=1, category_id=1, kind=assignment, max_points=10. |
| TA question editor submits choices and selected answer | Flutter component | PASS | Four options, correct_index=1, and points=2 submitted through the form. |
| TA quiz form selects assigned section/category/count/duration | Flutter component | PASS | section_id=1, category_id=1, question_count=2, duration_minutes=20 submitted. |
| TA grade zero submits recorded result and reloads | Flutter component | PASS | Explicit zero, recorded state, revision=0 submitted; stored response displayed 0.00. |
| TA recorded numeric grade clears existing excuse checkbox | Flutter component | FAIL | Expected checkbox false after typing 3; actual true. Retained failing acceptance test at test/roles/ta_role_test.dart:271. |

## Limits and next work batch

TA camera check-in is not an available role feature, and the API correctly
denies it. Physical scanner/device validation belongs to the student/device
test plan. Browser form writes marked INCOMPLETE still need a final real
browser walkthrough; the relevant API and component checks are reported
separately. Native Android/iOS behavior was not tested by this role pass.

Start the repair batch with TA data isolation and persistent search, then
quiz expiry, correction auditing, and the grade/excuse display. Re-run the
retained acceptance checks after fixes. Prioritize requested additions
against the graduation rubric before extending the implementation.
