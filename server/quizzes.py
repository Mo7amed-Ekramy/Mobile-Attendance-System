from datetime import datetime, timedelta, timezone
from decimal import Decimal
import random
import secrets

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from core import audit, authorize_offering, enrollment, fail, money, notify, principal
from grading import AssessmentDraft, create_assessment

router = APIRouter()


def expire_stale_attempts(db, user_ctx=None, offering_id=None):
    """BUG-03: Finalize any in_progress attempts whose deadline has already passed.
    user_ctx may be None when called from a background/admin sweep.
    Returns the number of attempts finalized."""
    stale = db.execute('''
        SELECT t.*, q.assessment_id, q.offering_id AS quiz_offering_id
        FROM quiz_attempts t
        JOIN quizzes q ON q.id=t.quiz_id
        WHERE t.state='in_progress' AND t.deadline_at <= now()
        AND (%s::bigint IS NULL OR q.offering_id=%s)
        FOR UPDATE OF t SKIP LOCKED
    ''', (offering_id, offering_id)).fetchall()
    for attempt in stale:
        quiz = db.execute(
            'SELECT q.*,a.title,a.max_points FROM quizzes q JOIN assessments a ON a.id=q.assessment_id WHERE q.id=%s',
            (attempt['quiz_id'],)).fetchone()
        # Synthesize a minimal user context so audit records are accurate.
        actor = db.execute('''SELECT s.user_id AS id FROM enrollments e
            JOIN students s ON s.id=e.student_id WHERE e.id=%s''', (attempt['enrollment_id'],)).fetchone()
        finish_attempt(db, actor, quiz, attempt, timed_out=True)
    return len(stale)


def advance_quiz_lifecycle(db, offering_id=None):
    db.execute("""UPDATE quizzes SET state=CASE WHEN ends_at<=now() THEN 'closed' ELSE 'active' END
        WHERE state IN ('scheduled','active') AND starts_at<=now()
        AND (state='scheduled' OR ends_at<=now())
        AND (%s::bigint IS NULL OR offering_id=%s)""", (offering_id, offering_id))
    return expire_stale_attempts(db, offering_id=offering_id)


class QuestionDraft(BaseModel):
    prompt: str = Field(min_length=1, max_length=3000)
    options: list[str] = Field(min_length=2, max_length=6)
    correct_index: int = Field(ge=0)
    points: Decimal = Field(default=Decimal(1), gt=0, le=100, max_digits=9, decimal_places=2, allow_inf_nan=False)


@router.get('/courses/{offering_id}/questions')
def questions(offering_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, staff=True)
        rows = db.execute('SELECT id,prompt,points FROM questions WHERE offering_id=%s ORDER BY id', (offering_id,)).fetchall()
        for row in rows:
            row['options'] = db.execute('SELECT id,text,is_correct FROM question_options WHERE question_id=%s ORDER BY position', (row['id'],)).fetchall()
        return rows


@router.post('/courses/{offering_id}/questions')
def add_question(offering_id: int, body: QuestionDraft, request: Request, user=Depends(principal)):
    if body.correct_index >= len(body.options) or any(not option.strip() for option in body.options):
        fail(422, 'اكتب جميع الاختيارات وحدد الإجابة الصحيحة.')
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, staff=True)
        bank = db.execute('SELECT id FROM question_banks WHERE offering_id=%s ORDER BY id LIMIT 1', (offering_id,)).fetchone()
        if not bank:
            bank = db.execute('INSERT INTO question_banks(offering_id,title,created_by) VALUES (%s,%s,%s) RETURNING id', (offering_id, 'بنك أسئلة المقرر', user['id'])).fetchone()
        question_id = db.execute('INSERT INTO questions(bank_id,offering_id,prompt,points) VALUES (%s,%s,%s,%s) RETURNING id', (bank['id'], offering_id, body.prompt.strip(), body.points)).fetchone()['id']
        for position, text in enumerate(body.options):
            db.execute('INSERT INTO question_options(question_id,position,text,is_correct) VALUES (%s,%s,%s,%s)', (question_id, position, text.strip(), position == body.correct_index))
        audit(db, user, offering_id, 'question.create', 'question', question_id)
        return {'id': question_id}


