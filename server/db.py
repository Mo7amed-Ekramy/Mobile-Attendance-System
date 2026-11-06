from contextlib import contextmanager
import os
from pathlib import Path

from psycopg.conninfo import make_conninfo
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

HERE = Path(__file__).resolve().parent


def settings(path: Path | None = None) -> dict[str, str]:
    values = {}
    path = path or HERE / '.env'
    if path.exists():
        for line in path.read_text(encoding='utf-8-sig').splitlines():
            if line.strip() and not line.lstrip().startswith('#'):
                key, separator, value = line.partition('=')
                if separator:
                    values[key.strip()] = value
    for key in ('PGHOST', 'PGPORT', 'PGUSER', 'PGPASSWORD', 'PGDATABASE'):
        if os.environ.get('ATTENDANCE_' + key) is not None:
            values[key] = os.environ['ATTENDANCE_' + key]
    return values


def connection_info(values: dict[str, str]) -> str:
    return make_conninfo(host=values.get('PGHOST', 'localhost'), port=values.get('PGPORT', '5432'),
        user=values.get('PGUSER', 'university_attendance_api'), password=values.get('PGPASSWORD', ''),
        dbname=values.get('PGDATABASE', 'university_attendance'), connect_timeout=5,
        options='-c search_path=attendance,public -c timezone=UTC -c statement_timeout=15000')


class Database:
    def __init__(self, values: dict[str, str] | None = None):
        self.pool = ConnectionPool(connection_info(values or settings()), min_size=1, max_size=8,
            timeout=10, open=False, kwargs={'row_factory': dict_row})

    def open(self):
        self.pool.open(wait=True)

    def close(self):
        self.pool.close()

    @contextmanager
    def transaction(self):
        with self.pool.connection() as connection:
            with connection.transaction():
                yield connection
