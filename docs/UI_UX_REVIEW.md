# Role-focused UI/UX review and improvements

Reviewed on 2026-11-01 against the current Flutter app, the three-role feedback,
and the earlier Phase 4 audit. This pass improves existing workflows and their
feedback, navigation and state preservation.

| Role | Usability gap | Current improvement |
|---|---|---|
| Doctor | Generic summary with little direction | Task-focused dashboard with lecture creation, grading, policy setup when missing, current sessions, rosters and scoped reports |
| TA | Assigned sections require several navigation steps | Direct section workspaces, a dedicated attendance destination, and scoped attendance/grade/roster actions |
| TA | Long attendance lists make unresolved rows hard to review | Search by name/ID, an unmarked-only filter, counts across the full roster, and a pinned finalize action |
| Doctor / TA | Save and publication controls disappear below long rosters | Pinned save/publication/paging controls; visible unsaved/pending-publication state; publication requires saving local edits first |
| Doctor / TA | Paging/refresh can silently replace entered grades | Explicit discard prompts before paging/manual refresh; route-exit protection remains in place |
| TA | Leaving a partial attendance roster loses marks silently | Exit/refresh protection and an explicit explanation that finalization saves the complete roster; filtering preserves all selected marks |
| Student | Scan destination opens the camera rather than attendance history | Attendance hub combines history and a deliberate scan/manual-entry action; the home screen retains direct check-in access |
| Student | Expired quizzes look available and invite futile retries | Clear closed/expired/saved/completed states; unavailable unstarted quizzes cannot be opened; completed attempts remain reachable |
| Student | Results published while a quiz view is open are hard to find | Completed attempts have an explicit result-refresh action; the dashboard explains an incomplete official total |
| All | Refresh hides forms and failure removes their input | Existing content remains during refresh, interaction pauses while loading, and recoverable errors retain input with retry/dismiss controls |
| All | Course, section and theme reset after restarting | Account-specific preferences restore only a course/section still returned by the authenticated API; other accounts start with their own preferences |
| All | Failed login feedback is transient | Inline credential/network error, keyboard submission, and disabled duplicate submission while signing in |

Primary role actions appear before the dashboard metrics on narrow screens.
University colors, logo and Arabic/RTL presentation remain the visual basis.
Metric cards wrap with available width and forms stay scrollable above pinned
actions. All roles now have five bottom destinations, with attendance available
without opening the camera. The TA's second destination lists assigned sections.

## Validation

- The full Flutter suite passed **29 tests**, including ten new UX acceptance
  checks in [role_ux_test.dart](../test/roles/role_ux_test.dart).
- Checks cover 320px role dashboards, permitted preference restoration/account
  isolation, direct section navigation, quiz availability, input retention after
  refresh failure, guarded grading pagination, complete filtered attendance
  submission, and attendance exit protection.
- `flutter analyze --no-pub` completed with no issues, and the release JavaScript
  web build succeeded. The existing Wasm secure-storage and Cupertino icon-font
  warnings remain; this validates the JavaScript build.
- The combined Chrome/API UX verification passed **25 checks, with zero
  failures**. It covered independent role logins, invalid-login recovery, all
  five destinations at 320px, direct TA section workspaces, student attendance
  navigation, pinned grading controls, published results, and account-specific
  scope/theme restoration after reload and API restart. No uncaught browser
  application exceptions were recorded. See
  [role-ux-browser-results.json](../review/role-ux-browser-results.json).
- Visually inspected all three role dashboards at **320 × 740** and
  **1280 × 1000**, including desktop dark-theme views. Primary actions and all
  five navigation destinations remain readable on the narrow screens; no
  material clipping or horizontal overflow was observed in these screenshots.
  Local screenshots are generated under `.dart_tool/role-checks/uiux/` and are
  ignored by Git.
- The final read-only [cleanup audit](../review/cleanup-audit.json) confirmed
  that no role/API test databases remained and the main API was healthy.

The original role matrices and Phase 5 rehearsal remain historical; this pass
does not relabel their results or claim that every original scenario was rerun.

## Next UX work

Add a searchable course/section selector, policy-draft exit protection, and more
grade-roster search/review tools. Question editing and flexible option counts in
the question form remain separate work. Attendance draft persistence, quiz
scheduling/cancellation and report export/print still require their unfinished
feature contracts; their controls are not presented as working features here.

Native keyboard overlap, accessibility scaling and real camera/permission
behavior still require a mobile device. A 320px Chrome view is useful layout
evidence but does not complete that native-device coverage.


The 2026-11-06 refinement supersedes the draft-persistence and quiz-lifecycle
limitations above. See [UI_REFINEMENT.md](UI_REFINEMENT.md) for the responsive
visual refresh, new workflows and current verification evidence.
