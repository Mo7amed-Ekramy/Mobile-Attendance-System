# PostgreSQL attendance API

FastAPI and psycopg serve Flutter directly from PostgreSQL. .NET is not used
at runtime. Python 3.13 and PostgreSQL 18 were used for local validation.

## Setup

From the project root in PowerShell:

~~~powershell
python -m venv server/.venv
.\server\.venv\Scripts\python.exe -m pip install -r server/requirements.lock
~~~

For a fresh database, follow [database instructions](../database/README.md)
first, then apply API migrations and provision authentication:

~~~powershell
.\server\.venv\Scripts\python.exe server/setup.py
~~~

Setup reads administrator credentials from ignored database/.env. It applies
migrations 004 and 005, initializes only missing account password hashes, creates
the restricted university_attendance_api login, and writes generated connection
credentials to ignored server/.env. Re-running setup preserves existing hashes
and does not seed operational records.

requirements.lock pins the validated environment. requirements.txt describes
direct dependency ranges for intentional upgrades.

## Run

~~~powershell
.\server\.venv\Scripts\python.exe server/run.py
~~~

- API: http://127.0.0.1:8000/api/v1
- Database health: http://127.0.0.1:8000/api/v1/health
- Interactive documentation: http://127.0.0.1:8000/docs

Local browser origins on localhost/127.0.0.1 are allowed, including Flutter's
development port. Add --host 0.0.0.0 --port 8000 to serve native devices on the LAN.
Configure CORS explicitly for a separately hosted web frontend. Restart after
backend edits; the runner does not auto-reload.

Flutter uses API_BASE_URL at build time. Android emulator:
http://10.0.2.2:8000/api/v1. Physical device: the PC's LAN address.

## Authentication and configuration

See [development accounts](../README.md). Staff passwords are initialized by role
(Doctor@123, TA@123); students initially use their university IDs. Doctor, TA, and
student roles can sign in. Imported admins have no mobile interface.

Passwords use salted scrypt hashes. Opaque bearer sessions expire after 12 hours,
with only token hashes stored in PostgreSQL. Logout revokes the session. Requests
check current account activation and course/section assignments. Login throttling
is in memory per API process.

`POST /api/v1/auth/change-password` requires current and new passwords. A wrong
current password returns 422 without expiring the bearer session. Successful
change revokes other sessions while preserving the changing session; there is
no self-service recovery endpoint.

server/.env variables: PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD.
Environment overrides use the ATTENDANCE_ prefix, e.g. ATTENDANCE_PGHOST.
Flutter receives the API URL and session token only. The API database role has no
schema-owner/admin permissions, cannot modify migration/seed metadata, and cannot
update/delete audit events.

## Workflow rules

QR credentials rotate and expire on the server. Transactional check-in prevents
duplicate attendance. Lecture closure records remaining eligible absences.
TA finalization requires a resolved status for every student in the saved roster.

Published policies are locked. Fixed assessment budgets apply per section,
including shared assessments. Grades preserve zero versus missing and require
current revisions. Corrections require reasons; previous published snapshots
stay visible until republication. Section assessments apply to that section only.

Question banks and quiz question/option snapshots persist in PostgreSQL.
Student responses exclude answer keys. Deadlines and scores are server-controlled.
Results appear after instructor publication. Notifications are in-app;
external push/email delivery is not configured.

## Tests

~~~powershell
.\server\.venv\Scripts\python.exe -m unittest discover -s server -p 'test_*.py' -v
dart run tool/verify_api.dart
~~~

The eleven integration journeys create a unique attendance_api_test_* database,
apply seed/migrations there, and drop that exact database afterward. They require
administrator settings and the provisioned API role. They never truncate or add
workflow fixtures to university_attendance.
They include all-role password/session changes, early quiz closure, and
selected-section reports/attendance summaries with excuse exclusion.

The Dart live verifier requires the running API. It parses actual responses
through the app's Dart models and checks all three roles' reads/scope/logout.
Override API_BASE_URL, DOCTOR_USERNAME/DOCTOR_PASSWORD, TA_USERNAME/TA_PASSWORD,
or STUDENT_USERNAME/STUDENT_PASSWORD through environment variables for different
development accounts. Tokens and passwords are not printed.

## Demo limits

The seed has no historical workflows or academic year/dates; the imported term
remains legacy-semester-2. The SQL Server backup has not been restored/imported.
Account administration, password recovery, external push, deployment/HTTPS, and
physical-device camera/network verification remain beyond the local demo.
