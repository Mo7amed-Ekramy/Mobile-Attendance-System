"""Student persona checks against a unique real PostgreSQL/API/browser sandbox."""
from pathlib import Path
import json
import sys
import re
import time

from support import Sandbox, ROOT
from security import token_hash
import auth

sys.stdout.reconfigure(encoding='utf-8', errors='replace')


RESULTS = []
STATE = {}


def expect(condition, message='Unexpected behavior'):
    if not condition:
        raise AssertionError(message)


def check(name, layer, action):
    try:
        detail = action()
        RESULTS.append({'name': name, 'layer': layer, 'status': 'PASS', 'detail': detail or 'Verified'})
        print('PASS:', name, flush=True)
    except Exception as error:
        detail = str(error).split('Call log:')[0][:600]
        RESULTS.append({'name': name, 'layer': layer, 'status': 'FAIL', 'detail': detail})
        if layer=='Chrome' and STATE.get('page'):
            page=STATE['page']
            diagnostic_dir=ROOT/'.dart_tool'/'role-checks'
            diagnostic_dir.mkdir(parents=True,exist_ok=True)
            data={'name':name,'text':page.locator('body').inner_text(),
                  'roles':page.locator('[role],[aria-label]').evaluate_all('(els)=>els.map(e=>({role:e.getAttribute("role"),label:e.getAttribute("aria-label"),text:e.textContent}))')}
            (diagnostic_dir/f'student-fail-{len(RESULTS)}.json').write_text(json.dumps(data,indent=2,ensure_ascii=False),encoding='utf-8')
        print('FAIL:', name, type(error).__name__, detail[:180], flush=True)


