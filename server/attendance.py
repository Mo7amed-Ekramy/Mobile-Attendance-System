from datetime import datetime, timedelta, timezone
import hashlib
import json
import secrets
from typing import Literal

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field
from psycopg.types.json import Jsonb

from core import audit, authorize_offering, enrollment, fail, notify, principal
from security import token_hash

router = APIRouter()


def session_scope(db, user, offering_id, session_id, *, write=False):
    row = db.execute('SELECT * FROM attendance_sessions WHERE id=%s AND offering_id=%s' + (' FOR UPDATE' if write else ''), (session_id, offering_id)).fetchone()
    if not row:
        fail(404, 'جلسة الحضور غير موجودة.')
    authorize_offering(db, user, offering_id, row['course_section_id'], staff=write)
    if user['role'] == 'student':
        enrolled = enrollment(db, user, offering_id)
        if not db.execute('SELECT 1 FROM session_eligibility WHERE session_id=%s AND enrollment_id=%s', (session_id, enrolled['id'])).fetchone():
            fail(403, 'أنت غير مسجل في هذه الجلسة.')
    return row


class CreateSession(BaseModel):
    kind: Literal['lecture', 'section']
    title: str = Field(min_length=1, max_length=150)
    section_id: int | None = Field(default=None, gt=0)
    duration_minutes: int = Field(default=30, ge=1, le=180)


@router.post('/courses/{offering_id}/sessions')
def create_session(offering_id: int, body: CreateSession, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, body.section_id, staff=True)
        if body.kind == 'lecture' and user['role'] != 'doctor':
            fail(403, 'فتح المحاضرة خاص بدكتور المقرر.')
        if body.kind == 'section' and (body.section_id is None or user['role'] != 'ta'):
            fail(403, 'حضور السكشن يتطلب معيداً مسنداً للسكشن.')
        now = datetime.now(timezone.utc)
        row = db.execute('''INSERT INTO attendance_sessions(offering_id,course_section_id,kind,title,starts_at,ends_at,state,created_by)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING *''',
            (offering_id, body.section_id, body.kind, body.title.strip(), now, now + timedelta(minutes=body.duration_minutes), 'open' if body.kind == 'lecture' else 'draft', user['id'])).fetchone()
        db.execute('''INSERT INTO session_eligibility(session_id,enrollment_id,offering_id)
            SELECT %s,id,offering_id FROM enrollments WHERE offering_id=%s AND state='active'
            AND (%s::bigint IS NULL OR course_section_id=%s)''', (row['id'], offering_id, body.section_id, body.section_id))
        audit(db, user, offering_id, 'attendance.create', 'session', row['id'], after=row)
        return row


@router.get('/courses/{offering_id}/sessions')
def sessions(offering_id: int, request: Request, section_id: int | None = None, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, section_id)
        params = [offering_id]
        condition = 's.offering_id=%s'
        if user['role'] == 'student':
            own = enrollment(db, user, offering_id)
            condition += " AND s.state<>'draft' AND EXISTS(SELECT 1 FROM session_eligibility x WHERE x.session_id=s.id AND x.enrollment_id=%s)"
            params.append(own['id'])
            own_condition = 'r.enrollment_id=%s'
            own_params = [own['id']]
        else:
            own_condition, own_params = 'false', []
            if user['role'] == 'ta':
                condition += ' AND s.course_section_id IN (SELECT id FROM course_sections WHERE ta_user_id=%s)'
                params.append(user['id'])
        if section_id is not None:
            condition += ' AND (s.course_section_id=%s OR s.course_section_id IS NULL)'
            params.append(section_id)
        return db.execute('''SELECT s.*,
            (SELECT count(*) FROM session_eligibility x WHERE x.session_id=s.id) AS eligible_count,
            (SELECT count(*) FROM attendance_records r WHERE r.session_id=s.id AND r.status='present') AS present_count,
            (SELECT r.status FROM attendance_records r WHERE r.session_id=s.id AND ''' + own_condition + ''') AS own_status
            FROM attendance_sessions s WHERE ''' + condition + ' ORDER BY s.starts_at DESC,s.id DESC LIMIT 100', own_params + params).fetchall()


