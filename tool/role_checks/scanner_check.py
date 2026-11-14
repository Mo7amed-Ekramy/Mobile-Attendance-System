"""Exercise scanner layout and actual browser MediaStream cleanup without check-in."""
import json
import sys

from demo_rehearsal import wait_text
from refinement_check import button
from support import ROOT, Sandbox


def main():
    diagnostic = '--diagnostic' in sys.argv
    artifacts = ROOT / ('.dart_tool/scanner-check' if diagnostic else 'screenshots/scanner-fix')
    artifacts.mkdir(parents=True, exist_ok=True)
    checks = []
    with Sandbox('student') as sandbox:
        with sandbox.browser(width=1531, height=715) as page:
            errors = []
            page.on('console', lambda message: errors.append(message.text)
                    if message.type == 'error' and 'status of 422' not in message.text else None)
            sandbox.open_ui(page)
            sandbox.ui_login(page, 'student')
            button(page, 'تحديث البيانات').wait_for()
            page.evaluate('''() => {
                window.scannerStreams = [];
                window.scannerRequests = 0;
                window.delayScannerPermission = false;
                const canvas = document.createElement('canvas');
                canvas.width = canvas.height = 640;
                const ctx = canvas.getContext('2d');
                const paint = () => {ctx.fillStyle = 'white'; ctx.fillRect(0,0,640,640);};
                paint(); setInterval(paint, 100);
                window.unrelatedStream = canvas.captureStream(10);
                navigator.mediaDevices.getUserMedia = async () => {
                    window.scannerRequests++;
                    if (window.delayScannerPermission) {
                        await new Promise(resolve => window.grantScannerPermission = resolve);
                    }
                    const stream = canvas.captureStream(10);
                    window.scannerStreams.push(stream);
                    return stream;
                };
            }''')
            button(page, 'مسح رمز الحضور').click()
            page.wait_for_function('window.scannerStreams.length > 0', timeout=30000)
            page.wait_for_timeout(500)
            button(page, 'إدخال الرمز يدوياً').click()
            page.wait_for_timeout(500)
            page.screenshot(path=str(artifacts / 'manual-desktop.png'))
            (artifacts / 'manual-desktop.txt').write_text(page.locator('body').aria_snapshot(), encoding='utf-8')
            (artifacts / 'console-errors.txt').write_text('\n'.join(errors), encoding='utf-8')
            live_before = page.evaluate("scannerStreams.flatMap(s => s.getTracks()).map(t => t.readyState)")
            button(page, 'رجوع').click()
            button(page, 'تحديث البيانات').wait_for()
            page.wait_for_timeout(700)
            after = page.evaluate("scannerStreams.flatMap(s => s.getTracks()).map(t => t.readyState)")
            print(json.dumps({'console_errors': errors, 'before_exit': live_before, 'after_exit': after}, ensure_ascii=False))
            if not diagnostic:
                assert not errors
                assert live_before and all(state == 'ended' for state in after)
                assert page.evaluate("unrelatedStream.getTracks().every(t => t.readyState === 'live')")
                checks.append({'check': 'Leaving without scanning ends actual owned video tracks and preserves unrelated tracks', 'passed': True})

                # Reopen the same workflow: a new stream must start and the
                # compact manual field must work on desktop and mobile.
                for width, height, label in [(1531, 715, 'desktop'), (400, 900, 'mobile')]:
                    page.set_viewport_size({'width': width, 'height': height})
                    previous = page.evaluate('scannerStreams.length')
                    button(page, 'مسح رمز الحضور').click()
                    page.wait_for_function('(n) => scannerStreams.length > n', arg=previous)
                    button(page, 'إدخال الرمز يدوياً').click()
                    field = page.get_by_role('textbox', name='رمز الحضور', exact=True)
                    field.wait_for()
                    field.click()
                    page.evaluate('() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))')
                    page.keyboard.type('invalid_token', delay=10)
                    page.evaluate('() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))')
                    assert field.bounding_box()['height'] < 110
                    button(page, 'تأكيد الحضور').click()
                    wait_text(page, 'رمز الحضور غير صحيح.')
                    field.click()
                    page.evaluate('() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))')
                    assert field.input_value() == 'invalid_token'
                    page.screenshot(path=str(artifacts / f'manual-{label}.png'))
                    button(page, 'رجوع').click()
                    button(page, 'تحديث البيانات').wait_for()
                    page.wait_for_function("scannerStreams.every(s => s.getTracks().every(t => t.readyState === 'ended'))")
                    checks.append({'check': f'{label}: compact manual entry submits, retains failed input, and camera ends on back', 'passed': True})

                # Leave while browser permission is unresolved, then grant it.
                # The late stream must be stopped even though the route is gone.
                previous = page.evaluate('scannerRequests')
                page.evaluate('window.delayScannerPermission = true')
                button(page, 'مسح رمز الحضور').click()
                page.wait_for_function('(n) => scannerRequests > n', arg=previous)
                button(page, 'رجوع').click()
                button(page, 'تحديث البيانات').wait_for()
                page.evaluate('window.grantScannerPermission()')
                page.wait_for_function("scannerStreams.length > 3 && scannerStreams.every(s => s.getTracks().every(t => t.readyState === 'ended'))")
                assert not errors, errors
                checks.append({'check': 'Permission granted after route exit cannot leave a live camera stream', 'passed': True})
                page.evaluate('window.delayScannerPermission = false')
                previous = page.evaluate('scannerStreams.length')
                button(page, 'مسح رمز الحضور').click()
                try:
                    page.wait_for_function('(n) => scannerStreams.length > n && scannerStreams.at(-1).getTracks().every(t => t.readyState === "live")', arg=previous)
                except Exception:
                    (artifacts / 'reopen-failure.txt').write_text(page.locator('body').aria_snapshot(), encoding='utf-8')
                    print(page.evaluate('({requests: scannerRequests, streams: scannerStreams.map(s => s.getTracks().map(t => t.readyState)), delay: delayScannerPermission})'))
                    raise
                button(page, 'رجوع').click()
                button(page, 'تحديث البيانات').wait_for()
                page.wait_for_function("scannerStreams.every(s => s.getTracks().every(t => t.readyState === 'ended'))")
                checks.append({'check': 'Scanner can reopen normally after cancelling a pending camera permission request', 'passed': True})

    if not diagnostic:
        (ROOT / 'review/scanner-fix-results.json').write_text(json.dumps({
            'checks': checks, 'isolated_database_cleaned': True,
            'camera': 'Real browser MediaStream tracks from simulated video; physical device not used',
        }, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(f'Passed {len(checks)} scanner regression checks')


if __name__ == '__main__':
    main()
