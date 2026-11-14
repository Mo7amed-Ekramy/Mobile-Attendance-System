# UI and workflow refinement — 2026-11-06

The pre-refinement version was committed and pushed to GitHub first:
[956c031](https://github.com/Mo7amed-Ekramy/Mobile-Attendance-System/commit/956c031).

The implementation follows the repository's
[UI/UX design skill](../.agent/skills/ui-ux-designer/SKILL.md) and
[visual validation skill](../.agent/skills/ui-visual-validator/SKILL.md).

## Interface changes

- University branding, Arabic labels and RTL navigation are preserved.
- Ivory page backgrounds, outlined cards, dark brown welcome panels and shared
  icon tiles give screens a consistent hierarchy. See [design tokens](../DESIGN_SYSTEM.md).
- Noto Sans Arabic and Noto Sans are bundled, including their license. UI and
  PDF typography no longer depend on downloading fonts at runtime.
- Login uses a university identity panel on desktop and a compact scrollable
  form on mobile. Inputs, validation, password visibility and keyboard submission
  retain their behavior.
- Navigation switches to a rail at 960 dp. Dashboard actions use two columns at
  640 dp, with role-specific tasks, live summaries and the selected course scope.
- Async card actions show failures. New notices replace stale snackbar messages.
- Flutter owns RTL direction. Applying RTL to the outer HTML container shifted
  accessibility hit areas off-screen; that duplicate direction was removed.
- Grade ratios and attendance fractions isolate left-to-right numeric runs,
  including in Arabic report cards and exported PDF tables.
- Browser titles, manifest colors, icons and the startup indicator use the
  university identity.

## Working features

**Attendance drafts.** A TA can save a partially marked roster, reload or reopen
it, and continue later. Draft marks are stored separately from official records.
Saves require the current session revision; stale writes and foreign/duplicate
students are rejected. Finalization still requires every eligible student and
removes the draft marks. Drafts do not affect attendance percentages or grades.
Save/finalization controls stay in a pinned footer, with unsaved-change guards.

**Attendance history.** Session lists support 50-row UI pages and stable ordering.
Full-history summaries respect the selected section and exclude excuses from the
denominator. TA lists include eligible shared lectures, with counts restricted
to their permitted students.

**Quiz lifecycle.** Creation supports immediate opening, future scheduling, or
an invisible preparation draft. Staff can open drafts or cancel a quiz before
any attempt starts. Once attempts exist, early closure preserves and scores
saved answers. Cancelled quizzes no longer consume grading allocations or appear
as active assessments; their results cannot be edited or published.

The API runs a maintenance sweep every 10 seconds. It opens due scheduled
quizzes, closes expired windows and finalizes abandoned attempts without a new
student request. Listing and start endpoints also enforce the lifecycle.
Automatic finalization now uses an existing audit actor. A late autosave rejects
the answer after committing finalization, rather than rolling that update back.
Quiz pages refresh automatically, and an open runner updates its server deadline.

**Student reports.** Staff can open **المزيد → تقرير المقرر → كشف الطلاب والطباعة**
for the complete authorized roster, full-history attendance and official published
grade totals. Search/pagination affect the displayed rows; export includes every
student in the selected scope. PDF export embeds Arabic/Latin fonts and prints
attendance and grade tables with repeated page headers. Missing/incomplete
results remain distinct from a score of zero.

## Validation and evidence

- `flutter test --no-pub`: **32 passed**.
- `python -m unittest discover -s server -p 'test_*.py' -v`: **16 passed** against
  a temporary PostgreSQL database, removed after testing.
- `flutter analyze --no-pub`: **no issues**.
- `flutter build web --no-pub --no-web-resources-cdn`: **release build passed**.
  The existing secure-storage package still prevents a WebAssembly build; the
  verified target is JavaScript.
- Flutter layout checks cover 320×640 mobile and 1440×900 desktop, both themes,
  and 150% mobile text scaling.
- **Seven browser checks passed**; evidence is in [ui-refinement-results.json](../review/ui-refinement-results.json).
  The harness uses an isolated database and actual Chrome/Flutter controls.
- A cold live-preview login rendered with external HTTPS blocked, zero external
  resource requests and zero browser errors. This verifies bundled startup
  assets; authentication and writes still require the local API.
- PDF generation covered a 64-student roster, followed by visual inspection of
  rendered pages. Latin identifiers and attendance fractions read correctly.

Measured text contrast: primary brown on white **10.37:1**, muted text on ivory
**4.77:1**, white on the welcome panel **13.73:1**, and gold on that panel **6.67:1**.
The inspected mobile screens have readable text, distinguishable controls and
visible pinned actions. This is focused validation, not a complete accessibility
certification.

Screenshots: [desktop login](../screenshots/refined/login-1440.png),
[mobile login](../screenshots/refined/login-400.png),
[doctor dashboard](../screenshots/refined/doctor-home.png),
[student dashboard](../screenshots/refined/student-home.png),
[dark theme](../screenshots/refined/student-dark.png),
[attendance draft](../screenshots/refined/attendance-draft.png), and
[student report](../screenshots/refined/student-report.png), and
[quiz preparation](../screenshots/refined/quiz-preparation.png).

## Running and upgrading

Rerun `server/setup.py` and restart the API after pulling the change. Migration
006 adds the draft-mark table and cancelled quiz state without reseeding records.
Local setup applied it with zero account hash changes; existing operational row
counts were preserved, and the restarted API returned a healthy response.

The local preview is served at **http://localhost:8080**, with API requests going
to **http://localhost:8000/api/v1**. A repeatable check is:

```powershell
.\server\.venv\Scripts\python.exe tool/role_checks/refinement_check.py
```

PDF generation/download and web behavior are verified. Physical-device camera,
native PDF sharing and actual printer output still require device checks. CSV
export, audit-history browsing, password recovery and the other explicitly
deferred enhancements remain listed in [FEATURE_STATUS.md](FEATURE_STATUS.md).
