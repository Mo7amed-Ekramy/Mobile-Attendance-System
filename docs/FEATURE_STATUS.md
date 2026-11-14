# Implemented and deferred graduation scope

The later [priority workflow update](PRIORITY_WORKFLOW_UPDATE.md) implements
selected role-review recommendations and documents the QR image-to-database check.
The later [scanner fix](SCANNER_FIX.md) verifies camera release on exit without
scanning, late permission cleanup and the manual-entry rendering correction.

This matrix includes the 2026-11-06 UI/workflow refinement. See
[refinement verification](UI_REFINEMENT.md) for current implementation and evidence.
The older role reviews and Phase 4 audit are historical snapshots. [Phase 4 audit](../review/phase4-audit.md)
records the gate decision; [Phase 5 verification](PHASE5_VERIFICATION.md) records
the checks. Deferred work remains in [PROJECT_REVIEW.md](../PROJECT_REVIEW.md).

| Capability | Current status | Evidence / remaining work |
|---|---|---|
| Three-role login, restore, expiry and logout | Implemented; verified | Existing API/Flutter checks and shared browser rehearsal |
| In-app password change | Implemented; verified | Current password required; salted hash; other sessions revoked; current session retained |
| Password recovery / reset administration | Deferred | No recovery/reset UI or verified recovery mechanism |
| Lecture QR attendance and closure | Implemented; real browser decoder verified with simulated video | Actual displayed QR decoded and persisted in isolated PostgreSQL; duplicates/expiry/closure checked; scanning pauses after success; physical camera pending |
| Reopenable student attendance receipt | Implemented; verified | Actual course/session, own receipt ID/time/status and copy action; ownership isolation |
| TA complete section attendance finalization | Implemented | Every eligible row required; persisted, immutable finalized roster |
| Saving a partially marked attendance draft | Implemented; verified (ADD-04) | Server persistence, optimistic revisions, reload recovery and partial-row validation; drafts excluded from official totals |
| Attendance navigation warning | Implemented; tested (ADD-04) | Explicit discard for route exit/refresh; unmarked filtering retains all marks |
| Saved draft grades | Implemented | Explicit page save, revision checks and published snapshots |
| Attendance/grade revision-conflict review | Implemented; verified | Local input retained; explicit local/server comparison, discard or reviewed rebase; no automatic overwrite |
| Full-assessment publication preview | Implemented; verified | Full-scope counts and saved results, independent of visible page/section; stale preview rejected |
| Policy unsaved-edit guard | Implemented; verified | Save/discard/cancel for exit/refresh, allocation examples; published policy remains locked |
| Unsaved grade route-exit warning | Implemented; verified | Cancel retains edits; discard is explicit; equivalent number formatting is ignored |
| Grade refresh/pagination guards and republication indicators | Implemented for current page (ADD-04) | Explicit discard, pinned actions and unsaved/pending-publication feedback |
| Quiz creation, autosave, deadlines, submission and scoring | Implemented | Creates immediately active quizzes with immutable snapshots |
| Quiz readiness and answer-save feedback | Implemented; verified | Viewing creates no attempt; explicit start, server timing, pending/confirmed/failed choices and retry; unanswered overview |
| Early quiz close | Implemented; tested for normal flow | Scoped staff control, saved-answer scoring and notifications; cancellation is supported before attempts begin |
| Quiz scheduling, preparation and cancellation | Implemented; verified (ADD-06) | Future scheduled starts, hidden preparation drafts, explicit launch and cancellation before any attempt; 10-second server sweep |
| Course/section report screen | Implemented; verified | Scoped counts, attendance summaries, policy and assessments |
| Per-student report rows, print and export | Implemented for PDF (ADD-07) | Complete scoped roster, full-history attendance, published grade totals, embedded Arabic/Latin fonts, PDF export and print; CSV deferred |
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
| Full-history attendance percentage | Implemented; verified | Excludes excuses, respects authorized scope, and paginates session history in 50-row pages |
| Abandoned expired quiz finalization without reopening | Implemented; verified (BUG-03) | API background sweep every 10 seconds, scoped listing maintenance, valid audit actor and committed late-answer finalization |
| Standalone setup and exact shared runbook | Documented (DOC-01/02) | Checked-in seed; no .NET runtime dependency |
| Rubric/status matrix | Documented (DOC-03) | This document distinguishes implemented, partial and deferred scope |
| Offline web startup | Partial (DOC-04) | Prepare online and retain loaded sessions; fully offline cold startup remains unverified |
| Native camera/storage/LAN behavior | Manual pending | No mobile device/emulator was available during the earlier device check |

The principal Phase 4 workflow gaps are now implemented. Physical camera and
native print/share checks, CSV export, audit-history browsing and the other
explicitly deferred enhancements are separate from the verified web scope.
Bundled fonts and renderer assets remove their CDN dependency; fully offline
authentication and operational writes are not implemented.

See [UI_UX_REVIEW.md](UI_UX_REVIEW.md) for the newer role-navigation and input
preservation checks, which are separate from the earlier acceptance matrices.
