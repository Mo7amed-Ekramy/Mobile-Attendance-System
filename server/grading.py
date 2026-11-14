from decimal import Decimal
import hashlib
import json
from typing import Literal

from fastapi import APIRouter, Depends, Query, Request
from pydantic import BaseModel, Field

from core import audit, authorize_offering, enrollment, fail, money, notify, principal, scoped_rows

router = APIRouter()


def current_policy(db, offering_id, student=False):
    row = db.execute('SELECT * FROM grading_policies WHERE offering_id=%s' + (" AND state='published'" if student else '') + ' ORDER BY version DESC LIMIT 1', (offering_id,)).fetchone()
    if row:
        row['total_points'] = money(row['total_points'])
        row['categories'] = db.execute('SELECT * FROM grade_categories WHERE policy_id=%s ORDER BY position,id', (row['id'],)).fetchall()
        for category in row['categories']:
            category['max_points'] = money(category['max_points'])
    return row


def section_allocations(db, offering_id, category_id):
    """Count shared assessments once in each section that receives them."""
    return db.execute('''SELECT cs.id,COALESCE(sum(a.max_points),0) AS total
        FROM course_sections cs LEFT JOIN assessments a ON a.category_id=%s
        AND (a.course_section_id IS NULL OR a.course_section_id=cs.id)
        AND NOT EXISTS(SELECT 1 FROM quizzes q WHERE q.assessment_id=a.id AND q.state='cancelled')
        WHERE cs.offering_id=%s GROUP BY cs.id ORDER BY cs.id''',
        (category_id, offering_id)).fetchall()


@router.get('/courses/{offering_id}/policy')
def policy(offering_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id)
        return current_policy(db, offering_id, user['role'] == 'student')


class Category(BaseModel):
    code: str = Field(min_length=1, max_length=50)
    name: str = Field(min_length=1, max_length=150)
    kind: Literal['assessment', 'lecture_attendance', 'section_attendance']
    max_points: Decimal = Field(ge=0, le=1000, max_digits=9, decimal_places=2, allow_inf_nan=False)
    allocation_mode: Literal['fixed', 'normalized', 'proportional']


class PolicyDraft(BaseModel):
    total_points: Decimal = Field(gt=0, le=1000, max_digits=9, decimal_places=2, allow_inf_nan=False)
    categories: list[Category] = Field(min_length=1, max_length=20)


@router.put('/courses/{offering_id}/policy')
def save_policy(offering_id: int, body: PolicyDraft, request: Request, user=Depends(principal)):
    if len({c.code for c in body.categories}) != len(body.categories):
        fail(422, 'رموز بنود التقييم يجب أن تكون مختلفة.')
    for category in body.categories:
        if (category.kind == 'assessment') == (category.allocation_mode == 'proportional'):
            fail(422, 'اختر طريقة توزيع مناسبة لبند التقييم.')
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, doctor=True)
        db.execute('SELECT id FROM course_offerings WHERE id=%s FOR UPDATE', (offering_id,))
        existing = current_policy(db, offering_id)
        if existing and existing['state'] != 'draft':
            fail(409, 'اللائحة المنشورة مقفلة. لا يمكن تعديلها مباشرة.')
        if existing:
            policy_id = existing['id']
            for category in body.categories:
                if db.execute('''SELECT 1 FROM grade_categories c JOIN assessments a ON a.category_id=c.id
                    WHERE c.policy_id=%s AND c.code=%s AND c.kind<>%s LIMIT 1''',
                    (policy_id, category.code, category.kind)).fetchone():
                    fail(422, 'لا يمكن تغيير نوع بند يحتوي على تقييمات.')
            db.execute('UPDATE grading_policies SET total_points=%s WHERE id=%s', (body.total_points, policy_id))
            codes = [category.code for category in body.categories]
            if db.execute('''SELECT 1 FROM assessments a JOIN grade_categories c ON c.id=a.category_id
                WHERE c.policy_id=%s AND NOT(c.code=ANY(%s)) LIMIT 1''', (policy_id, codes)).fetchone():
                fail(422, 'لا يمكن حذف بند يحتوي على تقييمات.')
            db.execute('DELETE FROM grade_categories WHERE policy_id=%s AND NOT(code=ANY(%s))', (policy_id, codes))
            # Avoid transient unique-position conflicts during a reorder.
            db.execute('UPDATE grade_categories SET position=position+1000 WHERE policy_id=%s', (policy_id,))
        else:
            policy_id = db.execute('INSERT INTO grading_policies(offering_id,version,total_points) VALUES (%s,1,%s) RETURNING id', (offering_id, body.total_points)).fetchone()['id']
        for position, category in enumerate(body.categories):
            db.execute('''INSERT INTO grade_categories(policy_id,offering_id,code,name,kind,max_points,allocation_mode,position)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT(policy_id,code) DO UPDATE SET
                name=EXCLUDED.name,kind=EXCLUDED.kind,max_points=EXCLUDED.max_points,allocation_mode=EXCLUDED.allocation_mode,position=EXCLUDED.position''',
                (policy_id, offering_id, category.code, category.name, category.kind, category.max_points, category.allocation_mode, position))
        audit(db, user, offering_id, 'policy.save', 'policy', policy_id, before=existing, after=body.model_dump())
        return current_policy(db, offering_id)


