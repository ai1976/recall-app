-- Name: [DIAGNOSTIC] T-001 Step 0 — live catalog + data facts for the pre-8.8.6 backlog
--
-- Description: READ-ONLY. Confirms against the LIVE database every database-side
-- claim in docs/discussions/T-001 Round 2 that could only be inferred from repo
-- files (CLAUDE.md rule: absence/behaviour of a DB object is never concluded from
-- code or docs alone; several committed migration files have drifted from live).
-- Covers: live function bodies (badge/Review/heatmap/removal/join/access request),
-- study_sessions constraints + triggers + columns, the course-identity landscape
-- (profiles.course_level, profile_courses, disciplines, subjects, target_course,
-- custom_course), batch-membership states, and RLS/grants for the touched tables.
-- No INSERT/UPDATE/DELETE/DDL. Safe to run in the Supabase SQL Editor.
--
-- HOW TO RUN: run each numbered block separately (the editor shows only the last
-- result set). For blocks 1 and 3, results are long text — export or paste to a
-- file under docs/discussions/evidence/ (NOT raw/ unless it contains personal
-- data; counts only below, no emails or names are selected).
-- Record: environment = production, execution date, and which blocks were run.

-- ============================================================================
-- 1. Live function bodies (compare with repo copies named in T-001 Round 2)
-- ============================================================================
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS args,
       p.prosecdef AS security_definer,
       pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'remove_group_member','leave_group','get_group_detail',
    'join_group_by_token','get_group_preview',
    'get_admin_pending_batch_requests','approve_batch_join_request','reject_batch_join_request',
    'get_due_forecast','get_study_queue','get_my_cards','get_study_heatmap',
    'submit_access_request','link_access_request'
  )
ORDER BY p.proname;

-- ============================================================================
-- 2. EXECUTE grants on the same functions (who can call remove_group_member?)
-- ============================================================================
SELECT routine_name, grantee, privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name IN ('remove_group_member','leave_group','get_due_forecast','get_study_heatmap',
                       'submit_access_request','get_admin_pending_batch_requests')
ORDER BY routine_name, grantee;

-- ============================================================================
-- 3. study_sessions: columns, ALL constraints, indexes, triggers (broad scan)
-- ============================================================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'study_sessions'
ORDER BY ordinal_position;

SELECT conname, contype, pg_get_constraintdef(oid) AS definition, convalidated
FROM pg_constraint
WHERE conrelid = 'public.study_sessions'::regclass
ORDER BY conname;

SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'study_sessions' ORDER BY indexname;

-- Broad trigger scan (trigger_schema = 'public', NOT filtered by table), per standing rule.
SELECT trigger_name, event_object_table, event_manipulation, action_timing
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- RLS policies + table grants on study_sessions
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies WHERE schemaname = 'public' AND tablename = 'study_sessions';

SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND table_name = 'study_sessions'
ORDER BY grantee, privilege_type;

-- Source / category distribution (no personal data)
SELECT source, (category IS NOT NULL) AS has_category, count(*) AS rows,
       round(sum(duration_seconds) / 3600.0, 1) AS hours
FROM study_sessions GROUP BY 1, 2 ORDER BY 1, 2;

-- ============================================================================
-- 4. Course identity landscape
-- ============================================================================
-- 4a. Platform courses and subject counts
SELECT d.id, d.name, d.code, d.level, d.is_active,
       (SELECT count(*) FROM subjects s WHERE s.discipline_id = d.id) AS subjects
FROM disciplines d ORDER BY d.order_num, d.name;

-- 4b. profiles.course_level: distinct values (is it only the 3 platform labels, or free text?)
SELECT course_level, role, count(*) AS profiles
FROM profiles GROUP BY 1, 2 ORDER BY 3 DESC;

-- 4c. Constraints on profiles.course_level and on flashcards/notes course columns
SELECT conrelid::regclass AS tbl, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('public.profiles'::regclass, 'public.flashcards'::regclass,
                   'public.notes'::regclass, 'public.profile_courses'::regclass)
  AND contype = 'c'
  AND (pg_get_constraintdef(oid) ILIKE '%course%')
ORDER BY 1, 2;

-- 4d. profile_courses: columns, and who has rows (role split only)
SELECT column_name, data_type, is_nullable FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profile_courses' ORDER BY ordinal_position;

SELECT p.role, count(DISTINCT pc.user_id) AS users_with_rows, count(*) AS rows
FROM profile_courses pc JOIN profiles p ON p.id = pc.user_id GROUP BY 1;

