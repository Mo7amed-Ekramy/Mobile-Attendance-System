"""Real Flutter QR decoder -> API -> PostgreSQL, using a simulated camera.

The video input is the QR rendered by the doctor's actual Flutter page. No
barcode detector, check-in response, API or database write is mocked. The
temporary database is owned and cleaned by Sandbox; app data is never changed.
"""
import base64
import json

from demo_rehearsal import wait_text
from refinement_check import button, select_shared_scope, tab
from support import ROOT, Sandbox


def main():
    artifacts = ROOT / 'screenshots' / 'priority'
    artifacts.mkdir(parents=True, exist_ok=True)
    checks = []
    with Sandbox('smoke') as sandbox:
        with sandbox.browser(width=1440, height=1000) as doctor:
            sandbox.open_ui(doctor)
            sandbox.ui_login(doctor, 'doctor')
            button(doctor, 'تحديث البيانات').wait_for()
            select_shared_scope(doctor)
            button(doctor, 'فتح محاضرة').click()
            title = doctor.get_by_role('textbox', name='عنوان الجلسة', exact=True)
            title.click()
            title.press_sequentially('QR attendance proof', delay=15)
            button(doctor, 'فتح الجلسة وعرض الرمز').click()
            wait_text(doctor, 'qr code')
            doctor.screenshot(path=str(artifacts / 'doctor-qr.png'))
            session = sandbox.query("SELECT * FROM attendance_sessions WHERE title='QR attendance proof'")[0]
            assert session['course_section_id'] == 1
            checks.append({'check': 'Doctor creates scoped lecture and renders actual QR', 'passed': True})

            with sandbox.browser(width=400, height=900, browser_instance=doctor.context.browser) as student:
                sandbox.open_ui(student)
                sandbox.ui_login(student, 'student')
                button(student, 'تحديث البيانات').wait_for()
                # Refresh the actual visible image immediately before scanning.
                # Fixed 1440px viewport: visually verified 260px QR centered at y=167.
                # The real decoder below must succeed, so a wrong crop cannot pass.
                png = doctor.screenshot(clip={'x': 582, 'y': 159, 'width': 276, 'height': 276})
                (artifacts / 'qr-camera-input.png').write_bytes(png)
                student.evaluate('''async png => {
                    const image = new Image();
                    image.src = 'data:image/png;base64,' + png;
                    await image.decode();
                    const canvas = document.createElement('canvas');
                    canvas.width = canvas.height = 640;
                    const ctx = canvas.getContext('2d');
                    const paint = () => {
                        ctx.fillStyle = 'white'; ctx.fillRect(0, 0, 640, 640);
                        ctx.drawImage(image, 80, 80, 480, 480);
                    };
                    paint();
                    window.__qrCameraCanvas = canvas;
                    setInterval(paint, 100);
                    navigator.mediaDevices.getUserMedia = async () => canvas.captureStream(10);
                }''', base64.b64encode(png).decode())
                scanned = []
                student.on('request', lambda req: scanned.append(json.loads(req.post_data)['payload'])
                           if req.method == 'POST' and '/attendance/check-ins' in req.url else None)
                button(student, 'مسح رمز الحضور').click()
                try:
                    wait_text(student, 'تم تسجيل حضورك')
                except Exception:
                    student.screenshot(path=str(artifacts / 'scanner-failure.png'))
                    (artifacts / 'scanner-failure.txt').write_text(student.locator('body').aria_snapshot(), encoding='utf-8')
                    raise
                student.screenshot(path=str(artifacts / 'student-qr-receipt.png'))
                assert scanned, 'The decoder did not send a check-in'
                record = sandbox.query('''SELECT * FROM attendance_records
                    WHERE session_id=%s AND enrollment_id=%s''',
                    (session['id'], sandbox.shared['enrollment_id']))[0]
                assert record['source'] == 'qr' and record['status'] == 'present'
                assert scanned[0].startswith(f"v1.{session['id']}.")
                snapshot = student.locator('body').aria_snapshot()
                assert 'CS381' in snapshot and 'QR attendance proof' in snapshot
                assert str(record['id']) in snapshot
                student.screenshot(path=str(artifacts / 'student-qr-receipt.png'))
                checks.append({'check': 'Real QR decoder reads doctor image from simulated video and persists present/source=qr in PostgreSQL',
                               'passed': True, 'record_count': 1})
                button(student, 'تم').click()
                student.wait_for_timeout(1200)
                assert not student.get_by_role('alertdialog').count(), 'Scanning reopened the same receipt automatically'
                assert len(scanned) == 1, 'The same frame triggered another check-in'
                checks.append({'check': 'Scanner pauses after success; keeping QR in frame does not reopen receipt', 'passed': True})
                button(student, 'مسح رمز آخر').click()
                wait_text(student, 'حضورك مسجل بالفعل')
                assert len(scanned) == 2
                assert sandbox.query('SELECT count(*) AS n FROM attendance_records WHERE session_id=%s AND enrollment_id=%s',
                    (session['id'], sandbox.shared['enrollment_id']))[0]['n'] == 1
                checks.append({'check': 'Explicit scan-another restarts the real decoder and returns the same receipt without duplicate records', 'passed': True})
                student.reload()
                sandbox.enable_semantics(student)
                button(student, 'تحديث البيانات').wait_for()
                select_shared_scope(student)
                tab(student, 'الحضور').click()
                button(student, 'QR attendance proof').click()
                wait_text(student, 'نسخ إيصال الحضور')
                own_detail = sandbox.call('GET', f"/courses/1/sessions/{session['id']}", role='student')
                assert own_detail['record']['receipt_id'] == record['id']
                assert own_detail['record']['recorded_at'] == record['recorded_at'].isoformat()
                student.screenshot(path=str(artifacts / 'reopened-attendance-receipt.png'))
                checks.append({'check': 'Student reopens the same persisted receipt after browser reload', 'passed': True})
                assert not sandbox.browser_errors, 'Student browser errors'

            # Closing the actual lecture must retain present and materialize absences.
            button(doctor, 'إغلاق جلسة الحضور').click()
            button(doctor, 'تأكيد').click()
            wait_text(doctor, 'لا يوجد رمز نشط')
            saved = sandbox.query('SELECT status FROM attendance_records WHERE id=%s', (record['id'],))[0]
            assert saved['status'] == 'present'
            summary = sandbox.call('GET', '/courses/1/sessions/summary', role='student')
            assert summary['lecture'] == {'present': 1, 'eligible': 1}
            checks.append({'check': 'Doctor closes lecture; saved QR attendance remains present in official totals', 'passed': True})

        # Capture the readiness screen without creating an attempt.
        policy = sandbox.call('PUT', '/courses/1/policy', json={'total_points': '100', 'categories': [
            {'code': 'quiz', 'name': 'الكويزات', 'kind': 'assessment', 'max_points': '100', 'allocation_mode': 'normalized'}]})
        sandbox.call('POST', '/courses/1/questions', json={
            'prompt': 'سؤال تجريبي', 'options': ['أ', 'ب'], 'correct_index': 0, 'points': '1'})
        sandbox.call('POST', '/courses/1/quizzes', json={'title': 'كويز الاستعداد', 'section_id': 1,
            'category_id': policy['categories'][0]['id'], 'question_count': 1, 'duration_minutes': 20})
        with sandbox.browser(width=400, height=900) as student:
            sandbox.open_ui(student)
            sandbox.ui_login(student, 'student')
            button(student, 'تحديث البيانات').wait_for()
            select_shared_scope(student)
            button(student, 'الكويزات').click()
            button(student, 'كويز الاستعداد').click()
            wait_text(student, 'قبل بدء الكويز')
            assert sandbox.query('SELECT count(*) AS n FROM quiz_attempts')[0]['n'] == 0
            student.screenshot(path=str(artifacts / 'quiz-readiness.png'))
            checks.append({'check': 'Mobile readiness screen displays real timing and creates zero attempts', 'passed': True})
            button(student, 'ابدأ المحاولة الآن').click()
            wait_text(student, 'الإجابات المؤكدة')
            assert sandbox.query('SELECT count(*) AS n FROM quiz_attempts')[0]['n'] == 1
            checks.append({'check': 'Explicit start creates exactly one attempt', 'passed': True})
            assert not sandbox.browser_errors
    result = {'checks': checks, 'isolated_database_cleaned': True,
              'camera': 'Simulated video of the doctor-rendered QR; physical phone camera not tested'}
    (ROOT / 'review' / 'priority-workflow-results.json').write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Passed {len(checks)} browser checks; isolated database cleaned')


if __name__ == '__main__':
    main()