class QuizDraft(BaseModel):
    section_id: int = Field(gt=0)
    category_id: int = Field(gt=0)
    title: str = Field(min_length=1, max_length=150)
    question_count: int = Field(ge=1, le=100)
    duration_minutes: int = Field(ge=1, le=120)
    starts_at: datetime | None = None
    prepare_only: bool = False


@router.post('/courses/{offering_id}/quizzes')
def create_quiz(offering_id: int, body: QuizDraft, request: Request, user=Depends(principal)):
    now = datetime.now(timezone.utc)
    if body.starts_at is not None and (body.starts_at.tzinfo is None or body.starts_at <= now):
        fail(422, 'اختر موعداً مستقبلياً للكويز مع المنطقة الزمنية.')
    starts = body.starts_at or now
    state = 'draft' if body.prepare_only else ('scheduled' if body.starts_at else 'active')
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, body.section_id, staff=True)
        pool = db.execute('SELECT * FROM questions WHERE offering_id=%s ORDER BY id', (offering_id,)).fetchall()
        if body.question_count > len(pool):
            fail(422, 'عدد الأسئلة المطلوبة أكبر من بنك الأسئلة.')
        selected = secrets.SystemRandom().sample(pool, body.question_count)
        assessment = create_assessment(db, user, offering_id, AssessmentDraft(section_id=body.section_id, category_id=body.category_id, title=body.title, kind='quiz', max_points=sum(q['points'] for q in selected)))
        quiz = db.execute('''INSERT INTO quizzes(assessment_id,offering_id,course_section_id,duration_minutes,starts_at,ends_at,state)
            VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING *''',
            (assessment['id'], offering_id, body.section_id, body.duration_minutes, starts,
             starts + timedelta(minutes=body.duration_minutes), state)).fetchone()
        for position, question in enumerate(selected):
            snapshot_id = db.execute('INSERT INTO quiz_questions(quiz_id,offering_id,source_question_id,prompt,points,position) VALUES (%s,%s,%s,%s,%s,%s) RETURNING id',
                (quiz['id'], offering_id, question['id'], question['prompt'], question['points'], position)).fetchone()['id']
            db.execute('INSERT INTO quiz_options(quiz_question_id,text,is_correct,position) SELECT %s,text,is_correct,position FROM question_options WHERE question_id=%s', (snapshot_id, question['id']))
        if state != 'draft':
            notify_quiz(db, quiz, 'quiz_scheduled' if state == 'scheduled' else 'quiz_open',
                        'كويز مجدول للسكشن' if state == 'scheduled' else 'كويز جديد للسكشن', body.title)
        audit(db, user, offering_id, 'quiz.' + state, 'quiz', quiz['id'], after=body.model_dump())
        return quiz


def notify_quiz(db, quiz, kind, title, message):
    for student in db.execute("""SELECT s.user_id FROM enrollments e JOIN students s ON s.id=e.student_id
        WHERE e.course_section_id=%s AND e.state='active'""", (quiz['course_section_id'],)):
        notify(db, student['user_id'], quiz['offering_id'], kind, title, str(message))


def staff_quiz(db, user, offering_id, quiz_id):
    quiz = db.execute('SELECT * FROM quizzes WHERE id=%s AND offering_id=%s FOR UPDATE',
                      (quiz_id, offering_id)).fetchone()
    if not quiz:
        fail(404, 'الكويز غير موجود.')
    authorize_offering(db, user, offering_id, quiz['course_section_id'], staff=True)
    return quiz


class LaunchQuiz(BaseModel):
    starts_at: datetime | None = None


