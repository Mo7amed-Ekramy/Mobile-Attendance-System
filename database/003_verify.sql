-- Read validation plus temporary constraint probes. All probe rows are rolled back.
BEGIN;
SET LOCAL search_path TO attendance, public;
DO $verify$
DECLARE
    offering bigint;
    doctor bigint;
    eligible bigint;
    section bigint;
    wrong_section_enrollment bigint;
    other_offering_enrollment bigint;
BEGIN
    IF EXISTS (
        SELECT 1 FROM students s JOIN department_sections ds ON ds.id = s.department_section_id
        WHERE s.department_id <> ds.department_id
    ) THEN RAISE EXCEPTION 'Imported student section/department mismatch'; END IF;
    IF EXISTS (
        SELECT 1 FROM enrollments e JOIN students s ON s.id = e.student_id
        JOIN course_sections cs ON cs.id = e.course_section_id
        WHERE s.department_section_id <> cs.department_section_id OR e.offering_id <> cs.offering_id
    ) THEN RAISE EXCEPTION 'Imported enrollment does not match original seeder rules'; END IF;
    IF EXISTS (SELECT 1 FROM app_users WHERE password_hash IS NOT NULL AND password_hash NOT LIKE 'scrypt$%') THEN
        RAISE EXCEPTION 'Unexpected password format';
    END IF;
    IF EXISTS (SELECT 1 FROM students s JOIN app_users u ON u.id = s.user_id WHERE u.role <> 'student') THEN
        RAISE EXCEPTION 'Student account mapping is invalid';
    END IF;

    SELECT e.offering_id, e.id, e.course_section_id, o.doctor_user_id
        INTO STRICT offering, eligible, section, doctor
        FROM enrollments e JOIN course_offerings o ON o.id = e.offering_id ORDER BY e.id LIMIT 1;
    SELECT id INTO STRICT wrong_section_enrollment FROM enrollments
        WHERE offering_id = offering AND course_section_id <> section ORDER BY id LIMIT 1;
    SELECT id INTO STRICT other_offering_enrollment FROM enrollments
        WHERE offering_id <> offering ORDER BY id LIMIT 1;

    INSERT INTO grading_policies (id, offering_id, version) VALUES (-90001, offering, 999999);
    INSERT INTO grade_categories (id, policy_id, offering_id, code, name, kind, max_points, allocation_mode, position)
        VALUES (-90002, -90001, offering, '__verify', 'Verification', 'assessment', 10, 'fixed', 0);
    INSERT INTO assessments (id, offering_id, category_id, title, kind, max_points, created_by)
        VALUES (-90003, offering, -90002, 'Verification', 'quiz', 10, doctor);
    INSERT INTO assessment_results (id, assessment_id, offering_id, enrollment_id, state, score)
        VALUES (-90004, -90003, offering, eligible, 'unrecorded', NULL);
    UPDATE assessment_results SET state = 'recorded', score = 0 WHERE id = -90004;
    IF NOT EXISTS (SELECT 1 FROM assessment_results WHERE id = -90004 AND score = 0 AND state = 'recorded') THEN
        RAISE EXCEPTION 'Explicit zero was not retained';
    END IF;
    BEGIN
        UPDATE assessment_results SET score = 11 WHERE id = -90004;
        RAISE EXCEPTION 'Out-of-range score was accepted';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN
        UPDATE assessment_results SET state = 'unrecorded', score = 0 WHERE id = -90004;
        RAISE EXCEPTION 'Unrecorded result accepted a numeric score';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN
        INSERT INTO assessment_results (id, assessment_id, offering_id, enrollment_id, state, score)
            VALUES (-90005, -90003, offering, other_offering_enrollment, 'recorded', 1);
        RAISE EXCEPTION 'Cross-offering assessment result was accepted';
    EXCEPTION WHEN foreign_key_violation THEN NULL; END;

    INSERT INTO attendance_sessions (id, offering_id, course_section_id, kind, title, starts_at, ends_at, created_by)
        VALUES (-90010, offering, section, 'section', 'Verification', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + interval '1 hour', doctor);
    INSERT INTO session_eligibility (session_id, offering_id, enrollment_id) VALUES (-90010, offering, eligible);
    BEGIN
        INSERT INTO session_eligibility (session_id, offering_id, enrollment_id)
            VALUES (-90010, offering, wrong_section_enrollment);
        RAISE EXCEPTION 'Wrong-section attendance eligibility was accepted';
    EXCEPTION WHEN check_violation THEN NULL; END;
    INSERT INTO attendance_records (id, session_id, offering_id, enrollment_id, status, source)
        VALUES (-90011, -90010, offering, eligible, 'present', 'manual');
    BEGIN
        INSERT INTO attendance_records (id, session_id, offering_id, enrollment_id, status, source)
            VALUES (-90012, -90010, offering, eligible, 'present', 'qr');
        RAISE EXCEPTION 'Duplicate attendance was accepted';
    EXCEPTION WHEN unique_violation THEN NULL; END;

    INSERT INTO quizzes (id, assessment_id, offering_id, course_section_id, duration_minutes, starts_at, ends_at)
        VALUES (-90020, -90003, offering, section, 20, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + interval '1 hour');
    INSERT INTO quiz_attempts (id, quiz_id, course_section_id, enrollment_id, deadline_at)
        VALUES (-90021, -90020, section, eligible, CURRENT_TIMESTAMP + interval '20 minutes');
    BEGIN
        INSERT INTO quiz_attempts (id, quiz_id, course_section_id, enrollment_id, deadline_at)
            VALUES (-90022, -90020, section, eligible, CURRENT_TIMESTAMP + interval '20 minutes');
        RAISE EXCEPTION 'Duplicate quiz attempt was accepted';
    EXCEPTION WHEN unique_violation THEN NULL; END;
    BEGIN
        INSERT INTO quiz_attempts (id, quiz_id, course_section_id, enrollment_id, deadline_at)
            VALUES (-90023, -90020, section, wrong_section_enrollment, CURRENT_TIMESTAMP + interval '20 minutes');
        RAISE EXCEPTION 'Wrong-section quiz attempt was accepted';
    EXCEPTION WHEN foreign_key_violation THEN NULL; END;
END;
$verify$;
ROLLBACK;
