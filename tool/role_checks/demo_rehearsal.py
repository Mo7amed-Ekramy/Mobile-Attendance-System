"""Shared three-role rehearsal in one temporary DB; main application data is untouched."""
from contextlib import ExitStack
import json
import re
import socket
import threading
import time
import sys

import httpx
import uvicorn

from support import ROOT, Sandbox
from app import create_app
from db import Database


def restart_api(sandbox):
    sandbox.api_server.should_exit = True
    sandbox.api_thread.join(timeout=15)
    if sandbox.api_thread.is_alive():
        raise AssertionError('Isolated API did not stop')
    sandbox.api_socket.close()
    sandbox.client.close()
    sandbox.api_socket = socket.socket()
    sandbox.api_socket.bind(('127.0.0.1', 0))
    sandbox.api_url = f'http://127.0.0.1:{sandbox.api_socket.getsockname()[1]}/api/v1'
    sandbox.api_server = uvicorn.Server(uvicorn.Config(create_app(Database(sandbox.runtime)),
        host='127.0.0.1', port=0, log_level='error', access_log=False))
    sandbox.api_thread = threading.Thread(target=sandbox.api_server.run,
        kwargs={'sockets': [sandbox.api_socket]}, daemon=True)
    sandbox.api_thread.start()
    deadline = time.monotonic() + 20
    while not sandbox.api_server.started:
        if not sandbox.api_thread.is_alive() or time.monotonic() >= deadline:
            raise AssertionError('Isolated API did not restart')
        time.sleep(.05)
    sandbox.client = httpx.Client(base_url=sandbox.api_url + '/', timeout=20)


def wait_text(page, value):
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        if value in page.locator('body').aria_snapshot():
            return
        page.wait_for_timeout(100)
    raise AssertionError('Expected rehearsal text was not displayed')


def select_shared_scope(page):
    header = page.get_by_role('button', name=re.compile(r'^CS\d+ ·')).first
    current = re.search(r'CS\d+', header.get_attribute('aria-label') or header.inner_text()).group()
    header.click()
    if current != 'CS381':
        page.get_by_role('button', name=re.compile('^' + current + ' ·')).last.click()
        page.get_by_role('button', name=re.compile(r'^CS381 ·')).last.click()
    page.get_by_role('button', name=re.compile(r'سكشن 1 \(SE\)')).last.click()
    page.get_by_role('button', name=re.compile(r'^CS381 ·')).first.wait_for()