@router.post('/courses/{offering_id}/policy/publish')
def publish_policy(offering_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, doctor=True)
        db.execute('SELECT id FROM course_offerings WHERE id=%s FOR UPDATE', (offering_id,))
        value = current_policy(db, offering_id)
        if not value:
            fail(422, 'أنشئ مسودة اللائحة أولاً.')
        if value['state'] == 'published':
            return value
        total = sum(Decimal(c['max_points']) for c in value['categories'])
        if total != Decimal(value['total_points']):
            fail(422, f"المجموع الموزع {total} لا يساوي {value['total_points']}.")
        for category in value['categories']:
            items = db.execute('SELECT COALESCE(sum(max_points),0) AS total,count(*) AS count FROM assessments WHERE category_id=%s', (category['id'],)).fetchone()
            if category['kind'] == 'assessment' and Decimal(category['max_points']) > 0:
                if category['allocation_mode'] == 'fixed':
                    allocations = section_allocations(db, offering_id, category['id'])
                    if not allocations or any(row['total'] != Decimal(category['max_points']) for row in allocations):
                        fail(422, f"درجات التقييمات داخل {category['name']} يجب أن تساوي {category['max_points']} لكل سكشن.")
                if category['allocation_mode'] == 'normalized' and not items['count']:
                    fail(422, f"أضف تقييماً داخل {category['name']} أولاً.")
        db.execute("UPDATE grading_policies SET state='published',published_at=now() WHERE id=%s", (value['id'],))
        audit(db, user, offering_id, 'policy.publish', 'policy', value['id'], after=value)
        return current_policy(db, offering_id)


def assessment_scope(db, user, offering_id, assessment_id):
    authorize_offering(db, user, offering_id, staff=True)
    row = db.execute('SELECT * FROM assessments WHERE id=%s AND offering_id=%s', (assessment_id, offering_id)).fetchone()
    if not row:
        fail(404, 'التقييم غير موجود.')
    if db.execute("SELECT 1 FROM quizzes WHERE assessment_id=%s AND state='cancelled'", (assessment_id,)).fetchone():
        fail(409, 'لا يمكن تعديل أو نشر تقييم كويز ملغى.')
    if row['course_section_id'] is not None:
        authorize_offering(db, user, offering_id, row['course_section_id'], staff=True)
    return row


class AssessmentDraft(BaseModel):
    section_id: int | None = Field(default=None, gt=0)
    category_id: int = Field(gt=0)
    title: str = Field(min_length=1, max_length=150)
    kind: Literal['quiz', 'project', 'assignment', 'midterm', 'final']
    max_points: Decimal = Field(gt=0, le=1000, max_digits=9, decimal_places=2, allow_inf_nan=False)


def create_assessment(db, user, offering_id, body):
    authorize_offering(db, user, offering_id, body.section_id, staff=True)
    if user['role'] == 'ta' and body.kind in ('midterm', 'final'):
        fail(403, 'تقييمات الميدتيرم والفاينال خاصة بدكتور المقرر. المعيد مسؤول عن أعمال السكشن فقط.')
    if user['role'] == 'ta' and body.section_id is None:
        fail(422, 'اختر السكشن الخاص بهذا التقييم.')
    db.execute('SELECT id FROM course_offerings WHERE id=%s FOR UPDATE', (offering_id,))
    category = db.execute('SELECT * FROM grade_categories WHERE id=%s AND offering_id=%s', (body.category_id, offering_id)).fetchone()
    if not category or category['kind'] != 'assessment':
        fail(422, 'يرجى اختيار بند تقييم من لائحة المقرر.')
    if category['allocation_mode'] == 'fixed':
        allocations = section_allocations(db, offering_id, category['id'])
        applicable = [row for row in allocations if body.section_id is None or row['id'] == body.section_id]
        if any(row['total'] + body.max_points > category['max_points'] for row in applicable):
            fail(422, 'درجات التقييم تتجاوز المخصص لهذا البند.')
    row = db.execute('INSERT INTO assessments(offering_id,category_id,title,kind,max_points,created_by,course_section_id) VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING *',
        (offering_id, body.category_id, body.title.strip(), body.kind, body.max_points, user['id'], body.section_id)).fetchone()
    audit(db, user, offering_id, 'assessment.create', 'assessment', row['id'], after=row)
    return row