def api_checks(s):
    uid = s.shared['user_id']
    eid = s.shared['enrollment_id']
    identifier, password = s.credentials['student']
    original_username=s.query('SELECT username FROM app_users WHERE id=%s',(uid,))[0]['username']

    def login_status(identifier_value=None, password_value=None, expected=200):
        result = s.login('student', identifier=identifier_value, password=password_value)
        expect(result.status_code == expected, f'Expected HTTP {expected}, got {result.status_code}')
        if expected == 200:
            expect(result.json()['user']['role'] == 'student', 'Wrong role returned')
        return f'HTTP {expected}'

    for name, ident, pw, status in [
        ('login: correct student credentials', identifier, password, 200),
        ('login: wrong password rejected', identifier, 'wrong', 401),
        ('login: unknown identifier rejected', 'unknown_student', password, 401),
        ('login: blank identifier rejected', '', password, 422),
        ('login: blank password rejected', identifier, '', 422),
        ('login: whitespace identifier rejected', '   ', password, 401),
        ('login: whitespace password rejected', identifier, '   ', 401),
        ('login: identifier surrounding whitespace accepted', '  '+identifier+'  ', password, 200),
        ('login: password surrounding whitespace not silently trimmed', identifier, ' '+password+' ', 401),
        ('login: oversized identifier rejected', 'x'*151, password, 422),
        ('login: oversized password rejected', identifier, 'x'*513, 422),
        ('login: SQL-like identifier is not accepted', "' OR 1=1 --", password, 401),
        ('login: another role password is rejected', identifier, 'Doctor@123', 401),
    ]:
        check(name, 'API', lambda i=ident,p=pw,e=status: login_status(i,p,e))

    def alias_login():
        s.query('UPDATE app_users SET username=%s WHERE id=%s', ('Student_Alias', uid))
        try:
            login_status('student_alias', password)
            login_status(identifier, password)
            return 'Case-insensitive username alias and separate university ID both authenticate'
        finally:
            s.query('UPDATE app_users SET username=%s WHERE id=%s', (original_username, uid))
    check('login: username alias/case and university ID both work', 'API', alias_login)
    check('login: actual imported username works separately from university ID', 'API',
          lambda:login_status(original_username,password,200))
    check('login: imported admin blocked from mobile roles', 'API',
          lambda: expect(s.login('admin').status_code == 403, 'Admin role allowed'))
    check('login: unauthenticated request rejected', 'API',
          lambda: s.call('GET','/me',role=None,expected=401))
    check('login: forged bearer rejected', 'API',
          lambda: s.call('GET','/me',role=None,headers={'Authorization':'Bearer forged'},expected=401))

    def inactive():
        token_headers = s.headers('student')
        s.query('UPDATE app_users SET is_active=false WHERE id=%s',(uid,))
        try:
            login_status(identifier,password,401)
            s.call('GET','/me',role=None,headers=token_headers,expected=401)
        finally:
            s.query('UPDATE app_users SET is_active=true WHERE id=%s',(uid,))
            s.tokens.pop('student',None)
        return 'Inactive login and existing session both rejected'
    check('login: deactivated account cannot sign in or keep session', 'API', inactive)

    def expired():
        headers = s.headers('student')
        s.query("UPDATE api_sessions SET expires_at=now()-interval '1 second' WHERE token_hash=%s",(token_hash(s.tokens['student']),))
        s.call('GET','/me',role=None,headers=headers,expected=401)
        s.tokens.pop('student',None)
        return 'HTTP 401 after server expiry'
    check('login: expired session rejected', 'API', expired)

    def logout():
        headers = s.headers('student')
        s.call('POST','/auth/logout',role='student')
        s.call('GET','/me',role=None,headers=headers,expected=401)
        s.tokens.pop('student',None)
        return 'Logout revoked the stored session'
    check('login: logout revokes token and relogin works', 'API', logout)

    def throttle():
        auth.failures.clear()
        for _ in range(10):
            login_status(identifier,'bad-password',401)
        login_status(identifier,password,429)
        auth.failures.clear()  # Only this test process; avoid a five-minute fixture delay.
        login_status(identifier,password,200)
        return '10 failures trigger HTTP 429, even for subsequent correct credentials'
    check('login: repeated failures are throttled', 'API', throttle)

    check('profile: university ID/department/section present', 'API',
          lambda: expect(all(key in s.call('GET','/me',role='student') for key in ('university_id','department','section_number'))))

    def courses():
        rows=s.call('GET','/courses',role='student')
        expect(len(rows)==6,'Unexpected imported student course count')
        expect(all(len(row['sections'])==1 for row in rows),'Student exposed another section')
        STATE['courses']=rows
        unassigned=s.query('SELECT id FROM course_offerings WHERE id NOT IN (SELECT offering_id FROM enrollments WHERE student_id=%s)',(s.shared['student_id'],))[0]['id']
        s.call('GET',f'/courses/{unassigned}/policy',role='student',expected=403)
        s.call('GET','/courses/1/policy?section_id=2',role='student')  # Policy is intentionally offering-wide.
        return '6 enrolled offerings, one own section each; unassigned course denied'
    check('courses: actual enrollment and section isolation', 'API', courses)
    for path in ('/courses/1/roster','/courses/1/questions','/courses/1/assignments','/courses/1/report','/catalog-options'):
        check('permissions: student denied '+path,'API',lambda p=path:s.call('GET',p,role='student',expected=403))
    for path,body in [
        ('/courses/1/sessions',{'kind':'lecture','title':'Forbidden'}),
        ('/courses/1/questions',{'prompt':'Forbidden','options':['a','b'],'correct_index':0}),
        ('/courses',{'code':'Forbidden','name':'Forbidden','department_section_id':1,'ta_user_id':1}),
        ('/courses/1/policy/publish',None),
    ]:
        check('permissions: student cannot write '+path,'API',lambda p=path,b=body:s.call('POST',p,role='student',json=b,expected=403))
    check('grades: no policy gives explicit empty state','API',lambda:expect(s.call('GET','/courses/1/grades',role='student')['policy'] is None))
    check('attendance: no sessions gives empty list','API',lambda:expect(s.call('GET','/courses/1/sessions',role='student')==[]))
    check('quizzes: no quizzes gives empty list','API',lambda:expect(s.call('GET','/courses/1/quizzes',role='student')==[]))
    check('notifications: no events gives empty list','API',lambda:expect(s.call('GET','/notifications',role='student')==[]))

    def lecture(title,section=1):
        return s.call('POST','/courses/1/sessions',json={'kind':'lecture','title':title,'section_id':section,'duration_minutes':30})
    def qr(session):
        return s.call('GET',f"/courses/1/sessions/{session['id']}/qr")['payload']
    def checkin(payload,expected=200):
        return s.call('POST','/attendance/check-ins',role='student',json={'payload':payload},expected=expected)

    STATE['lecture']=lecture('Student checked lecture')
    STATE['qr']=qr(STATE['lecture'])
    check('attendance: valid QR records own attendance','API',lambda:expect(checkin(STATE['qr'])['status']=='present'))
    check('attendance: duplicate QR returns original receipt','API',lambda:expect(checkin(STATE['qr'])['duplicate'] is True))
    for payload in ('invalid_token', 'v2.1.invalidtoken', 'v1.xyz.invalidtoken', 'v1.999999.invalidtoken'):
        status=404 if '999999' in payload else 422
        check('attendance: invalid QR format/session '+payload.split('.')[0],'API',lambda p=payload,e=status:checkin(p,e))
    check('attendance: staff QR endpoint forbidden to student','API',lambda:s.call('GET',f"/courses/1/sessions/{STATE['lecture']['id']}/qr",role='student',expected=403))
    check('attendance: own detail contains no roster','API',lambda:expect('rows' not in s.call('GET',f"/courses/1/sessions/{STATE['lecture']['id']}",role='student')))
    other=lecture('Wrong section',2)
    check('attendance: QR for another section rejected','API',lambda:checkin(qr(other),403))
    check('attendance: another section detail rejected','API',lambda:s.call('GET',f"/courses/1/sessions/{other['id']}",role='student',expected=403))
    expired_lecture=lecture('Expired QR')
    expired_qr=qr(expired_lecture)
    s.query("UPDATE qr_tokens SET valid_from=now()-interval '1 minute',valid_until=now()-interval '1 second' WHERE session_id=%s",(expired_lecture['id'],))
    check('attendance: expired QR rejected','API',lambda:checkin(expired_qr,422))
    s.call('POST',f"/courses/1/sessions/{STATE['lecture']['id']}/close")
    check('attendance: closed session QR rejected','API',lambda:checkin(STATE['qr'],409))
    absent=lecture('Absent lecture')
    s.call('POST',f"/courses/1/sessions/{absent['id']}/close")
    check('attendance: closed lecture materializes own absence','API',lambda:expect(s.call('GET',f"/courses/1/sessions/{absent['id']}",role='student')['record']['status']=='absent'))

    section=s.call('POST','/courses/1/sessions',role='ta',json={'kind':'section','title':'Excused section','section_id':1})
    detail=s.call('GET',f"/courses/1/sessions/{section['id']}",role='ta')
    check('attendance: draft section excluded from own list','API',lambda:expect(all(x['id']!=section['id'] for x in s.call('GET','/courses/1/sessions',role='student'))))
    check('attendance: guessed draft section detail is hidden','API',lambda:s.call('GET',f"/courses/1/sessions/{section['id']}",role='student',expected=403))
    rows=[{'enrollment_id':r['enrollment_id'],'status':'excused' if r['enrollment_id']==eid else 'absent'} for r in detail['rows']]
    s.call('POST',f"/courses/1/sessions/{section['id']}/finalize",role='ta',json={'revision':detail['revision'],'rows':rows})
    check('attendance: finalized excuse shown to student','API',lambda:expect(s.call('GET',f"/courses/1/sessions/{section['id']}",role='student')['record']['status']=='excused'))

    def policy_fixture():
        policy=s.call('PUT','/courses/1/policy',json={'total_points':'100','categories':[
            {'code':'quiz','name':'Quizzes','kind':'assessment','max_points':'80','allocation_mode':'normalized'},
            {'code':'lecture','name':'Lecture attendance','kind':'lecture_attendance','max_points':'20','allocation_mode':'proportional'}]})
        STATE['category']=policy['categories'][0]['id']
        STATE['assessment']=s.call('POST','/courses/1/assessments',json={'category_id':STATE['category'],'title':'Zero then correction','kind':'assignment','max_points':'10','section_id':1})
        return 'Doctor prerequisite policy/assessment created through API'
    check('grades: counterpart grading setup','API',policy_fixture)
    check('grades: draft policy and assessments hidden','API',lambda:expect(s.call('GET','/courses/1/policy',role='student') is None and s.call('GET','/courses/1/assessments',role='student')==[]))
    s.call('POST','/courses/1/policy/publish')
    grade_path=f"/courses/1/assessments/{STATE['assessment']['id']}/results"
    check('grades: student cannot see staff gradebook','API',lambda:s.call('GET',grade_path,role='student',expected=403))
    check('grades: student cannot edit grades','API',lambda:s.call('PATCH',grade_path,role='student',json={'rows':[{'enrollment_id':eid,'state':'recorded','score':'10','revision':0}]},expected=403))
    check('grades: missing score leaves official total incomplete','API',lambda:expect(s.call('GET','/courses/1/grades',role='student')['official_total'] is None))
    s.call('PATCH',grade_path,role='ta',json={'rows':[{'enrollment_id':eid,'state':'recorded','score':'0','revision':0}]})
    check('grades: saved unpublished score remains hidden','API',lambda:expect(s.call('GET','/courses/1/assessments',role='student')==[]))
    s.call('POST',f"/courses/1/assessments/{STATE['assessment']['id']}/publish")
    check('grades: published zero remains distinct from missing','API',lambda:expect(float(s.call('GET','/courses/1/assessments',role='student')[0]['score'])==0))
    check('grades: closed lecture attendance gives 50 percent of category','API',lambda:expect(s.call('GET','/courses/1/grades',role='student')['categories'][1]['earned']=='10.00'))
    s.call('PATCH',grade_path,role='ta',json={'reason':'Correct marking','rows':[{'enrollment_id':eid,'state':'recorded','score':'8','revision':1}]})
    check('grades: pending correction retains published zero','API',lambda:expect(float(s.call('GET','/courses/1/assessments',role='student')[0]['score'])==0))
    s.call('POST',f"/courses/1/assessments/{STATE['assessment']['id']}/publish")
    check('grades: republished correction updates own grade','API',lambda:expect(float(s.call('GET','/courses/1/assessments',role='student')[0]['score'])==8))
    s.call('PATCH',grade_path,role='ta',json={'reason':'Approved excuse','rows':[{'enrollment_id':eid,'state':'excused','score':None,'revision':2}]})
    s.call('POST',f"/courses/1/assessments/{STATE['assessment']['id']}/publish")
    check('grades: published excuse is explicit and has no score','API',lambda:expect(s.call('GET','/courses/1/assessments',role='student')[0]['state']=='excused' and s.call('GET','/courses/1/assessments',role='student')[0]['score'] is None))

    for point in (2,3):
        s.call('POST','/courses/1/questions',role='ta',json={'prompt':f'Student question {point}','options':['Correct','Wrong'],'correct_index':0,'points':str(point)})
    def make_quiz(title,section=1):
        return s.call('POST','/courses/1/quizzes',role='doctor',json={'title':title,'section_id':section,'category_id':STATE['category'],'question_count':2,'duration_minutes':20})
    STATE['quiz']=make_quiz('Student practice quiz')
    other_quiz=make_quiz('Other section quiz',2)
    check('quizzes: only own section appears','API',lambda:expect(all(q['course_section_id']==1 for q in s.call('GET','/courses/1/quizzes',role='student'))))
    check('quizzes: another section start forbidden','API',lambda:s.call('POST',f"/quizzes/{other_quiz['id']}/start",role='student',expected=403))
    qid=STATE['quiz']['id']
    attempt=s.call('POST',f'/quizzes/{qid}/start',role='student')
    STATE['attempt']=attempt
    check('quizzes: student response excludes answer keys','API',lambda:expect('is_correct' not in json.dumps(attempt) and attempt['score'] is None))
    answer={'question_id':attempt['questions'][0]['id'],'option_id':attempt['questions'][0]['options'][0]['id']}
    s.call('PATCH',f'/quizzes/{qid}/answers',role='student',json={'answers':[answer]})
    resumed=s.call('POST',f'/quizzes/{qid}/start',role='student')
    check('quizzes: autosave/resume preserves answers/deadline/option order','API',lambda:expect(resumed['answers']==[answer] and resumed['deadline_at']==attempt['deadline_at'] and resumed['questions']==attempt['questions']))
    check('quizzes: unrelated option rejected','API',lambda:s.call('PATCH',f'/quizzes/{qid}/answers',role='student',json={'answers':[{'question_id':answer['question_id'],'option_id':999999}]},expected=422))
    submitted=s.call('POST',f'/quizzes/{qid}/submit',role='student',json={'answers':[answer]})
    check('quizzes: submit locks attempt and hides score until publication','API',lambda:expect(submitted['state']=='submitted' and submitted['score'] is None))
    check('quizzes: saved answers immutable after submission','API',lambda:s.call('PATCH',f'/quizzes/{qid}/answers',role='student',json={'answers':[]},expected=409))
    check('quizzes: repeated submit returns same completed attempt','API',lambda:expect(s.call('POST',f'/quizzes/{qid}/submit',role='student',json={'answers':[]})['id']==attempt['id']))
    s.call('POST',f"/courses/1/assessments/{STATE['quiz']['assessment_id']}/publish")
    check('quizzes: published score visible to own student','API',lambda:expect(s.call('POST',f'/quizzes/{qid}/start',role='student')['score'] is not None))

    late=make_quiz('Expired student attempt')
    late_attempt=s.call('POST',f"/quizzes/{late['id']}/start",role='student')
    correct=s.query('SELECT q.id AS question_id,o.id AS option_id FROM quiz_questions q JOIN quiz_options o ON o.quiz_question_id=q.id WHERE q.quiz_id=%s AND o.is_correct ORDER BY q.id',(late['id'],))
    s.call('PATCH',f"/quizzes/{late['id']}/answers",role='student',json={'answers':correct[:1]})
    s.query("UPDATE quiz_attempts SET started_at=now()-interval '10 minutes',deadline_at=now()-interval '1 second' WHERE id=%s",(late_attempt['id'],))
    check('quizzes: expired autosave rejected','API',lambda:s.call('PATCH',f"/quizzes/{late['id']}/answers",role='student',json={'answers':correct},expected=409))
    def late_submit():
        result=s.call('POST',f"/quizzes/{late['id']}/submit",role='student',json={'answers':correct})
        score=s.query('SELECT score FROM quiz_attempts WHERE id=%s',(late_attempt['id'],))[0]['score']
        expected=s.query('SELECT points FROM quiz_questions WHERE id=%s',(correct[0]['question_id'],))[0]['points']
        expect(result['state']=='timed_out' and score==expected,'Late answers affected score')
        return 'Server scored only the previously autosaved answer'
    check('quizzes: late submit cannot add answers after deadline','API',late_submit)

    abandoned=make_quiz('Abandoned student attempt')
    abandoned_attempt=s.call('POST',f"/quizzes/{abandoned['id']}/start",role='student')
    s.query("UPDATE quiz_attempts SET started_at=now()-interval '10 minutes',deadline_at=now()-interval '1 second' WHERE id=%s",(abandoned_attempt['id'],))
    def abandoned_check():
        s.call('GET','/courses/1/quizzes',role='doctor')
        result=s.query('SELECT state,submitted_at FROM quiz_attempts WHERE id=%s',(abandoned_attempt['id'],))[0]
        expect(result['state']=='timed_out' and result['submitted_at'] is not None,'Expired abandoned attempt remains in_progress')
    check('quizzes: abandoned expired attempt finalizes without reopening','API',abandoned_check)
    closed=make_quiz('Never-started closed quiz')
    s.query("UPDATE quizzes SET starts_at=now()-interval '2 hours',ends_at=now()-interval '1 hour' WHERE id=%s",(closed['id'],))
    check('quizzes: never-started expired quiz rejected','API',lambda:s.call('POST',f"/quizzes/{closed['id']}/start",role='student',expected=409))

    def notifications():
        rows=s.call('GET','/notifications',role='student')
        expect(any(r['type']=='quiz_open' for r in rows) and any(r['type']=='grade_published' for r in rows))
        s.call('POST',f"/notifications/{rows[0]['id']}/read",role='student')
        expect(s.call('GET','/notifications',role='student')[0]['read_at'] is not None)
        other=s.query('SELECT id FROM notifications WHERE recipient_user_id<>%s LIMIT 1',(uid,))[0]['id']
        s.call('POST',f'/notifications/{other}/read',role='student',expected=404)
        return 'Quiz/publication events present; read persisted; another recipient denied'
    check('notifications: scoped events/read state/recipient isolation','API',notifications)
    check('persistence: logout/login retains own published results','API',lambda: (logout(),login_status(identifier,password),expect(s.call('GET','/courses/1/assessments',role='student')!=[])))


