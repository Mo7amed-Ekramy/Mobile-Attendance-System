BEGIN;
SET LOCAL search_path TO attendance, public;
DO $migration$
BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE version = 7) THEN RETURN; END IF;
    -- Existing questions need staff classification; do not invent their difficulty.
    ALTER TABLE questions ADD COLUMN difficulty text
        CHECK (difficulty IN ('easy', 'medium', 'hard'));
    ALTER TABLE quiz_questions ADD COLUMN difficulty text
        CHECK (difficulty IN ('easy', 'medium', 'hard'));
    INSERT INTO schema_migrations(version, description)
        VALUES (7, 'Classify question difficulty and preserve balanced quiz snapshots');
END;
$migration$;
COMMIT;