@router.post('/courses/{offering_id}/assessments')
def new_assessment(offering_id: int, body: AssessmentDraft, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, staff=True)
        return create_assessment(db, user, offering_id, body)


@router.get('/courses/{offering_id}/assessments')
def assessments(offering_id: int, request: Request, section_id: int | None = None, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, section_id)
        if user['role'] == 'student':
            own = enrollment(db, user, offering_id)
            return db.execute('''SELECT a.id,a.title,a.kind,a.max_points,c.name AS category,p.score,p.state,p.published_at
                FROM assessments a JOIN grade_categories c ON c.id=a.category_id JOIN grading_policies gp ON gp.id=c.policy_id
                LEFT JOIN assessment_results r ON r.assessment_id=a.id AND r.enrollment_id=%s
                LEFT JOIN published_results p ON p.result_id=r.id WHERE a.offering_id=%s AND a.published_at IS NOT NULL
                AND gp.state='published' AND (a.course_section_id IS NULL OR a.course_section_id=%s)
                AND NOT EXISTS(SELECT 1 FROM quizzes q WHERE q.assessment_id=a.id AND q.state='cancelled')
                ORDER BY a.id''', (own['id'], offering_id, own['course_section_id'])).fetchall()
        query = '''SELECT a.*,c.name AS category FROM assessments a JOIN grade_categories c ON c.id=a.category_id WHERE a.offering_id=%s
            AND NOT EXISTS(SELECT 1 FROM quizzes q WHERE q.assessment_id=a.id AND q.state='cancelled')'''
        params = [offering_id]
        if section_id is not None:
            query += ' AND (a.course_section_id IS NULL OR a.course_section_id=%s)'
            params.append(section_id)
        if user['role'] == 'ta':
            query += " AND a.kind NOT IN ('midterm','final')"
            query += ' AND (a.course_section_id IS NULL OR a.course_section_id IN (SELECT id FROM course_sections WHERE ta_user_id=%s))'
            params.append(user['id'])
        return db.execute(query + ' ORDER BY a.id', params).fetchall()


def result_editing_error(db, user, assessment):
    if user['role'] == 'ta' and assessment['kind'] in ('midterm', 'final'):
        return 403, 'رصد درجات الميدتيرم والفاينال خاص بدكتور المقرر.'
    quiz = db.execute('SELECT state FROM quizzes WHERE assessment_id=%s', (assessment['id'],)).fetchone()
    if quiz and quiz['state'] != 'closed':
        return 409, 'التصحيح الإلكتروني تلقائي. يمكن تعديل النتائج ونشرها بعد إغلاق الكويز فقط.'
    return None


def require_result_editing(db, user, assessment):
    error = result_editing_error(db, user, assessment)
    if error:
        fail(*error)


