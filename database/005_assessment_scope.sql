BEGIN;
SET LOCAL search_path TO attendance, public;
DO $migration$
BEGIN
    IF EXISTS (SELECT 1 FROM schema_migrations WHERE version=5) THEN RETURN; END IF;
    ALTER TABLE assessments ADD COLUMN course_section_id bigint;
    ALTER TABLE assessments ADD CONSTRAINT assessments_section_scope
        FOREIGN KEY(course_section_id,offering_id) REFERENCES course_sections(id,offering_id);
    INSERT INTO schema_migrations(version,description) VALUES(5,'Section-specific assessments and quiz grade eligibility');
END;
$migration$;
COMMIT;
