"""Reset operational data while preserving the complete academic directory.

Default: read-only inventory. --apply creates and restores a full backup before
truncating the explicitly listed operational tables in one transaction.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import secrets
import subprocess
import sys

import psycopg
from psycopg import sql

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'server'))
from db import connection_info, settings
from manage import connection_env, find_psql

ACADEMIC = (
    'academic_terms', 'app_users', 'course_departments', 'course_offerings',
    'course_sections', 'courses', 'department_sections', 'departments',
    'enrollments', 'schema_migrations', 'seed_imports', 'students',
)
OPERATIONAL = (
    'api_requests', 'api_sessions', 'assessment_results', 'assessments',
    'attendance_draft_marks', 'attendance_records', 'attendance_sessions',
    'audit_events', 'grade_categories', 'grading_policies', 'notifications',
    'published_results', 'qr_tokens', 'question_banks', 'question_options',
    'questions', 'quiz_answers', 'quiz_attempts', 'quiz_options',
    'quiz_questions', 'quizzes', 'session_eligibility',
)
ALL_TABLES = tuple(sorted(ACADEMIC + OPERATIONAL))


def snapshot(connection):
    tables = {row[0] for row in connection.execute(
        "SELECT tablename FROM pg_tables WHERE schemaname='attendance'")}
    if tables != set(ALL_TABLES):
        raise RuntimeError('Unexpected attendance tables; review the reset scope first.')
    result = {}
    for table in ALL_TABLES:
        query = sql.SQL('SELECT row_to_json(t)::text FROM attendance.{} t '
                        'ORDER BY row_to_json(t)::text').format(sql.Identifier(table))
        digest = hashlib.sha256()
        count = 0
        for (row,) in connection.execute(query):
            digest.update(row.encode('utf-8'))
            digest.update(b'\n')
            count += 1
        result[table] = {'count': count, 'sha256': digest.hexdigest()}
    return result


def run_pg(arguments, env):
    result = subprocess.run(arguments, env=env, capture_output=True, timeout=180)
    if result.returncode:
        # Restore errors can contain source data; do not print SQL or credentials.
        raise RuntimeError(f'{Path(arguments[0]).name} failed with exit code {result.returncode}')


def verified_backup(env, before, directory):
    binaries = Path(find_psql()).parent
    archive = directory / 'before-reset.dump'
    run_pg([str(binaries / 'pg_dump.exe'), '--no-password', '--format=custom',
            '--lock-wait-timeout=10s', '--file', str(archive),
            '--dbname', env['PGDATABASE']], env)
    verification_db = f'attendance_reset_check_{secrets.token_hex(8)}'
    created = False
    try:
        with psycopg.connect(connection_info(env | {'PGDATABASE': 'postgres'}),
                             autocommit=True) as admin:
            admin.execute(sql.SQL("CREATE DATABASE {} TEMPLATE template0 ENCODING 'UTF8'")
                          .format(sql.Identifier(verification_db)))
            created = True
        run_pg([str(binaries / 'pg_restore.exe'), '--no-password', '--no-owner',
                '--no-privileges', '--exit-on-error', '--dbname', verification_db,
                str(archive)], env)
        with psycopg.connect(connection_info(env | {'PGDATABASE': verification_db})) as restored:
            if snapshot(restored) != before:
                raise RuntimeError('Restored backup differs from the source; reset aborted.')
    finally:
        if created:
            # This exact generated name is the disposable verification database.
            if not verification_db.startswith('attendance_reset_check_'):
                raise RuntimeError('Unexpected backup-verification database name.')
            with psycopg.connect(connection_info(env | {'PGDATABASE': 'postgres'}),
                                 autocommit=True) as admin:
                admin.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)')
                              .format(sql.Identifier(verification_db)))
    return {'path': str(archive), 'bytes': archive.stat().st_size,
            'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'restored_and_verified': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', required=True, help='Exact existing application database name')
    parser.add_argument('--apply', action='store_true', help='Apply the reset after verifying a full backup')
    args = parser.parse_args()
    env = connection_env()
    runtime = settings()
    if env['PGDATABASE'] != args.database:
        raise RuntimeError('Requested database does not match database/.env.')
    defaults = {'PGHOST': 'localhost', 'PGPORT': '5432', 'PGDATABASE': 'university_attendance'}
    for key, default in defaults.items():
        if str(runtime.get(key, default)) != str(env.get(key, default)):
            raise RuntimeError('API and administrator database targets differ; reset aborted.')
    with psycopg.connect(connection_info(env)) as connection:
        before = snapshot(connection)
    summary = {
        'database': args.database,
        'preserved': {t: before[t]['count'] for t in ACADEMIC},
        'cleared': {t: before[t]['count'] for t in OPERATIONAL},
    }
    if not args.apply:
        print(json.dumps({'mode': 'read-only', **summary}, indent=2))
        return

    timestamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    directory = ROOT / '.local-backups' / f'operational-reset-{timestamp}-{secrets.token_hex(3)}'
    directory.mkdir(parents=True, exist_ok=False)
    backup = verified_backup(env, before, directory)
    manifest = directory / 'reset-manifest.json'
    evidence = {'status': 'backup_verified', 'timestamp_utc': timestamp,
                **summary, 'backup': backup, 'before': before}
    manifest.write_text(json.dumps(evidence, indent=2), encoding='utf-8')

    with psycopg.connect(connection_info(env)) as connection:
        with connection.transaction():
            connection.execute("SET LOCAL lock_timeout='10s'")
            tables = sql.SQL(', ').join(sql.Identifier('attendance', t) for t in ALL_TABLES)
            connection.execute(sql.SQL('LOCK TABLE {} IN ACCESS EXCLUSIVE MODE').format(tables))
            if snapshot(connection) != before:
                raise RuntimeError('Data changed after backup; reset aborted without deleting data.')
            targets = sql.SQL(', ').join(sql.Identifier('attendance', t) for t in OPERATIONAL)
            # RESTRICT deliberately avoids cascading into accounts or academic data.
            connection.execute(sql.SQL('TRUNCATE TABLE {} RESTART IDENTITY RESTRICT').format(targets))
            after = snapshot(connection)
            if any(after[t]['count'] for t in OPERATIONAL):
                raise RuntimeError('Operational tables were not emptied; transaction rolled back.')
            if any(after[t] != before[t] for t in ACADEMIC):
                raise RuntimeError('Academic data changed; transaction rolled back.')
    evidence.update(status='complete', after=after, academic_data_unchanged=True)
    manifest.write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps({'status': 'complete', **summary, 'backup': backup,
                      'manifest': str(manifest), 'academic_data_unchanged': True}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'Operational reset failed: {type(error).__name__}: {error}', file=sys.stderr)
        raise SystemExit(1)