@router.post('/courses/{offering_id}/quizzes/{quiz_id}/launch')
def launch_quiz(offering_id: int, quiz_id: int, body: LaunchQuiz, request: Request, user=Depends(principal)):
    now = datetime.now(timezone.utc)
    if body.starts_at is not None and (body.starts_at.tzinfo is None or body.starts_at <= now):
        fail(422, 'اختر موعداً مستقبلياً صحيحاً.')
    with request.app.state.db.transaction() as db:
        quiz = staff_quiz(db, user, offering_id, quiz_id)
        if quiz['state'] != 'draft':
            fail(409, 'يمكن فتح المسودة فقط.')
        starts = body.starts_at or now
        state = 'scheduled' if body.starts_at else 'active'
        quiz = db.execute('''UPDATE quizzes SET state=%s,starts_at=%s,ends_at=%s WHERE id=%s RETURNING *''',
                          (state, starts, starts + timedelta(minutes=quiz['duration_minutes']), quiz_id)).fetchone()
        notify_quiz(db, quiz, 'quiz_open', 'كويز جديد للسكشن', 'تم فتح كويز جديد. راجع صفحة الكويزات.')
        audit(db, user, offering_id, 'quiz.launch', 'quiz', quiz_id, after=quiz)
        return quiz


@router.post('/courses/{offering_id}/quizzes/{quiz_id}/cancel')
def cancel_quiz(offering_id: int, quiz_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        quiz = staff_quiz(db, user, offering_id, quiz_id)
        if quiz['state'] == 'cancelled':
            return {'ok': True}
        if quiz['state'] not in ('draft', 'scheduled', 'active') or db.execute(
                'SELECT 1 FROM quiz_attempts WHERE quiz_id=%s', (quiz_id,)).fetchone():
            fail(409, 'لا يمكن إلغاء كويز بدأ الطلاب حله. استخدم الإغلاق المبكر.')
        db.execute("UPDATE quizzes SET state='cancelled' WHERE id=%s", (quiz_id,))
        if quiz['state'] != 'draft':
            notify_quiz(db, quiz, 'quiz_cancelled', 'تم إلغاء كويز السكشن', 'لن يحتسب الكويز الملغى في الدرجات.')
        audit(db, user, offering_id, 'quiz.cancel', 'quiz', quiz_id)
        return {'ok': True}


@router.post('/courses/{offering_id}/quizzes/{quiz_id}/close')
def close_quiz(offering_id: int, quiz_id: int, request: Request, user=Depends(principal)):
    """ADD-06: Close an active quiz early and auto-finalize any in-progress attempts."""
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, staff=True)
        quiz = db.execute('SELECT * FROM quizzes WHERE id=%s AND offering_id=%s FOR UPDATE', (quiz_id, offering_id)).fetchone()
        if not quiz:
            fail(404, 'الكويز غير موجود.')
        if user['role'] == 'ta':
            # TA can only close quizzes for their own sections.
            authorized = db.execute(
                'SELECT 1 FROM course_sections WHERE id=%s AND ta_user_id=%s',
                (quiz['course_section_id'], user['id'])).fetchone()
            if not authorized:
                fail(403, 'لا يمكنك إغلاق كويز لسكشن لم يُسند إليك.')
        if quiz['state'] == 'closed':
            return {'ok': True, 'finalized': 0}
        if quiz['state'] != 'active':
            fail(409, 'الكويز ليس نشطاً.')
        # Set quiz to closed so no new attempts can start.
        db.execute("UPDATE quizzes SET state='closed',ends_at=GREATEST(now(),starts_at+interval '1 millisecond') WHERE id=%s", (quiz_id,))
        # Auto-finalize any in-progress attempts.
        stale = db.execute(
            "SELECT t.* FROM quiz_attempts t WHERE t.quiz_id=%s AND t.state='in_progress' FOR UPDATE",
            (quiz_id,)).fetchall()
        count = 0
        for attempt in stale:
            q = db.execute('SELECT q.*,a.title,a.max_points FROM quizzes q JOIN assessments a ON a.id=q.assessment_id WHERE q.id=%s', (quiz_id,)).fetchone()
            finish_attempt(db, user, q, attempt, timed_out=True)
            count += 1
        # Notify students.
        for student in db.execute(
                "SELECT s.user_id FROM enrollments e JOIN students s ON s.id=e.student_id WHERE e.course_section_id=%s AND e.state='active'",
                (quiz['course_section_id'],)):
            notify(db, student['user_id'], offering_id, 'quiz_closed', 'تم إغلاق الكويز', str(quiz_id))
        audit(db, user, offering_id, 'quiz.close', 'quiz', quiz_id, after={'finalized': count})
        return {'ok': True, 'finalized': count}



