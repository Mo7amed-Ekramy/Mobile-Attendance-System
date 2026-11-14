BEGIN;
SET LOCAL search_path TO attendance, public;
DO $migration$
BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE version = 6) THEN RETURN; END IF;
    CREATE TABLE attendance_draft_marks (
        session_id bigint NOT NULL,
        enrollment_id bigint NOT NULL,
        offering_id bigint NOT NULL,
        status text NOT NULL CHECK (status IN ('present', 'absent', 'excused')),
        updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (session_id, enrollment_id),
        FOREIGN KEY (session_id, enrollment_id)
            REFERENCES session_eligibility(session_id, enrollment_id) ON DELETE CASCADE,
        FOREIGN KEY (session_id, offering_id) REFERENCES attendance_sessions(id, offering_id)
    );
    ALTER TABLE quizzes DROP CONSTRAINT quizzes_state_check;
    ALTER TABLE quizzes ADD CONSTRAINT quizzes_state_check
        CHECK (state IN ('draft', 'scheduled', 'active', 'closed', 'finalized', 'cancelled'));
    INSERT INTO schema_migrations(version, description)
        VALUES (6, 'Persist attendance drafts and support quiz cancellation');
END;
$migration$;
COMMIT;
