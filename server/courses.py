from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, Field

from core import audit, authorize_offering, fail, principal, scoped_rows

router = APIRouter()


@router.get('/courses')
def courses(request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        if user['role'] == 'doctor':
            condition, params = 'o.doctor_user_id=%s', (user['id'],)
        elif user['role'] == 'ta':
            condition, params = 'EXISTS(SELECT 1 FROM course_sections x WHERE x.offering_id=o.id AND x.ta_user_id=%s)', (user['id'],)
        else:
            condition, params = "EXISTS(SELECT 1 FROM enrollments e JOIN students s ON s.id=e.student_id WHERE e.offering_id=o.id AND s.user_id=%s AND e.state='active')", (user['id'],)
        rows = db.execute('''SELECT o.id,c.id AS course_id,c.code,c.name,c.level,t.name AS term,t.is_archived,
            o.doctor_user_id,u.full_name AS doctor_name FROM course_offerings o
            JOIN courses c ON c.id=o.course_id JOIN academic_terms t ON t.id=o.term_id
            JOIN app_users u ON u.id=o.doctor_user_id WHERE ''' + condition + ' ORDER BY c.code,o.id', params).fetchall()
        for course in rows:
            section_condition = ''
            section_params = [course['id']]
            if user['role'] == 'ta':
                section_condition = ' AND ta_user_id=%s'
                section_params.append(user['id'])
            elif user['role'] == 'student':
                section_condition = " AND id IN (SELECT e.course_section_id FROM enrollments e JOIN students s ON s.id=e.student_id WHERE s.user_id=%s AND e.state='active')"
                section_params.append(user['id'])
            course['sections'] = db.execute('''SELECT id,section_number,department_code,ta_user_id,ta_name,student_count
                FROM course_section_directory WHERE offering_id=%s''' + section_condition + ' ORDER BY department_code,section_number,id', section_params).fetchall()
        return rows


@router.get('/courses/{offering_id}/roster')
def roster(offering_id: int, request: Request, section_id: int | None = None, search: str = Query('', max_length=100),
           limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        return scoped_rows(db, user, offering_id, section_id, search, limit, offset)


@router.get('/courses/{offering_id}/assignments')
def assignments(offering_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, staff=True)
        extra, params = (' AND ta_user_id=%s', (offering_id, user['id'])) if user['role'] == 'ta' else ('', (offering_id,))
        return db.execute('SELECT * FROM course_section_directory WHERE offering_id=%s' + extra + ' ORDER BY department_code,section_number', params).fetchall()


class NewCourse(BaseModel):
    code: str = Field(min_length=1, max_length=20)
    name: str = Field(min_length=1, max_length=150)
    department_section_id: int = Field(gt=0)
    ta_user_id: int = Field(gt=0)
    level: int = Field(default=3, ge=1, le=10)


@router.get('/catalog-options')
def catalog_options(request: Request, user=Depends(principal)):
    if user['role'] != 'doctor':
        fail(403, 'هذه العملية خاصة بدكتور المقرر.')
    with request.app.state.db.transaction() as db:
        return {'sections': db.execute('''SELECT ds.id,ds.number,d.code FROM department_sections ds
            JOIN departments d ON d.id=ds.department_id ORDER BY d.code,ds.number''').fetchall(),
            'tas': db.execute("SELECT id,full_name FROM app_users WHERE role='ta' AND is_active ORDER BY full_name").fetchall()}


@router.post('/courses')
def add_course(body: NewCourse, request: Request, user=Depends(principal)):
    if user['role'] != 'doctor':
        fail(403, 'هذه العملية خاصة بدكتور المقرر.')
    with request.app.state.db.transaction() as db:
        section = db.execute('SELECT * FROM department_sections WHERE id=%s', (body.department_section_id,)).fetchone()
        ta = db.execute("SELECT 1 FROM app_users WHERE id=%s AND role='ta' AND is_active", (body.ta_user_id,)).fetchone()
        if not section or not ta:
            fail(422, 'يرجى اختيار سكشن ومعيد صحيحين.')
        term = db.execute('SELECT id FROM academic_terms WHERE NOT is_archived ORDER BY id DESC LIMIT 1').fetchone()
        if not term:
            fail(422, 'لا يوجد فصل دراسي نشط.')
        course_id = db.execute('INSERT INTO courses(code,name,level) VALUES (%s,%s,%s) RETURNING id', (body.code.strip().upper(), body.name.strip(), body.level)).fetchone()['id']
        db.execute('INSERT INTO course_departments(course_id,department_id) VALUES (%s,%s)', (course_id, section['department_id']))
        offering_id = db.execute('INSERT INTO course_offerings(course_id,term_id,doctor_user_id) VALUES (%s,%s,%s) RETURNING id', (course_id, term['id'], user['id'])).fetchone()['id']
        section_id = db.execute('''INSERT INTO course_sections(offering_id,course_id,department_id,department_section_id,ta_user_id)
            VALUES (%s,%s,%s,%s,%s) RETURNING id''', (offering_id, course_id, section['department_id'], section['id'], body.ta_user_id)).fetchone()['id']
        db.execute('''INSERT INTO enrollments(student_id,offering_id,course_section_id)
            SELECT id,%s,%s FROM students WHERE department_section_id=%s AND level=%s''', (offering_id, section_id, section['id'], body.level))
        audit(db, user, offering_id, 'course.create', 'course', course_id, after=body.model_dump())
    return {'id': offering_id}