@router.get('/courses/{offering_id}/assessments/{assessment_id}/results')
def gradebook(offering_id: int, assessment_id: int, request: Request, section_id: int | None = None,
              limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        assessment = assessment_scope(db, user, offering_id, assessment_id)
        if assessment['course_section_id'] is not None:
            if section_id is not None and section_id != assessment['course_section_id']:
                fail(403, 'هذا التقييم مخصص لسكشن مختلف.')
            section_id = assessment['course_section_id']
        result = scoped_rows(db, user, offering_id, section_id, limit=limit, offset=offset)
        for row in result['rows']:
            record = db.execute('SELECT id,score,state,visibility,revision FROM assessment_results WHERE assessment_id=%s AND enrollment_id=%s', (assessment_id, row['enrollment_id'])).fetchone()
            row.update(record or {'score': None, 'state': 'unrecorded', 'visibility': 'draft', 'revision': 0})
            row['score'] = money(row['score'])
        error = result_editing_error(db, user, assessment)
        return result | {'assessment': assessment, 'editable': error is None,
                         'editing_unavailable_reason': error[1] if error else None}


class ResultRow(BaseModel):
    enrollment_id: int = Field(gt=0)
    score: Decimal | None = Field(default=None, ge=0, max_digits=9, decimal_places=2, allow_inf_nan=False)
    state: Literal['unrecorded', 'recorded', 'excused']
    revision: int = Field(ge=0)


class ResultBatch(BaseModel):
    rows: list[ResultRow] = Field(min_length=1, max_length=100)
    reason: str | None = Field(default=None, max_length=500)


@router.patch('/courses/{offering_id}/assessments/{assessment_id}/results')
def save_results(offering_id: int, assessment_id: int, body: ResultBatch, request: Request, user=Depends(principal)):
    if len({r.enrollment_id for r in body.rows}) != len(body.rows):
        fail(422, 'لا يمكن تكرار الطالب في نفس الطلب.')
    with request.app.state.db.transaction() as db:
        assessment = assessment_scope(db, user, offering_id, assessment_id)
        db.execute('SELECT id FROM course_offerings WHERE id=%s FOR UPDATE', (offering_id,))
        require_result_editing(db, user, assessment)
        for row in body.rows:
            own = db.execute("SELECT * FROM enrollments WHERE id=%s AND offering_id=%s AND state='active'", (row.enrollment_id, offering_id)).fetchone()
            if not own:
                fail(403, 'الطالب غير مسجل في هذا المقرر.')
            if assessment['course_section_id'] is not None and own['course_section_id'] != assessment['course_section_id']:
                fail(403, 'الطالب غير مسجل في سكشن هذا التقييم.')
            authorize_offering(db, user, offering_id, own['course_section_id'], staff=True)
            if (row.state == 'recorded') != (row.score is not None) or (row.score is not None and row.score > assessment['max_points']):
                fail(422, 'راجع حالة النتيجة والدرجة العظمى.')
            old = db.execute('SELECT * FROM assessment_results WHERE assessment_id=%s AND enrollment_id=%s FOR UPDATE', (assessment_id, row.enrollment_id)).fetchone()
            if row.revision != (old['revision'] if old else 0):
                fail(409, 'تغيرت الدرجات. يرجى تحديث الصفحة قبل الحفظ.')
            has_pub = db.execute('SELECT 1 FROM published_results WHERE result_id=%s', (old['id'],)).fetchone() if old else None
            if (old and (old['visibility'] == 'published' or has_pub)) and not (body.reason or '').strip():
                fail(422, 'تعديل درجة منشورة يتطلب سبباً للتصحيح.')
            saved = db.execute('''INSERT INTO assessment_results(assessment_id,enrollment_id,offering_id,score,state,revision,visibility)
                VALUES (%s,%s,%s,%s,%s,1,'draft') ON CONFLICT(assessment_id,enrollment_id) DO UPDATE SET
                score=EXCLUDED.score,state=EXCLUDED.state,visibility='draft',revision=assessment_results.revision+1,updated_at=now()
                WHERE assessment_results.revision=%s RETURNING *''',
                (assessment_id, row.enrollment_id, offering_id, row.score, row.state, row.revision)).fetchone()
            if not saved:
                fail(409, 'تغيرت الدرجات. يرجى تحديث الصفحة قبل الحفظ.')
            audit(db, user, offering_id, 'grade.save', 'result', saved['id'], before=old, after=saved, reason=body.reason)
    return {'ok': True, 'count': len(body.rows)}


def publication_preview(db, offering_id, assessment):
    roster = db.execute('''SELECT e.id,r.state,r.revision,r.visibility FROM enrollments e
        LEFT JOIN assessment_results r ON r.enrollment_id=e.id AND r.assessment_id=%s
        WHERE e.offering_id=%s AND e.state='active'
        AND (%s::bigint IS NULL OR e.course_section_id=%s) ORDER BY e.id''',
        (assessment['id'], offering_id, assessment['course_section_id'], assessment['course_section_id'])).fetchall()
    saved = db.execute('''SELECT id,enrollment_id,revision,state,visibility FROM assessment_results
        WHERE assessment_id=%s ORDER BY id''', (assessment['id'],)).fetchall()
    scope = 'جميع سكاشن المقرر'
    if assessment['course_section_id'] is not None:
        section = db.execute('SELECT section_number,department_code FROM course_section_directory WHERE id=%s',
                             (assessment['course_section_id'],)).fetchone()
        scope = f"سكشن {section['section_number']} ({section['department_code']})"
    fingerprint = hashlib.sha256(json.dumps({'roster': roster, 'saved': saved,
        'published_at': assessment['published_at']}, sort_keys=True, default=str).encode()).hexdigest()
    return {'assessment_id': assessment['id'], 'title': assessment['title'], 'scope': scope,
        'eligible': len(roster), 'recorded': sum(r['state'] == 'recorded' for r in roster),
        'excused': sum(r['state'] == 'excused' for r in roster),
        'unrecorded': sum(r['state'] in (None, 'unrecorded') for r in roster),
        'saved_results': len(saved), 'pending_changes': sum(r['visibility'] == 'draft' for r in saved),
        'republication': assessment['published_at'] is not None, 'fingerprint': fingerprint}


@router.get('/courses/{offering_id}/assessments/{assessment_id}/publication-preview')
def preview_publication(offering_id: int, assessment_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, doctor=True)
        db.execute('SELECT id FROM course_offerings WHERE id=%s FOR UPDATE', (offering_id,))
        assessment = assessment_scope(db, user, offering_id, assessment_id)
        require_result_editing(db, user, assessment)
        return publication_preview(db, offering_id, assessment)


class PublicationConfirmation(BaseModel):
    fingerprint: str = Field(min_length=64, max_length=64)


@router.post('/courses/{offering_id}/assessments/{assessment_id}/publish')
def publish_results(offering_id: int, assessment_id: int, request: Request,
                    body: PublicationConfirmation | None = None, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, doctor=True)
        db.execute('SELECT id FROM course_offerings WHERE id=%s FOR UPDATE', (offering_id,))
        assessment = assessment_scope(db, user, offering_id, assessment_id)
        require_result_editing(db, user, assessment)
        if body and body.fingerprint != publication_preview(db, offering_id, assessment)['fingerprint']:
            fail(409, 'تغيرت النتائج بعد المعاينة. افتح مراجعة النشر من جديد.')
        if not current_policy(db, offering_id, student=True):
            fail(422, 'اعتمد لائحة المقرر أولاً.')
        rows = db.execute('SELECT * FROM assessment_results WHERE assessment_id=%s FOR UPDATE', (assessment_id,)).fetchall()
        for row in rows:
            db.execute('''INSERT INTO published_results(result_id,score,state,feedback,published_by)
                VALUES (%s,%s,%s,%s,%s) ON CONFLICT(result_id) DO UPDATE SET score=EXCLUDED.score,state=EXCLUDED.state,
                feedback=EXCLUDED.feedback,published_by=EXCLUDED.published_by,published_at=now()''',
                (row['id'], row['score'], row['state'], row['feedback'], user['id']))
            recipient = db.execute('SELECT s.user_id FROM enrollments e JOIN students s ON s.id=e.student_id WHERE e.id=%s', (row['enrollment_id'],)).fetchone()['user_id']
            notify(db, recipient, offering_id, 'grade_published', 'تم نشر نتيجة تقييم', 'يمكنك مراجعة نتيجتك في صفحة الدرجات.')
        db.execute("UPDATE assessment_results SET visibility='published' WHERE assessment_id=%s", (assessment_id,))
        db.execute('UPDATE assessments SET published_at=now() WHERE id=%s', (assessment_id,))
        audit(db, user, offering_id, 'grade.publish', 'assessment', assessment_id, after={'count': len(rows)})
    return {'ok': True, 'count': len(rows)}


@router.get('/courses/{offering_id}/grades')
def own_grades(offering_id: int, request: Request, user=Depends(principal)):
    if user['role'] != 'student':
        fail(403, 'هذه الصفحة تعرض نتائج الطالب نفسه.')
    with request.app.state.db.transaction() as db:
        own = enrollment(db, user, offering_id)
        return grades_for_enrollment(db, offering_id, own)


def grades_for_enrollment(db, offering_id, own):
    value = current_policy(db, offering_id, student=True)
    if not value:
        return {'policy': None, 'categories': [], 'earned': None, 'official_total': None}
    categories, earned_total, complete = [], Decimal(0), True
    for category in value['categories']:
        maximum = Decimal(category['max_points'])
        earned, ready = None, False
        if maximum == 0:
            earned, ready = Decimal(0), True
        elif category['kind'] != 'assessment':
            kind = 'lecture' if category['kind'] == 'lecture_attendance' else 'section'
            count = db.execute('''SELECT count(*) FILTER(WHERE r.status='present') AS present,
                count(*) FILTER(WHERE r.status IN ('present','absent')) AS eligible
                FROM attendance_records r JOIN attendance_sessions s ON s.id=r.session_id
                WHERE r.enrollment_id=%s AND s.kind=%s AND s.state IN ('closed','finalized')''', (own['id'], kind)).fetchone()
            if count['eligible']:
                earned, ready = maximum * Decimal(count['present']) / Decimal(count['eligible']), True
        else:
            items = db.execute('''SELECT a.max_points,p.score,p.state FROM assessments a
                LEFT JOIN assessment_results r ON r.assessment_id=a.id AND r.enrollment_id=%s
                LEFT JOIN published_results p ON p.result_id=r.id WHERE a.category_id=%s
                AND (a.course_section_id IS NULL OR a.course_section_id=%s)
                    AND NOT EXISTS(SELECT 1 FROM quizzes q WHERE q.assessment_id=a.id AND q.state='cancelled')''', (own['id'], category['id'], own['course_section_id'])).fetchall()
            included = [item for item in items if item['state'] == 'recorded']
            ready = bool(items) and all(item['state'] in ('recorded', 'excused') for item in items)
            if included:
                raw = sum(item['score'] for item in included)
                denominator = sum(item['max_points'] for item in included)
                earned = raw if category['allocation_mode'] == 'fixed' else maximum * raw / denominator
        complete = complete and ready
        if earned is not None:
            earned_total += earned
        categories.append({'id': category['id'], 'name': category['name'], 'max_points': money(maximum), 'earned': money(earned), 'complete': ready})
    return {'policy': value, 'categories': categories, 'earned': money(earned_total), 'official_total': money(earned_total) if complete else None}


@router.get('/courses/{offering_id}/report')
def report(offering_id: int, request: Request, section_id: int | None = None, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        rows = scoped_rows(db, user, offering_id, section_id, limit=100)
        condition, params = 's.offering_id=%s', [offering_id]
        if user['role'] == 'ta':
            condition += ''' AND EXISTS(SELECT 1 FROM session_eligibility x
                JOIN enrollments e ON e.id=x.enrollment_id
                JOIN course_sections cs ON cs.id=e.course_section_id
                WHERE x.session_id=s.id AND cs.ta_user_id=%s)'''
            params.append(user['id'])
        if section_id is not None:
            # BUG-05: include shared lectures (NULL section) alongside section-specific ones.
            condition += ' AND (s.course_section_id=%s OR s.course_section_id IS NULL)'
            params.append(section_id)
        count = db.execute('''SELECT count(*) AS sessions,count(*) FILTER(WHERE state IN ('closed','finalized')) AS finalized
            FROM attendance_sessions s WHERE ''' + condition, params).fetchone()
        return {'students': rows['total'], **count, 'policy': current_policy(db, offering_id)}


@router.get('/courses/{offering_id}/report/students')
def student_report(offering_id: int, request: Request, section_id: int | None = None, user=Depends(principal)):
    """Complete scoped roster with full-history attendance and official published totals."""
    with request.app.state.db.transaction() as db:
        result = scoped_rows(db, user, offering_id, section_id, limit=100000)
        ids = [row['enrollment_id'] for row in result['rows']]
        counts = db.execute("""SELECT r.enrollment_id,s.kind,
            count(*) FILTER(WHERE r.status='present') AS present,
            count(*) FILTER(WHERE r.status='absent') AS absent,
            count(*) FILTER(WHERE r.status='excused') AS excused
            FROM attendance_records r JOIN attendance_sessions s ON s.id=r.session_id
            WHERE r.enrollment_id=ANY(%s) AND s.state IN ('closed','finalized')
            GROUP BY r.enrollment_id,s.kind""", (ids,)).fetchall()
        by_student = {}
        for count in counts:
            eligible = count['present'] + count['absent']
            by_student.setdefault(count['enrollment_id'], {})[count['kind']] = {
                'present': count['present'], 'absent': count['absent'], 'excused': count['excused'],
                'eligible': eligible, 'rate': money(Decimal(100) * count['present'] / eligible) if eligible else None}
        for row in result['rows']:
            row['attendance'] = by_student.get(row['enrollment_id'], {})
            grades = grades_for_enrollment(db, offering_id, {'id': row['enrollment_id'], 'course_section_id': row['course_section_id']})
            row.update({'earned': grades['earned'], 'official_total': grades['official_total'], 'categories': grades['categories']})
        return result | {'policy': current_policy(db, offering_id, student=True)}
