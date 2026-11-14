"""Inspect refined Flutter screens and exercise workflows in an isolated database."""
import json
import re

from support import ROOT, Sandbox
from demo_rehearsal import wait_text


def select_shared_scope(page):
    header = page.get_by_role('button', name=re.compile(r'^CS\d+ ·')).first
    current = re.search(r'CS\d+', header.get_attribute('aria-label') or header.inner_text()).group()
    header.click()
    page.wait_for_timeout(400)
    if current != 'CS381':
        page.get_by_role('button', name=re.compile('^' + current + ' ·')).last.click()
        page.wait_for_timeout(400)
        page.get_by_role('button', name=re.compile(r'^CS381 ·')).last.click()
        page.wait_for_timeout(400)
    section = page.get_by_role('button', name=re.compile(r'سكشن 1 \(SE\)')).last
    for _ in range(12):
        bounds = section.bounding_box() if section.count() else None
        if bounds and bounds['y'] >= 0 and bounds['y'] + bounds['height'] < page.viewport_size['height']:
            section.click()
            break
        page.mouse.move(page.viewport_size['width'] / 2, page.viewport_size['height'] * .75)
        page.mouse.wheel(0, 350)
        page.wait_for_timeout(200)
    else:
        raise AssertionError('Could not scroll to the authorized SE1 section')
    page.get_by_role('button', name=re.compile(r'^CS381 ·')).first.wait_for()


def button(page, label):
    return page.get_by_role('button', name=re.compile(re.escape(label))).first


def tab(page, label):
    return page.get_by_role('tab', name=re.compile(re.escape(label))).or_(
        page.get_by_role('button', name=re.compile('^' + re.escape(label) + '$'))).last


def seed(sandbox):
    policy = sandbox.call('PUT', '/courses/1/policy', json={
        'total_points': '100', 'categories': [
            {'code': 'lecture', 'name': 'حضور المحاضرات', 'kind': 'lecture_attendance', 'max_points': '10', 'allocation_mode': 'proportional'},
            {'code': 'section', 'name': 'حضور السكاشن', 'kind': 'section_attendance', 'max_points': '10', 'allocation_mode': 'proportional'},
            {'code': 'quiz', 'name': 'الكويزات', 'kind': 'assessment', 'max_points': '80', 'allocation_mode': 'normalized'},
        ]})
    sandbox.call('POST', '/courses/1/questions', json={
        'prompt': 'ما الهدف من اختبار البرمجيات؟', 'options': ['اكتشاف الأخطاء', 'زيادة الأخطاء'], 'correct_index': 0, 'points': '5'})
    sandbox.call('POST', '/courses/1/quizzes', json={
        'title': 'كويز المراجعة', 'section_id': 1, 'category_id': policy['categories'][2]['id'],
        'question_count': 1, 'duration_minutes': 20})
    sandbox.call('POST', '/courses/1/policy/publish')
    lecture = sandbox.call('POST', '/courses/1/sessions', json={'kind': 'lecture', 'title': 'المحاضرة السابقة'})
    sandbox.call('POST', f"/courses/1/sessions/{lecture['id']}/close")
    sandbox.call('POST', '/courses/1/sessions', json={'kind': 'lecture', 'title': 'محاضرة اليوم'})
    return sandbox.call('POST', '/courses/1/sessions', role='ta',
                        json={'kind': 'section', 'section_id': 1, 'title': 'كشف حضور محفوظ'})