@router.get('/courses/{offering_id}/sessions/summary')
def sessions_summary(offering_id: int, request: Request, section_id: int | None = None,
                     user=Depends(principal)):
    """Full-history attendance counts, scoped to the student or permitted section.
    Excused records are excluded from the denominator, as in grade calculation."""
    with request.app.state.db.transaction() as db:
        authorize_offering(db, user, offering_id, section_id)
        conditions = ['s.offering_id=%s', "s.state IN ('closed','finalized')"]
        params = [offering_id]
        if user['role'] == 'student':
            own = enrollment(db, user, offering_id)
            conditions.append('r.enrollment_id=%s')
            params.append(own['id'])
        elif user['role'] == 'ta':
            conditions.append('cs.ta_user_id=%s')
            params.append(user['id'])
        if section_id is not None:
            conditions.append('e.course_section_id=%s')
            params.append(section_id)
        rows = db.execute('''SELECT s.kind,
                count(*) FILTER (WHERE r.status='present') AS present,
                count(*) FILTER (WHERE r.status IN ('present','absent')) AS eligible
            FROM attendance_records r JOIN attendance_sessions s ON s.id=r.session_id
            JOIN enrollments e ON e.id=r.enrollment_id
            JOIN course_sections cs ON cs.id=e.course_section_id
            WHERE ''' + ' AND '.join(conditions) + ' GROUP BY s.kind', params).fetchall()
        return {row['kind']: {'present': row['present'], 'eligible': row['eligible']} for row in rows}


