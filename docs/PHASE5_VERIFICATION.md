# Phase 5 verification and documentation

Date: 2026-11-01. Phase 4 remains **partial**, as recorded in
[the audit](../review/phase4-audit.md). This phase packages and checks the current
implementation; it does not imply that missing Phase 4 features have been built.

## Deliverables

| Requirement | Artifact / status |
|---|---|
| DOC-01: standalone setup | [SETUP.md](SETUP.md): checked-in seed, local `.env`, provisioned API login, supported SDKs, startup and build commands |
| DOC-02: exact shared demo | [DEMO_RUNBOOK.md](DEMO_RUNBOOK.md): three isolated identities, CS381/SE1, persisted attendance/quiz/publication and restart |
| DOC-03: implemented/deferred matrix | [FEATURE_STATUS.md](FEATURE_STATUS.md) |
| DOC-04: offline preparation | Runbook records online preparation and retained browser sessions; production fully offline cold startup remains unverified |

## Final checks

| Check | Result | Command / evidence |
|---|---|---|
| Full Flutter suite | **19 passed, 0 failed** | `flutter test --no-pub` |
| Backend integration journeys | **11 passed, 0 failed** | `.\server\.venv\Scripts\python.exe -m unittest discover -s server -p 'test_*.py' -v` |
| Seed conversion | **6 passed, 0 failed** | `.\server\.venv\Scripts\python.exe -m unittest discover -s database -p 'test_*.py' -v`; optional legacy source present on this PC |
| Flutter analysis | **No issues found** | `flutter analyze --no-pub` |
| Release JavaScript web build | **Succeeded** | `flutter build web --release --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1` |
| Shared three-role rehearsal | **12 passed, 0 failed** | [demo-rehearsal.json](../review/demo-rehearsal.json) |
| Python source compilation | **Passed** | Changed backend files and role-check helpers compiled with `py_compile` |
| Main API | **Healthy; updated routes loaded** | Restarted the previously running local API; health, password-change route and section-summary parameter verified |
| Device availability | Windows, Chrome, Edge only | `flutter devices --machine`; no mobile device/emulator |
| Cleanup | **No temporary databases remain** | [Read-only audit](../review/cleanup-audit.json); operational data preserved |

The shared rehearsal imports only the checked-in SQL seed into a fresh temporary
database. Its HTTP writes cover lecture check-in/duplicate protection/closure,
TA section finalization, quiz autosave/submission/publication and an official
100/100 student result. Three separate Chrome contexts verify exact CS381/SE1
scope, staff report rendering and login restoration. The isolated API is stopped
and restarted before rechecking persisted records and all three browser sessions.

The release artifact is JavaScript. Its Wasm dry run reports the secure-storage
web dependency's incompatibility, and the compiler reports a Cupertino icon-font
warning. A Wasm build and resolution of that asset warning were not part of this
successful JavaScript build. The backend environment also emits a Starlette
test-client deprecation warning; all assertions pass.

The earlier 325-scenario matrices remain historical and have not been relabeled
as passing by this follow-up. These targeted checks do not re-run that complete
matrix or close every earlier BUG/ADD item.

## Remaining gates

Complete the missing Phase 4 features listed in the audit, finish the six TA
browser checks, verify native camera/permissions/storage/LAN on a real device,
and validate a production cold startup with no external renderer/font fetches.
The shared rehearsal uses API-driven workflow writes and actual Chrome views;
it does not replace the complete manual form-by-form defense rehearsal.