@router.get('/courses/{offering_id}/quizzes')
def quiz_list(offering_id: int, request: Request, section_id: int | None = None, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, section_id)
        advance_quiz_lifecycle(db, offering_id)
        conditions, params = ['q.offering_id=%s'], [offering_id]
        if user['role'] == 'student':
            conditions.append("q.state<>'draft'")
            own = enrollment(db, user, offering_id)
            conditions.append('q.course_section_id=%s')
            params.append(own['course_section_id'])
        elif user['role'] == 'ta':
            conditions.append('cs.ta_user_id=%s')
            params.append(user['id'])
        if section_id is not None:
            conditions.append('q.course_section_id=%s')
            params.append(section_id)
        rows = db.execute('''SELECT q.*,a.title,a.max_points,ds.number AS section_number,d.code AS department_code,
            (SELECT count(*) FROM quiz_attempts t WHERE t.quiz_id=q.id AND t.state<>'in_progress') AS submitted_count
            FROM quizzes q JOIN assessments a ON a.id=q.assessment_id JOIN course_sections cs ON cs.id=q.course_section_id
            JOIN department_sections ds ON ds.id=cs.department_section_id JOIN departments d ON d.id=cs.department_id
            WHERE ''' + ' AND '.join(conditions) + ' ORDER BY q.id DESC', params).fetchall()
        if user['role'] == 'student':
            for row in rows:
                attempt = db.execute('SELECT id,state FROM quiz_attempts WHERE quiz_id=%s AND enrollment_id=%s', (row['id'], own['id'])).fetchone()
                row['attempt'] = attempt
        return rows


def student_quiz(db, user, quiz_id):
    if user['role'] != 'student':
        fail(403, 'حل الكويز متاح للطلاب فقط.')
    quiz = db.execute('SELECT q.*,a.title,a.max_points FROM quizzes q JOIN assessments a ON a.id=q.assessment_id WHERE q.id=%s FOR UPDATE OF q', (quiz_id,)).fetchone()
    if not quiz:
        fail(404, 'الكويز غير موجود.')
    own = enrollment(db, user, quiz['offering_id'])
    if own['course_section_id'] != quiz['course_section_id']:
        fail(403, 'الكويز غير مخصص لسكشنك.')
    if quiz['state'] in ('draft', 'cancelled'):
        fail(409, 'الكويز غير متاح للحل.')
    if quiz['state'] == 'scheduled' and quiz['starts_at'] <= datetime.now(timezone.utc):
        quiz['state'] = 'active'
        db.execute("UPDATE quizzes SET state='active' WHERE id=%s", (quiz_id,))
    return quiz, own


@router.get('/quizzes/{quiz_id}/readiness')
def quiz_readiness(quiz_id: int, request: Request, user=Depends(principal)):
    """Read timing/context without creating an attempt or exposing questions/keys."""
    with request.app.state.db.transaction() as db:
        quiz, own = student_quiz(db, user, quiz_id)
        context = db.execute('''SELECT c.code AS course_code,c.name AS course_name,
            ds.number AS section_number,d.code AS department_code FROM course_offerings o
            JOIN courses c ON c.id=o.course_id JOIN course_sections cs ON cs.id=%s
            JOIN department_sections ds ON ds.id=cs.department_section_id
            JOIN departments d ON d.id=cs.department_id WHERE o.id=%s''',
            (quiz['course_section_id'], quiz['offering_id'])).fetchone()
        attempt = db.execute('SELECT id,state FROM quiz_attempts WHERE quiz_id=%s AND enrollment_id=%s',
                             (quiz_id, own['id'])).fetchone()
        return {key: quiz[key] for key in ('id', 'title', 'offering_id', 'duration_minutes', 'starts_at', 'ends_at', 'state')} | dict(context) | {
            'server_now': datetime.now(timezone.utc), 'attempt': attempt}


