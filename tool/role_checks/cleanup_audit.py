"""Read-only audit of role-test cleanup and the user's existing API health."""
import json

import httpx
import psycopg
from psycopg.rows import dict_row

from support import ROOT, connection_env, connection_info


def main():
    admin = connection_env()
    with psycopg.connect(connection_info(admin | {'PGDATABASE': 'postgres'}),
                         row_factory=dict_row) as db:
        rows = db.execute('''SELECT datname FROM pg_database
            WHERE datname LIKE 'attendance_role_%' OR datname LIKE 'attendance_api_test_%'
            ORDER BY datname''').fetchall()
    remaining = [row['datname'] for row in rows]
    try:
        response = httpx.get('http://127.0.0.1:8000/api/v1/health', timeout=5)
        health = response.status_code == 200 and response.json().get('status') == 'ok'
    except (httpx.HTTPError, ValueError):
        health = False
    result = {'temporary_databases_remaining': remaining, 'main_api_healthy': health,
              'audit': 'Read-only; no databases or services were modified.'}
    (ROOT / 'review' / 'cleanup-audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))
    if remaining:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
