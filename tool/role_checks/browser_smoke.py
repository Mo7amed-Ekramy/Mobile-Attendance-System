"""Verify that the role harness can drive the actual Flutter login in Chrome."""
from pathlib import Path
from support import ROOT, Sandbox


def main():
    artifacts = ROOT / '.dart_tool' / 'role-checks'
    artifacts.mkdir(parents=True, exist_ok=True)
    with Sandbox('smoke') as sandbox:
        with sandbox.browser() as page:
            try:
                sandbox.open_ui(page)
            except Exception:
                print('Browser startup errors: ' + '; '.join(sandbox.browser_errors))
                print('Flutter DOM: ' + str(page.evaluate('''() => {
                    const found=[];
                    function walk(root) {
                        for (const e of root.querySelectorAll('*')) {
                            if (e.tagName.toLowerCase().startsWith('flt-') || e.tagName==='FLUTTER-VIEW')
                                found.push({tag:e.tagName,role:e.getAttribute('role'),label:e.getAttribute('aria-label')});
                            if(e.shadowRoot) walk(e.shadowRoot);
                        }
                    }
                    walk(document); return found;
                }''')))
                page.screenshot(path=str(artifacts / 'startup-failure.png'))
                raise
            page.get_by_role('textbox').nth(0).wait_for()
            print('Actual Flutter login rendered; accessibility enabled')
            page.screenshot(path=str(artifacts / 'login-screen.png'))
            sandbox.ui_login(page, 'doctor')
            try:
                page.get_by_role('button', name='تحديث البيانات').first.wait_for()
            except Exception:
                print('API request outcomes: ' + str(sandbox.browser_requests))
                print('Visible button labels: ' + str(page.get_by_role('button').all_text_contents()))
                page.screenshot(path=str(artifacts / 'login-result.png'))
                raise
            print('Doctor login through real UI and isolated PostgreSQL API passed')
            page.screenshot(path=str(artifacts / 'doctor-home.png'))
            if sandbox.browser_errors:
                raise AssertionError('Browser errors: ' + '; '.join(sandbox.browser_errors))
    print('Browser smoke passed; isolated database cleaned up')


if __name__ == '__main__':
    main()
