BEGIN;
SET LOCAL search_path TO attendance, public;
DO $migration$
BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE version = 4) THEN RETURN; END IF;
    CREATE TABLE api_sessions (
        token_hash text PRIMARY KEY,
        user_id bigint NOT NULL REFERENCES app_users(id),
        created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        expires_at timestamptz NOT NULL,
        revoked_at timestamptz
    );
    CREATE INDEX api_sessions_user ON api_sessions(user_id);
    CREATE TABLE api_requests (
        user_id bigint NOT NULL REFERENCES app_users(id),
        operation text NOT NULL,
        request_key text NOT NULL,
        request_hash text NOT NULL,
        response jsonb NOT NULL,
        created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY(user_id, operation, request_key)
    );
    ALTER TABLE assessments ADD COLUMN published_at timestamptz;
    CREATE TABLE published_results (
        result_id bigint PRIMARY KEY REFERENCES assessment_results(id),
        score numeric(9,2),
        state text NOT NULL CHECK (state IN ('unrecorded', 'recorded', 'excused')),
        feedback text,
        published_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        published_by bigint NOT NULL REFERENCES app_users(id),
        CHECK ((state = 'recorded' AND score IS NOT NULL AND score >= 0)
            OR (state IN ('unrecorded', 'excused') AND score IS NULL))
    );
    INSERT INTO schema_migrations(version, description) VALUES (4, 'API authentication and published result snapshots');
END;
$migration$;
COMMIT;