@router.get('/courses/{offering_id}/sessions/{session_id}')
def session_detail(offering_id: int, session_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        row = session_scope(db, user, offering_id, session_id)
        # BUG-11: draft sessions are invisible in the listing; block detail too.
        if user['role'] == 'student' and row['state'] == 'draft':
            fail(403, 'الجلسة في مرحلة المسودة ولا يمكن عرضها حالياً.')
        if user['role'] == 'student':
            own = enrollment(db, user, offering_id)
            row['record'] = db.execute('SELECT status,recorded_at FROM attendance_records WHERE session_id=%s AND enrollment_id=%s', (session_id, own['id'])).fetchone()
        else:
            ta_filter = ''
            params = [session_id]
            if user['role'] == 'ta':
                ta_filter = ''' AND e.course_section_id IN (
                    SELECT id FROM course_sections WHERE offering_id=%s AND ta_user_id=%s
                )'''
                params.extend([offering_id, user['id']])
            row['rows'] = db.execute('''SELECT e.id AS enrollment_id,u.full_name,s.university_id,r.status
                FROM session_eligibility x JOIN enrollments e ON e.id=x.enrollment_id JOIN students s ON s.id=e.student_id
                JOIN app_users u ON u.id=s.user_id LEFT JOIN attendance_records r ON r.session_id=x.session_id AND r.enrollment_id=e.id
                WHERE x.session_id=%s''' + ta_filter + ''' ORDER BY u.full_name,e.id''', tuple(params)).fetchall()
        return row


@router.get('/courses/{offering_id}/sessions/{session_id}/qr')
def session_qr(offering_id: int, session_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        row = session_scope(db, user, offering_id, session_id, write=True)
        if user['role'] != 'doctor' or row['kind'] != 'lecture':
            fail(403, 'رمز الحضور خاص بالمحاضرة ودكتور المقرر.')
        now = datetime.now(timezone.utc)
        if row['state'] != 'open' or now >= row['ends_at']:
            fail(409, 'جلسة الحضور مغلقة أو انتهت مدتها.')
        raw = secrets.token_urlsafe(24)
        until = min(now + timedelta(seconds=45), row['ends_at'])
        db.execute('INSERT INTO qr_tokens(session_id,token_hash,valid_from,valid_until) VALUES (%s,%s,%s,%s)', (session_id, token_hash(raw), now, until))
        return {'payload': f'v1.{session_id}.{raw}', 'valid_until': until}


class CheckIn(BaseModel):
    payload: str = Field(min_length=10, max_length=300)


@router.post('/attendance/check-ins')
def check_in(body: CheckIn, request: Request, user=Depends(principal)):
    if user['role'] != 'student':
        fail(403, 'تسجيل الحضور متاح للطلاب فقط.')
    parts = body.payload.strip().split('.')
    if len(parts) != 3 or parts[0] != 'v1' or not parts[1].isdigit():
        fail(422, 'رمز الحضور غير صحيح.')
    key = request.headers.get('idempotency-key')
    if key and len(key) > 128:
        fail(422, 'مفتاح الطلب غير صحيح.')
    digest = hashlib.sha256(body.payload.encode()).hexdigest()
    with request.app.state.db.transaction() as db:
        if key:
            db.execute('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))', (f"check-in:{user['id']}:{key}",))
            cached = db.execute("SELECT * FROM api_requests WHERE user_id=%s AND operation='check-in' AND request_key=%s", (user['id'], key)).fetchone()
            if cached:
                if cached['request_hash'] != digest:
                    fail(409, 'لا يمكن استخدام مفتاح الطلب لرمز مختلف.')
                return cached['response']
        row = db.execute('SELECT * FROM attendance_sessions WHERE id=%s FOR UPDATE', (int(parts[1]),)).fetchone()
        if not row:
            fail(404, 'جلسة الحضور غير موجودة.')
        own = enrollment(db, user, row['offering_id'])
        if not db.execute('SELECT 1 FROM session_eligibility WHERE session_id=%s AND enrollment_id=%s', (row['id'], own['id'])).fetchone():
            fail(403, 'أنت غير مسجل في هذه الجلسة.')
        valid = db.execute('''SELECT 1 FROM qr_tokens WHERE session_id=%s AND token_hash=%s
            AND valid_from<=now() AND valid_until>now() AND revoked_at IS NULL''', (row['id'], token_hash(parts[2]))).fetchone()
        if row['state'] != 'open' or datetime.now(timezone.utc) >= row['ends_at']:
            fail(409, 'جلسة الحضور مغلقة أو انتهت مدتها.')
        if not valid:
            fail(422, 'انتهت صلاحية الرمز. امسح الرمز الجديد.')
        record = db.execute('SELECT id,status,recorded_at FROM attendance_records WHERE session_id=%s AND enrollment_id=%s', (row['id'], own['id'])).fetchone()
        duplicate = record is not None
        if not record:
            record = db.execute("INSERT INTO attendance_records(session_id,enrollment_id,offering_id,status,source) VALUES (%s,%s,%s,'present','qr') RETURNING id,status,recorded_at",
                (row['id'], own['id'], row['offering_id'])).fetchone()
            audit(db, user, row['offering_id'], 'attendance.check-in', 'record', record['id'], after=record)
        response = {'receipt_id': record['id'], 'session_id': row['id'], 'offering_id': row['offering_id'], 'status': record['status'], 'recorded_at': record['recorded_at'].isoformat(), 'duplicate': duplicate}
        if key:
            db.execute("INSERT INTO api_requests(user_id,operation,request_key,request_hash,response) VALUES (%s,'check-in',%s,%s,%s)", (user['id'], key, digest, Jsonb(response)))
        return response


class RollRow(BaseModel):
    enrollment_id: int = Field(gt=0)
    status: Literal['present', 'absent', 'excused']


class FinalizeRoll(BaseModel):
    revision: int = Field(gt=0)
    rows: list[RollRow] = Field(min_length=1, max_length=1000)


@router.post('/courses/{offering_id}/sessions/{session_id}/finalize')
def finalize_roll(offering_id: int, session_id: int, body: FinalizeRoll, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        row = session_scope(db, user, offering_id, session_id, write=True)
        if user['role'] != 'ta' or row['kind'] != 'section':
            fail(403, 'اعتماد حضور السكشن خاص بالمعيد المسند إليه.')
        if row['state'] != 'draft' or row['revision'] != body.revision:
            fail(409, 'تغير كشف الحضور أو سبق اعتماده. يرجى تحديثه.')
        ids = {x['enrollment_id'] for x in db.execute('SELECT enrollment_id FROM session_eligibility WHERE session_id=%s', (session_id,))}
        if len(body.rows) != len(ids) or {x.enrollment_id for x in body.rows} != ids:
            fail(422, 'يجب تحديد حالة جميع الطلاب المسجلين دون إضافة طلاب من سكشن آخر.')
        for mark in body.rows:
            db.execute("INSERT INTO attendance_records(session_id,enrollment_id,offering_id,status,source) VALUES (%s,%s,%s,%s,'manual')", (session_id, mark.enrollment_id, offering_id, mark.status))
        db.execute("UPDATE attendance_sessions SET state='finalized',revision=revision+1 WHERE id=%s", (session_id,))
        audit(db, user, offering_id, 'attendance.finalize', 'session', session_id, after=body.model_dump())
        return {'ok': True, 'count': len(ids)}


@router.post('/courses/{offering_id}/sessions/{session_id}/close')
def close_lecture(offering_id: int, session_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        row = session_scope(db, user, offering_id, session_id, write=True)
        if user['role'] != 'doctor' or row['kind'] != 'lecture':
            fail(403, 'إغلاق المحاضرة خاص بدكتور المقرر.')
        if row['state'] == 'closed':
            return {'ok': True}
        if row['state'] != 'open':
            fail(409, 'الجلسة ليست مفتوحة.')
        db.execute("INSERT INTO attendance_records(session_id,enrollment_id,offering_id,status,source) SELECT session_id,enrollment_id,offering_id,'absent','manual' FROM session_eligibility WHERE session_id=%s ON CONFLICT(session_id,enrollment_id) DO NOTHING", (session_id,))
        db.execute("UPDATE attendance_sessions SET state='closed',revision=revision+1 WHERE id=%s", (session_id,))
        db.execute('UPDATE qr_tokens SET revoked_at=now() WHERE session_id=%s', (session_id,))
        audit(db, user, offering_id, 'attendance.close', 'session', session_id, before=row)
        return {'ok': True}
