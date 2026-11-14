from contextlib import asynccontextmanager
import asyncio
import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import psycopg

import attendance
import auth
import courses
from db import Database
import grading
import quizzes


def create_app(database: Database | None = None):
    async def maintain_quizzes(db):
        def sweep():
            with db.transaction() as connection:
                quizzes.advance_quiz_lifecycle(connection)
        while True:
            try:
                await asyncio.to_thread(sweep)
            except Exception:
                logging.getLogger(__name__).exception('Quiz lifecycle sweep failed')
            await asyncio.sleep(10)

    @asynccontextmanager
    async def lifespan(app):
        app.state.db = database or Database()
        app.state.db.open()
        maintenance = asyncio.create_task(maintain_quizzes(app.state.db))
        try:
            yield
        finally:
            maintenance.cancel()
            try:
                await maintenance
            except asyncio.CancelledError:
                pass
            app.state.db.close()

    app = FastAPI(title='University Attendance API', version='1.0.0', lifespan=lifespan)
    app.add_middleware(CORSMiddleware, allow_origin_regex=r'https?://(localhost|127\.0\.0\.1)(:\d+)?',
        allow_methods=['GET', 'POST', 'PUT', 'PATCH'], allow_headers=['Authorization', 'Content-Type', 'Idempotency-Key'])

    @app.exception_handler(psycopg.Error)
    async def database_error(request: Request, error: psycopg.Error):
        if error.sqlstate == '23505':
            return JSONResponse(status_code=409, content={'detail': 'السجل موجود أو تغير أثناء الحفظ. يرجى تحديث الصفحة.'})
        if error.sqlstate in ('23503', '23514', '23502', '22003'):
            return JSONResponse(status_code=422, content={'detail': 'البيانات غير متوافقة مع قواعد المقرر أو السكشن.'})
        print(f'Database request failed: {type(error).__name__} ({error.sqlstate})')
        return JSONResponse(status_code=503, content={'detail': 'تعذر الوصول إلى قاعدة البيانات. يرجى المحاولة لاحقاً.'})

    @app.get('/api/v1/health')
    def health(request: Request):
        with request.app.state.db.transaction() as db:
            db.execute('SELECT 1').fetchone()
        return {'status': 'ok'}

    for router in (auth.router, courses.router, attendance.router, grading.router, quizzes.router):
        app.include_router(router, prefix='/api/v1')
    return app


app = create_app()
