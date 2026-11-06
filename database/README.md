# Local PostgreSQL database

Database: **university_attendance**. Server: **localhost:5432**, PostgreSQL 18.
Application tables live in the **attendance** schema. The database is independent
of the .NET project: .NET was used only as the source of the initial academic data.

## Imported data

| Table | Rows |
|---|---:|
| departments | 4 |
| department_sections | 19 |
| app_users | 451 |
| students | 415 |
| academic_terms | 1 |
| courses | 14 |
| course_departments | 18 |
| course_offerings | 14 |
| course_sections | 108 |
| enrollments | 2,460 |

The 451 accounts comprise 9 doctors, 21 TAs, 6 admins, and 415 students.
Names, university IDs, course codes, assignments, and source IDs are retained.
Student usernames and full names are stored once in `app_users`; the
`student_directory` view joins their academic profile.

The source is `../legacy-attendance-system/Seeding/*.json` relative to the
mobile project, with relationships checked against its `Models/Data/AppDBContext.cs`
and `AppDbContext.sql`. `Models/Data/DbSeeder.cs` supplies the enrollment rules:
match the student's department to `CourseDepartment`, then match course and
department section to `CourseSection`. The checked-in `NewMigration.Up()` is
empty, so it is not a complete database-creation source.

Staff IDs remain 0–35 and student profile IDs remain 1–415. Student application
user IDs occupy 36–450. These are seed IDs, not an assertion about the IDs assigned
in a separately restored SQL Server database. University IDs remain text.

Courses belong to a catalog, while offerings belong to a term. The seed contains
semester `2` but no academic year or dates, so the imported term is explicitly
named `legacy-semester-2`. Set its real year/dates when known. No academic dates
were invented.

Attendance, grade policies/categories, assessments/results, question banks,
quizzes/attempts/answers, notifications, and audit events have tables but start
empty. The JSON does not contain these records. No default passwords, generated
GPA values, or invented contact details were imported by the seed. The API setup
now provisions password hashes for imported accounts; see
[server/README.md](../server/README.md). Operational records are created through
the app and persisted here.

The SQL Server `.bak` is not a PostgreSQL backup. Historical operational records
inside it have not been imported. Bringing them across would require restoring
it in SQL Server and exporting those tables separately.

## Files

- `001_schema.sql`: PostgreSQL schema migration, keys, indexes, and validation triggers.
- `002_seed.sql`: generated, UTF-8 SQL containing the extracted source records.
- `003_verify.sql`: relationship checks and temporary constraint probes; probes roll back.
- `004_api_schema.sql`: hashed login sessions, idempotency receipts, published snapshots.
- `005_assessment_scope.sql`: section-specific assessment eligibility.
- `seed_manifest.json`: source fingerprints, counts, and checksums of every imported field.
- `prepare_seed.py`: reproducible conversion; uses Python standard library only.
- `manage.py`: creates the database if absent, applies scripts, and verifies the import.
- `.env`: local connection settings, ignored by Git. Keep the password here, outside Flutter.

Schema and seed scripts are transactional and safe to replay. The identical seed
is skipped on a repeat run, preserving existing data. A different seed will fail
if academic data already exists; it does not silently overwrite or delete rows.
Future schema edits require a new numbered migration recorded in
`attendance.schema_migrations`. `server/setup.py` applies API migrations 004 and
005 separately after the academic seed is installed.

## Inspect in pgAdmin

Register/connect to the local server on port 5432 as `postgres` using your local
password. Expand:

`Databases → university_attendance → Schemas → attendance → Tables`

Open Query Tool **in university_attendance**:

```sql
SELECT * FROM attendance.course_section_directory ORDER BY course_code, section_number;
SELECT * FROM attendance.student_directory ORDER BY id LIMIT 20;

-- Roster by an actual section ID; never parse an Arabic/English section label.
SELECT s.university_id, s.full_name, e.id AS enrollment_id
FROM attendance.enrollments e
JOIN attendance.student_directory s ON s.id = e.student_id
WHERE e.course_section_id = 1 AND e.state = 'active'
ORDER BY s.full_name;
```

## Recreate or verify

From the `mobile` directory, Python 3 and PostgreSQL client tools are sufficient:

For a fresh checkout, copy `.env.example` to ignored `.env` and configure local
administrator credentials first. Use the checked-in seed directly; no .NET
checkout is required. See [standalone setup](../docs/SETUP.md).

```powershell
python database/manage.py --check-connection
python database/manage.py
python database/manage.py --verify-only
```

Optional regeneration (`python database/prepare_seed.py`) and the six conversion
tests (`python -m unittest discover -s database -p 'test_*.py' -v`) require the
legacy source JSON. They are separate from importing the checked-in seed.

`manage.py` reads `.env` literally and passes credentials through the child process
environment. It does not evaluate settings as shell commands or print the
password. It discovers `psql` in PATH or the PostgreSQL installation under
Program Files. Scripts can also be run in pgAdmin in numeric order inside an
empty database; `.env` is only needed by the Python helper.

Verification compares every imported field and count with the prepared seed,
then checks score bounds, zero versus missing, cross-offering result isolation,
section eligibility, duplicate attendance, and quiz-attempt uniqueness/scope.
This is a **seed snapshot check**; it is intended for initial setup, before
accounts/enrollments are edited or authentication credentials are provisioned.

## Application integration

Flutter now reads and writes through the authenticated FastAPI service in `server/`.
The static academic directory and runtime mock state have been removed from
Flutter. The API enforces role/assignment scope, student result visibility,
publication, server-controlled quiz deadlines/scoring, QR expiry, transactions,
and audit writes. Its restricted database login is `university_attendance_api`;
generated credentials stay in ignored `server/.env`.

Keep administrator credentials in ignored `database/.env`. Only the API connects
to PostgreSQL. Directory views remain administrative SQL helpers; mobile rosters
are returned only after authentication and scope checks.

See [root README](../README.md) for Flutter startup/development accounts, and
[API instructions](../server/README.md) for provisioning and integration tests.
