from collections import defaultdict, deque
from datetime import datetime, timedelta, timezone
import secrets
import threading
import time

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel, Field

from core import fail, principal
from security import hash_password, token_hash, verify_password

router = APIRouter()
failures = defaultdict(deque)
attempt_lock = threading.Lock()


class Login(BaseModel):
    identifier: str = Field(min_length=1, max_length=150)
    password: str = Field(min_length=1, max_length=512)


def profile(db, user):
    student = db.execute('''SELECT s.university_id,s.level,d.name AS department,ds.number AS section_number
        FROM students s JOIN departments d ON d.id=s.department_id
        JOIN department_sections ds ON ds.id=s.department_section_id WHERE s.user_id=%s''', (user['id'],)).fetchone()
    return {key: user[key] for key in ('id', 'username', 'full_name', 'email', 'role')} | (student or {})


@router.post('/auth/login')
def login(body: Login, request: Request):
    key = (request.client.host if request.client else 'local', body.identifier.strip().lower())
    now = time.monotonic()
    with attempt_lock:
        history = failures[key]
        while history and now - history[0] > 300:
            history.popleft()
        if len(history) >= 10:
            fail(429, 'محاولات كثيرة. يرجى الانتظار خمس دقائق.')
    with request.app.state.db.transaction() as db:
        user = db.execute('''SELECT u.* FROM app_users u LEFT JOIN students s ON s.user_id=u.id
            WHERE lower(u.username)=%s OR s.university_id=%s''', (body.identifier.strip().lower(), body.identifier.strip())).fetchone()
        if not user or not user['is_active'] or not verify_password(body.password, user['password_hash']):
            with attempt_lock:
                failures[key].append(now)
            fail(401, 'اسم المستخدم أو كلمة المرور غير صحيحة.')
        if user['role'] not in ('doctor', 'ta', 'student'):
            fail(403, 'هذا الحساب ليس من أدوار تطبيق الحضور.')
        token = secrets.token_urlsafe(32)
        expires = datetime.now(timezone.utc) + timedelta(hours=12)
        db.execute('INSERT INTO api_sessions(token_hash,user_id,expires_at) VALUES (%s,%s,%s)', (token_hash(token), user['id'], expires))
        result = {'token': token, 'expires_at': expires, 'user': profile(db, user)}
    with attempt_lock:
        failures.pop(key, None)
    return result


@router.get('/me')
def me(request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        return profile(db, user)


@router.post('/auth/logout')
def logout(request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        db.execute('UPDATE api_sessions SET revoked_at=now() WHERE token_hash=%s', (token_hash(request.headers['authorization'][7:]),))
    return {'ok': True}


class ChangePassword(BaseModel):
    current_password: str = Field(min_length=1, max_length=512)
    new_password: str = Field(min_length=8, max_length=512)


@router.post('/auth/change-password')
def change_password(body: ChangePassword, request: Request, user=Depends(principal)):
    """ADD-01: Verify current password, update hash, and revoke all other active sessions."""
    if body.new_password == body.current_password:
        fail(422, 'كلمة المرور الجديدة يجب أن تختلف عن الحالية.')
    with request.app.state.db.transaction() as db:
        full = db.execute('SELECT * FROM app_users WHERE id=%s FOR UPDATE', (user['id'],)).fetchone()
        if not verify_password(body.current_password, full['password_hash']):
            # The bearer session is valid; this is a form-validation error.
            fail(422, 'كلمة المرور الحالية غير صحيحة.')
        new_hash = hash_password(body.new_password)
        db.execute('UPDATE app_users SET password_hash=%s WHERE id=%s', (new_hash, user['id']))
        # Revoke all other active sessions so any stolen token becomes invalid.
        current_token_hash = token_hash(request.headers['authorization'][7:])
        db.execute(
            'UPDATE api_sessions SET revoked_at=now() WHERE user_id=%s AND token_hash<>%s AND revoked_at IS NULL',
            (user['id'], current_token_hash))
    return {'ok': True}


@router.get('/notifications')
def notifications(request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        return db.execute('''SELECT id,offering_id,type,title,message,created_at,read_at FROM notifications
            WHERE recipient_user_id=%s ORDER BY created_at DESC,id DESC LIMIT 100''', (user['id'],)).fetchall()


@router.post('/notifications/{notification_id}/read')
def read_notification(notification_id: int, request: Request, user=Depends(principal)):
    with request.app.state.db.transaction() as db:
        row = db.execute('UPDATE notifications SET read_at=COALESCE(read_at,now()) WHERE id=%s AND recipient_user_id=%s RETURNING id',
            (notification_id, user['id'])).fetchone()
        if not row:
            fail(404, 'الإشعار غير موجود.')
    return {'ok': True}