def main():
    screenshots = ROOT / 'screenshots' / 'refined'
    screenshots.mkdir(parents=True, exist_ok=True)
    artifacts = ROOT / '.dart_tool' / 'ui-refinement'
    artifacts.mkdir(parents=True, exist_ok=True)
    checks = []
    with Sandbox('smoke') as sandbox:
        draft = seed(sandbox)
        for role, width, height in [('doctor', 1440, 1000), ('ta', 400, 900), ('student', 400, 900)]:
            with sandbox.browser(width=width, height=height) as page:
                sandbox.open_ui(page)
                button(page, 'تسجيل الدخول').wait_for()
                page.screenshot(path=str(screenshots / f'login-{width}.png'))
                sandbox.ui_login(page, role)
                button(page, 'تحديث البيانات').wait_for()
                try:
                    select_shared_scope(page)
                except Exception:
                    page.screenshot(path=str(artifacts / 'scope-failure.png'))
                    (artifacts / 'scope-dom.txt').write_text(page.locator('body').aria_snapshot(), encoding='utf-8')
                    raise
                wait_text(page, {'doctor': 'كل تفاصيل مقررك', 'ta': 'سكشنك جاهز', 'student': 'خطوة جديدة'}[role])
                page.screenshot(path=str(screenshots / f'{role}-home.png'))
                checks.append({'check': f'{role} responsive login and scope', 'passed': True})
                if role == 'ta':
                    tab(page, 'الحضور').click()
                    button(page, 'كشف حضور محفوظ').wait_for()
                    button(page, 'كشف حضور محفوظ').click()
                    choice = page.get_by_role('checkbox', name=re.compile('حاضر')).or_(
                        page.get_by_role('button', name=re.compile('حاضر'))).first
                    choice.wait_for()
                    choice.click()
                    button(page, 'حفظ مسودة الحضور').click()
                    wait_text(page, 'تم حفظ المسودة')
                    saved = sandbox.call('GET', f"/courses/1/sessions/{draft['id']}", role='ta')
                    assert sum(row['status'] == 'present' for row in saved['rows']) == 1
                    page.screenshot(path=str(screenshots / 'attendance-draft.png'))
                    page.reload()
                    sandbox.enable_semantics(page)
                    tab(page, 'الحضور').wait_for()
                    tab(page, 'الحضور').click()
                    button(page, 'كشف حضور محفوظ').click()
                    wait_text(page, 'المسودة محفوظة')
                    checks.append({'check': 'attendance draft survives browser reload', 'passed': True})
                    page.reload()
                    sandbox.enable_semantics(page)
                    button(page, 'الكويزات').wait_for()
                    button(page, 'الكويزات').click()
                    button(page, 'إنشاء كويز للسكشن').click()
                    field = page.get_by_role('textbox').first
                    field.click()
                    page.wait_for_timeout(100)
                    field.press_sequentially('Browser prepared quiz', delay=15)
                    combo = page.get_by_role('combobox')
                    (combo.nth(1) if combo.count() > 1 else button(page, 'بند اللائحة')).click()
                    page.get_by_role('menuitem', name='الكويزات', exact=True).click()
                    mode = page.get_by_role('checkbox', name='حفظ مسودة', exact=True)
                    for _ in range(6):
                        if mode.count():
                            break
                        page.mouse.move(200, 650)
                        page.mouse.wheel(0, 300)
                        page.wait_for_timeout(200)
                    page.screenshot(path=str(artifacts / 'quiz-controls.png'))
                    (artifacts / 'quiz-dom.txt').write_text(page.locator('body').aria_snapshot(), encoding='utf-8')
                    mode.click()
                    page.wait_for_timeout(350)
                    page.screenshot(path=str(screenshots / 'quiz-preparation.png'))
                    button(page, 'حفظ مسودة الكويز').click()
                    button(page, 'Browser prepared quiz').wait_for()
                    prepared = sandbox.query("SELECT q.id,q.state FROM quizzes q JOIN assessments a ON a.id=q.assessment_id WHERE a.title='Browser prepared quiz'")[0]
                    assert prepared['state'] == 'draft'
                    button(page, 'إلغاء الكويز').click()
                    button(page, 'تأكيد').click()
                    wait_text(page, 'ملغى')
                    assert sandbox.query('SELECT state FROM quizzes WHERE id=%s', (prepared['id'],))[0]['state'] == 'cancelled'
                    checks.append({'check': 'quiz preparation and cancellation through UI', 'passed': True})
                    page.reload()
                    sandbox.enable_semantics(page)
                    tab(page, 'المزيد').wait_for()
                    tab(page, 'المزيد').click()
                    button(page, 'تقرير المقرر').click()
                    button(page, 'كشف الطلاب والطباعة').click()
                    button(page, 'تصدير PDF').wait_for()
                    with page.expect_download(timeout=30000) as download:
                        button(page, 'تصدير PDF').click()
                    file = download.value
                    file.save_as(str(artifacts / 'browser-report.pdf'))
                    assert (artifacts / 'browser-report.pdf').stat().st_size > 10000
                    page.screenshot(path=str(screenshots / 'student-report.png'))
                    checks.append({'check': 'scoped Arabic PDF download', 'passed': True})
                if role == 'student':
                    tab(page, 'المزيد').click()
                    button(page, 'الوضع الداكن').or_(page.get_by_role('switch', name=re.compile('الوضع الداكن'))).first.click()
                    tab(page, 'الرئيسية').click()
                    page.mouse.move(0, 0)
                    page.wait_for_timeout(800)
                    page.screenshot(path=str(screenshots / 'student-dark.png'))
                    checks.append({'check': 'student dark theme', 'passed': True})
                assert not sandbox.browser_errors, 'Flutter browser errors were observed'
                assert not any(status == 500 for _, _, status in sandbox.browser_requests)
        # Exercise the same server lifecycle that drives the scheduling controls.
    output = ROOT / 'review' / 'ui-refinement-results.json'
    output.write_text(json.dumps({'checks': checks, 'isolated_database_cleaned': True}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Passed {len(checks)} browser checks; screenshots and report retained; isolated database cleaned')


if __name__ == '__main__':
    main()
