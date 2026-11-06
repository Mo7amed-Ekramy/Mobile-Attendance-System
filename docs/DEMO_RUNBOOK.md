# Shared doctor, TA and student graduation demo

Use one database and three independent browser profiles/contexts or devices.
Tabs at the same origin in one profile share token storage and are unsuitable
for three simultaneous identities. Start PostgreSQL, the API and the Flutter
web server using [SETUP.md](SETUP.md).

## Accounts and exact scope

| Role / item | Value |
|---|---|
| Doctor | `doc_rasha01`, initial password `Doctor@123` |
| TA | `ta_nehad00`, initial password `TA@123` |
| Student | University ID `20720236007` or username `ahmd_1478`; initial password `20720236007` |
| Course / offering ID | `CS381` / `1` |
| Course section / label | ID `1` / `سكشن 1 (SE)` |
| Student enrollment ID | `31` |
| Term shown / stored code | `Imported semester 2` / `legacy-semester-2` |

The TA initially opens AI section 5. The doctor and student also have different
default courses. In each session open the course/section selector and select
**CS381 → سكشن 1 (SE)** before starting. Section number 1 alone is ambiguous
across departments. Use current passwords if someone changed the initial ones.

## Rehearsal preconditions

Use an academic-only demo database with no published CS381 policy, or inspect
its existing policy before the defense. Published policies are locked; do not
try to recreate them or delete real data to make this runbook work. Preparing a
fresh rehearsal database through the isolated checker below avoids that risk.

Install packages and load every browser with internet available. The production
web bootstrap can fetch renderer/font assets on cold startup. Keep those browser
sessions open for the presentation. A first-ever offline load is **not verified**.
If internet disappears after preparation, keep the app and local API running;
check Arabic text and actual refresh on those same profiles before proceeding.
Do not clear browser storage/cache, switch to a new profile, or claim a guaranteed
fully offline cold start. Bundling and validating all renderer/font assets is
still required for that stronger guarantee (DOC-04).

## Shared sequence

1. Sign in as the three roles and select the exact shared scope above. Demonstrate
   a wrong password and a subsequent valid login in a separate disposable session.
2. Doctor opens **الدرجات → لائحة توزيع الدرجات** and saves a draft policy with
   total 100: lecture attendance 20 (proportional), section attendance 20
   (proportional), and quizzes 60 (normalized assessment allocation).
3. TA opens the question bank, saves two questions (the current UI has four
   options per question), assigns the correct answer, and sets points to 2 and 3.
4. TA creates a CS381/SE1 quiz with both questions and a 20-minute duration.
   Creation starts it immediately. Scheduling/cancellation are not implemented.
5. Doctor publishes the grading policy and opens a 20-minute lecture. Confirm
   that a rotating QR is displayed; the student scans it with a tested camera or
   copies the exact payload into the manual-entry panel.
6. Student confirms attendance, then repeats the same valid payload to show that
   the existing receipt is returned without adding a duplicate record.
7. Student starts the quiz, answers both questions and submits. Show autosave and
   persistence by reopening it. Scores remain hidden until doctor publication.
8. Doctor closes the lecture, materializing absences for students who did not
   check in. TA creates a section attendance session, marks every eligible row
   explicitly, and finalizes it with the student marked present. Partial marks
   cannot yet be saved as a draft; finish the roster before navigating away.
9. Doctor publishes quiz results. With both answers correct and the student
   present in both sessions, the official student total is 100/100. Open the
   student's grades, attendance history and notifications.
10. Doctor and TA open **المزيد → تقرير المقرر**. Check the selected SE1 scope,
    student count, two finalized sessions and attendance summaries. This is a
    screen report; CSV/PDF export, printing and an audit-history viewer are pending.
11. Stop only the API with Ctrl+C and restart it with the same `server/.env`.
    Refresh each browser, reselect CS381/SE1 if needed, and confirm attendance,
    submitted quiz, published grades, notifications and restored identities remain.
12. Demonstrate logout revocation and expiry/retry using disposable sessions.
    For password change, use a rehearsal account, show current-password validation
    and verify that other sessions are revoked while the changing session remains.
    Keep its new password privately; there is no self-service recovery flow yet.

Do not use early quiz close on the scored walkthrough unless intended: it
finalizes saved answers immediately. Exercise that control in a separate quiz.
Fixed grading budgets require all applicable sections to be allocated before
publication; normalized allocation is appropriate for this single-section demo.

## Repeatable isolated verification

With the release web build present, install the role-check dependencies and run:

```powershell
.\server\.venv\Scripts\python.exe -m pip install -r tool/role_checks/requirements.txt
.\server\.venv\Scripts\python.exe tool/role_checks/demo_rehearsal.py
.\server\.venv\Scripts\python.exe tool/role_checks/cleanup_audit.py
```

The checker uses one temporary PostgreSQL database for all three identities,
real HTTP workflows, and three independent Chrome login/report/restoration
sessions. It restarts its own API and removes only its temporary database.
The workflow writes are API-driven; this does not prove every form was operated
by three humans. Results: [demo-rehearsal.json](../review/demo-rehearsal.json).
The harness routes the renderer to local build assets; that override is not a
claim that the production cold-offline bootstrap is complete.

## Remaining physical checks

Scan an actual rotating QR; test camera denial/re-grant, repeated detection,
lighting, pause/resume, native storage/restart, keyboard overlap and LAN access.
Complete the six previously incomplete TA browser checks. Record these results
before describing the full mobile defense rehearsal as complete.
