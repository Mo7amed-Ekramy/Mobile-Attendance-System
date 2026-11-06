"""Doctor-persona API journey against an isolated database, never app records.

Run from project root with server/.venv/Scripts/python.exe.
Browser checks are added when the coordinator's browser harness is available.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import re
import sys
import threading
import time

import psycopg

sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'server'))

import auth
from support import Sandbox
from security import token_hash


class HttpClientProxy:
    def __init__(self, sandbox):
        self.sandbox = sandbox

    def request(self, method, path, **kwargs):
        return self.sandbox.client.request(method, path.removeprefix('/api/v1').lstrip('/'), **kwargs)

    def patch(self, path, **kwargs):
        return self.request('PATCH', path, **kwargs)


class HttpJourney:
    """Compatibility adapter: every call reaches the actual isolated HTTP API."""
    def __init__(self, sandbox):
        self.sandbox = sandbox
        self.client = HttpClientProxy(sandbox)
        self.query = sandbox.query
        self.doctor = sandbox.headers('doctor')
        self.ta = sandbox.headers('ta')
        self.learner = sandbox.headers('student')
        self.student = {'university_id': sandbox.credentials['student'][0], **sandbox.shared}
        self.peer = sandbox.query('''SELECT e.id AS enrollment_id FROM enrollments e
            WHERE e.course_section_id=1 AND e.id<>%s ORDER BY e.id LIMIT 1''',
            (sandbox.shared['enrollment_id'],))[0]


class DoctorChecks:
    def __init__(self, journey):
        self.j = journey
        self.rows = []
        self.doctor = journey.doctor
        self.ta = journey.ta
        self.student = journey.learner

    def check(self, feature, scenario, fn):
        try:
            detail = fn()
            self.rows.append((feature, scenario, 'PASS', str(detail or 'Verified')))
            if feature.startswith('UI '):
                print(f'Doctor browser PASS: {scenario}', flush=True)
            return detail
        except Exception as error:
            # Do not log request headers, credentials, or full API responses.
            self.rows.append((feature, scenario, 'FAIL', f'{type(error).__name__}: {error}'))
            if feature.startswith('UI '):
                print(f'Doctor browser FAIL: {scenario}', flush=True)
            return None

    @staticmethod
    def require(condition, message):
        if not condition:
            raise AssertionError(message)

    def call(self, method, path, body=None, role=None, status=200):
        headers = self.doctor if role is None else role
        response = self.j.client.request(method, '/api/v1' + path, json=body, headers=headers)
        self.require(response.status_code == status,
                     f'{method} {path}: expected HTTP {status}, got {response.status_code}')
        return response.json()

    def login(self, name='doc_rasha01', password='Doctor@123', status=200):
        return self.call('POST', '/auth/login', {'identifier': name, 'password': password}, role={}, status=status)

    def run(self):
        C = self.check
        R = self.require
        C('Login', 'Valid doctor credentials select doctor role', lambda: R(self.login()['user']['role'] == 'doctor', 'Wrong role'))
        C('Login', 'Username case and surrounding whitespace', lambda: R(self.login('  DOC_RASHA01  ')['user']['role'] == 'doctor', 'Username normalization failed'))
        C('Login', 'Blank username rejected', lambda: self.login('', status=422) and 'HTTP 422')
        C('Login', 'Blank password rejected', lambda: self.login(password='', status=422) and 'HTTP 422')
        C('Login', 'Wrong password rejected', lambda: self.login(password='invalid-password', status=401) and 'HTTP 401')
        C('Login', 'Unknown username rejected', lambda: self.login('doctor-role-unknown', status=401) and 'HTTP 401')
        C('Login', 'Password case matters', lambda: self.login(password='doctor@123', status=401) and 'HTTP 401')
        C('Login', 'Password whitespace is not silently removed', lambda: self.login(password=' Doctor@123 ', status=401) and 'HTTP 401')
        C('Login', 'SQL-like username is rejected', lambda: self.login("' OR 1=1 --", status=401) and 'HTTP 401')
        C('Session', 'Anonymous profile request rejected', lambda: self.call('GET', '/me', role={}, status=401) and 'HTTP 401')
        C('Session', 'Invented bearer token rejected', lambda: self.call('GET', '/me', role={'Authorization': 'Bearer not-a-session'}, status=401) and 'HTTP 401')
        profile = self.call('GET', '/me')
        C('Session', 'Restore existing bearer session/profile', lambda: R(profile['username'] == 'doc_rasha01', 'Unexpected profile'))

        def expiration():
            value = self.login()
            headers = {'Authorization': 'Bearer ' + value['token']}
            self.j.query("UPDATE api_sessions SET expires_at=now()-interval '1 second' WHERE token_hash=%s", (token_hash(value['token']),))
            self.call('GET', '/me', role=headers, status=401)
            return 'Expired token rejected with HTTP 401'
        C('Session', 'Server session expiry enforced', expiration)

        def disabled():
            self.j.query('UPDATE app_users SET is_active=false WHERE id=%s', (profile['id'],))
            try:
                self.login(status=401)
                self.call('GET', '/me', status=401)
            finally:
                self.j.query('UPDATE app_users SET is_active=true WHERE id=%s', (profile['id'],))
            return 'Disabled login and existing token both rejected'
        C('Login', 'Disabled doctor account cannot sign in or use a session', disabled)

        def throttling():
            auth.failures.clear()
            for _ in range(10):
                self.login('doctor-role-throttle', password='incorrect', status=401)
            self.login('doctor-role-throttle', password='incorrect', status=429)
            auth.failures.clear()
            return 'First 10 failures reject credentials; next attempt returns HTTP 429'
        C('Login', 'Repeated failed attempts are throttled', throttling)

        courses = self.call('GET', '/courses')
        C('Courses', 'Assigned courses loaded with actual sections', lambda: R(len(courses) == 2 and any(c['id'] == 1 for c in courses), 'Unexpected assigned courses'))
        C('Permissions', 'Other doctor course cannot be read', lambda: self.call('GET', '/courses/2/roster', status=403) and 'HTTP 403')
        roster = self.call('GET', '/courses/1/roster')
        C('Rosters', 'Full assigned course roster is paginated', lambda: R(roster['total'] > 50 and len(roster['rows']) == 50, 'Pagination missing'))
        C('Rosters', 'Next page has different enrollment rows', lambda: R(not ({r['enrollment_id'] for r in roster['rows']} & {r['enrollment_id'] for r in self.call('GET', '/courses/1/roster?offset=50')['rows']}), 'Pagination duplicates rows'))
        C('Rosters', 'University ID search finds exact student', lambda: R(self.call('GET', '/courses/1/roster?search=' + self.j.student['university_id'])['total'] == 1, 'Exact search mismatch'))
        C('Rosters', 'Section selection constrains eligible students', lambda: R(all(r['course_section_id'] == 1 for r in self.call('GET', '/courses/1/roster?section_id=1')['rows']), 'Wrong section rows'))
        C('Rosters', 'Out-of-scope section rejected', lambda: self.call('GET', '/courses/1/roster?section_id=108', status=403) and 'HTTP 403')
        options = self.call('GET', '/catalog-options')
        C('Course creation', 'Actual department sections and active TAs loaded', lambda: R(bool(options['sections']) and bool(options['tas']), 'Catalog choices missing'))
        new_course = {'code': 'DOCROLE01', 'name': 'Doctor role test course', 'level': 3,
                      'department_section_id': options['sections'][0]['id'], 'ta_user_id': options['tas'][0]['id']}
        created = self.call('POST', '/courses', new_course)
        C('Course creation', 'New offering, assignment, and enrollments persist', lambda: R(any(c['id'] == created['id'] for c in self.call('GET', '/courses')), 'Created course absent'))
        C('Course creation', 'Duplicate code rejected', lambda: self.call('POST', '/courses', new_course, status=409) and 'HTTP 409')
        C('Course creation', 'Invalid section rejected', lambda: self.call('POST', '/courses', new_course | {'code': 'DOCROLE02', 'department_section_id': 999999}, status=422) and 'HTTP 422')
        C('Course creation', 'Invalid TA rejected', lambda: self.call('POST', '/courses', new_course | {'code': 'DOCROLE03', 'ta_user_id': 999999}, status=422) and 'HTTP 422')
        C('Course creation', 'TA cannot create a course', lambda: self.call('POST', '/courses', new_course, role=self.ta, status=403) and 'HTTP 403')
        C('Assignments', 'Doctor views all assigned course sections', lambda: R(len(self.call('GET', '/courses/1/assignments')) > 1, 'Teaching assignments missing'))

        fixed_root = f"/courses/{created['id']}"
        fixed = self.call('PUT', fixed_root + '/policy', {'total_points': '100', 'categories': [
            {'code': 'fixed', 'name': 'Fixed assessment', 'kind': 'assessment', 'max_points': '100', 'allocation_mode': 'fixed'}]})
        fixed_body = {'category_id': fixed['categories'][0]['id'], 'title': 'Fixed points', 'kind': 'assignment', 'max_points': '40'}
        self.call('POST', fixed_root + '/assessments', fixed_body)
        C('Policy', 'Fixed allocation cannot publish an underfilled budget', lambda: self.call('POST', fixed_root + '/policy/publish', status=422) and 'HTTP 422')
        C('Policy', 'Fixed allocation cannot exceed budget', lambda: self.call('POST', fixed_root + '/assessments', fixed_body | {'max_points': '61'}, status=422) and 'HTTP 422')
        self.call('POST', fixed_root + '/assessments', fixed_body | {'max_points': '60'})
        C('Policy', 'Fully allocated fixed policy can publish', lambda: R(self.call('POST', fixed_root + '/policy/publish')['state'] == 'published', 'Fixed publication failed'))

        lecture = self.call('POST', '/courses/1/sessions', {'kind': 'lecture', 'title': 'Doctor role lecture', 'duration_minutes': 30})
        sid = lecture['id']
        C('Lecture attendance', 'Opening a lecture saves eligible roster', lambda: R(len(self.call('GET', f'/courses/1/sessions/{sid}')['rows']) == roster['total'], 'Saved eligibility mismatch'))
        first = self.call('GET', f'/courses/1/sessions/{sid}/qr')
        second = self.call('GET', f'/courses/1/sessions/{sid}/qr')
        C('Lecture attendance', 'QR credentials rotate with an expiry', lambda: R(first['payload'] != second['payload'] and bool(second['valid_until']), 'QR did not rotate'))
        C('Permissions', 'Doctor cannot check in as a student', lambda: self.call('POST', '/attendance/check-ins', {'payload': first['payload']}, status=403) and 'HTTP 403')
        self.call('POST', '/attendance/check-ins', {'payload': first['payload']}, role=self.student)
        C('Lecture attendance', 'Counterpart student check-in appears in doctor roster', lambda: R(any(r['enrollment_id'] == self.j.student['enrollment_id'] and r['status'] == 'present' for r in self.call('GET', f'/courses/1/sessions/{sid}')['rows']), 'Checked-in student not visible'))
        self.call('POST', f'/courses/1/sessions/{sid}/close')
        C('Lecture attendance', 'Close materializes absences without overwriting presence', lambda: R(self.j.query('SELECT count(*) AS count FROM attendance_records WHERE session_id=%s', (sid,))[0]['count'] == roster['total'], 'Closed roster incomplete'))
        C('Lecture attendance', 'Closing again is safe', lambda: self.call('POST', f'/courses/1/sessions/{sid}/close') and 'HTTP 200')
        C('Lecture attendance', 'QR is unavailable after closing', lambda: self.call('GET', f'/courses/1/sessions/{sid}/qr', status=409) and 'HTTP 409')
        C('Lecture attendance', 'Late student check-in rejected', lambda: self.call('POST', '/attendance/check-ins', {'payload': first['payload']}, role=self.student, status=409) and 'HTTP 409')
        C('Reports', 'Shared closed lecture counted for selected section', lambda: R(self.call('GET', '/courses/1/report?section_id=1')['sessions'] >= 1, 'Shared lecture shown in attendance but omitted from section report'))
        C('Reports', 'All-course report counts closed lecture', lambda: R(self.call('GET', '/courses/1/report')['finalized'] >= 1, 'Closed lecture missing from report'))

        def policy(points='100', mode='normalized'):
            return {'total_points': '100', 'categories': [{'code': 'quiz', 'name': 'Role assessments', 'kind': 'assessment', 'max_points': points, 'allocation_mode': mode}]}
        self.call('PUT', '/courses/1/policy', policy('95'))
        C('Policy', 'Publishing incomplete total is rejected', lambda: self.call('POST', '/courses/1/policy/publish', status=422) and 'HTTP 422')
        draft = self.call('PUT', '/courses/1/policy', policy())
        cid = draft['categories'][0]['id']
        C('Policy', 'Saved draft categories returned with stable IDs', lambda: R(self.call('GET', '/courses/1/policy')['categories'][0]['id'] == cid, 'Draft not persisted'))
        C('Policy', 'TA cannot modify doctor policy', lambda: self.call('PUT', '/courses/1/policy', policy(), role=self.ta, status=403) and 'HTTP 403')
        C('Policy', 'Publish requires an assessment in normalized category', lambda: self.call('POST', '/courses/1/policy/publish', status=422) and 'HTTP 422')
        assessment = self.call('POST', '/courses/1/assessments', {'section_id': 1, 'category_id': cid, 'title': 'Doctor manual assessment', 'kind': 'assignment', 'max_points': '10'})
        aid = assessment['id']
        path = f'/courses/1/assessments/{aid}/results'
        C('Assessment', 'Created assessment returns selected section only', lambda: R(all(r['course_section_id'] == 1 for r in self.call('GET', path)['rows']), 'Gradebook includes other sections'))
        C('Policy', 'Used category cannot change to attendance kind', lambda: self.call('PUT', '/courses/1/policy', {'total_points': '100', 'categories': [policy()['categories'][0] | {'kind': 'lecture_attendance', 'allocation_mode': 'proportional'}]}, status=422) and 'HTTP 422')
        self.call('POST', '/courses/1/policy/publish')
        C('Policy', 'Published policy is visible to student and locked', lambda: R(self.call('GET', '/courses/1/policy', role=self.student)['state'] == 'published', 'Published policy absent'))
        C('Policy', 'Direct editing of published policy rejected', lambda: self.call('PUT', '/courses/1/policy', policy(), status=409) and 'HTTP 409')
        eid = self.j.student['enrollment_id']
        peer = self.j.peer['enrollment_id']
        row = lambda score, rev=0, state='recorded', enrollment=eid: {'enrollment_id': enrollment, 'score': score, 'state': state, 'revision': rev}
        self.call('PATCH', path, {'rows': [row('0'), row(None, state='unrecorded', enrollment=peer)]})
        C('Grades', 'Zero and unrecorded states are stored differently', lambda: R({r['enrollment_id']: r['state'] for r in self.call('GET', path)['rows']}[peer] == 'unrecorded', 'Missing grade confused with zero'))
        C('Grades', 'Draft results hidden from student', lambda: R(self.call('GET', '/courses/1/assessments', role=self.student) == [], 'Draft leaked'))
        self.call('POST', f'/courses/1/assessments/{aid}/publish')
        C('Grades', 'Published zero remains official zero', lambda: R(self.call('GET', '/courses/1/grades', role=self.student)['official_total'] == '0.00', 'Zero result lost'))
        C('Grades', 'Score above maximum rejected', lambda: self.call('PATCH', path, {'rows': [row('11', 1)]}, status=422) and 'HTTP 422')
        C('Grades', 'Negative score rejected', lambda: self.call('PATCH', path, {'rows': [row('-1', 1)]}, status=422) and 'HTTP 422')
        C('Grades', 'Existing stale revision rejected', lambda: self.call('PATCH', path, {'rows': [row('7', 0)], 'reason': 'Test revision'}, status=409) and 'HTTP 409')
        C('Grades', 'Published correction requires a reason', lambda: self.call('PATCH', path, {'rows': [row('7', 1)]}, status=422) and 'HTTP 422')
        self.call('PATCH', path, {'rows': [row('7', 1)], 'reason': 'Doctor corrected marking'})
        C('Grades', 'Previous published snapshot retained during correction', lambda: R(self.call('GET', '/courses/1/grades', role=self.student)['official_total'] == '0.00', 'Unpublished correction leaked'))
        C('Grades', 'Every follow-up correction still requires a reason', lambda: self.call('PATCH', path, {'rows': [row('8', 2)]}, status=422) and 'HTTP 422')
        self.call('POST', f'/courses/1/assessments/{aid}/publish')
        C('Grades', 'Reasoned correction audit persists', lambda: R(bool(self.j.query("SELECT 1 FROM audit_events WHERE reason='Doctor corrected marking'")), 'Correction audit missing'))

        concurrent = self.call('POST', '/courses/1/assessments', {'section_id': 1, 'category_id': cid, 'title': 'Concurrent initial grade', 'kind': 'project', 'max_points': '10'})
        def concurrent_writes():
            route = f"/api/v1/courses/1/assessments/{concurrent['id']}/results"
            # Synchronize immediately after both real transactions SELECT the
            # nonexistent grade. This makes the legitimate race reproducible.
            original_execute = psycopg.Connection.execute
            barrier = threading.Barrier(2)
            def gated_execute(connection, query, params=None, **kwargs):
                cursor = original_execute(connection, query, params, **kwargs)
                if (query == 'SELECT * FROM assessment_results WHERE assessment_id=%s AND enrollment_id=%s FOR UPDATE'
                        and params == (concurrent['id'], eid)):
                    barrier.wait(timeout=10)
                return cursor
            psycopg.Connection.execute = gated_execute
            try:
                with ThreadPoolExecutor(max_workers=2) as workers:
                    responses = list(workers.map(lambda score: self.j.client.patch(route, headers=self.doctor, json={'rows': [row(score)]}), ('2', '9')))
            finally:
                psycopg.Connection.execute = original_execute
            codes = sorted(r.status_code for r in responses)
            R(codes == [200, 409], f'Two initial revision-0 writes returned {codes}, expected one success and one conflict')
            return 'One initial write succeeds, one conflicts'
        C('Grades', 'Concurrent initial edits do not silently overwrite', concurrent_writes)

        C('Question bank', 'Invalid correct-answer index rejected', lambda: self.call('POST', '/courses/1/questions', {'prompt': 'Question', 'options': ['A', 'B'], 'correct_index': 4}, status=422) and 'HTTP 422')
        C('Question bank', 'Blank option rejected', lambda: self.call('POST', '/courses/1/questions', {'prompt': 'Question', 'options': ['A', ' '], 'correct_index': 0}, status=422) and 'HTTP 422')
        for index in (1, 2):
            self.call('POST', '/courses/1/questions', {'prompt': f'Doctor question {index}', 'options': ['Correct', 'Wrong'], 'correct_index': 0, 'points': '2'})
        C('Question bank', 'Questions and marked answers persist for staff', lambda: R(len(self.call('GET', '/courses/1/questions')) == 2, 'Questions missing'))
        C('Permissions', 'Student cannot fetch bank answer keys', lambda: self.call('GET', '/courses/1/questions', role=self.student, status=403) and 'HTTP 403')
        quiz_body = {'section_id': 1, 'category_id': cid, 'title': 'Doctor role quiz', 'question_count': 2, 'duration_minutes': 20}
        C('Quiz creation', 'Request exceeding question bank rejected', lambda: self.call('POST', '/courses/1/quizzes', quiz_body | {'question_count': 3}, status=422) and 'HTTP 422')
        quiz = self.call('POST', '/courses/1/quizzes', quiz_body)
        qid = quiz['id']
        C('Quiz creation', 'Doctor-created quiz appears with result link', lambda: R(self.call('GET', '/courses/1/quizzes')[0]['assessment_id'] == quiz['assessment_id'], 'Quiz/result link missing'))
        C('Permissions', 'Doctor cannot start a student attempt', lambda: self.call('POST', f'/quizzes/{qid}/start', status=403) and 'HTTP 403')
        attempt = self.call('POST', f'/quizzes/{qid}/start', role=self.student)
        C('Quiz results', 'Counterpart student sees questions without answer keys', lambda: R('is_correct' not in json.dumps(attempt), 'Answer keys leaked'))
        answers = self.j.query('''SELECT q.id AS question_id,o.id AS option_id FROM quiz_questions q
            JOIN quiz_options o ON o.quiz_question_id=q.id WHERE q.quiz_id=%s AND o.is_correct''', (qid,))
        self.call('POST', f'/quizzes/{qid}/submit', {'answers': answers}, role=self.student)
        C('Quiz results', 'Server-scored quiz appears in doctor gradebook', lambda: R(any(r['enrollment_id'] == eid and str(r['score']) in ('4', '4.00') for r in self.call('GET', f"/courses/1/assessments/{quiz['assessment_id']}/results")['rows']), 'Scored attempt missing'))
        self.call('POST', f"/courses/1/assessments/{quiz['assessment_id']}/publish")
        C('Quiz results', 'Publishing exposes score to counterpart student', lambda: R(self.call('POST', f'/quizzes/{qid}/start', role=self.student)['score'] == '4.00', 'Published quiz score missing'))
        C('Notifications', 'Workflow creates student notifications', lambda: R(len(self.call('GET', '/notifications', role=self.student)) >= 2, 'Workflow notifications missing'))
        student_notifications = self.call('GET', '/notifications', role=self.student)
        C('Notifications', 'Doctor cannot mark another user notification read', lambda: self.call('POST', f"/notifications/{student_notifications[0]['id']}/read", status=404) and 'HTTP 404')
        C('Notifications', 'Own empty notification inbox loads', lambda: R(self.call('GET', '/notifications') == [], 'Unexpected doctor inbox'))
        C('Persistence', 'Records survive doctor logout and sign-in', self.persistence)

    def persistence(self):
        self.call('POST', '/auth/logout')
        self.call('GET', '/me', status=401)
        new_token = self.login()['token']
        self.doctor = {'Authorization': 'Bearer ' + new_token}
        self.j.sandbox.tokens['doctor'] = new_token
        self.require(len(self.call('GET', '/courses/1/questions')) == 2, 'Question records lost after login')
        self.require(bool(self.call('GET', '/courses/1/sessions')), 'Attendance records lost after login')
        self.require(bool(self.call('GET', '/courses/1/assessments')), 'Assessment records lost after login')
        return 'Logout revoked old token; questions, sessions, and assessments persisted'

    def write_results(self):
        out = ROOT / 'review'
        out.mkdir(exist_ok=True)
        if '--excuse-only' in sys.argv and (out / 'doctor-api-results.json').exists():
            previous = json.loads((out / 'doctor-api-results.json').read_text(encoding='utf-8'))
            fresh = {(row[0], row[1]): row for row in self.rows}
            self.rows = [fresh.pop((row[0], row[1]), row) for row in previous] + list(fresh.values())
        (out / 'doctor-api-results.json').write_text(json.dumps(self.rows, indent=2, ensure_ascii=False), encoding='utf-8')
        counts = {status: sum(r[2] == status for r in self.rows) for status in ('PASS', 'FAIL')}
        print('Doctor API checks:', json.dumps(counts))
        for feature, scenario, status, evidence in self.rows:
            if status == 'FAIL':
                print(f'{status}: {feature} / {scenario}: {evidence}')

    def browser(self, sandbox):
        with sandbox.browser() as page:
            failures = []
            browser_tokens = []
            login_diagnostics = []
            page.on('requestfailed', lambda request: failures.append(request.url))
            def response_seen(response):
                if '/auth/login' in response.url:
                    body = response.request.post_data_json
                    login_diagnostics.append({'status': response.status,
                        'identifier': body.get('identifier'),
                        'password_correct': body.get('password') == sandbox.credentials['doctor'][1],
                        'password_length': len(body.get('password', ''))})
                    if response.status == 200:
                        browser_tokens.append(response.json()['token'])
            page.on('response', response_seen)
            C, R = self.check, self.require
            def button(name):
                return page.get_by_role('button', name=name).first
            def enter(field, value):
                field.click()
                page.evaluate('() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))')
                page.keyboard.press('Control+A')
                page.keyboard.press('Backspace')
                page.keyboard.type(value, delay=15)
            def wait_text(text, timeout=15):
                end = time.monotonic() + timeout
                while time.monotonic() < end:
                    if text in page.locator('body').aria_snapshot():
                        return text
                    page.wait_for_timeout(100)
                raise AssertionError(f'Visible accessibility content did not include {text}')
            def home():
                page.reload(wait_until='domcontentloaded')
                placeholder = page.locator('flt-semantics-placeholder')
                try:
                    placeholder.wait_for(state='attached', timeout=5000)
                    placeholder.evaluate('(element) => element.click()')
                except Exception:
                    page.locator('flt-semantics').first.wait_for(state='attached', timeout=5000)
                button('تحديث البيانات').wait_for()
                wait_text('لوحة متابعة المقرر')
            def tab(name):
                page.get_by_role('tab', name=name, exact=True).click()
            def footer():
                page.mouse.move(700, 650)
                page.mouse.wheel(0, 100000)
                page.wait_for_timeout(300)
            def shared(section=False):
                scope = page.get_by_role('button', name=re.compile(r'^CS\d+ ·')).first
                scope.click()
                # The initially expanded first course has identically named
                # section rows. Collapse it before choosing CS381 to avoid
                # clicking a different course's same-numbered section.
                page.get_by_role('button', name=re.compile(r'^CS211 ·')).last.click()
                page.get_by_role('button', name=re.compile('CS381')).last.click()
                if section:
                    page.get_by_role('button', name=re.compile(r'سكشن 1 \(SE\)')).last.click()
                else:
                    page.get_by_role('button', name='جميع السكاشن', exact=True).first.click()
                page.get_by_role('button', name=re.compile(r'^CS381 ·')).first.wait_for()
                wait_text('CS381')
            def sign_out():
                tab('المزيد')
                button('تسجيل الخروج').click()
                button('تأكيد').click()
                button('تسجيل الدخول').wait_for()
            def enter_home(identifier=None):
                sandbox.ui_login(page, 'doctor', identifier=identifier)
                button('تحديث البيانات').wait_for()
                wait_text('لوحة متابعة المقرر')
            def readonly_page(title, text):
                home()
                tab('المزيد')
                button(title).click()
                return wait_text(text)
            def grade_page():
                home()
                shared(section=True)
                tab('الدرجات')
                button('Doctor manual assessment').click()
                page.get_by_role('textbox').first.wait_for()
            def grade_excuse():
                grade_page()
                checkbox = page.get_by_role('checkbox').first
                if not checkbox.is_checked():
                    checkbox.click()
                    page.wait_for_timeout(300)
                R(checkbox.is_checked(), 'Fixture excuse toggle did not settle')
                enter(page.get_by_role('textbox', name='الدرجة').first, '3')
                page.wait_for_timeout(300)
                R(not checkbox.is_checked(), 'Excused remains visually checked after entering a recorded score')
                return 'Checkbox state matches numeric score'

            sandbox.open_ui(page)
            if '--excuse-only' in sys.argv:
                enter_home()
                C('UI Grades', 'Excused checkbox updates when entering a numeric grade', grade_excuse)
                return
            C('UI Login', 'Blank form displays both required-field messages',
              lambda: (button('تسجيل الدخول').click(), wait_text('أدخل اسم المستخدم'), wait_text('أدخل كلمة المرور')) and 'Required-field messages visible')
            C('UI Login', 'Wrong password shows credential error and remains signed out',
              lambda: (sandbox.ui_login(page, 'doctor', password='wrong-password'), wait_text('اسم المستخدم أو كلمة المرور غير صحيحة')) and 'Credential rejection visible')
            C('UI Login', 'Valid uppercase/whitespace doctor username reaches actual home',
              lambda: enter_home('  DOC_RASHA01  ') or 'POST login, assigned courses, and home succeeded')
            if not browser_tokens:
                print('Doctor sanitized login diagnostics:', login_diagnostics)
                print('Doctor textbox metadata:', page.get_by_role('textbox').evaluate_all('(elements) => elements.map(e=>({label:e.getAttribute("aria-label"),type:e.type,length:e.value?.length}))'))
                return
            C('UI Home', 'Doctor navigation shows all five destinations', lambda: R(page.get_by_role('tab').count() == 5, 'Unexpected role destinations'))
            C('UI Session', 'Reload restores the authenticated doctor session', lambda: home() or 'Session restored without credential entry')
            C('UI Courses', 'Course list and local course search retain typed text',
              lambda: (tab('المقررات'), enter(page.get_by_role('textbox').first, 'CS381'), wait_text('CS381'), R(page.get_by_role('textbox').first.input_value() == 'CS381', 'Course search text lost')) and 'Course search retained')

            def roster_search():
                home(); shared(section=True)
                button('كشف الطلاب').click()
                field = page.get_by_role('textbox').first
                field.wait_for()
                enter(field, '207')
                page.wait_for_timeout(800)
                R(page.get_by_role('textbox').first.input_value() == '207', 'Roster search resets its text during loading')
                return 'Multi-character roster search retained'
            C('UI Rosters', 'Typing a roster search preserves text and focus', roster_search)
            C('UI Scope', 'Doctor can select CS381 section 1 explicitly', lambda: (home(), shared(section=True), wait_text('سكشن 1 (SE)')) and 'Shared scope selectable')

            def course_creation():
                home(); tab('المقررات'); button('إضافة مقرر').click()
                wait_text('كود المقرر')
                button('إنشاء المقرر').click()
                wait_text('أكمل بيانات المقرر والسكشن والمعيد')
                return 'Course creation form and required validation exercised; successful write tested through HTTP'
            C('UI Course creation', 'Creation form opens and rejects incomplete input', course_creation)

            def lecture_open():
                home(); shared(section=True); tab('الحضور')
                button('فتح جلسة محاضرة').click()
                button('فتح الجلسة وعرض الرمز').click()
                wait_text('اكتب عنوان الجلسة')
                enter(page.get_by_role('textbox', name='عنوان الجلسة').first, 'Doctor browser lecture')
                enter(page.get_by_role('textbox', name='مدة فتح الحضور بالدقائق').first, '30')
                button('فتح الجلسة وعرض الرمز').click()
                wait_text('إغلاق جلسة الحضور')
                return 'Lecture created through browser and QR/close screen rendered'
            C('UI Lecture attendance', 'Validate, open lecture, and display QR controls', lecture_open)
            def lecture_close():
                button('إغلاق جلسة الحضور').click(); button('تأكيد').click()
                return wait_text('لا يوجد رمز نشط')
            C('UI Lecture attendance', 'Doctor closes lecture through confirmation', lecture_close)

            def policy_view():
                home(); shared(section=True); tab('الدرجات')
                button('لائحة توزيع الدرجات').click()
                wait_text('لائحة منشورة ومقفلة')
                R(all(not field.is_enabled() for field in page.get_by_role('textbox').all()), 'Published policy input is enabled')
                return 'Published policy displayed with disabled fields'
            C('UI Policy', 'Published policy screen is read-only', policy_view)
            def policy_draft_and_publish():
                home(); tab('الدرجات'); button('لائحة توزيع الدرجات').click()
                button('إضافة بند').click()
                enter(page.get_by_role('textbox', name='اسم البند').first, 'Doctor browser policy')
                enter(page.get_by_role('textbox', name='الدرجات المخصصة').first, '100')
                button('حفظ مسودة اللائحة').click()
                wait_text('تم حفظ مسودة اللائحة')
                draft = sandbox.call('GET', '/courses/11/policy')
                sandbox.call('POST', '/courses/11/assessments', json={
                    'category_id': draft['categories'][0]['id'], 'title': 'UI policy prerequisite',
                    'kind': 'assignment', 'max_points': '100'})
                button('اعتماد اللائحة').click(); button('تأكيد').click()
                wait_text('تم اعتماد اللائحة')
                R(sandbox.call('GET', '/courses/11/policy')['state'] == 'published', 'Policy browser publication did not persist')
                return 'Doctor created/saved draft and published it through UI after API setup of the required shared assessment'
            C('UI Policy', 'Create/save policy draft and publish it through browser', policy_draft_and_publish)

            def new_assessment_form():
                home(); shared(section=True); tab('الدرجات')
                button('إضافة تقييم').click()
                wait_text('عنوان التقييم')
                button('إنشاء التقييم').click()
                return wait_text('اكتب عنواناً واختر بنداً')
            C('UI Assessment', 'Assessment form opens and validates required fields', new_assessment_form)

            def grade_save():
                grade_page()
                enter(page.get_by_role('textbox', name='سبب تصحيح').first, 'Doctor browser grade verification')
                enter(page.get_by_role('textbox', name='الدرجة').first, '0')
                footer()
                button('حفظ درجات الصفحة').click()
                return wait_text('تم حفظ الدرجات')
            C('UI Grades', 'Save explicit zero from browser with correction reason', grade_save)
            C('UI Grades', 'Excused checkbox updates when entering a numeric grade', grade_excuse)
            def grade_publish():
                grade_page()
                footer()
                button('نشر نتائج التقييم').click(); button('تأكيد').click()
                return wait_text('تم نشر النتائج')
            C('UI Grades', 'Publish saved assessment results through confirmation', grade_publish)

            def question_bank():
                home(); shared(section=True); tab('الدرجات')
                button('بنك الأسئلة وكويزات السكشن').click()
                button('بنك أسئلة المقرر').click()
                wait_text('Doctor question 1')
                button('إضافة سؤال').click()
                button('حفظ السؤال').click()
                wait_text('اكتب السؤال وجميع الاختيارات')
                enter(page.get_by_role('textbox', name='نص السؤال').first, 'Doctor browser question')
                for i in range(1, 5):
                    enter(page.get_by_role('textbox', name=f'الاختيار {i}').first, f'Option {i}')
                button('حفظ السؤال').click()
                return wait_text('Doctor browser question')
            C('UI Question bank', 'Read questions, validate editor, and save a question', question_bank)
            def quiz_creation_form():
                home(); shared(section=True); tab('الدرجات')
                button('بنك الأسئلة وكويزات السكشن').click()
                button('إنشاء كويز للسكشن').click()
                wait_text('عنوان الكويز')
                button('فتح الكويز وإشعار الطلاب').click()
                return wait_text('راجع عنوان الكويز والسكشن')
            C('UI Quiz creation', 'Quiz creation form opens and validates input', quiz_creation_form)
            def quiz_results():
                home(); shared(section=True); tab('الدرجات')
                button('بنك الأسئلة وكويزات السكشن').click()
                button('Doctor role quiz').click()
                return wait_text('الدرجة العظمى')
            C('UI Quiz results', 'Submitted quiz opens the staff gradebook', quiz_results)
            C('UI Assignments', 'Teaching-assignment view loads real sections/TAs', lambda: readonly_page('التكليفات التدريسية', 'سكشن'))
            C('UI Reports', 'Report view loads student/session counts', lambda: readonly_page('تقرير المقرر', 'عدد الطلاب'))
            C('UI Notifications', 'Own empty inbox displays its empty state', lambda: readonly_page('الإشعارات', 'لا توجد إشعارات'))
            def dark_mode():
                home(); tab('المزيد')
                switch = page.get_by_role('switch').first
                switch.click()
                page.wait_for_timeout(300)
                R(switch.is_checked(), 'Dark mode switch failed')
                return 'Dark mode switch changes current session theme'
            C('UI Theme', 'Doctor can switch to dark mode', dark_mode)
            C('UI Logout', 'Confirmed logout returns to login and revokes token',
              lambda: (home(), sign_out(), R(sandbox.request('GET', 'me', role=None, headers={'Authorization': 'Bearer ' + browser_tokens[-1]}).status_code == 401, 'Logged-out token remains valid')) and 'Logged out and revoked')
            def offline_login():
                pattern = '**/api/v1/auth/login*'
                page.context.route(pattern, lambda route: route.abort())
                try:
                    sandbox.ui_login(page, 'doctor')
                    wait_text('تعذر الاتصال بالخادم')
                    R(page.get_by_role('tab').count() == 0, 'Offline login incorrectly signed in')
                finally:
                    page.context.unroute(pattern)
                enter_home()
                return 'Connection error shown; retry after connection recovery succeeds'
            C('UI Login', 'Offline login error and retry are handled', offline_login)
            def expiry_ui():
                sandbox.query("UPDATE api_sessions SET expires_at=now()-interval '1 second' WHERE token_hash=%s", (token_hash(browser_tokens[-1]),))
                button('تحديث البيانات').click()
                button('تسجيل الدخول').wait_for()
                R(page.get_by_role('tab').count() == 0, 'Expired session still exposes doctor navigation')
                return 'Expired session returned to sign-in'
            C('UI Session', 'Expired session exits doctor screens and returns to login', expiry_ui)
            C('UI Runtime', 'No uncaught browser page errors during journeys', lambda: R(not sandbox.browser_errors, 'Uncaught browser JavaScript errors occurred'))


def main():
    with Sandbox('doctor') as sandbox:
        journey = HttpJourney(sandbox)
        checks = DoctorChecks(journey)
        try:
            if '--browser-only' not in sys.argv:
                checks.run()
            checks.browser(sandbox)
        finally:
            if '--browser-only' not in sys.argv:
                checks.write_results()


if __name__ == '__main__':
    main()