def main():
    ux = '--ux' in sys.argv
    rows = []
    phase = 'setup'
    failure = None
    try:
        with Sandbox('smoke') as sandbox:
            call = sandbox.call
            policy = call('PUT', '/courses/1/policy', json={'total_points': '100', 'categories': [
                {'code': 'lecture', 'name': 'Lectures', 'kind': 'lecture_attendance',
                 'max_points': '20', 'allocation_mode': 'proportional'},
                {'code': 'section', 'name': 'Sections', 'kind': 'section_attendance',
                 'max_points': '20', 'allocation_mode': 'proportional'},
                {'code': 'quiz', 'name': 'Quizzes', 'kind': 'assessment',
                 'max_points': '60', 'allocation_mode': 'normalized'}]})
            category = next(item['id'] for item in policy['categories'] if item['code'] == 'quiz')
            for points in (2, 3):
                call('POST', '/courses/1/questions', role='ta', json={
                    'prompt': f'Rehearsal question {points}', 'options': ['Correct', 'Wrong'],
                    'correct_index': 0, 'points': str(points), 'difficulty': 'easy' if points == 2 else 'medium'})
            quiz = call('POST', '/courses/1/quizzes', role='ta', json={
                'section_id': 1, 'category_id': category, 'title': 'Shared rehearsal quiz',
                'question_count': 2, 'duration_minutes': 20})
            call('POST', '/courses/1/policy/publish')
            lecture = call('POST', '/courses/1/sessions', json={
                'kind': 'lecture', 'title': 'Shared rehearsal lecture', 'duration_minutes': 20})
            code = call('GET', f"/courses/1/sessions/{lecture['id']}/qr")
            receipt = call('POST', '/attendance/check-ins', role='student', json={'payload': code['payload']})
            duplicate = call('POST', '/attendance/check-ins', role='student', json={'payload': code['payload']})
            assert duplicate['duplicate'] and duplicate['receipt_id'] == receipt['receipt_id']
            call('POST', f"/courses/1/sessions/{lecture['id']}/close")
            section = call('POST', '/courses/1/sessions', role='ta', json={
                'kind': 'section', 'title': 'Shared rehearsal section', 'section_id': 1})
            detail = call('GET', f"/courses/1/sessions/{section['id']}", role='ta')
            call('POST', f"/courses/1/sessions/{section['id']}/finalize", role='ta', json={
                'revision': detail['revision'], 'rows': [
                    {'enrollment_id': row['enrollment_id'], 'status': 'present'
                     if row['enrollment_id'] == sandbox.shared['enrollment_id'] else 'absent'}
                    for row in detail['rows']]})
            call('POST', f"/quizzes/{quiz['id']}/start", role='student')
            answers = sandbox.query('''SELECT q.id AS question_id,o.id AS option_id
                FROM quiz_questions q JOIN quiz_options o ON o.quiz_question_id=q.id
                WHERE q.quiz_id=%s AND o.is_correct''', (quiz['id'],))
            call('PATCH', f"/quizzes/{quiz['id']}/answers", role='student', json={'answers': answers})
            call('POST', f"/quizzes/{quiz['id']}/submit", role='student', json={'answers': []})
            call('POST', f"/courses/1/assessments/{quiz['assessment_id']}/publish")
            assert call('GET', '/courses/1/grades', role='student')['official_total'] == '100.00'
            rows.append({'scenario': 'Shared API attendance, quiz, publication and duplicate protection', 'status': 'PASS'})

            with ExitStack() as browsers:
                pages = {}
                errors = []
                browser_instance = None
                for role in ('doctor', 'ta', 'student'):
                    phase = role + ' browser context creation'
                    page = browsers.enter_context(sandbox.browser(browser_instance=browser_instance))
                    browser_instance = page.context.browser
                    page.on('pageerror', lambda error: errors.append(type(error).__name__))
                    phase = role + ' browser startup'
                    sandbox.open_ui(page)
                    phase = role + ' browser login'
                    if ux and role == 'student':
                        sandbox.ui_login(page, role, password='incorrect-password')
                        wait_text(page, 'اسم المستخدم أو كلمة المرور غير صحيحة')
                        rows.append({'scenario': 'Student inline login error permits a valid retry', 'status': 'PASS'})
                    sandbox.ui_login(page, role)
                    page.get_by_role('button', name='تحديث البيانات', exact=True).wait_for()
                    phase = role + ' browser shared scope'
                    select_shared_scope(page)
                    pages[role] = page
                    rows.append({'scenario': role + ' independent Chrome login and CS381/SE1 scope', 'status': 'PASS'})
                    if ux:
                        phase = role + ' dashboard and narrow layout'
                        heading = {'doctor': 'لوحة متابعة المقرر', 'ta': 'مهام السكشن', 'student': 'يومي الدراسي'}[role]
                        primary = {'doctor': 'فتح محاضرة', 'ta': 'إنشاء كشف حضور السكشن', 'student': 'مسح رمز الحضور'}[role]
                        wait_text(page, heading)
                        page.get_by_role('button', name=re.compile('^' + primary)).first.wait_for()
                        shots = ROOT / '.dart_tool' / 'role-checks' / 'uiux'
                        shots.mkdir(parents=True, exist_ok=True)
                        page.screenshot(path=str(shots / (role + '-desktop.png')))
                        rows.append({'scenario': role + ' task-focused dashboard and primary action', 'status': 'PASS'})
                        page.set_viewport_size({'width': 320, 'height': 740})
                        page.wait_for_timeout(300)
                        assert page.get_by_role('tab').count() == 5
                        wait_text(page, heading)
                        page.screenshot(path=str(shots / (role + '-phone.png')))
                        page.set_viewport_size({'width': 1280, 'height': 1000})
                        rows.append({'scenario': role + ' five destinations and dashboard at 320px', 'status': 'PASS'})
                        page.get_by_role('tab', name='المزيد', exact=True).click()
                        toggle = page.get_by_role('switch', name=re.compile('الوضع الداكن'))
                        if toggle.count() == 0:
                            toggle = page.get_by_role('checkbox', name=re.compile('الوضع الداكن'))
                        toggle.click()
                        page.wait_for_function('''() => [...document.querySelectorAll('[role=switch],[role=checkbox]')]
                            .some(element => element.getAttribute('aria-checked') === 'true')''')
                        page.get_by_role('tab', name='الرئيسية', exact=True).click()
                        wait_text(page, heading)
                        page.screenshot(path=str(shots / (role + '-dark.png')))
                if ux:
                    phase = 'TA exact-section workspace'
                    page = pages['ta']
                    page.get_by_role('tab', name='السكاشن', exact=True).click()
                    page.get_by_role('button', name=re.compile(r'^CS381 · سكشن 1')).last.click()
                    wait_text(page, 'إنشاء كشف حضور السكشن')
                    rows.append({'scenario': 'TA opens assigned section workspace directly', 'status': 'PASS'})
                    page.get_by_role('button', name=re.compile('رجوع|Back')).first.click()
                    phase = 'Student attendance hub'
                    page = pages['student']
                    page.get_by_role('tab', name='الحضور', exact=True).click()
                    wait_text(page, 'سجل الحضور')
                    page.get_by_role('button', name=re.compile('^مسح رمز الحضور')).first.wait_for()
                    rows.append({'scenario': 'Student attendance history and scan entry share one destination', 'status': 'PASS'})
                phase = 'student published-grade browser view'
                page = pages['student']
                page.get_by_role('tab', name='الدرجات', exact=True).click()
                wait_text(page, 'المجموع النهائي')
                wait_text(page, '100')
                rows.append({'scenario': 'Student Chrome displays published results in shared scope', 'status': 'PASS'})
                for role in ('doctor', 'ta'):
                    phase = role + ' scoped browser report'
                    page = pages[role]
                    page.get_by_role('tab', name='المزيد', exact=True).click()
                    page.get_by_role('button', name=re.compile('تقرير المقرر')).first.click()
                    wait_text(page, 'إحصائيات الطلاب')
                    wait_text(page, 'سكشن 1 (SE)')
                    rows.append({'scenario': role + ' Chrome renders selected-section report', 'status': 'PASS'})
                if ux:
                    phase = 'Doctor pinned grade actions'
                    page = pages['doctor']
                    page.get_by_role('button', name=re.compile('رجوع|Back')).first.click()
                    page.get_by_role('tab', name='الدرجات', exact=True).click()
                    page.get_by_role('button', name=re.compile('^Shared rehearsal quiz')).first.click()
                    save = page.get_by_role('button', name='حفظ درجات الصفحة', exact=True)
                    save.wait_for()
                    assert save.is_visible()
                    rows.append({'scenario': 'Doctor grade save control is visible without scrolling the roster', 'status': 'PASS'})
                phase = 'API restart and persistence'
                restart_api(sandbox)
                assert call('GET', '/courses/1/grades', role='student')['official_total'] == '100.00'
                stored = call('GET', f"/courses/1/sessions/{lecture['id']}", role='student')
                assert stored['record']['status'] == 'present'
                assert call('GET', f"/courses/1/sessions/{section['id']}", role='ta')['state'] == 'finalized'
                assert call('GET', '/notifications', role='student')
                for role, page in pages.items():
                    phase = role + ' browser restoration after API restart'
                    page.reload(wait_until='domcontentloaded')
                    sandbox.enable_semantics(page)
                    page.get_by_role('button', name='تحديث البيانات', exact=True).wait_for()
                    if ux:
                        page.get_by_role('button', name=re.compile(r'^CS381 · سكشن 1')).first.wait_for()
                    select_shared_scope(page)
                    rows.append({'scenario': role + ' Chrome restores its session after API restart', 'status': 'PASS'})
                    if ux:
                        page.get_by_role('tab', name='المزيد', exact=True).click()
                        toggle = page.get_by_role('switch', name=re.compile('الوضع الداكن'))
                        if toggle.count() == 0:
                            toggle = page.get_by_role('checkbox', name=re.compile('الوضع الداكن'))
                        assert toggle.get_attribute('aria-checked') == 'true'
                        rows.append({'scenario': role + ' selected scope and dark theme persist through reload', 'status': 'PASS'})
                assert not errors, 'Browser reported an application exception'
                rows.append({'scenario': 'Saved attendance, grades and notifications survive API restart', 'status': 'PASS'})
                rows.append({'scenario': 'No uncaught browser application exceptions', 'status': 'PASS'})
    except Exception as error:
        # Never retain request dumps, bearer tokens or entered passwords.
        failure = type(error).__name__
        rows.append({'scenario': phase, 'status': 'FAIL', 'error_type': failure})
    result = {'database': 'Temporary shared rehearsal database; removed afterward',
              'workflow_layer': 'HTTP API; three independent Chrome login/report/restoration views',
              'scenarios': rows, 'success': failure is None}
    name = 'role-ux-browser-results.json' if ux else 'demo-rehearsal.json'
    (ROOT / 'review' / name).write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'success': result['success'], 'passed': sum(r['status'] == 'PASS' for r in rows),
                      'failed': sum(r['status'] == 'FAIL' for r in rows)}))
    if failure:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
