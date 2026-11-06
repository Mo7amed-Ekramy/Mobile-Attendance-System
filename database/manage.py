"""Create/import the local PostgreSQL database. No pip dependencies required."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent


def connection_env() -> dict[str, str]:
    env = os.environ.copy()
    config = HERE / '.env'
    if config.exists():
        for line in config.read_text(encoding='utf-8-sig').splitlines():
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            key, separator, value = line.partition('=')
            key = key.strip()
            if not separator or key not in {'PGHOST', 'PGPORT', 'PGUSER', 'PGPASSWORD', 'PGDATABASE'}:
                raise ValueError('Invalid setting in database/.env')
            env[key] = value  # Literal text, never evaluated by a shell.
    env.setdefault('PGHOST', 'localhost')
    env.setdefault('PGPORT', '5432')
    env.setdefault('PGUSER', 'postgres')
    env.setdefault('PGDATABASE', 'university_attendance')
    env['PGCONNECT_TIMEOUT'] = '5'
    env['PGCLIENTENCODING'] = 'UTF8'
    return env


def find_psql() -> str:
    executable = shutil.which('psql')
    if executable:
        return executable
    root = Path(os.environ.get('ProgramFiles', r'C:\Program Files')) / 'PostgreSQL'
    candidates = sorted(root.glob('*/bin/psql.exe'), key=lambda p: int(p.parent.parent.name) if p.parent.parent.name.isdigit() else 0, reverse=True)
    if candidates:
        return str(candidates[0])
    raise ValueError('psql was not found; install PostgreSQL or add its bin directory to PATH')


def psql(executable: str, env: dict[str, str], database: str, *, sql: str | None = None, file: Path | None = None) -> str:
    args = [executable, '-X', '-w', '--set=ON_ERROR_STOP=1', '--no-psqlrc', '-A', '-t', '-d', database]
    if sql is not None:
        args += ['-c', sql]
    elif file is not None:
        args += ['-f', str(file)]
    else:
        raise ValueError('SQL or file required')
    result = subprocess.run(args, env=env, capture_output=True, encoding='utf-8', errors='replace', timeout=60)
    if result.returncode:
        # PostgreSQL errors may contain source data. Print them locally, never a DSN/password.
        message = result.stderr.strip()
        if env.get('PGPASSWORD'):
            message = message.replace(env['PGPASSWORD'], '[redacted]')
        raise RuntimeError(message)
    return result.stdout.strip()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-connection', action='store_true')
    parser.add_argument('--verify-only', action='store_true')
    args = parser.parse_args()
    env = connection_env()
    executable = find_psql()
    database = env['PGDATABASE']
    if not re.fullmatch(r'[a-z_][a-z0-9_]{0,62}', database):
        raise ValueError('PGDATABASE must be a lowercase PostgreSQL identifier')
    identity = psql(executable, env, 'postgres', sql='SELECT current_user;')
    if args.check_connection:
        print(f"Connected to PostgreSQL as {identity} on {env['PGHOST']}:{env['PGPORT']}")
        return
    if not args.verify_only:
        for name in ('001_schema.sql', '002_seed.sql', 'seed_manifest.json', '003_verify.sql'):
            if not (HERE / name).is_file():
                raise ValueError(f'{name} is missing; prepare the seed first')
        exists = psql(executable, env, 'postgres', sql=f"SELECT 1 FROM pg_database WHERE datname = '{database}';")
        if exists != '1':
            psql(executable, env, 'postgres', sql=f'CREATE DATABASE "{database}" WITH ENCODING \'UTF8\' TEMPLATE template0;')
            print(f'Created database {database}')
        else:
            print(f'Using existing database {database}; no tables will be dropped')
        for name in ('001_schema.sql', '002_seed.sql'):
            psql(executable, env, database, file=HERE / name)
            print(f'Applied {name}')
    psql(executable, env, database, file=HERE / '003_verify.sql')
    manifest = json.loads((HERE / 'seed_manifest.json').read_text(encoding='utf-8'))
    tables = manifest['counts']
    rows = psql(executable, env, database, sql=' UNION ALL '.join(
        f"SELECT '{table}', count(*) FROM attendance.{table}" for table in tables))
    actual = {name: int(count) for name, count in (line.split('|') for line in rows.splitlines())}
    if actual != tables:
        raise RuntimeError(f'Database counts differ from seed manifest: {actual}')
    fingerprint = psql(executable, env, database, sql='SELECT source_hash FROM attendance.seed_imports;')
    if fingerprint != manifest['source_hash']:
        raise RuntimeError('Database source fingerprint differs from prepared seed')
    payload = psql(executable, env, database, sql=' UNION ALL '.join(
        f"SELECT '{table}', COALESCE(json_agg(json_build_array({', '.join(check['columns'])}) ORDER BY id), '[]'::json) FROM attendance.{table}"
        for table, check in manifest['data_checksums'].items()))
    for line in payload.splitlines():
        table, serialized = line.split('|', 1)
        canonical = json.dumps(json.loads(serialized), ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        if hashlib.sha256(canonical).hexdigest() != manifest['data_checksums'][table]['sha256']:
            raise RuntimeError(f'{table}: imported values differ from the original seed conversion')
    print('Verified every imported field, counts, relationships, score/section constraints, and source fingerprint')
    print(json.dumps(actual, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f'Database setup failed: {error}', file=sys.stderr)
        sys.exit(1)