def browser_checks(s,login_only=False):
    with s.browser(width=320 if '--narrow-login' in sys.argv else 1280,
                   height=640 if '--narrow-login' in sys.argv else 1000) as page:
        STATE['page']=page
        s.open_ui(page)
        login_trace=[]
        def login_response(response):
            if '/auth/login' not in response.url: return
            body=response.request.post_data_json
            login_trace.append({'status':response.status,
                'student_identifier':body.get('identifier') in ('20720236007','ahmd_1478'),
                'student_password_matches':body.get('password')==s.credentials['student'][1],
                'password_length':len(body.get('password',''))})
            if login_only:
                d=ROOT/'.dart_tool'/'role-checks';d.mkdir(parents=True,exist_ok=True)
                (d/'student-login-redacted-trace.json').write_text(json.dumps(login_trace,indent=2),encoding='utf-8')
        page.on('response',login_response)
        def ui(name, action): check(name,'Chrome',action)
        def text(value):
            page.wait_for_function('(word)=>document.body.innerText.includes(word)',arg=value)
        def click(pattern):
            page.get_by_role('button',name=re.compile(pattern)).first.click()
        def tab(label):
            page.get_by_role('tab',name=label,exact=True).click()
        def back():
            click('رجوع|Back')
        def home():
            for _ in range(5):
                if page.get_by_role('tab',name='المزيد',exact=True).count(): break
                back()
            page.get_by_role('tab',name='المزيد',exact=True).wait_for(state='attached')
        def field_type(field,value):
            field.click()
            field.press('Control+A')
            field.press('Backspace')
            field.press_sequentially(value,delay=10)
        def login_wait(identifier=None,password=None):
            ui_login(s,page,identifier=identifier,password=password)
            page.get_by_role('tab',name='المزيد',exact=True).wait_for(state='attached')
        def logout_ui(confirm=True):
            home();tab('المزيد');click('تسجيل الخروج');text('سيتم إنهاء الجلسة')
            click('^تأكيد$' if confirm else '^إلغاء$')
            if confirm: page.get_by_role('textbox').first.wait_for(state='attached')
        ui('login UI: blank fields display validation',lambda:(click('تسجيل الدخول'),text('أدخل اسم المستخدم أو الرقم الجامعي.'),text('أدخل كلمة المرور.')))
        def password_visibility():
            click('إظهار كلمة المرور')
            page.get_by_role('button',name='إخفاء كلمة المرور',exact=False).wait_for(state='attached')
            click('إخفاء كلمة المرور')
            page.get_by_role('button',name='إظهار كلمة المرور',exact=False).wait_for(state='attached')
        ui('login UI: password show/hide controls work',password_visibility)
        ui('login UI: wrong password shows error and remains signed out',lambda:(ui_login(s,page,password='wrong'),text('اسم المستخدم أو كلمة المرور غير صحيحة.'),expect(page.get_by_role('button',name='تسجيل الدخول',exact=False).count()==1)))
        ui('login UI: university-ID login reaches student tabs',lambda:login_wait())
        ui('login UI: refresh restores secure session',lambda:(page.reload(wait_until='domcontentloaded'),s.enable_semantics(page),page.get_by_role('tab',name='المزيد',exact=True).wait_for(state='attached')))
        if login_only:
            page.wait_for_load_state('networkidle')
            return
        ui('navigation UI: student has five correct destinations',lambda:expect([x.get_attribute('aria-label') for x in page.get_by_role('tab').all()]==['الرئيسية','المقررات','الحضور','الدرجات','المزيد']))
        ui('navigation UI: course search retains text and own records',lambda:(tab('المقررات'),field_type(page.get_by_role('textbox').first,'CS381'),expect(page.get_by_role('textbox').first.input_value()=='CS381'),page.get_by_role('button',name=re.compile('^CS381')).first.wait_for(state='attached')))
        ui('navigation UI: open CS381 course and its own section details',lambda:(click('^CS381'),text('CS381'),text('سكشن 1 (SE)'),back()))
        ui('navigation UI: home respects selected CS381',lambda:(tab('الرئيسية'),text('CS381')))
        def scopes():
            click('^CS381');text('اختيار المقرر والسكشن')
            expect('جميع السكاشن' not in page.locator('body').inner_text(),'Student offered all sections')
            click('سكشن 1 \\(SE\\)')
            text('CS381')
        ui('navigation UI: scope chooser offers only own section',scopes)
        ui('navigation UI: refresh reloads records without signing out',lambda:(click('تحديث'),page.get_by_role('tab',name='المزيد',exact=True).wait_for(state='attached')))

        ui('scanner UI: open scan screen/manual fallback',lambda:(tab('الحضور'),click('^مسح رمز الحضور'),text('مسح رمز حضور المحاضرة'),click('إدخال الرمز يدوياً'),page.get_by_role('textbox').first.wait_for(state='attached')))
        def camera_error():
            text('تعذر فتح الكاميرا')
            return 'Headless Chrome with no physical camera displays the manual-entry fallback'
        ui('scanner UI: unavailable camera gives clear fallback',camera_error)
        ui('scanner UI: invalid manual payload displays server error',lambda:(field_type(page.get_by_role('textbox').first,'invalid_token'),click('تأكيد الحضور'),text('رمز الحضور غير صحيح.')))
        ui('scanner UI: failed submission keeps manual form expanded',lambda:expect(page.get_by_role('textbox').count()>0,'Manual entry panel collapses after failed check-in'))
        def ensure_manual():
            if page.get_by_role('textbox').count()==0: click('إدخال الرمز يدوياً')
            page.get_by_role('textbox').first.wait_for(state='attached')
        def valid_manual():
            ensure_manual()
            session=s.call('POST','/courses/1/sessions',json={'kind':'lecture','title':'Browser attended lecture','section_id':1,'duration_minutes':30})
            STATE['browser_lecture']=session
            payload=s.call('GET',f"/courses/1/sessions/{session['id']}/qr")['payload']
            STATE['browser_qr']=payload
            field_type(page.get_by_role('textbox').first,payload)
            click('تأكيد الحضور');text('تم تسجيل حضورك');click('^تم$')
            result=s.query('SELECT status FROM attendance_records WHERE session_id=%s AND enrollment_id=%s',(session['id'],s.shared['enrollment_id']))[0]
            expect(result['status']=='present')
            return 'Real browser POST persisted own present record in isolated database'
        ui('scanner UI: valid manual QR persists attendance receipt',valid_manual)
        ui('scanner UI: duplicate shows already-recorded receipt',lambda:(ensure_manual(),click('تأكيد الحضور'),text('حضورك مسجل بالفعل'),click('^تم$')))
        def closed_manual():
            ensure_manual()
            s.call('POST',f"/courses/1/sessions/{STATE['browser_lecture']['id']}/close")
            click('تأكيد الحضور');text('جلسة الحضور مغلقة أو انتهت مدتها.')
        ui('scanner UI: closed QR rejects with useful error',closed_manual)
        ui('attendance UI: attendance log percentages and excuses shown',lambda:(back(),tab('الرئيسية'),click('^سجل الحضور'),text('حضور المحاضرات'),text('66.7%'),text('بعذر')))
        ui('attendance UI: own lecture detail excludes staff roster',lambda:(click('^Student checked lecture'),text('حاضر'),expect(page.get_by_role('textbox').count()==0),back(),back()))
        ui('grades UI: published grades and incomplete total visible',lambda:(tab('الدرجات'),text('درجاتي المنشورة'),text('غير مكتمل'),text('بعذر')))
        ui('grades UI: no student assessment editor or publication controls',lambda:expect(page.get_by_role('button',name=re.compile('إضافة تقييم|اعتماد اللائحة|نشر نتائج التقييم')).count()==0))

        STATE['browser_quiz']=s.call('POST','/courses/1/quizzes',json={'title':'Browser student quiz','section_id':1,'category_id':STATE['category'],'question_count':2,'duration_minutes':20})
        ui('quizzes UI: own section quiz listing hides other section',lambda:(click('^كويزات السكشن'),text('Browser student quiz'),expect(page.get_by_role('button',name=re.compile('Other section quiz')).count()==0)))
        ui('quizzes UI: start real attempt and show question timer',lambda:(click('^Browser student quiz'),text('السؤال 1 من 2'),text('الوقت المتبقي')))
        def choose_correct():
            with page.expect_response(lambda r:'/answers' in r.url and r.request.method=='PATCH') as result:
                click('^Correct$')
            expect(result.value.status==200)
        ui('quizzes UI: answer selection autosaves on server',choose_correct)
        ui('quizzes UI: next/previous navigation retains attempt',lambda:(click('^التالي$'),text('السؤال 2 من 2'),click('^السابق$'),text('السؤال 1 من 2'),click('^التالي$'),text('السؤال 2 من 2')))
        ui('quizzes UI: second answer autosaves',choose_correct)
        ui('quizzes UI: submit confirmation and hidden result state',lambda:(click('^تسليم الكويز$'),text('سيتم تسليم الإجابات المحفوظة'),click('^تأكيد$'),text('تم التسليم'),text('في انتظار نشر النتيجة.')))
        def quiz_publication():
            s.call('POST',f"/courses/1/assessments/{STATE['browser_quiz']['assessment_id']}/publish")
            back();click('^Browser student quiz');text('5.00 / 5.00')
            return 'Doctor publication reached the student after reopening completed attempt'
        ui('quizzes UI: publication makes server-scored result visible',quiz_publication)
        ui('quizzes UI: completed attempt has no submit button',lambda:expect(page.get_by_role('button',name='تسليم الكويز',exact=True).count()==0))
        ui('quizzes UI: reopening completed quiz preserves result',lambda:(back(),click('^Browser student quiz'),text('5.00 / 5.00'),back(),back()))
        def browser_timeout():
            quiz=s.call('POST','/courses/1/quizzes',json={'title':'Browser timeout quiz','section_id':1,'category_id':STATE['category'],'question_count':1,'duration_minutes':1})
            # Shorten only this isolated test window to exercise the real browser timer.
            s.query("UPDATE quizzes SET ends_at=now()+interval '12 seconds' WHERE id=%s",(quiz['id'],))
            click('^كويزات السكشن');click('^Browser timeout quiz');text('الوقت المتبقي')
            choose_correct()
            page.wait_for_function("document.body.innerText.includes('تم التسليم')",timeout=25000)
            row=s.query('SELECT state FROM quiz_attempts WHERE quiz_id=%s AND enrollment_id=%s',(quiz['id'],s.shared['enrollment_id']))[0]
            expect(row['state']!='in_progress')
            back();back()
            return 'Real countdown automatically completed the attempt at its short test deadline'
        ui('quizzes UI: countdown automatically submits saved answers',browser_timeout)

        def notification_read():
            home();tab('المزيد');click('^الإشعارات');text('تم نشر نتيجة تقييم')
            with page.expect_response(lambda r:'/notifications/' in r.url and r.request.method=='POST') as result:
                click('^تم نشر نتيجة تقييم')
            expect(result.value.status==200)
            notification_id=int(result.value.url.split('/notifications/')[1].split('/')[0])
            expect(s.query('SELECT read_at FROM notifications WHERE id=%s',(notification_id,))[0]['read_at'] is not None)
            back()
            return 'Read action persisted for the logged-in student recipient'
        ui('notifications UI: open events and mark published result read',notification_read)
        ui('profile UI: student university ID shown',lambda:(home(),tab('المزيد'),text('20720236007')))
        def theme():
            switch=page.get_by_role('switch',name=re.compile('الوضع الداكن'))
            if switch.count()==0: switch=page.get_by_role('checkbox',name=re.compile('الوضع الداكن'))
            before=switch.get_attribute('aria-checked');switch.click()
            page.wait_for_function('(old)=>[...document.querySelectorAll("[role=switch],[role=checkbox]")].some(e=>e.getAttribute("aria-checked")!==old)',arg=before)
            switch.click()
        ui('settings UI: dark mode toggles and resets',theme)
        ui('logout UI: cancel keeps authenticated student',lambda:(logout_ui(False),page.get_by_role('tab',name='المزيد',exact=True).wait_for(state='attached')))
        def offline_refresh():
            def blocked(route): route.abort('failed')
            page.context.route('**/api/v1/**',blocked)
            try:
                click('تحديث');text('تعذر الاتصال بالخادم')
                expect(page.get_by_role('tab',name='المزيد',exact=True).count()==1)
            finally:
                page.context.unroute('**/api/v1/**',blocked)
        ui('network UI: offline refresh displays error without invented data',offline_refresh)
        def logout_revocation():
            home();tab('المزيد');click('تسجيل الخروج');text('سيتم إنهاء الجلسة')
            with page.expect_response(lambda r:'/auth/logout' in r.url) as result:
                click('^تأكيد$')
            expect(result.value.status==200)
            old_authorization=result.value.request.headers.get('authorization')
            page.get_by_role('textbox').first.wait_for(state='attached')
            if old_authorization:
                s.call('GET','/me',role=None,headers={'Authorization':old_authorization},expected=401)
            expect(page.get_by_role('tab').count()==0)
            return 'Logout removed role UI and revoked its actual browser bearer session'
        ui('logout UI: confirm clears student UI and revokes bearer',logout_revocation)
        def offline_login():
            def blocked(route): route.abort('failed')
            page.context.route('**/api/v1/**',blocked)
            try:
                ui_login(s,page);text('تعذر الاتصال بالخادم')
                expect(page.get_by_role('tab').count()==0)
            finally:
                page.context.unroute('**/api/v1/**',blocked)
            return 'Offline login reports connection error and does not authenticate'
        ui('login UI: offline failure stays on sign-in with useful error',offline_login)
        actual_username=s.query('SELECT username FROM app_users WHERE id=%s',(s.shared['user_id'],))[0]['username']
        ui('login UI: actual imported username ahmd_1478 works',lambda:login_wait(identifier=actual_username))
        def session_expiry():
            s.query("UPDATE api_sessions SET expires_at=now()-interval '1 second' WHERE user_id=%s",(s.shared['user_id'],))
            click('تحديث');page.get_by_role('textbox').first.wait_for(state='attached')
            expect(page.get_by_role('tab').count()==0)
            s.tokens.pop('student',None)
            return 'Expired stored session routes back to sign-in and removes role navigation'
        ui('session UI: server expiry clears authenticated navigation',session_expiry)
        ui('session UI: login succeeds after expiry',lambda:login_wait())
        ui('session UI: reload restores after fresh login',lambda:(page.reload(wait_until='domcontentloaded'),s.enable_semantics(page),page.get_by_role('tab',name='المزيد',exact=True).wait_for(state='attached')))
        def account_switch():
            logout_ui(True)
            user,password=s.credentials['doctor']
            ui_login(s,page,identifier=user,password=password)
            page.get_by_role('tab',name='الحضور',exact=True).wait_for(state='attached')
            text('لوحة متابعة المقرر')
            logout_ui(True)
            login_wait()
            text('يومي الدراسي')
            return 'Student→doctor→student switching renders each correct role and clears prior scope'
        ui('login UI: switching accounts cannot retain previous role tabs',account_switch)
        ui('browser UI: no uncaught application exceptions',lambda:expect(not s.browser_errors,f'{len(s.browser_errors)} browser errors'))
        diagnostic_dir=ROOT/'.dart_tool'/'role-checks'
        diagnostic_dir.mkdir(parents=True,exist_ok=True)
        (diagnostic_dir/'student-browser-text.txt').write_text(page.locator('body').inner_text(),encoding='utf-8')
        print('BROWSER_ERRORS:',len(s.browser_errors),flush=True)


