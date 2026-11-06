# Doctor, TA and student acceptance checks

These checks exercise the real FastAPI HTTP service and the built Flutter app in
headless Chrome. Each run creates its own uniquely named PostgreSQL database,
imports the academic seed/migrations, provisions development accounts there,
starts an isolated API/static web server, and drops only that database afterward.
The running user's API and university_attendance records are preserved.

From the project root in PowerShell:

~~~powershell
.\server\.venv\Scripts\python.exe -m pip install -r tool/role_checks/requirements.txt
flutter build web --release --no-pub
.\server\.venv\Scripts\python.exe tool/role_checks/browser_smoke.py
.\server\.venv\Scripts\python.exe tool/role_checks/doctor_check.py
.\server\.venv\Scripts\python.exe tool/role_checks/ta_check.py
.\server\.venv\Scripts\python.exe tool/role_checks/student_check.py
.\server\.venv\Scripts\python.exe tool/role_checks/demo_rehearsal.py
.\server\.venv\Scripts\python.exe tool/role_checks/collect_results.py
.\server\.venv\Scripts\python.exe tool/role_checks/cleanup_audit.py
~~~

Requirements: the server dependencies/virtual environment, local PostgreSQL
administrator settings in ignored database/.env, the provisioned API database
login in ignored server/.env, an existing build/web, and installed Google Chrome.
Playwright uses installed Chrome, so no separate browser download is needed.

Browser API requests are proxied to the sandbox's own HTTP service. The test
bootstrap points CanvasKit at the built local assets; production bootstrap files
are not modified. Chrome still needs access to Flutter's font assets during cold
startup. Restricted execution environments may require approved network access.

The helper activates Flutter's off-screen accessibility control, then uses normal
keystrokes so text enters Flutter's real controllers. It preserves independent
browser storage for each sandbox. Browser selectors and numeric JSON formatting
must be validated before treating an assertion failure as a product defect.

`demo_rehearsal.py` uses a single temporary database shared by all three actors.
It creates independent Chrome contexts in one Playwright instance, performs
HTTP workflow prerequisites, verifies browser logins/scopes/reports, and restarts
its own API to verify persistence. Results are separate from the historical role
matrix in review/demo-rehearsal.json. See docs/DEMO_RUNBOOK.md.

Reports and scenario results live in review/. Raw browser diagnostics/screenshots
belong under ignored .dart_tool/role-checks/. Read PROJECT_REVIEW.md for the merged
bug backlog, role requests, coverage and remaining physical-device checks.
Run the read-only cleanup audit after all role checks have finished; it records
remaining test databases and main API health in review/cleanup-audit.json.

Expected permission denials are successful tests. Confirmed product discrepancies
remain failed checks until fixed. Scenario checkers preserve a report even when
individual assertions fail; a completed process is not proof that all scenarios
passed. Inspect role-test-summary.json and the role coverage matrices.
Headless browser tests do not establish physical
camera scanning, Android/iOS permissions, secure-storage behavior, or LAN/HTTPS
configuration on a real device.
