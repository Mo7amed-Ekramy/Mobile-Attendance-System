# Standalone setup on Windows

The checked-in `database/001_schema.sql` and `002_seed.sql` are sufficient to
initialize the academic database. The legacy .NET project is not required to
install or run this app. Regenerating the seed is optional and requires that
legacy source.

## Prerequisites

Validated locally with Flutter **3.47.6**, Dart **3.13.5**, Python **3.13.16**,
PostgreSQL **18**, and Chrome. Install Flutter with its platform tools, Python,
and PostgreSQL including `psql`; start the local PostgreSQL service. The app uses
APIs such as `CardThemeData`, so the Dart lower bound in `pubspec.yaml` alone is
not a sufficient Flutter version requirement. Use the validated Flutter version
for the defense.

The initial package installation needs internet. Commands below run in
PowerShell from the project root, `D:\Flutter_System\mobile` on this PC.

## 1. Configure and initialize PostgreSQL

On a fresh checkout, copy the example without replacing an existing configuration:

```powershell
if (!(Test-Path -LiteralPath database/.env)) {
    Copy-Item -LiteralPath database/.env.example -Destination database/.env
}
```

Edit `database/.env` locally. Set `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, and
`PGDATABASE`. The example uses `localhost:5432`, administrator `postgres`, and
database `university_attendance`. Enter the administrator password as literal
text after `PGPASSWORD=`. No quotes or PowerShell commands are evaluated.
Do not put this password in Flutter or commit `.env`.

```powershell
python database/manage.py --check-connection
python database/manage.py
```

The helper discovers `psql` in PATH or the standard Windows PostgreSQL directory.
It creates an absent database, applies the academic schema and checked-in seed,
and verifies imported counts and checksums. It does not drop an existing database.
For a genuinely fresh import expect 415 students, 451 users, 14 courses,
108 course sections and 2,460 enrollments.

This checksum verification is an **initial seed snapshot** check. It may fail
after legitimate academic/account edits or password provisioning; that does not
authorize deleting or reseeding a working database. Subsequent operational
validation uses the API and integration tests.

## 2. Install and provision the API

```powershell
python -m venv server/.venv
.\server\.venv\Scripts\python.exe -m pip install -r server/requirements.lock
.\server\.venv\Scripts\python.exe server/setup.py
```

Setup applies migrations 004, 005 and 006, initializes only missing password hashes,
and provisions the restricted `university_attendance_api` database login.
Generated credentials are written to ignored `server/.env`; preserve that file
when rerunning setup. Setup preserves existing passwords and creates no
attendance, quizzes, grades, or other operational demo fixtures.

Start the API in a dedicated terminal:

```powershell
.\server\.venv\Scripts\python.exe server/run.py
```

Verify <http://127.0.0.1:8000/api/v1/health> returns `{"status":"ok"}`.
API documentation is at <http://127.0.0.1:8000/docs>. Keep the service running.
The runner does not auto-reload: stop it with Ctrl+C and start it again after
backend edits. PostgreSQL data survives an API restart.

After pulling the UI/workflow refinement, rerun `server/setup.py` before restarting
the API. Migration 006 adds draft attendance marks and quiz cancellation; it
preserves existing academic and operational records. The running API sweeps quiz
deadlines every 10 seconds, including when students close the app.

## 3. Run Flutter

In another project-root terminal:

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Use the exact accounts and scope in [the demo runbook](DEMO_RUNBOOK.md).
If a password was changed, use that changed password; setup will not reset it.
The database is initially empty of workflow history, so empty operational
screens are expected.

## 4. Build and serve the web demo

```powershell
flutter build web --release --no-pub --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
python -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

Open <http://127.0.0.1:8080>. Serve the output over HTTP; opening `index.html`
directly does not provide a supported origin for Flutter and token storage.
See the runbook's renderer/font and offline preparation requirements.

## 5. Native devices and validation

For an Android emulator use `API_BASE_URL=http://10.0.2.2:8000/api/v1`.
For a physical Android device, start the API with `--host 0.0.0.0`, use the PC's
LAN IP, and check port 8000 firewall access. Android debug supports local HTTP;
release devices need an appropriate HTTPS endpoint. Camera permissions, native
storage and LAN behavior still require a real-device check.

```powershell
flutter test --no-pub
flutter analyze --no-pub
.\server\.venv\Scripts\python.exe -m unittest discover -s server -p 'test_*.py' -v
```

Backend tests import the checked-in seed into their own temporary database and
remove it afterward. They require the administrator and provisioned API settings.
The optional six conversion tests (`unittest discover -s database`) additionally
require the legacy JSON source; they are not required to install a standalone
checkout. See [API details](../server/README.md) and [database details](../database/README.md).
