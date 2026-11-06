# Phase 4 audit

Checked against [REMEDIATION_PLAN_EN.md](../REMEDIATION_PLAN_EN.md) on 2026-11-01.
**Gate: Phase 4 is partially implemented and does not pass its full deliverables.**
Phase 5 verification/documentation is proceeding with these gaps recorded; that
does not mark Phase 4 or the graduation project complete.

Later UI work adds attendance exit/refresh guards, grading pagination/refresh
protection and pending-publication feedback. See [UI_UX_REVIEW.md](../docs/UI_UX_REVIEW.md)
for that follow-up; draft persistence, scheduling/cancellation and export remain missing.

| Item | Verified current behavior | Missing / gate result |
|---|---|---|
| ADD-04: drafts and navigation protection | Grades save explicitly. A route-exit warning permits keeping edits or discarding them. Numeric formatting alone no longer triggers a false warning. | Attendance marks are page memory only; no partial draft save or attendance exit prompt. Grade refresh/paging and pending republication need more protection. **Partial.** |
| ADD-06: quiz lifecycle | Early closure enforces staff/section scope, finalizes saved answers, prevents new attempts, retains hidden results until publication, and is repeatable. | Creation always starts immediately; no scheduled start, preparation/cancel workflow or updated early-close countdown. **Partial.** |
| ADD-07: printable/exportable reports | Report screen loads and refreshes selected-section counts, summaries, policy and assessments. | No per-student export/print control or audit-history view. **Partial.** |
| ADD-01: password management | All three roles can verify current credentials, change to a different password of at least eight characters, retain the current session, and revoke other sessions. | Self-service account recovery remains deferred under the broader ADD-01 request. The narrower Phase 4 password-update requirement **passes**. |

## Corrections made during verification

- Report refresh passed a synchronous callback to `AsyncButton`; fixed the type
  mismatch that prevented Flutter compilation.
- Wrong current password returned 401, which Flutter interprets as session
  expiry. It now returns a 422 validation error; users can correct it and retry.
- Attendance summary ignored `section_id` and exposed whole-course aggregate
  counts to TAs. It now verifies the selected section and restricts records to
  the student's enrollment or TA's assigned sections.
- Excused records were included in the summary denominator despite being
  excluded by grading. Both now use present/absent records only.
- TA section reports excluded shared lectures. The report now includes sessions
  with eligible students in the TA's assigned scope.
- Grade exit warnings compared formatted strings such as `0` and `0.00`.
  They now compare numeric values and retain warnings for invalid or changed data.

## Evidence and next work

Retained checks are in [server/test_api.py](../server/test_api.py) and
[phase4_test.dart](../test/roles/phase4_test.dart). They exercise real temporary
PostgreSQL state for password/session rules, early closure, and scoped summaries,
plus Flutter report refresh, password retry and grade exit behavior.

The full gate still requires attendance draft persistence and guards, quiz
scheduling/cancellation/countdown updates, and per-student report export/print.
The earlier BUG-03 independent-expiry requirement and full-history pagination
also remain prerequisites for claiming the entire remediation is complete.
See [the current feature matrix](../docs/FEATURE_STATUS.md) and
[Phase 5 verification](../docs/PHASE5_VERIFICATION.md).