def save_answers(db, attempt, answers):
    for answer in answers:
        question = db.execute('SELECT 1 FROM quiz_questions WHERE id=%s AND quiz_id=%s', (answer.question_id, attempt['quiz_id'])).fetchone()
        option = db.execute('SELECT 1 FROM quiz_options WHERE id=%s AND quiz_question_id=%s', (answer.option_id, answer.question_id)).fetchone()
        if not question or not option:
            fail(422, 'الإجابة لا تنتمي إلى أسئلة هذا الكويز.')
        db.execute('''INSERT INTO quiz_answers(attempt_id,quiz_id,quiz_question_id,selected_option_id)
            VALUES (%s,%s,%s,%s) ON CONFLICT(attempt_id,quiz_question_id) DO UPDATE SET selected_option_id=EXCLUDED.selected_option_id''',
            (attempt['id'], attempt['quiz_id'], answer.question_id, answer.option_id))


def finish_attempt(db, user, quiz, attempt, timed_out=False):
    if attempt['state'] != 'in_progress':
        return attempt
    # Serialize automatic grade writes with staff edits/publication previews.
    db.execute('SELECT id FROM course_offerings WHERE id=%s FOR UPDATE', (quiz['offering_id'],))
    score = db.execute('''SELECT COALESCE(sum(CASE WHEN o.is_correct THEN q.points ELSE 0 END),0) AS score
        FROM quiz_questions q LEFT JOIN quiz_answers a ON a.quiz_question_id=q.id AND a.attempt_id=%s
        LEFT JOIN quiz_options o ON o.id=a.selected_option_id WHERE q.quiz_id=%s''', (attempt['id'], quiz['id'])).fetchone()['score']
    db.execute('''UPDATE quiz_answers a SET points_awarded=CASE WHEN o.is_correct THEN q.points ELSE 0 END
        FROM quiz_options o,quiz_questions q WHERE a.selected_option_id=o.id AND q.id=a.quiz_question_id AND a.attempt_id=%s''', (attempt['id'],))
    attempt = db.execute('UPDATE quiz_attempts SET score=%s,state=%s,submitted_at=now() WHERE id=%s RETURNING *',
        (score, 'timed_out' if timed_out else 'submitted', attempt['id'])).fetchone()
    db.execute('''INSERT INTO assessment_results(assessment_id,enrollment_id,offering_id,score,state)
        VALUES (%s,%s,%s,%s,'recorded') ON CONFLICT(assessment_id,enrollment_id) DO UPDATE SET
        score=EXCLUDED.score,state='recorded',visibility='draft',revision=assessment_results.revision+1,updated_at=now()''',
        (quiz['assessment_id'], attempt['enrollment_id'], quiz['offering_id'], score))
    audit(db, user, quiz['offering_id'], 'quiz.submit', 'attempt', attempt['id'], after={'score': money(score), 'timed_out': timed_out})
    return attempt


def attempt_payload(db, quiz, attempt):
    questions = db.execute('SELECT id,prompt,points FROM quiz_questions WHERE quiz_id=%s ORDER BY position', (quiz['id'],)).fetchall()
    randomizer = random.Random(attempt['id'])
    for question in questions:
        # Correctness stays on the server; this endpoint never selects is_correct.
        options = db.execute('SELECT id,text FROM quiz_options WHERE quiz_question_id=%s ORDER BY position', (question['id'],)).fetchall()
        randomizer.shuffle(options)
        question['options'] = options
    answers = db.execute('SELECT quiz_question_id AS question_id,selected_option_id AS option_id FROM quiz_answers WHERE attempt_id=%s', (attempt['id'],)).fetchall()
    published = db.execute('''SELECT p.score FROM published_results p JOIN assessment_results r ON r.id=p.result_id
        WHERE r.assessment_id=%s AND r.enrollment_id=%s''', (quiz['assessment_id'], attempt['enrollment_id'])).fetchone()
    return {'id': attempt['id'], 'quiz_id': quiz['id'], 'title': quiz['title'], 'state': attempt['state'],
        'deadline_at': attempt['deadline_at'], 'server_now': datetime.now(timezone.utc), 'questions': questions,
        'answers': answers, 'score': money(published['score']) if published else None, 'max_points': money(quiz['max_points'])}


