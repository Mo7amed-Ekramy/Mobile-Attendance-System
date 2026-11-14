# Priority workflow update — 2026-11-06

Selected role-review recommendations were implemented after the owner authorized
the priority changes and specifically requested verification of QR attendance.
The original persona reviews remain proposals, rather than implementation instructions.

## Changes

- **TA-01:** Bulk absence affects only unmarked students across the entire roster.
  Confirmation states the number and full-list scope. Undo removes the bulk marks
  while retaining subsequent manual decisions.
- **TA-02 / DOC-01:** Finalization reviews the exact course, section, term, session,
  date and all present/absent/excused counts. It explains the current correction
  limitation. Lecture creation fetches the eligible roster count, and staff
  dashboard follow-up cards identify responsibility and view-only actions.
- **TA-03:** Revision conflicts retain local attendance and grade input. A review
  shows local/server values and offers cancellation, explicit discard, or retaining
  local changes against the reviewed revision. Unchanged rows use the latest
  server values. Nothing is automatically resubmitted. Finalized attendance cannot
  be rebased into an editable record.
- **DOC-02:** Policy exit/refresh offers save, discard or cancel. Failed saves keep
  the editor open. Allocation examples explain fixed versus normalized totals.
  Successful saves preserve the editor state; published policies remain locked.
- **DOC-03:** Publication previews the entire assessment, independent of visible
  section/page, including eligible/recorded/excused/unrecorded counts and pending
  saved results. Confirmation carries a fingerprint; changed results require a new
  preview. Staff and automatic quiz-grade writes serialize with publication.
- **STU-03:** A read-only readiness endpoint supplies server timing and course
  context without creating an attempt or disclosing questions/keys. New attempts
  require explicit start; existing attempts resume directly.
- **STU-04 / STU-05:** Quiz answers distinguish pending, failed and acknowledged
  choices, support retry and show confirmed-answer counts/direct navigation.
  Submission warns about unanswered/unconfirmed choices and submits the answers
  already stored on the server. Manual and automatic completion have different labels.
- **STU-06:** Attendance receipts include the actual QR course/session, status,
  timestamp and receipt ID. Students can reopen their own receipt and copy it.
- **DOC-07 / DOC-11 / TA-11 / STU-02:** Quiz creation explicitly describes random
  selection by count. Imported term labels have an accurate Arabic display name
  without inventing an academic year or changing stored identifiers.
- **QR issue reproduced during browser testing:** The web reader kept emitting
  the same image after receipt dismissal. The database prevented duplicate rows,
  but repeated dialogs blocked normal use. Confirmed check-in now pauses scanning;
  **مسح رمز آخر** explicitly resumes it. Manual entry remains available.

No attendance-correction policy, question-bank editing, staff reassignment,
external notification delivery or account-recovery workflow was introduced.
No database migration is required for these changes. Restart an existing API and
rebuild/reload Flutter together because the new UI uses the new endpoints.

## Verification

- `flutter test --no-pub`: **36 passed**. New/updated regressions cover safe bulk
  marking/undo, conflict cancellation/rebase, full-roster approval, policy
  save/cancel/exit, quiz readiness, delayed/failed answer saves and publication scope.
- Server integration suite: **19 passed**, using a temporary PostgreSQL database.
  Includes actual stored QR receipt/source/timestamp, ownership isolation, duplicate
  requests, expired/tampered QR rejection, closure, readiness without attempts,
  global quiz deadlines and stale publication-preview rejection.
- `flutter analyze --no-pub`: **no issues**.
- `flutter build web --release --no-pub --no-web-resources-cdn`: **passed** for
  JavaScript. Existing secure-storage WebAssembly limitations remain unchanged.
- `dart run tool/verify_api.dart`: **all three roles passed** against the reloaded
  local API. Read-only academic row counts matched before/after API reload and
  role verification. Test attendance was created only in isolated databases.
- Browser evidence: **8 checks passed**, [results](../review/priority-workflow-results.json).
  Reproduce with `server/.venv/Scripts/python.exe tool/role_checks/priority_check.py`.
  The harness captures the QR rendered by the actual doctor Flutter page, feeds
  that image through a simulated video stream to the real scanner, and checks
  `attendance_records` for the student's `present` record with `source='qr'`.
  API responses, decoder output and database writes are not mocked.

## Visual evidence and limits

From the visual evidence, I observe an Arabic RTL receipt dialog with course code,
course/session names, present status, recording time, receipt ID, copy action and
a visible confirmation button at 400×900. The QR remains visible behind the modal.
The recorded desktop lecture screen displays a clear centered QR and closure control.
The reloaded mobile attendance detail shows the same receipt ID and recording time.
The mobile readiness screen displays course/section, duration, closing time, actual
remaining time, an early-closure warning, and separate start/back controls within
the recorded 400×900 viewport. These focused visual goals are achieved in the
captured states; full accessibility and physical-camera verification remain partial.

- [Doctor QR](../screenshots/priority/doctor-qr.png)
- [Student receipt](../screenshots/priority/student-qr-receipt.png)
- [Reopened receipt](../screenshots/priority/reopened-attendance-receipt.png)
- [Quiz readiness](../screenshots/priority/quiz-readiness.png)

The camera input is simulated video of the actual displayed QR. No Android/iOS
device or emulator was connected. Physical camera focus, permission recovery,
LAN/native networking and native sharing remain unverified. Browser scanner
decoding may load its pinned decoder library from a CDN; fully offline scanning
is not claimed. This focused visual review does not certify full accessibility;
screen-reader speech and physical touch targets still require device checks.
