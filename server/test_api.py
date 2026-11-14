"""Role journeys against an isolated, temporary PostgreSQL database, never app data."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
import os
from pathlib import Path
import secrets
import sys
import time
import unittest

from fastapi.testclient import TestClient
import psycopg
from psycopg import sql
from psycopg.rows import dict_row

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'database'))
from manage import connection_env
from app import create_app
from db import Database, connection_info, settings
from security import hash_password
from quiz_balance import difficulty_counts


class ApiJourneys(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.admin = connection_env()
        cls.name = f'attendance_api_test_{os.getpid()}_{secrets.token_hex(3)}'
        cls.test_config = cls.admin | {'PGDATABASE': cls.name}
        with psycopg.connect(connection_info(cls.admin | {'PGDATABASE': 'postgres'}), autocommit=True) as admin:
            admin.execute(sql.SQL('CREATE DATABASE {} TEMPLATE template0 ENCODING \'UTF8\'').format(sql.Identifier(cls.name)))
        try:
            with psycopg.connect(connection_info(cls.test_config), autocommit=True, row_factory=dict_row) as db:
                for file in ('001_schema.sql', '002_seed.sql', '004_api_schema.sql', '005_assessment_scope.sql', '006_workflow_completion.sql', '007_quiz_difficulty.sql'):
                    db.execute((HERE.parent / 'database' / file).read_text(encoding='utf-8'))
                cls.student = db.execute('''SELECT u.username,s.university_id,s.id AS student_id,s.user_id,e.id AS enrollment_id
                    FROM students s JOIN app_users u ON u.id=s.user_id JOIN enrollments e ON e.student_id=s.id
                    WHERE e.course_section_id=1 ORDER BY s.id LIMIT 1''').fetchone()
                cls.peer = db.execute('''SELECT u.username,s.university_id,s.id AS student_id,s.user_id,e.id AS enrollment_id
                    FROM students s JOIN app_users u ON u.id=s.user_id JOIN enrollments e ON e.student_id=s.id
                    WHERE e.course_section_id=1 AND s.id<>%s ORDER BY s.id LIMIT 1''', (cls.student['student_id'],)).fetchone()
                cls.outside = db.execute('''SELECT u.username,s.university_id,s.user_id,e.id AS enrollment_id
                    FROM students s JOIN app_users u ON u.id=s.user_id JOIN enrollments e ON e.student_id=s.id
                    WHERE e.offering_id=1 AND e.course_section_id<>1 ORDER BY s.id LIMIT 1''').fetchone()
                credentials = [('doc_rasha01', 'Doctor@123'), ('ta_nehad00', 'TA@123')] + [
                    (row['username'], row['university_id']) for row in (cls.student, cls.peer, cls.outside)]
                for identifier, password in credentials:
                    db.execute('UPDATE app_users SET password_hash=%s WHERE username=%s', (hash_password(password), identifier))
                cls.runtime_config = settings() | {'PGDATABASE': cls.name}
                role = cls.runtime_config['PGUSER']
                db.execute(sql.SQL('GRANT USAGE ON SCHEMA attendance TO {}').format(sql.Identifier(role)))
                db.execute(sql.SQL('GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA attendance TO {}').format(sql.Identifier(role)))
                db.execute(sql.SQL('GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA attendance TO {}').format(sql.Identifier(role)))
            cls.client = TestClient(create_app(Database(cls.runtime_config)))
            cls.client.__enter__()
        except Exception:
            cls.drop_database()
            raise

    @classmethod
    def drop_database(cls):
        with psycopg.connect(connection_info(cls.admin | {'PGDATABASE': 'postgres'}), autocommit=True) as admin:
            admin.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(cls.name)))

    @classmethod
    def tearDownClass(cls):
        cls.client.__exit__(None, None, None)
        cls.drop_database()

    def query(self, query, params=()):
        with psycopg.connect(connection_info(self.test_config), row_factory=dict_row) as db:
            cursor = db.execute(query, params)
            return cursor.fetchall() if cursor.description else []

    def setUp(self):
        self.query('''TRUNCATE api_sessions,api_requests,audit_events,notifications,grading_policies,
            attendance_sessions,question_banks RESTART IDENTITY CASCADE''')
        self.query('UPDATE app_users SET is_active=true')
        self.doctor = self.login('doc_rasha01', 'Doctor@123')
        self.ta = self.login('ta_nehad00', 'TA@123')
        self.learner = self.login(self.student['username'], self.student['university_id'])

    def login(self, username, password):
        result = self.client.post('/api/v1/auth/login', json={'identifier': username, 'password': password})
        self.assertEqual(result.status_code, 200, result.text)
        return {'Authorization': 'Bearer ' + result.json()['token']}

    def call(self, method, path, user=None, body=None, status=200):
        response = self.client.request(method, '/api/v1' + path, headers=user or self.doctor, json=body)
        self.assertEqual(response.status_code, status, response.text)
        return response.json()

    def policy(self, points='100'):
        return self.call('PUT', '/courses/1/policy', body={'total_points': '100', 'categories': [
            {'code': 'quiz', 'name': 'Quizzes', 'kind': 'assessment', 'max_points': points, 'allocation_mode': 'normalized'}]})

    def test_authentication_and_scope_have_no_demo_bypass(self):
        self.call('POST', '/auth/login', body={'identifier': 'doc_rasha01', 'password': ''}, status=422)
        self.call('POST', '/auth/login', body={'identifier': 'prefix_doc_rasha01', 'password': 'Doctor@123'}, status=401)
        self.call('GET', '/courses/2/roster', self.doctor, status=403)
        self.call('GET', '/courses/1/roster', self.learner, status=403)
        self.call('GET', '/courses/1/roster?section_id=2', self.ta, status=403)
        roster = self.call('GET', '/courses/1/roster?section_id=1', self.ta)
        expected = self.query('SELECT count(*) AS count FROM enrollments WHERE course_section_id=1')[0]['count']
        self.assertEqual(roster['total'], expected)
        self.assertTrue(all(row['course_section_id'] == 1 for row in roster['rows']))
        courses = self.call('GET', '/courses', self.learner)
        self.assertTrue(any(course['id'] == 1 for course in courses))
        self.query('UPDATE app_users SET is_active=false WHERE id=%s', (self.student['user_id'],))
        self.call('GET', '/me', self.learner, status=401)

    def test_qr_check_in_duplicate_concurrency_closure_and_expiry(self):
        session = self.call('POST', '/courses/1/sessions', body={'kind': 'lecture', 'title': 'Lecture', 'duration_minutes': 30})
        lecture_detail = self.call('GET', f"/courses/1/sessions/{session['id']}", self.ta)
        self.assertTrue(all(r['university_id'] != self.outside['university_id'] for r in lecture_detail['rows']))
        self.assertTrue(any(r['university_id'] == self.student['university_id'] for r in lecture_detail['rows']))
        qr = self.call('GET', f"/courses/1/sessions/{session['id']}/qr")
        body = {'payload': qr['payload']}
        headers = self.learner | {'Idempotency-Key': 'same-request'}
        with ThreadPoolExecutor(max_workers=5) as workers:
            responses = list(workers.map(lambda _: self.client.post('/api/v1/attendance/check-ins', headers=headers, json=body), range(5)))
        self.assertTrue(all(result.status_code == 200 for result in responses))
        self.assertEqual(len({result.json()['receipt_id'] for result in responses}), 1)
        duplicate = self.call('POST', '/attendance/check-ins', self.learner, body)
        self.assertTrue(duplicate['duplicate'])
        self.call('POST', f"/courses/1/sessions/{session['id']}/close")
        self.call('POST', '/attendance/check-ins', self.learner, body, status=409)
        replay = self.client.post('/api/v1/attendance/check-ins', headers=headers, json=body)
        self.assertEqual(replay.status_code, 200)
        self.assertEqual(self.query('SELECT count(*) AS count FROM attendance_records WHERE session_id=%s AND enrollment_id=%s',
            (session['id'], self.student['enrollment_id']))[0]['count'], 1)
        records = self.query('SELECT status,count(*) AS count FROM attendance_records GROUP BY status')
        self.assertTrue(any(row['status'] == 'absent' for row in records))
        other = self.call('POST', '/courses/1/sessions', body={'kind': 'lecture', 'title': 'Expired', 'duration_minutes': 30})
        token = self.call('GET', f"/courses/1/sessions/{other['id']}/qr")
        self.query("UPDATE qr_tokens SET valid_from=now()-interval '1 minute',valid_until=now()-interval '1 second' WHERE session_id=%s", (other['id'],))
        self.call('POST', '/attendance/check-ins', self.learner, {'payload': token['payload']}, status=422)

    def test_section_finalization_rejects_unresolved_and_cross_section_rows(self):
        session = self.call('POST', '/courses/1/sessions', self.ta, {'kind': 'section', 'title': 'Section', 'section_id': 1})
        detail = self.call('GET', f"/courses/1/sessions/{session['id']}", self.ta)
        rows = [{'enrollment_id': row['enrollment_id'], 'status': 'present'} for row in detail['rows']]
        path = f"/courses/1/sessions/{session['id']}/finalize"
        self.call('POST', path, self.ta, {'revision': 1, 'rows': rows[:-1]}, status=422)
        invalid = list(rows)
        invalid[0] = {'enrollment_id': self.outside['enrollment_id'], 'status': 'present'}
        self.call('POST', path, self.ta, {'revision': 1, 'rows': invalid}, status=422)
        self.call('POST', path, self.ta, {'revision': 1, 'rows': rows})
        self.call('POST', path, self.ta, {'revision': 1, 'rows': rows}, status=409)
        own = self.call('GET', '/courses/1/sessions', self.learner)
        self.assertEqual(own[0]['own_status'], 'present')
        self.call('POST', '/auth/logout', self.ta)
        signed_in_again = self.login('ta_nehad00', 'TA@123')
        self.assertEqual(self.call('GET', f"/courses/1/sessions/{session['id']}", signed_in_again)['state'], 'finalized')

    def test_qr_receipt_is_persisted_reopenable_scoped_and_not_duplicated(self):
        session = self.call('POST', '/courses/1/sessions', body={
            'kind': 'lecture', 'section_id': 1, 'title': 'QR persistence proof', 'duration_minutes': 30})
        path = f"/courses/1/sessions/{session['id']}"
        qr = self.call('GET', path + '/qr')
        body = {'payload': qr['payload']}
        outside = self.login(self.outside['username'], self.outside['university_id'])
        self.call('POST', '/attendance/check-ins', outside, body, status=403)
        self.call('POST', '/attendance/check-ins', self.ta, body, status=403)
        self.call('POST', '/attendance/check-ins', self.learner,
                  {'payload': qr['payload'] + 'tampered'}, status=422)
        self.assertEqual(self.query('SELECT count(*) AS n FROM attendance_records')[0]['n'], 0)
        receipt = self.call('POST', '/attendance/check-ins', self.learner, body)
        stored = self.query('SELECT * FROM attendance_records WHERE id=%s', (receipt['receipt_id'],))[0]
        self.assertEqual((stored['enrollment_id'], stored['status'], stored['source']),
                         (self.student['enrollment_id'], 'present', 'qr'))
        self.assertEqual(stored['recorded_at'].isoformat(), receipt['recorded_at'])
        self.assertEqual(receipt['session_title'], 'QR persistence proof')
        self.assertTrue(receipt['course_code'])
        duplicate = self.call('POST', '/attendance/check-ins', self.learner, body)
        self.assertTrue(duplicate['duplicate'])
        self.assertEqual(duplicate['receipt_id'], receipt['receipt_id'])
        self.call('POST', '/auth/logout', self.learner)
        learner = self.login(self.student['username'], self.student['university_id'])
        detail = self.call('GET', path, learner)
        self.assertEqual(detail['record']['receipt_id'], receipt['receipt_id'])
        self.assertEqual(detail['record']['recorded_at'], receipt['recorded_at'])
        self.assertEqual(detail['course_code'], receipt['course_code'])
        peer = self.login(self.peer['username'], self.peer['university_id'])
        self.assertIsNone(self.call('GET', path, peer)['record'])
        self.call('GET', path, outside, status=403)
        self.call('POST', path + '/close')
        summary = self.call('GET', '/courses/1/sessions/summary', learner)
        self.assertEqual(summary['lecture'], {'present': 1, 'eligible': 1})
        self.assertEqual(self.query('SELECT count(*) AS n FROM attendance_records WHERE session_id=%s AND enrollment_id=%s',
                                  (session['id'], self.student['enrollment_id']))[0]['n'], 1)

    def test_quiz_readiness_does_not_start_attempt_and_uses_global_close(self):
        quiz = self.create_live_quiz()
        path = f"/quizzes/{quiz['id']}"
        self.query("UPDATE quizzes SET ends_at=now()+interval '1 minute' WHERE id=%s", (quiz['id'],))
        for _ in range(2):
            info = self.call('GET', path + '/readiness', self.learner)
            self.assertIsNone(info['attempt'])
            self.assertNotIn('questions', info)
            self.assertNotIn('is_correct', str(info))
            self.assertTrue(info['course_code'])
        self.assertEqual(self.query('SELECT count(*) AS n FROM quiz_attempts')[0]['n'], 0)
        outside = self.login(self.outside['username'], self.outside['university_id'])
        self.call('GET', path + '/readiness', outside, status=403)
        attempt = self.call('POST', path + '/start', self.learner)
        self.assertEqual(attempt['deadline_at'], info['ends_at'])
        self.assertEqual(self.call('POST', path + '/start', self.learner)['id'], attempt['id'])
        self.assertEqual(self.query('SELECT count(*) AS n FROM quiz_attempts')[0]['n'], 1)

    def test_publication_preview_covers_whole_assessment_and_rejects_stale_preview(self):
        policy = self.policy()
        assessment = self.call('POST', '/courses/1/assessments', body={
            'category_id': policy['categories'][0]['id'], 'title': 'Shared publication', 'kind': 'assignment', 'max_points': '10'})
        self.call('POST', '/courses/1/policy/publish')
        base = f"/courses/1/assessments/{assessment['id']}"
        students = [self.student, self.outside]
        self.call('PATCH', base + '/results', body={'rows': [
            {'enrollment_id': s['enrollment_id'], 'state': 'recorded', 'score': '0', 'revision': 0} for s in students]})
        preview = self.call('GET', base + '/publication-preview?section_id=1&offset=50')
        total = self.query("SELECT count(*) AS n FROM enrollments WHERE offering_id=1 AND state='active'")[0]['n']
        self.assertEqual(preview['eligible'], total)
        self.assertEqual((preview['recorded'], preview['unrecorded'], preview['saved_results']), (2, total - 2, 2))
        self.assertEqual(preview['scope'], 'جميع سكاشن المقرر')
        self.call('GET', base + '/publication-preview', self.ta, status=403)
        self.call('GET', base + '/publication-preview', self.learner, status=403)
        self.call('PATCH', base + '/results', body={'rows': [
            {'enrollment_id': self.student['enrollment_id'], 'state': 'excused', 'score': None, 'revision': 1}]})
        self.call('POST', base + '/publish', body={'fingerprint': preview['fingerprint']}, status=409)
        self.assertEqual(self.query('SELECT count(*) AS n FROM published_results')[0]['n'], 0)
        preview = self.call('GET', base + '/publication-preview')
        self.assertEqual(preview['excused'], 1)
        result = self.call('POST', base + '/publish', body={'fingerprint': preview['fingerprint']})
        self.assertEqual(result['count'], 2)
        self.assertTrue(self.call('GET', base + '/publication-preview')['republication'])

    def test_grade_policy_zero_missing_publication_and_audited_correction(self):
        self.policy('95')
        self.call('POST', '/courses/1/policy/publish', status=422)
        self.policy('105')
        self.call('POST', '/courses/1/policy/publish', status=422)
        value = self.policy()
        category = value['categories'][0]['id']
        assessment = self.call('POST', '/courses/1/assessments', body={'title': 'Quiz', 'category_id': category, 'kind': 'quiz', 'max_points': '10'})
        self.call('POST', '/courses/1/policy/publish')
        path = f"/courses/1/assessments/{assessment['id']}/results"
        self.call('PATCH', path, self.ta, {'rows': [
            {'enrollment_id': self.student['enrollment_id'], 'score': '0', 'state': 'recorded', 'revision': 0},
            {'enrollment_id': self.peer['enrollment_id'], 'score': None, 'state': 'unrecorded', 'revision': 0}]})
        self.assertEqual(self.call('GET', '/courses/1/assessments', self.learner), [])
        self.call('POST', f"/courses/1/assessments/{assessment['id']}/publish")
        grades = self.call('GET', '/courses/1/grades', self.learner)
        self.assertEqual(grades['official_total'], '0.00')
        peer = self.login(self.peer['username'], self.peer['university_id'])
        self.assertIsNone(self.call('GET', '/courses/1/grades', peer)['official_total'])
        self.call('PATCH', path, self.ta, {'rows': [{'enrollment_id': self.student['enrollment_id'], 'score': '11', 'state': 'recorded', 'revision': 1}]}, status=422)
        self.call('PATCH', path, self.ta, {'rows': [{'enrollment_id': self.outside['enrollment_id'], 'score': '8', 'state': 'recorded', 'revision': 0}]}, status=403)
        correction = {'reason': 'Corrected marking', 'rows': [{'enrollment_id': self.student['enrollment_id'], 'score': '8', 'state': 'recorded', 'revision': 1}]}
        self.call('PATCH', path, self.ta, correction)
        # Subsequent draft correction without a reason must return 422 while publication history exists
        self.call('PATCH', path, self.ta, {'rows': [{'enrollment_id': self.student['enrollment_id'], 'score': '9', 'state': 'recorded', 'revision': 2}]}, status=422)
        self.assertEqual(self.call('GET', '/courses/1/grades', self.learner)['official_total'], '0.00')
        self.call('POST', f"/courses/1/assessments/{assessment['id']}/publish")
        self.assertEqual(self.call('GET', '/courses/1/grades', self.learner)['official_total'], '80.00')
        self.assertTrue(self.query("SELECT 1 FROM audit_events WHERE reason='Corrected marking'"))

    def create_live_quiz(self):
        value = self.policy()
        for point, level in ((2, 'easy'), (3, 'medium')):
            self.call('POST', '/courses/1/questions', self.ta, {'prompt': f'Question {point}', 'options': ['Correct', 'Wrong'], 'correct_index': 0, 'points': str(point), 'difficulty': level})
        quiz = self.call('POST', '/courses/1/quizzes', self.ta, {'title': 'Live quiz', 'section_id': 1, 'category_id': value['categories'][0]['id'], 'question_count': 2, 'duration_minutes': 20})
        self.call('POST', '/courses/1/policy/publish')
        return quiz

    def test_quiz_persists_between_accounts_hides_keys_and_scores_on_server(self):
        quiz = self.create_live_quiz()
        self.call('POST', '/auth/logout', self.ta)
        listing = self.call('GET', '/courses/1/quizzes', self.learner)
        self.assertEqual(listing[0]['id'], quiz['id'])
        outside = self.login(self.outside['username'], self.outside['university_id'])
        self.call('POST', f"/quizzes/{quiz['id']}/start", outside, status=403)
        self.call('GET', '/courses/1/questions', self.learner, status=403)
        attempt = self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)
        self.assertNotIn('is_correct', str(attempt))
        answers = self.query('''SELECT q.id AS question_id,o.id AS option_id FROM quiz_questions q
            JOIN quiz_options o ON o.quiz_question_id=q.id WHERE q.quiz_id=%s AND o.is_correct''', (quiz['id'],))
        self.call('PATCH', f"/quizzes/{quiz['id']}/answers", self.learner, {'answers': answers})
        restored = self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)
        self.assertEqual(restored['deadline_at'], attempt['deadline_at'])
        self.assertEqual(len(restored['answers']), 2)
        submitted = self.call('POST', f"/quizzes/{quiz['id']}/submit", self.learner, {'answers': answers})
        self.assertIsNone(submitted['score'])
        self.assertEqual(self.query('SELECT score FROM quiz_attempts WHERE id=%s', (attempt['id'],))[0]['score'], 5)
        self.call('POST', f"/courses/1/quizzes/{quiz['id']}/close")
        self.call('POST', f"/courses/1/assessments/{quiz['assessment_id']}/publish")
        self.assertEqual(self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)['score'], '5.00')

    def test_question_difficulty_is_required_and_legacy_questions_can_be_classified(self):
        body = {'prompt': 'Bank question', 'options': ['Correct', 'Wrong'], 'correct_index': 0}
        self.call('POST', '/courses/1/questions', self.ta, body, status=422)
        self.call('POST', '/courses/1/questions', self.ta, body | {'difficulty': 'unknown'}, status=422)
        self.call('POST', '/courses/1/questions', self.ta, body | {'difficulty': 'easy', 'correct_index': 2}, status=422)
        self.call('POST', '/courses/1/questions', self.ta, body | {'difficulty': 'easy', 'prompt': '   '}, status=422)
        question = self.call('POST', '/courses/1/questions', self.ta, body | {'difficulty': 'easy'})
        self.query('UPDATE questions SET difficulty=NULL WHERE id=%s', (question['id'],))
        self.assertIsNone(self.call('GET', '/courses/1/questions', self.ta)[0]['difficulty'])
        category = self.policy()['categories'][0]['id']
        draft = {'title': 'Balanced', 'section_id': 1, 'category_id': category, 'question_count': 1, 'duration_minutes': 20}
        self.call('POST', '/courses/1/quizzes', self.ta, draft, status=422)
        self.assertFalse(self.query('SELECT 1 FROM assessments'))
        path = f"/courses/1/questions/{question['id']}/difficulty"
        self.call('PATCH', path, self.learner, {'difficulty': 'easy'}, status=403)
        self.call('PATCH', path, self.ta, {'difficulty': 'unknown'}, status=422)
        self.call('PATCH', f"/courses/2/questions/{question['id']}/difficulty", self.ta, {'difficulty': 'easy'}, status=403)
        self.call('PATCH', '/courses/1/questions/999999/difficulty', self.ta, {'difficulty': 'easy'}, status=404)
        self.call('PATCH', path, self.ta, {'difficulty': 'easy'})
        quiz = self.call('POST', '/courses/1/quizzes', self.ta, draft)
        self.call('PATCH', path, self.ta, {'difficulty': 'hard'})
        self.assertEqual(self.query('SELECT difficulty FROM quiz_questions WHERE quiz_id=%s', (quiz['id'],))[0]['difficulty'], 'easy')
        self.assertTrue(self.query("SELECT 1 FROM audit_events WHERE action='question.classify'"))

    def test_balanced_quiz_selection_is_exact_unique_and_rejects_shortages(self):
        category = self.policy()['categories'][0]['id']
        for level in ('easy', 'medium', 'hard'):
            for index in range(6):
                self.call('POST', '/courses/1/questions', self.ta, {
                    'prompt': f'{level} {index}', 'options': ['Correct', 'Wrong'],
                    'correct_index': 0, 'difficulty': level})
        draft = {'title': 'Balanced', 'section_id': 1, 'category_id': category, 'duration_minutes': 20}
        for quantity in (1, 2, 3, 4, 5, 6, 7, 10):
            quiz = self.call('POST', '/courses/1/quizzes', self.ta, draft | {'question_count': quantity})
            snapshots = self.query('SELECT source_question_id,difficulty FROM quiz_questions WHERE quiz_id=%s', (quiz['id'],))
            self.assertEqual(len({q['source_question_id'] for q in snapshots}), quantity)
            self.assertEqual({level: sum(q['difficulty'] == level for q in snapshots)
                              for level in ('easy', 'medium', 'hard')}, difficulty_counts(quantity))
        # The total bank is large enough, but the easy/medium pools cannot supply eight each.
        before = len(self.query('SELECT id FROM assessments'))
        response = self.call('POST', '/courses/1/quizzes', self.ta, draft | {'question_count': 18}, status=422)
        self.assertIn('متاح 6', response['detail'])
        self.assertEqual(len(self.query('SELECT id FROM assessments')), before)

    def test_section_quiz_shuffles_stably_notifies_and_shows_automatic_results_to_ta(self):
        category = self.policy()['categories'][0]['id']
        for level in ('easy', 'medium', 'hard'):
            for index in range(5):
                self.call('POST', '/courses/1/questions', self.ta, {
                    'prompt': f'{level} {index}', 'options': ['Correct', 'Wrong', 'Third', 'Fourth'],
                    'correct_index': 0, 'difficulty': level})
        quiz = self.call('POST', '/courses/1/quizzes', self.ta, {
            'title': 'Section quiz', 'section_id': 1, 'category_id': category,
            'question_count': 10, 'duration_minutes': 20})
        path = f"/quizzes/{quiz['id']}"
        results_path = f"/courses/1/quizzes/{quiz['id']}/results"
        peer = self.login(self.peer['username'], self.peer['university_id'])
        outside = self.login(self.outside['username'], self.outside['university_id'])
        self.assertEqual(self.call('GET', '/courses/1/quizzes', outside), [])
        self.assertEqual(self.call('GET', '/notifications', outside), [])
        self.assertTrue(self.call('GET', '/notifications', self.learner))
        self.assertTrue(self.call('GET', '/notifications', peer))
        self.call('GET', results_path, self.learner, status=403)
        self.call('GET', results_path + '?offset=-1', self.ta, status=422)
        self.call('POST', path + '/start', outside, status=403)
        first = self.call('POST', path + '/start', self.learner)
        second = self.call('POST', path + '/start', peer)
        ids = lambda attempt: [q['id'] for q in attempt['questions']]
        options = lambda attempt: {q['id']: [o['id'] for o in q['options']] for q in attempt['questions']}
        self.assertEqual(set(ids(first)), set(ids(second)))
        self.assertNotEqual(ids(first), ids(second))
        self.assertTrue(any(options(first)[id] != options(second)[id] for id in ids(first)))
        restored = self.call('POST', path + '/start', self.learner)
        self.assertEqual(ids(first), ids(restored))
        self.assertEqual(options(first), options(restored))
        self.assertNotIn('is_correct', str(first))
        self.assertNotIn('difficulty', str(first))
        answers = self.query('''SELECT q.id AS question_id,o.id AS option_id FROM quiz_questions q
            JOIN quiz_options o ON o.quiz_question_id=q.id WHERE q.quiz_id=%s AND o.is_correct''', (quiz['id'],))
        before = self.call('GET', results_path, self.ta)
        self.assertEqual(before['summary']['in_progress'], 2)
        submitted = self.call('POST', path + '/submit', self.learner, {'answers': answers})
        self.assertIsNone(submitted['score'])
        book_path = f"/courses/1/assessments/{quiz['assessment_id']}/results"
        book = self.call('GET', book_path, self.ta)
        recorded = next(row for row in book['rows'] if row['enrollment_id'] == self.student['enrollment_id'])
        self.assertEqual((recorded['score'], recorded['state'], recorded['revision']), ('10.00', 'recorded', 1))
        self.assertFalse(book['editable'])
        self.call('POST', path + '/submit', self.learner, {'answers': []})
        repeated = self.call('GET', book_path, self.ta)
        recorded_again = next(row for row in repeated['rows'] if row['enrollment_id'] == self.student['enrollment_id'])
        self.assertEqual((recorded_again['score'], recorded_again['revision']), ('10.00', 1))
        self.call('PATCH', path + '/answers', peer, {'answers': answers[:1]})
        self.query("UPDATE quiz_attempts SET started_at=now()-interval '2 minutes',deadline_at=now()-interval '1 second' WHERE id=%s", (second['id'],))
        after = self.call('GET', results_path, self.ta)
        by_enrollment = {row['enrollment_id']: row for row in after['rows']}
        self.assertEqual((by_enrollment[self.student['enrollment_id']]['attempt_state'],
                          by_enrollment[self.student['enrollment_id']]['score']), ('submitted', '10.00'))
        self.assertEqual((by_enrollment[self.peer['enrollment_id']]['attempt_state'],
                          by_enrollment[self.peer['enrollment_id']]['score']), ('timed_out', '1.00'))
        self.assertNotIn(self.outside['enrollment_id'], by_enrollment)
        self.assertEqual(after['summary']['not_started'], after['summary']['total'] - 2)
        self.assertEqual(after['difficulty_counts'], {'easy': 4, 'medium': 4, 'hard': 2})
        self.assertEqual(self.query('SELECT score FROM assessment_results WHERE assessment_id=%s AND enrollment_id=%s',
                                   (quiz['assessment_id'], self.student['enrollment_id']))[0]['score'], 10)
        paged = self.call('GET', results_path + '?offset=1&limit=1', self.ta)
        self.assertEqual(len(paged['rows']), 1)
        self.assertEqual(paged['summary'], after['summary'])
        self.call('POST', '/auth/logout', self.ta)
        ta = self.login('ta_nehad00', 'TA@123')
        self.assertEqual(self.call('GET', results_path, ta)['rows'], after['rows'])
        other = self.call('POST', '/courses/1/quizzes', self.doctor, {
            'title': 'Other section', 'section_id': 2, 'category_id': category,
            'question_count': 5, 'duration_minutes': 20})
        self.call('GET', f"/courses/1/quizzes/{other['id']}/results", ta, status=403)

    def test_late_quiz_submission_scores_only_autosaved_answers(self):
        quiz = self.create_live_quiz()
        attempt = self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)
        answers = self.query('''SELECT q.id AS question_id,o.id AS option_id FROM quiz_questions q
            JOIN quiz_options o ON o.quiz_question_id=q.id WHERE q.quiz_id=%s AND o.is_correct ORDER BY q.id''', (quiz['id'],))
        self.call('PATCH', f"/quizzes/{quiz['id']}/answers", self.learner, {'answers': answers[:1]})
        expected = self.query('SELECT points FROM quiz_questions WHERE id=%s', (answers[0]['question_id'],))[0]['points']
        self.query("UPDATE quiz_attempts SET started_at=now()-interval '10 minutes',deadline_at=now()-interval '1 second' WHERE id=%s", (attempt['id'],))
        submitted = self.call('POST', f"/quizzes/{quiz['id']}/submit", self.learner, {'answers': answers})
        self.assertEqual(submitted['state'], 'timed_out')
        self.assertEqual(self.query('SELECT score FROM quiz_attempts WHERE id=%s', (attempt['id'],))[0]['score'], expected)

    def test_assessments_from_other_sections_do_not_block_student_totals(self):
        quiz = self.create_live_quiz()
        policy = self.call('GET', '/courses/1/policy')
        self.call('POST', '/courses/1/quizzes', self.doctor, {'title': 'Other section quiz', 'section_id': 2,
            'category_id': policy['categories'][0]['id'], 'question_count': 2, 'duration_minutes': 20})
        attempt = self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)
        answers = self.query('''SELECT q.id AS question_id,o.id AS option_id FROM quiz_questions q
            JOIN quiz_options o ON o.quiz_question_id=q.id WHERE q.quiz_id=%s AND o.is_correct''', (quiz['id'],))
        self.call('POST', f"/quizzes/{quiz['id']}/submit", self.learner, {'answers': answers})
        self.call('POST', f"/courses/1/quizzes/{quiz['id']}/close")
        self.call('POST', f"/courses/1/assessments/{quiz['assessment_id']}/publish")
        grades = self.call('GET', '/courses/1/grades', self.learner)
        self.assertEqual(grades['official_total'], '100.00')
        roster = self.call('GET', f"/courses/1/assessments/{quiz['assessment_id']}/results")
        self.assertTrue(all(row['course_section_id'] == 1 for row in roster['rows']))

    def test_fixed_assessment_budgets_apply_to_each_section(self):
        draft = {'total_points': '100', 'categories': [{'code': 'fixed', 'name': 'Fixed assessments',
            'kind': 'assessment', 'max_points': '100', 'allocation_mode': 'fixed'}]}
        policy = self.call('PUT', '/courses/1/policy', body=draft)
        category_id = policy['categories'][0]['id']

        def assessment(points, section=None, user=None, status=200):
            return self.call('POST', '/courses/1/assessments', user, {'title': 'Assessment',
                'kind': 'assignment', 'category_id': category_id, 'max_points': points,
                'section_id': section}, status=status)

        assessment('60')  # Shared by every section.
        assessment('40', 1, self.ta)
        assessment('40', 2)  # Independent budget from section 1.
        assessment('1', 1, status=422)
        assessment('1', status=422)  # A shared item would also exceed section 1.
        assessment('1', user=self.ta, status=422)  # TAs must specify their section.
        assessment('1', 2, self.ta, status=403)
        self.call('POST', '/courses/1/policy/publish', status=422)
        for section in self.query('SELECT id FROM course_sections WHERE offering_id=1 AND id NOT IN (1,2)'):
            assessment('40', section['id'])
        # Reject changing an assessment category into attendance without losing the draft.
        changed = {'total_points': '100', 'categories': [draft['categories'][0] |
            {'kind': 'lecture_attendance', 'allocation_mode': 'proportional'}]}
        self.call('PUT', '/courses/1/policy', body=changed, status=422)
        self.assertEqual(self.call('GET', '/courses/1/policy')['categories'][0]['kind'], 'assessment')
        self.call('POST', '/courses/1/policy/publish')

    def test_password_change_verifies_credentials_and_revokes_other_sessions(self):
        accounts = [('doc_rasha01', 'Doctor@123'), ('ta_nehad00', 'TA@123'),
                    (self.student['username'], self.student['university_id'])]
        for identifier, original in accounts:
            with self.subTest(account=identifier):
                current = self.login(identifier, original)
                other = self.login(identifier, original)
                replacement = 'Phase5-test-' + secrets.token_hex(8)
                try:
                    self.call('POST', '/auth/change-password', current,
                              {'current_password': 'incorrect', 'new_password': replacement}, status=422)
                    self.call('GET', '/me', current)
                    self.call('GET', '/me', other)
                    self.call('POST', '/auth/change-password', current,
                              {'current_password': original, 'new_password': original}, status=422)
                    self.call('POST', '/auth/change-password', current,
                              {'current_password': original, 'new_password': 'short'}, status=422)
                    self.call('POST', '/auth/change-password', current,
                              {'current_password': original, 'new_password': replacement})
                    self.call('GET', '/me', current)
                    self.call('GET', '/me', other, status=401)
                    rejected = self.client.post('/api/v1/auth/login', json={
                        'identifier': identifier, 'password': original})
                    self.assertEqual(rejected.status_code, 401)
                    self.call('GET', '/me', self.login(identifier, replacement))
                    stored = self.query('SELECT password_hash FROM app_users WHERE username=%s', (identifier,))[0]
                    self.assertTrue(stored['password_hash'].startswith('scrypt$'))
                    self.assertNotEqual(stored['password_hash'], replacement)
                finally:
                    self.query('UPDATE app_users SET password_hash=%s WHERE username=%s',
                               (hash_password(original), identifier))

    def test_early_quiz_close_scores_saved_answers_and_enforces_section_scope(self):
        quiz = self.create_live_quiz()
        attempt = self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)
        answers = self.query('''SELECT q.id AS question_id,o.id AS option_id,q.points
            FROM quiz_questions q JOIN quiz_options o ON o.quiz_question_id=q.id
            WHERE q.quiz_id=%s AND o.is_correct ORDER BY q.id''', (quiz['id'],))
        saved = [{'question_id': answers[0]['question_id'], 'option_id': answers[0]['option_id']}]
        self.call('PATCH', f"/quizzes/{quiz['id']}/answers", self.learner, {'answers': saved})
        path = f"/courses/1/quizzes/{quiz['id']}/close"
        self.call('POST', path, self.learner, status=403)
        result = self.call('POST', path, self.ta)
        self.assertEqual(result['finalized'], 1)
        finalized = self.query('SELECT state,score FROM quiz_attempts WHERE id=%s', (attempt['id'],))[0]
        self.assertEqual(finalized['state'], 'timed_out')
        self.assertEqual(finalized['score'], answers[0]['points'])
        self.call('PATCH', f"/quizzes/{quiz['id']}/answers", self.learner, {'answers': saved}, status=409)
        peer = self.login(self.peer['username'], self.peer['university_id'])
        self.call('POST', f"/quizzes/{quiz['id']}/start", peer, status=409)
        self.assertEqual(self.call('POST', path, self.ta)['finalized'], 0)
        self.assertIsNone(self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)['score'])
        self.call('POST', f"/courses/1/assessments/{quiz['assessment_id']}/publish")
        self.assertEqual(self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)['score'], str(answers[0]['points']))
        category = self.call('GET', '/courses/1/policy')['categories'][0]['id']
        other = self.call('POST', '/courses/1/quizzes', body={'title': 'Other section',
            'section_id': 2, 'category_id': category, 'question_count': 1, 'duration_minutes': 20})
        self.call('POST', f"/courses/1/quizzes/{other['id']}/close", self.ta, status=403)
        self.assertTrue(self.query("SELECT 1 FROM audit_events WHERE action='quiz.close' AND entity_id=%s", (quiz['id'],)))

    def test_attendance_draft_round_trip_conflict_and_finalization(self):
        session = self.call('POST', '/courses/1/sessions', self.ta,
            {'kind': 'section', 'title': 'Persistent draft', 'section_id': 1})
        path = f"/courses/1/sessions/{session['id']}"
        detail = self.call('GET', path, self.ta)
        first = detail['rows'][0]['enrollment_id']
        body = {'revision': detail['revision'], 'rows': [{'enrollment_id': first, 'status': 'present'}]}
        with ThreadPoolExecutor(max_workers=2) as workers:
            responses = list(workers.map(lambda _: self.client.put('/api/v1' + path + '/draft',
                headers=self.ta, json=body), range(2)))
        self.assertEqual(sorted(response.status_code for response in responses), [200, 409])
        restored = self.call('GET', path, self.ta)
        self.assertEqual(restored['rows'][0]['status'], 'present')
        self.assertEqual(restored['revision'], detail['revision'] + 1)
        self.assertFalse(self.query('SELECT 1 FROM attendance_records WHERE session_id=%s', (session['id'],)))
        self.call('GET', path, self.learner, status=403)
        self.call('PUT', path + '/draft', self.ta, {'revision': restored['revision'], 'rows': [
            {'enrollment_id': self.outside['enrollment_id'], 'status': 'present'}]}, status=422)
        self.call('POST', path + '/finalize', self.ta, {'revision': restored['revision'], 'rows': [
            {'enrollment_id': row['enrollment_id'], 'status': row['status'] or 'absent'} for row in restored['rows']]})
        self.assertFalse(self.query('SELECT 1 FROM attendance_draft_marks WHERE session_id=%s', (session['id'],)))
        self.call('PUT', path + '/draft', self.ta, body, status=409)

    def test_quiz_preparation_schedule_and_cancel_release_grade_budget(self):
        self.policy(points='1')
        category = self.call('GET', '/courses/1/policy')['categories'][0]['id']
        self.call('POST', '/courses/1/questions', self.ta,
            {'prompt': 'Scheduled?', 'options': ['Yes', 'No'], 'correct_index': 0, 'difficulty': 'easy'})
        future = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
        draft = {'title': 'Prepared', 'section_id': 1, 'category_id': category,
                 'question_count': 1, 'duration_minutes': 20, 'prepare_only': True}
        quiz = self.call('POST', '/courses/1/quizzes', self.ta, draft)
        path = f"/courses/1/quizzes/{quiz['id']}"
        self.assertFalse(self.call('GET', '/courses/1/quizzes', self.learner))
        self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner, status=409)
        self.call('POST', path + '/launch', self.ta, {'starts_at': future})
        listed = self.call('GET', '/courses/1/quizzes', self.learner)
        self.assertEqual(listed[0]['state'], 'scheduled')
        self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner, status=409)
        self.call('POST', path + '/cancel', self.learner, status=403)
        self.call('POST', path + '/cancel', self.ta)
        self.call('POST', path + '/cancel', self.ta)
        self.assertFalse(self.call('GET', '/courses/1/assessments', self.ta))
        # A cancelled quiz must no longer consume the fixed grade allocation.
        self.query("UPDATE grade_categories SET allocation_mode='fixed' WHERE id=%s", (category,))
        active = self.call('POST', '/courses/1/quizzes', self.ta,
            draft | {'prepare_only': False, 'starts_at': future})
        self.query("UPDATE quizzes SET starts_at=now()-interval '1 minute',ends_at=now()+interval '20 minutes' WHERE id=%s", (active['id'],))
        self.call('POST', f"/quizzes/{active['id']}/start", self.learner)
        self.assertEqual(self.query('SELECT state FROM quizzes WHERE id=%s', (active['id'],))[0]['state'], 'active')
        self.call('POST', f"/courses/1/quizzes/{active['id']}/cancel", self.ta, status=409)
        self.call('POST', '/courses/1/quizzes', self.ta,
            draft | {'starts_at': '2020-01-01T12:00:00Z', 'prepare_only': False}, status=422)

    def test_background_finalizes_abandoned_attempt_without_student_request(self):
        quiz = self.create_live_quiz()
        attempt = self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)
        answer = self.query('''SELECT q.id AS question_id,o.id AS option_id,q.points
            FROM quiz_questions q JOIN quiz_options o ON o.quiz_question_id=q.id
            WHERE q.quiz_id=%s AND o.is_correct ORDER BY q.id LIMIT 1''', (quiz['id'],))[0]
        self.call('PATCH', f"/quizzes/{quiz['id']}/answers", self.learner, {'answers': [
            {'question_id': answer['question_id'], 'option_id': answer['option_id']}]})
        self.query("UPDATE quiz_attempts SET started_at=now()-interval '2 minutes',deadline_at=now()-interval '1 minute' WHERE id=%s", (attempt['id'],))
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            saved = self.query('SELECT state,score FROM quiz_attempts WHERE id=%s', (attempt['id'],))[0]
            if saved['state'] == 'timed_out':
                break
            time.sleep(.2)
        self.assertEqual(saved['state'], 'timed_out')
        self.assertEqual(saved['score'], answer['points'])
        self.assertTrue(self.query("SELECT 1 FROM audit_events WHERE action='quiz.submit' AND entity_id=%s", (attempt['id'],)))

    def test_late_answer_rejection_preserves_server_finalization(self):
        quiz = self.create_live_quiz()
        attempt = self.call('POST', f"/quizzes/{quiz['id']}/start", self.learner)
        self.query("UPDATE quiz_attempts SET started_at=now()-interval '2 minutes',deadline_at=now()-interval '1 minute' WHERE id=%s", (attempt['id'],))
        self.call('PATCH', f"/quizzes/{quiz['id']}/answers", self.learner, {'answers': []}, status=409)
        saved = self.query('SELECT state,score FROM quiz_attempts WHERE id=%s', (attempt['id'],))[0]
        self.assertEqual(saved['state'], 'timed_out')
        self.assertEqual(saved['score'], 0)

    def test_student_report_uses_full_history_and_published_grades_with_scope(self):
        sessions = self.query("""INSERT INTO attendance_sessions(offering_id,kind,title,starts_at,ends_at,state,created_by)
            SELECT 1,'lecture','Historical '||i,now()-i*interval '1 day',now()-i*interval '1 day'+interval '1 hour','closed',
                (SELECT id FROM app_users WHERE username='doc_rasha01') FROM generate_series(1,104) i RETURNING id""")
        self.query('''INSERT INTO session_eligibility(session_id,enrollment_id,offering_id)
            SELECT s.id,e.id,1 FROM attendance_sessions s CROSS JOIN enrollments e WHERE s.offering_id=1 AND e.offering_id=1''')
        self.query("""INSERT INTO attendance_records(session_id,enrollment_id,offering_id,status,source)
            SELECT x.session_id,x.enrollment_id,1,CASE WHEN x.session_id=%s THEN 'absent' ELSE 'present' END,'manual'
            FROM session_eligibility x WHERE x.enrollment_id=%s""", (sessions[0]['id'], self.student['enrollment_id']))
        first = self.call('GET', '/courses/1/sessions?limit=100', self.learner)
        last = self.call('GET', '/courses/1/sessions?limit=100&offset=100', self.learner)
        self.assertEqual(len(first) + len(last), 104)
        self.assertFalse({row['id'] for row in first} & {row['id'] for row in last})
        self.policy()
        category = self.call('GET', '/courses/1/policy')['categories'][0]['id']
        assessment = self.call('POST', '/courses/1/assessments', body={
            'title': 'Published score', 'kind': 'assignment', 'section_id': 1, 'category_id': category, 'max_points': '10'})
        self.call('POST', '/courses/1/policy/publish')
        self.call('PATCH', f"/courses/1/assessments/{assessment['id']}/results", self.ta, {'rows': [
            {'enrollment_id': self.student['enrollment_id'], 'score': '7', 'state': 'recorded', 'revision': 0}]})
        unpublished = self.call('GET', '/courses/1/report/students?section_id=1', self.ta)
        own = next(row for row in unpublished['rows'] if row['enrollment_id'] == self.student['enrollment_id'])
        self.assertIsNone(own['official_total'])
        self.call('POST', f"/courses/1/assessments/{assessment['id']}/publish")
        report = self.call('GET', '/courses/1/report/students?section_id=1', self.ta)
        self.assertTrue(all(row['course_section_id'] == 1 for row in report['rows']))
        own = next(row for row in report['rows'] if row['enrollment_id'] == self.student['enrollment_id'])
        self.assertEqual(own['official_total'], '70.00')
        self.assertEqual(own['attendance']['lecture']['eligible'], 104)
        self.assertEqual(own['attendance']['lecture']['rate'], '99.04')
        self.call('GET', '/courses/1/report/students?section_id=2', self.ta, status=403)
        self.call('GET', '/courses/1/report/students', self.learner, status=403)

    def test_report_summary_respects_section_scope_and_excludes_excuses(self):
        shared = self.call('POST', '/courses/1/sessions', body={'kind': 'lecture', 'title': 'Shared lecture'})
        self.call('POST', f"/courses/1/sessions/{shared['id']}/close")
        section = self.call('POST', '/courses/1/sessions', self.ta,
                            {'kind': 'section', 'title': 'Own section', 'section_id': 1})
        detail = self.call('GET', f"/courses/1/sessions/{section['id']}", self.ta)
        size = len(detail['rows'])
        self.call('POST', f"/courses/1/sessions/{section['id']}/finalize", self.ta, {
            'revision': detail['revision'], 'rows': [
                {'enrollment_id': row['enrollment_id'],
                 'status': 'excused' if row['enrollment_id'] == self.student['enrollment_id'] else 'present'}
                for row in detail['rows']]})
        outside = self.call('POST', '/courses/1/sessions', body={
            'kind': 'lecture', 'title': 'Outside section', 'section_id': 2})
        self.call('POST', f"/courses/1/sessions/{outside['id']}/close")
        for user in (self.doctor, self.ta):
            summary = self.call('GET', '/courses/1/sessions/summary?section_id=1', user)
            self.assertEqual(summary['lecture'], {'present': 0, 'eligible': size})
            self.assertEqual(summary['section'], {'present': size - 1, 'eligible': size - 1})
            report = self.call('GET', '/courses/1/report?section_id=1', user)
            self.assertEqual(report['students'], size)
            self.assertEqual(report['sessions'], 2)
        self.call('GET', '/courses/1/sessions/summary?section_id=2', self.ta, status=403)
        own = self.call('GET', '/courses/1/sessions/summary', self.learner)
        self.assertEqual(own['section'], {'present': 0, 'eligible': 0})


    def test_ta_cannot_create_or_grade_exams_but_doctor_can(self):
        policy = self.policy()
        for kind in ('midterm', 'final'):
            body = {'title': kind, 'kind': kind, 'category_id': policy['categories'][0]['id'],
                    'section_id': 1, 'max_points': '10'}
            self.call('POST', '/courses/1/assessments', self.ta, body, status=403)
            assessment = self.call('POST', '/courses/1/assessments', body=body)
            path = f"/courses/1/assessments/{assessment['id']}/results"
            result = self.call('GET', path, self.ta)
            self.assertFalse(result['editable'])
            row = {'enrollment_id': self.student['enrollment_id'], 'score': '0',
                   'state': 'recorded', 'revision': 0}
            self.call('PATCH', path, self.ta, {'rows': [row]}, status=403)
            self.call('PATCH', path, body={'rows': [row]})
            visible = self.call('GET', '/courses/1/assessments?section_id=1', self.ta)
            self.assertNotIn(assessment['id'], [item['id'] for item in visible])

    def test_electronic_quiz_results_are_read_only_until_quiz_closes(self):
        active = self.create_live_quiz()
        policy = self.call('GET', '/courses/1/policy')
        body = {'title': 'Prepared quiz', 'section_id': 1,
                'category_id': policy['categories'][0]['id'], 'question_count': 1,
                'duration_minutes': 20}
        draft = self.call('POST', '/courses/1/quizzes', self.ta, body | {'prepare_only': True})
        scheduled = self.call('POST', '/courses/1/quizzes', self.ta, body | {
            'starts_at': (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()})
        for quiz in (draft, scheduled, active):
            path = f"/courses/1/assessments/{quiz['assessment_id']}"
            for user in (self.ta, self.doctor):
                book = self.call('GET', path + '/results', user)
                self.assertFalse(book['editable'])
                self.call('PATCH', path + '/results', user, {'rows': [{
                    'enrollment_id': self.student['enrollment_id'], 'score': '0',
                    'state': 'recorded', 'revision': 0}]}, status=409)
            self.call('GET', path + '/publication-preview', status=409)
            self.call('POST', path + '/publish', status=409)
            self.call('POST', path + '/publish', self.ta, status=403)
        self.assertEqual(self.query('SELECT count(*) AS n FROM assessment_results')[0]['n'], 0)
        self.call('POST', f"/courses/1/quizzes/{active['id']}/close", self.ta)
        path = f"/courses/1/assessments/{active['assessment_id']}"
        self.assertTrue(self.call('GET', path + '/results', self.ta)['editable'])
        self.call('PATCH', path + '/results', self.ta, {'rows': [{
            'enrollment_id': self.student['enrollment_id'], 'score': '0',
            'state': 'recorded', 'revision': 0}]})
        self.call('POST', path + '/publish')

    def test_shared_lecture_details_match_the_selected_ta_section(self):
        lecture = self.call('POST', '/courses/1/sessions', body={'kind': 'lecture', 'title': 'Shared'})
        own_sections = self.call('GET', '/courses/1/assignments', self.ta)
        for section in own_sections[:2]:
            path = f"/courses/1/sessions/{lecture['id']}?section_id={section['id']}"
            rows = self.call('GET', path, self.ta)['rows']
            expected = self.query('SELECT id FROM enrollments WHERE course_section_id=%s AND state=\'active\'', (section['id'],))
            self.assertEqual({r['enrollment_id'] for r in rows}, {r['id'] for r in expected})
        self.call('GET', f"/courses/1/sessions/{lecture['id']}?section_id=2", self.ta, status=403)
        own = self.call('POST', '/courses/1/sessions', self.ta, {'kind': 'section', 'title': 'Own', 'section_id': 1})
        other_own = next(s for s in own_sections if s['id'] != 1)
        self.call('GET', f"/courses/1/sessions/{own['id']}?section_id={other_own['id']}", self.ta, status=403)

    def test_ta_cannot_create_an_empty_attendance_roster(self):
        ids = [r['id'] for r in self.query("SELECT id FROM enrollments WHERE course_section_id=1 AND state='active'")]
        try:
            self.query("UPDATE enrollments SET state='dropped' WHERE id=ANY(%s)", (ids,))
            self.call('POST', '/courses/1/sessions', self.ta,
                      {'kind': 'section', 'title': 'Empty', 'section_id': 1}, status=422)
            self.assertEqual(self.query('SELECT count(*) AS n FROM attendance_sessions')[0]['n'], 0)
        finally:
            self.query("UPDATE enrollments SET state='active' WHERE id=ANY(%s)", (ids,))

    def test_ta_pending_filter_keeps_only_own_drafts(self):
        draft = self.call('POST', '/courses/1/sessions', self.ta,
                          {'kind': 'section', 'title': 'Pending', 'section_id': 1})
        self.call('POST', '/courses/1/sessions', body={'kind': 'lecture', 'title': 'Lecture'})
        finalized = self.call('POST', '/courses/1/sessions', self.ta,
                              {'kind': 'section', 'title': 'Finalized', 'section_id': 1})
        detail = self.call('GET', f"/courses/1/sessions/{finalized['id']}", self.ta)
        self.call('POST', f"/courses/1/sessions/{finalized['id']}/finalize", self.ta, {
            'revision': detail['revision'], 'rows': [
                {'enrollment_id': r['enrollment_id'], 'status': 'present'} for r in detail['rows']]})
        rows = self.call('GET', '/courses/1/sessions?section_id=1&state=draft', self.ta)
        self.assertEqual([r['id'] for r in rows], [draft['id']])


if __name__ == '__main__':
    unittest.main()