-- 4e. flashcards/notes: how course is actually stored. DATABASE_SCHEMA.md says flashcards has
--     target_course + custom_subject/custom_topic but NO custom_course column, while notes has
--     custom_course. Run the column listing FIRST so a wrong doc cannot break the queries after it.
SELECT table_name, column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name IN ('flashcards','notes')
  AND (column_name LIKE '%course%' OR column_name LIKE 'custom_%' OR column_name IN ('discipline_id','subject_id'))
ORDER BY table_name, column_name;

SELECT 'flashcards' AS tbl, target_course, (subject_id IS NOT NULL) AS has_subject_id,
       (custom_subject IS NOT NULL) AS has_custom_subject, count(*) AS rows
FROM flashcards GROUP BY 2, 3, 4 ORDER BY 5 DESC;

SELECT 'notes' AS tbl, target_course, (custom_course IS NOT NULL) AS has_custom_course,
       (subject_id IS NOT NULL) AS has_subject_id, (custom_subject IS NOT NULL) AS has_custom_subject,
       count(*) AS rows
FROM notes GROUP BY 2, 3, 4, 5 ORDER BY 6 DESC;

-- 4f. Distinct custom strings in use (spelling variants?). Counts only, no personal data.
SELECT 'notes.custom_course' AS kind, custom_course AS value, count(*) AS rows
FROM notes WHERE custom_course IS NOT NULL GROUP BY 2
UNION ALL
SELECT 'flashcards.custom_subject', custom_subject, count(*)
FROM flashcards WHERE custom_subject IS NOT NULL GROUP BY 2
ORDER BY 1, 3 DESC LIMIT 100;

-- 4g. Do disciplines.name values equal profiles.course_level / flashcards.target_course labels?
SELECT d.name AS discipline_name,
       (SELECT count(*) FROM profiles p WHERE p.course_level = d.name) AS profiles_matching,
       (SELECT count(*) FROM flashcards f WHERE f.target_course = d.name) AS cards_matching
FROM disciplines d ORDER BY d.order_num;

-- ============================================================================
-- 5. Batch membership: states, admin roles, and the removal gap
-- ============================================================================
SELECT sg.is_batch_group, sgm.status, sgm.role, count(*) AS rows
FROM study_group_members sgm JOIN study_groups sg ON sg.id = sgm.group_id
GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;

-- Are any platform admins/super_admins also group-admin MEMBERS of batch groups?
-- (The GroupDetail Remove control shows only when the viewer's own membership role = 'admin'.)
SELECT p.role AS platform_role, sgm.role AS group_role, sgm.status, count(*) AS rows
FROM study_group_members sgm
JOIN study_groups sg ON sg.id = sgm.group_id AND sg.is_batch_group
JOIN profiles p ON p.id = sgm.user_id
WHERE sgm.role = 'admin' GROUP BY 1, 2, 3;

-- RLS policies on membership + audit log (does removal write an audit entry? see block 1 body)
SELECT tablename, policyname, cmd, roles, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('study_group_members','study_groups','access_requests','admin_audit_log')
ORDER BY tablename, policyname;

-- Distinct audit actions currently recorded for batches (is there a remove action?)
SELECT action, count(*) AS rows FROM admin_audit_log
WHERE action ILIKE '%batch%' OR action ILIKE '%member%' GROUP BY 1 ORDER BY 2 DESC;

-- ============================================================================
-- 6. Access requests + account_type (points 3/4 baseline; counts only)
-- ============================================================================
SELECT column_name, data_type, is_nullable FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'access_requests' ORDER BY ordinal_position;

SELECT status, count(*) AS rows FROM access_requests GROUP BY 1 ORDER BY 2 DESC;

SELECT account_type, role, count(*) AS profiles FROM profiles GROUP BY 1, 2 ORDER BY 3 DESC;

-- ============================================================================
-- 7. Badge vs Review page: students who have Removed or course-archived cards
--    that still have an active, due `reviews` row (counts only).
-- ============================================================================
SELECT e.status AS enrollment_status, count(DISTINCT e.user_id) AS students, count(*) AS due_review_rows
FROM my_cards_enrollment e
JOIN reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
WHERE r.status = 'active'
  AND r.next_review_date <= CURRENT_DATE
  AND (r.skip_until IS NULL OR r.skip_until <= CURRENT_DATE)
  AND e.status IN ('removed','course_archived')
GROUP BY 1;
