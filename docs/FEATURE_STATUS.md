# Implemented and deferred graduation scope

This matrix reflects the current code and the Phase 4 follow-up, rather than
the older role-review scenario counts. [Phase 4 audit](../review/phase4-audit.md)
records the gate decision; [Phase 5 verification](PHASE5_VERIFICATION.md) records
the checks. Deferred work remains in [PROJECT_REVIEW.md](../PROJECT_REVIEW.md).

| Capability | Current status | Evidence / remaining work |
|---|---|---|
| Three-role login, restore, expiry and logout | Implemented; verified | Existing API/Flutter checks and shared browser rehearsal |
| In-app password change | Implemented; verified | Current password required; salted hash; other sessions revoked; current session retained |
| Password recovery / reset administration | Deferred | No recovery/reset UI or verified recovery mechanism |
| Lecture QR attendance and closure | Implemented | Server check-in, expiry, duplicates and materialized absences; physical scanning pending |
| TA complete section attendance finalization | Implemented | Every eligible row required; persisted, immutable finalized roster |
| Saving a partially marked attendance draft | Missing (ADD-04) | Draft session exists, but marks stay in page memory until finalization |
| Attendance navigation warning | Implemented; tested (ADD-04) | Explicit discard for route exit/refresh; unmarked filtering retains all marks |
| Saved draft grades | Implemented | Explicit page save, revision checks and published snapshots |
| Unsaved grade route-exit warning | Implemented; verified | Cancel retains edits; discard is explicit; equivalent number formatting is ignored |
| Grade refresh/pagination guards and republication indicators | Implemented for current page (ADD-04) | Explicit discard, pinned actions and unsaved/pending-publication feedback |
| Quiz creation, autosave, deadlines, submission and scoring | Implemented | Creates immediately active quizzes with immutable snapshots |
| Early quiz close | Implemented; tested for normal flow | Scoped staff control, saved-answer scoring and notifications; cancellation is separate missing work |
| Quiz scheduling, preparation and cancellation | Missing (ADD-06) | No API/schema/UI workflow for scheduled start or cancellation |
| Course/section report screen | Implemented; verified | Scoped counts, attendance summaries, policy and assessments |
| Per-student report rows, print and export | Missing (ADD-07) | No export/print control or per-student report contract |
| Audit writes | Implemented | DB audit records for current workflows; append protections |
| Audit-history viewer | Deferred (ADD-07) | No staff browsing/export UI |
| Finalized-attendance corrections / student excuse request | Deferred (ADD-02) | No audited approval/correction workflow |
| Published grading-policy revisions | Deferred (ADD-03) | Published policy remains locked |
| Course creation | Implemented | Doctor-only authorized creation |
| Course editing and TA reassignment | Deferred (PLAN-01) | Existing assignments are read-only |
| Question creation | Implemented | API supports two-to-six options; current form uses four |
| Question editing/archive | Deferred (ADD-05) | Existing snapshots preserved; no editing/archive UI |
| Saved scope/theme preferences and TA shortcuts | Implemented (ADD-08) | Account-isolated preferences restore permitted scope; assigned section workspaces |
| In-app notifications | Implemented | Current quiz/publication events and recipient isolation |
| TA action notifications / external push | Deferred | No agreed TA event flow or external delivery |
| Full-history attendance percentage | Implemented summary | Now excludes excuses and respects authorized scope; list still capped at 100 without pagination |
| Abandoned expired quiz finalization without reopening | Partial (BUG-03) | Staff sweep exists; no scheduler/automatic listing sweep establishes independent expiry |
| Standalone setup and exact shared runbook | Documented (DOC-01/02) | Checked-in seed; no .NET runtime dependency |
| Rubric/status matrix | Documented (DOC-03) | This document distinguishes implemented, partial and deferred scope |
| Offline web startup | Partial (DOC-04) | Prepare online and retain loaded sessions; fully offline cold startup remains unverified |
| Native camera/storage/LAN behavior | Manual pending | No mobile device/emulator was available during the earlier device check |

Passing current automated suites does not complete missing Phase 4 features or
the remaining earlier acceptance items. Do not present exports, scheduling,
draft attendance persistence or fully offline cold startup as implemented.

See [UI_UX_REVIEW.md](UI_UX_REVIEW.md) for the newer role-navigation and input
preservation checks, which are separate from the earlier acceptance matrices.