def ui_login(s,page,identifier=None,password=None):
    normal_identifier,normal_password=s.credentials['student']
    for label,value in (
        ('اسم المستخدم أو الرقم الجامعي',normal_identifier if identifier is None else identifier),
        ('كلمة المرور',normal_password if password is None else password),
    ):
        page.locator(f'input[aria-label="{label}"]').last.click()
        # Flutter transfers editing focus from the semantics proxy on a frame.
        page.evaluate('()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
        page.keyboard.press('Control+A')
        page.keyboard.press('Backspace')
        page.evaluate('()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
        page.keyboard.type(value,delay=15)
        page.evaluate('()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
    page.get_by_role('button',name='تسجيل الدخول',exact=False).first.click()


def history_checks(s):
    def verify_history():
        # Counterpart doctor actions produce real history only in this sandbox.
        for number in range(100):
            session=s.call('POST','/courses/1/sessions',json={'kind':'lecture','title':f'History lecture {number}','section_id':1,'duration_minutes':30})
            payload=s.call('GET',f"/courses/1/sessions/{session['id']}/qr")['payload']
            s.call('POST','/attendance/check-ins',role='student',json={'payload':payload})
            s.call('POST',f"/courses/1/sessions/{session['id']}/close")
        returned=s.call('GET','/courses/1/sessions',role='student')
        finalized=[r for r in returned if r['kind']=='lecture' and r['state'] in ('closed','finalized') and r['own_status'] in ('present','absent')]
        ui_rate=sum(r['own_status']=='present' for r in finalized)/len(finalized)
        actual=s.query("""SELECT count(*) FILTER(WHERE r.status='present') AS present,count(*) AS eligible
            FROM attendance_records r JOIN attendance_sessions a ON a.id=r.session_id
            WHERE r.enrollment_id=%s AND a.kind='lecture' AND a.state IN ('closed','finalized')
            AND r.status IN ('present','absent')""",(s.shared['enrollment_id'],))[0]
        actual_rate=actual['present']/actual['eligible']
        expect(abs(ui_rate-actual_rate)<.00001,
               f"API returns only {len(returned)} sessions; UI rate {ui_rate:.4%}, complete history {actual_rate:.4%} ({actual['eligible']} eligible)")
        return 'History percentage matches complete finalized history'
    check('attendance history: percentage covers more than 100 sessions','API/Flutter calculation',verify_history)


def main():
    (ROOT/'review').mkdir(exist_ok=True)
    try:
        with Sandbox('student') as s:
            print('Student sandbox ready; real application database is not used.',flush=True)
            if '--ui-login-only' in sys.argv:
                browser_checks(s,login_only=True)
                return
            if '--ui-diagnostic' in sys.argv:
                with s.browser() as page:
                    s.open_ui(page)
                    observed=[]
                    page.on('response',lambda response:observed.append({'path':response.url.split('/api/v1')[-1],'status':response.status}) if '/api/v1' in response.url else None)
                    ui_login(s,page)
                    try:
                        page.wait_for_function("document.body.innerText.includes('مرحباً')",timeout=6000)
                    except Exception:
                        pass
                    roles=page.locator('[role], [aria-label]').evaluate_all('(els)=>els.map(e=>({tag:e.tagName,role:e.getAttribute("role"),label:e.getAttribute("aria-label"),text:e.textContent}))')
                    diagnostic_dir=ROOT/'.dart_tool'/'role-checks'
                    diagnostic_dir.mkdir(parents=True,exist_ok=True)
                    (diagnostic_dir/'student-ui-semantics.json').write_text(json.dumps({'roles':roles,'responses':observed,'text':page.locator('body').inner_text()},ensure_ascii=False,indent=2),encoding='utf-8')
                    print('Student browser semantics diagnostic captured.',flush=True)
                return
            api_checks(s)
            if '--api-only' not in sys.argv:
                browser_checks(s)
            history_checks(s)
    finally:
        if '--ui-diagnostic' not in sys.argv:
            name=('student-login-narrow-results.json' if '--narrow-login' in sys.argv else
                  'student-login-ui-results.json' if '--ui-login-only' in sys.argv else 'student-role-results.json')
            (ROOT/'review'/name).write_text(json.dumps(RESULTS,indent=2,ensure_ascii=False,default=str),encoding='utf-8')
        print('RESULTS:',sum(r['status']=='PASS' for r in RESULTS),'passed;',sum(r['status']=='FAIL' for r in RESULTS),'failed',flush=True)


if __name__=='__main__':
    main()