@router.post('/quizzes/expire-stale')
def trigger_expire(request: Request, user=Depends(principal)):
    """BUG-03: Admin/cron endpoint - finalize all globally overdue quiz attempts."""
    if user['role'] not in ('doctor', 'ta'):
        fail(403, 'هذه العملية مخصصة للطاقم فقط.')
    with request.app.state.db.transaction() as db:
        offerings = db.execute('SELECT id FROM course_offerings').fetchall()
        count = 0
        for offering in offerings:
            if user['role'] == 'doctor':
                allowed = db.execute('SELECT 1 FROM course_offerings WHERE id=%s AND doctor_user_id=%s', (offering['id'], user['id'])).fetchone()
            else:
                allowed = db.execute('SELECT 1 FROM course_sections WHERE offering_id=%s AND ta_user_id=%s', (offering['id'], user['id'])).fetchone()
            if allowed:
                count += advance_quiz_lifecycle(db, offering['id'])
    return {'ok': True, 'finalized': count}


@router.post('/quizzes/{quiz_id}/start')
def start_quiz(quiz_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        quiz, own = student_quiz(db, user, quiz_id)
        db.execute('SELECT id FROM quizzes WHERE id=%s FOR UPDATE', (quiz_id,))
        attempt = db.execute('SELECT * FROM quiz_attempts WHERE quiz_id=%s AND enrollment_id=%s FOR UPDATE', (quiz_id, own['id'])).fetchone()
        now = datetime.now(timezone.utc)
        if not attempt:
            if quiz['state'] != 'active' or not quiz['starts_at'] <= now < quiz['ends_at']:
                fail(409, 'الكويز مغلق أو انتهت مدته.')
            attempt = db.execute('''INSERT INTO quiz_attempts(quiz_id,enrollment_id,course_section_id,started_at,deadline_at)
                VALUES (%s,%s,%s,%s,%s) RETURNING *''', (quiz_id, own['id'], own['course_section_id'], now,
                    min(quiz['ends_at'], now + timedelta(minutes=quiz['duration_minutes'])))).fetchone()
        if attempt['state'] == 'in_progress' and now >= attempt['deadline_at']:
            attempt = finish_attempt(db, user, quiz, attempt, timed_out=True)
        return attempt_payload(db, quiz, attempt)


class Answer(BaseModel):
    question_id: int = Field(gt=0)
    option_id: int = Field(gt=0)


class Answers(BaseModel):
    answers: list[Answer] = Field(max_length=100)


@router.patch('/quizzes/{quiz_id}/answers')
def autosave(quiz_id: int, body: Answers, request: Request, user=Depends(principal)):
    expired = False
    with request.app.state.db.transaction() as db:
        quiz, own = student_quiz(db, user, quiz_id)
        attempt = db.execute('SELECT * FROM quiz_attempts WHERE quiz_id=%s AND enrollment_id=%s FOR UPDATE', (quiz_id, own['id'])).fetchone()
        now = datetime.now(timezone.utc)
        # BUG-03: eagerly finalize if deadline already passed before rejecting.
        if attempt and attempt['state'] == 'in_progress' and now >= attempt['deadline_at']:
            finish_attempt(db, user, quiz, attempt, timed_out=True)
            expired = True
        elif not attempt or attempt['state'] != 'in_progress' or now >= attempt['deadline_at']:
            fail(409, 'انتهت المحاولة. لا يمكن تعديل الإجابات.')
        else:
            save_answers(db, attempt, body.answers)
    if expired:
        fail(409, 'انتهت المحاولة. لا يمكن تعديل الإجابات.')
    return {'ok': True}


@router.post('/quizzes/{quiz_id}/submit')
def submit_quiz(quiz_id: int, body: Answers, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        quiz, own = student_quiz(db, user, quiz_id)
        attempt = db.execute('SELECT * FROM quiz_attempts WHERE quiz_id=%s AND enrollment_id=%s FOR UPDATE', (quiz_id, own['id'])).fetchone()
        if not attempt:
            fail(409, 'ابدأ المحاولة أولاً.')
        late = datetime.now(timezone.utc) >= attempt['deadline_at']
        if attempt['state'] == 'in_progress':
            if not late:
                save_answers(db, attempt, body.answers)
            attempt = finish_attempt(db, user, quiz, attempt, timed_out=late)
        return attempt_payload(db, quiz, attempt)
