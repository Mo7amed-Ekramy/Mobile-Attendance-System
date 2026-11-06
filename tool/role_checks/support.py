"""Isolated real-API/browser environment for doctor, TA and student checks.

Never connects the app under test to university_attendance. Every sandbox owns a
unique database, API port, static-web port and independent Chrome context.
"""
from contextlib import contextmanager, ExitStack
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import mimetypes
import os
import secrets
import socket
import sys
import threading
import time

import httpx
import psycopg
from psycopg import sql
from psycopg.rows import dict_row
import uvicorn

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'server'))
sys.path.insert(0, str(ROOT / 'database'))
from app import create_app
from db import Database, connection_info, settings
from manage import connection_env
from security import hash_password

mimetypes.add_type('application/wasm', '.wasm')
mimetypes.add_type('text/javascript', '.js')


class QuietWebHandler(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


class Sandbox:
    credentials = {
        'doctor': ('doc_rasha01', 'Doctor@123'),
        'ta': ('ta_nehad00', 'TA@123'),
        'student': ('20720236007', '20720236007'),
        'admin': ('admin_youssef03', 'Admin@123'),
    }

    def __init__(self, role):
        if role not in ('doctor', 'ta', 'student', 'smoke'):
            raise ValueError('Invalid role sandbox')
        self.role = role
        self.name = f'attendance_role_{role}_{os.getpid()}_{secrets.token_hex(3)}'
        self.admin = connection_env()
        self.config = self.admin | {'PGDATABASE': self.name}
        self.tokens = {}
        self.created = False
        self.api_server = self.web_server = self.client = None
        self.api_thread = self.web_thread = None
        self.shared = {'offering_id': 1, 'section_id': 1}

    def __enter__(self):
        try:
            with psycopg.connect(connection_info(self.admin | {'PGDATABASE': 'postgres'}), autocommit=True) as admin:
                admin.execute(sql.SQL("CREATE DATABASE {} TEMPLATE template0 ENCODING 'UTF8'").format(sql.Identifier(self.name)))
            self.created = True
            with psycopg.connect(connection_info(self.config), autocommit=True, row_factory=dict_row) as db:
                for name in ('001_schema.sql', '002_seed.sql', '004_api_schema.sql', '005_assessment_scope.sql'):
                    db.execute((ROOT / 'database' / name).read_text(encoding='utf-8'))
                # Provision documented development accounts only in this sandbox.
                for role in ('doctor', 'ta', 'student'):
                    identifier, password = self.credentials[role]
                    db.execute('''UPDATE app_users SET password_hash=%s WHERE username=%s
                        OR id IN (SELECT user_id FROM students WHERE university_id=%s)''',
                        (hash_password(password), identifier, identifier))
                admin_user = db.execute("SELECT username FROM app_users WHERE role='admin' ORDER BY id LIMIT 1").fetchone()
                self.credentials = dict(self.credentials)
                self.credentials['admin'] = (admin_user['username'], 'Admin@123')
                db.execute('UPDATE app_users SET password_hash=%s WHERE username=%s',
                    (hash_password('Admin@123'), admin_user['username']))
                self.shared.update(db.execute('''SELECT u.id AS user_id,s.id AS student_id,e.id AS enrollment_id
                    FROM app_users u JOIN students s ON s.user_id=u.id JOIN enrollments e ON e.student_id=s.id
                    WHERE s.university_id=%s AND e.offering_id=1''', (self.credentials['student'][0],)).fetchone())
                self.runtime = settings() | {'PGDATABASE': self.name}
                role = sql.Identifier(self.runtime['PGUSER'])
                db.execute(sql.SQL('GRANT USAGE ON SCHEMA attendance TO {}').format(role))
                db.execute(sql.SQL('GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA attendance TO {}').format(role))
                db.execute(sql.SQL('GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA attendance TO {}').format(role))
                db.execute(sql.SQL('REVOKE INSERT,UPDATE,DELETE ON schema_migrations,seed_imports FROM {}').format(role))
                db.execute(sql.SQL('REVOKE UPDATE,DELETE ON audit_events FROM {}').format(role))
            self.api_socket = socket.socket()
            self.api_socket.bind(('127.0.0.1', 0))
            self.api_url = f'http://127.0.0.1:{self.api_socket.getsockname()[1]}/api/v1'
            self.api_server = uvicorn.Server(uvicorn.Config(create_app(Database(self.runtime)),
                host='127.0.0.1', port=0, log_level='error', access_log=False))
            self.api_thread = threading.Thread(target=self.api_server.run,
                kwargs={'sockets': [self.api_socket]}, daemon=True)
            self.api_thread.start()
            deadline = time.monotonic() + 20
            while not self.api_server.started:
                if not self.api_thread.is_alive() or time.monotonic() > deadline:
                    raise RuntimeError('Isolated API did not start')
                time.sleep(.05)
            self.client = httpx.Client(base_url=self.api_url + '/', timeout=20)
            self.web_server = ThreadingHTTPServer(('127.0.0.1', 0),
                partial(QuietWebHandler, directory=str(ROOT / 'build' / 'web')))
            self.web_url = f'http://localhost:{self.web_server.server_port}'
            self.web_thread = threading.Thread(target=self.web_server.serve_forever, daemon=True)
            self.web_thread.start()
            return self
        except BaseException:
            self.close()
            raise

    def query(self, statement, params=()):
        with psycopg.connect(connection_info(self.config), row_factory=dict_row) as db:
            cursor = db.execute(statement, params)
            return cursor.fetchall() if cursor.description else []

    def login(self, role, identifier=None, password=None):
        normal_identifier, normal_password = self.credentials[role]
        response = self.client.post('auth/login', json={
            'identifier': normal_identifier if identifier is None else identifier,
            'password': normal_password if password is None else password,
        })
        if response.status_code == 200:
            self.tokens[role] = response.json()['token']
        return response

    def headers(self, role):
        if role not in self.tokens:
            response = self.login(role)
            if response.status_code != 200:
                raise RuntimeError(f'{role} fixture login failed: {response.status_code}')
        return {'Authorization': 'Bearer ' + self.tokens[role]}

    def request(self, method, path, role='doctor', *, json=None, headers=None, **kwargs):
        request_headers = self.headers(role) if role else {}
        request_headers |= headers or {}
        return self.client.request(method, path.lstrip('/'), headers=request_headers, json=json, **kwargs)

    def call(self, method, path, role='doctor', *, expected=200, **kwargs):
        response = self.request(method, path, role=role, **kwargs)
        if response.status_code != expected:
            raise AssertionError(f'{method} {path}: expected {expected}, got {response.status_code}')
        return response.json()

    @contextmanager
    def browser(self, *, width=1280, height=1000, browser_instance=None):
        from playwright.sync_api import sync_playwright
        with ExitStack() as resources:
            if browser_instance is None:
                pw = resources.enter_context(sync_playwright())
                browser = pw.chromium.launch(channel='chrome', headless=True,
                    args=['--disable-dev-shm-usage'])
                resources.callback(browser.close)
            else:
                browser = browser_instance
            context = browser.new_context(viewport={'width': width, 'height': height},
                service_workers='block')
            page = context.new_page()
            page.set_default_timeout(15000)
            self.browser_errors = []
            self.browser_requests = []
            page.on('pageerror', lambda error: self.browser_errors.append(str(error)))

            def proxy_api(route):
                # Forward every UI API request into this exact isolated database.
                path = route.request.url.split('/api/v1', 1)[1]
                try:
                    response = route.fetch(url=self.api_url + path)
                    self.browser_requests.append((route.request.method, path, response.status))
                    route.fulfill(response=response)
                except Exception:
                    # Playwright's raw fetch exception can include request bearer
                    # headers during teardown. Record safe metadata and abort.
                    self.browser_requests.append((route.request.method, path, 'proxy_unavailable_or_closed'))
                    try:
                        route.abort()
                    except Exception:
                        pass

            context.route('**/api/v1/**', proxy_api)

            def bootstrap(route):
                source = (ROOT / 'build' / 'web' / 'flutter_bootstrap.js').read_text(encoding='utf-8')
                source = source.replace('_flutter.loader.load({',
                    '_flutter.loader.load({config:{canvasKitBaseUrl:"' + self.web_url + '/canvaskit/"},', 1)
                route.fulfill(status=200, content_type='text/javascript', body=source)

            context.route('**/flutter_bootstrap.js', bootstrap)
            try:
                yield page
            finally:
                for active_page in context.pages:
                    active_page.close()
                context.unroute_all(behavior='ignoreErrors')
                context.close()

    def open_ui(self, page):
        page.goto(self.web_url, wait_until='domcontentloaded')
        self.enable_semantics(page)
        return page

    @staticmethod
    def enable_semantics(page):
        placeholder = page.locator('flt-semantics-placeholder')
        page.locator('flt-semantics-placeholder, flt-semantics').first.wait_for(
            state='attached', timeout=30000)
        if placeholder.count():
            placeholder.evaluate('(element) => element.click()')
        # A reload may preserve accessibility and therefore have no placeholder.
        page.locator('flt-semantics').first.wait_for(state='attached', timeout=10000)

    def ui_login(self, page, role, *, identifier=None, password=None):
        normal_identifier, normal_password = self.credentials[role]
        values = (
            ('اسم المستخدم أو الرقم الجامعي', normal_identifier if identifier is None else identifier),
            ('كلمة المرور', normal_password if password is None else password),
        )
        for label, value in values:
            # Trusted keystrokes follow actual Flutter focus/controller updates,
            # including after validation, reveal toggles and prior login errors.
            page.locator(f'input[aria-label="{label}"]').last.click()
            page.evaluate('''() => new Promise(resolve =>
                requestAnimationFrame(() => requestAnimationFrame(resolve)))''')
            page.keyboard.press('Control+A')
            page.keyboard.press('Backspace')
            page.keyboard.type(value, delay=15)
        page.get_by_role('button', name='تسجيل الدخول').first.click()

    def __exit__(self, *_):
        self.close()

    def close(self):
        if self.web_server:
            self.web_server.shutdown()
            self.web_server.server_close()
            self.web_thread.join(timeout=10)
        if self.client:
            self.client.close()
        if self.api_server:
            self.api_server.should_exit = True
            self.api_thread.join(timeout=15)
            if self.api_thread.is_alive():
                raise RuntimeError('Sandbox API still running; refusing database cleanup')
            self.api_socket.close()
        if self.created:
            if not self.name.startswith('attendance_role_') or self.name == self.admin.get('PGDATABASE'):
                raise RuntimeError('Unsafe sandbox database name; refusing cleanup')
            with psycopg.connect(connection_info(self.admin | {'PGDATABASE': 'postgres'}), autocommit=True) as admin:
                admin.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(self.name)))
            self.created = False
