"""Apply API migration and provision local-development login hashes and API role."""
import os
from pathlib import Path
import secrets
import sys

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'database'))
from manage import connection_env
from db import connection_info, settings
from security import hash_password


def main():
    admin = connection_env()
    with psycopg.connect(connection_info(admin), row_factory=dict_row) as connection:
        for migration in ('004_api_schema.sql', '005_assessment_scope.sql', '006_workflow_completion.sql'):
            connection.execute((HERE.parent / 'database' / migration).read_text(encoding='utf-8'))
        users = connection.execute('SELECT id, role FROM attendance.app_users WHERE password_hash IS NULL ORDER BY id').fetchall()
        student_ids = {row['user_id']: row['university_id'] for row in connection.execute('SELECT user_id, university_id FROM attendance.students')}
        for user in users:
            password = student_ids[user['id']] if user['role'] == 'student' else {'doctor': 'Doctor@123', 'ta': 'TA@123', 'admin': 'Admin@123'}[user['role']]
            connection.execute('UPDATE attendance.app_users SET password_hash=%s WHERE id=%s', (hash_password(password), user['id']))
        # Dedicated credentials for this API, separate from the PostgreSQL administrator.
        local = settings()
        role = local.get('PGUSER', 'university_attendance_api')
        exists = connection.execute('SELECT 1 FROM pg_roles WHERE rolname=%s', (role,)).fetchone()
        password = local.get('PGPASSWORD')
        if exists and not password:
            raise RuntimeError('API role exists but server/.env has no password; refusing to change an existing role')
        if not exists:
            password = password or secrets.token_urlsafe(32)
            connection.execute(sql.SQL('CREATE ROLE {} LOGIN PASSWORD {}').format(sql.Identifier(role), sql.Literal(password)))
        connection.execute(sql.SQL('GRANT CONNECT ON DATABASE {} TO {}').format(sql.Identifier(admin['PGDATABASE']), sql.Identifier(role)))
        connection.execute(sql.SQL('GRANT USAGE ON SCHEMA attendance TO {}').format(sql.Identifier(role)))
        connection.execute(sql.SQL('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA attendance TO {}').format(sql.Identifier(role)))
        connection.execute(sql.SQL('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA attendance TO {}').format(sql.Identifier(role)))
        connection.execute(sql.SQL('REVOKE INSERT, UPDATE, DELETE ON attendance.schema_migrations, attendance.seed_imports FROM {}').format(sql.Identifier(role)))
        connection.execute(sql.SQL('REVOKE UPDATE, DELETE ON attendance.audit_events FROM {}').format(sql.Identifier(role)))
        values = {'PGHOST': admin['PGHOST'], 'PGPORT': admin['PGPORT'], 'PGDATABASE': admin['PGDATABASE'], 'PGUSER': role, 'PGPASSWORD': password}
        (HERE / '.env').write_text(''.join(f'{key}={value}\n' for key, value in values.items()), encoding='utf-8')
    print(f'API migration applied; provisioned {len(users)} login hashes; restricted API role ready')


if __name__ == '__main__':
    main()
