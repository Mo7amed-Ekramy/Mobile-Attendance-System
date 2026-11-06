from decimal import Decimal
import json

from fastapi import HTTPException, Request
from psycopg.types.json import Jsonb

from security import token_hash


def fail(status: int, message: str):
    raise HTTPException(status_code=status, detail=message)


def principal(request: Request):
    authorization = request.headers.get('authorization', '')
    if not authorization.startswith('Bearer '):
        fail(401, 'يرجى تسجيل الدخول.')
    with request.app.state.db.transaction() as db:
        user = db.execute('''SELECT u.id, u.username, u.full_name, u.email, u.role
            FROM api_sessions s JOIN app_users u ON u.id=s.user_id
            WHERE s.token_hash=%s AND s.revoked_at IS NULL AND s.expires_at>now() AND u.is_active''',
            (token_hash(authorization[7:]),)).fetchone()
    if not user:
        fail(401, 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.')
    return user


def authorize_offering(db, user, offering_id: int, section_id: int | None = None, *, staff=False, doctor=False):
    offering = db.execute('SELECT * FROM course_offerings WHERE id=%s', (offering_id,)).fetchone()
    if not offering:
        fail(404, 'المقرر غير موجود.')
    if doctor and user['role'] != 'doctor':
        fail(403, 'هذه العملية خاصة بدكتور المقرر.')
    if staff and user['role'] not in ('doctor', 'ta'):
        fail(403, 'هذه العملية خاصة بأعضاء هيئة التدريس.')
    if user['role'] == 'doctor':
        allowed = offering['doctor_user_id'] == user['id']
    elif user['role'] == 'ta':
        allowed = db.execute('SELECT 1 FROM course_sections WHERE offering_id=%s AND ta_user_id=%s', (offering_id, user['id'])).fetchone()
    elif user['role'] == 'student':
        allowed = db.execute('''SELECT 1 FROM enrollments e JOIN students s ON s.id=e.student_id
            WHERE e.offering_id=%s AND s.user_id=%s AND e.state='active' ''', (offering_id, user['id'])).fetchone()
    else:
        allowed = False
    if not allowed:
        fail(403, 'ليس لديك صلاحية الوصول إلى هذا المقرر.')
    if section_id is not None:
        section = db.execute('SELECT * FROM course_sections WHERE id=%s AND offering_id=%s', (section_id, offering_id)).fetchone()
        if not section or (user['role'] == 'ta' and section['ta_user_id'] != user['id']):
            fail(403, 'ليس لديك صلاحية الوصول إلى هذا السكشن.')
        if user['role'] == 'student' and not db.execute('''SELECT 1 FROM enrollments e JOIN students s ON s.id=e.student_id
            WHERE e.course_section_id=%s AND s.user_id=%s AND e.state='active' ''', (section_id, user['id'])).fetchone():
            fail(403, 'أنت غير مسجل في هذا السكشن.')
    return offering


def enrollment(db, user, offering_id):
    row = db.execute('''SELECT e.* FROM enrollments e JOIN students s ON s.id=e.student_id
        WHERE e.offering_id=%s AND s.user_id=%s AND e.state='active' ''', (offering_id, user['id'])).fetchone()
    if not row:
        fail(403, 'أنت غير مسجل في هذا المقرر.')
    return row


def scoped_rows(db, user, offering_id, section_id=None, search='', limit=100, offset=0):
    authorize_offering(db, user, offering_id, section_id, staff=True)
    filters = ['e.offering_id=%s', "e.state='active'"]
    params = [offering_id]
    if user['role'] == 'ta':
        filters.append('cs.ta_user_id=%s')
        params.append(user['id'])
    if section_id is not None:
        filters.append('e.course_section_id=%s')
        params.append(section_id)
    if search:
        filters.append('(u.full_name ILIKE %s OR s.university_id ILIKE %s)')
        params += [f'%{search}%', f'%{search}%']
    joined = '''FROM enrollments e JOIN students s ON s.id=e.student_id
        JOIN app_users u ON u.id=s.user_id JOIN course_sections cs ON cs.id=e.course_section_id
        JOIN department_sections ds ON ds.id=cs.department_section_id JOIN departments d ON d.id=cs.department_id'''
    where = ' WHERE ' + ' AND '.join(filters)
    total = db.execute('SELECT count(*) AS count ' + joined + where, params).fetchone()['count']
    rows = db.execute('''SELECT e.id AS enrollment_id, s.id AS student_id, s.user_id, s.university_id,
        u.full_name, e.course_section_id, ds.number AS section_number, d.code AS department_code '''
        + joined + where + ' ORDER BY u.full_name, e.id LIMIT %s OFFSET %s', params + [limit, offset]).fetchall()
    return {'rows': rows, 'total': total}


def audit(db, user, offering_id, action, entity_type, entity_id, before=None, after=None, reason=None):
    def portable(value):
        return Jsonb(json.loads(json.dumps(value, default=str))) if value is not None else None
    db.execute('''INSERT INTO audit_events(actor_user_id,offering_id,action,entity_type,entity_id,before_data,after_data,reason)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s)''',
        (user['id'], offering_id, action, entity_type, entity_id, portable(before), portable(after), reason))


def notify(db, user_id, offering_id, kind, title, message):
    db.execute('''INSERT INTO notifications(recipient_user_id,offering_id,type,title,message)
        VALUES (%s,%s,%s,%s,%s)''', (user_id, offering_id, kind, title, message))


def money(value):
    return None if value is None else str(Decimal(value).quantize(Decimal('0.01')))
