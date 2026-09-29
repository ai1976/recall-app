-- ============================================================================
-- Name: [DIAGNOSTIC] Sprint 8.8.5c Step 0 - course-change archival: catalog facts + all-user sweep
-- Description: READ ONLY. Every block is a plain SELECT. Run each block separately in the Supabase
--   SQL Editor and paste the results back. Nothing here decides the design by inference - it answers:
--   (A) real enrollment schema, (B) who can write profiles.course_level (RPC-vs-trigger decision),
--   (C) is target_course the authoritative course mapping, (D) every function that reads enrollment
--   (what must be patched), (E) exact per-user affected list + counts for the backfill approval.
-- ============================================================================

-- ── A. my_cards_enrollment: actual columns, constraints, indexes ────────────
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'my_cards_enrollment'
ORDER BY ordinal_position;

SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.my_cards_enrollment'::regclass;

SELECT indexname, indexdef FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'my_cards_enrollment';

-- ── B1. Triggers - BROAD public scan (not filtered by table), per project rule ──
SELECT trigger_name, event_object_table, event_manipulation, action_timing, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- ── B2. RLS policies on profiles (which ones allow UPDATE, and to whom) ──────
SELECT policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'profiles'
ORDER BY cmd, policyname;

-- ── B3. Column/table privileges for client roles on profiles ─────────────────
SELECT grantee, privilege_type, column_name
FROM information_schema.column_privileges
WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'course_level'
  AND grantee IN ('authenticated', 'anon', 'PUBLIC')
ORDER BY grantee, privilege_type;

SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_schema = 'public' AND table_name = 'profiles' AND grantee IN ('authenticated', 'anon', 'PUBLIC')
ORDER BY grantee, privilege_type;

-- ── B4. Every public function that writes profiles.course_level ──────────────
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef AS security_definer
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%course_level%'
  AND p.prosrc ~* 'update\s+(public\.)?profiles'
ORDER BY p.proname;

-- ── B5. Role values, and do students use profile_courses? ────────────────────
SELECT role, COUNT(*) AS n FROM public.profiles GROUP BY role ORDER BY n DESC;

SELECT p.role, COUNT(DISTINCT pc.user_id) AS users_with_profile_courses
FROM public.profile_courses pc JOIN public.profiles p ON p.id = pc.user_id
GROUP BY p.role;

-- ── C. Is flashcards.target_course authoritative? Reconcile vs subject -> discipline ──
-- C1. Overall shape (nulls / unmapped)
SELECT
  COUNT(*)                                                        AS flashcards_total,
  COUNT(*) FILTER (WHERE f.target_course IS NULL)                 AS target_course_null,
  COUNT(*) FILTER (WHERE f.subject_id IS NULL)                    AS subject_id_null,
  COUNT(*) FILTER (WHERE f.subject_id IS NOT NULL AND d.id IS NULL) AS subject_without_discipline,
  COUNT(*) FILTER (WHERE d.name IS NOT NULL AND f.target_course = d.name)   AS agrees_with_discipline,
  COUNT(*) FILTER (WHERE d.name IS NOT NULL AND f.target_course IS DISTINCT FROM d.name) AS disagrees_with_discipline
FROM public.flashcards f
LEFT JOIN public.subjects s ON s.id = f.subject_id
LEFT JOIN public.disciplines d ON d.id = s.discipline_id
WHERE f.question_type <> 'concept_card';

-- C2. The disagreeing pairs (what target_course says vs what the subject's discipline says)
SELECT f.target_course, d.name AS discipline_course, COUNT(*) AS n
FROM public.flashcards f
JOIN public.subjects s ON s.id = f.subject_id
JOIN public.disciplines d ON d.id = s.discipline_id
WHERE f.question_type <> 'concept_card' AND f.target_course IS DISTINCT FROM d.name
GROUP BY 1, 2 ORDER BY n DESC LIMIT 40;

-- C3. Course strings in use: profile course_level vs card target_course vs discipline names
SELECT 'profiles.course_level' AS source, course_level AS course, COUNT(*) AS n
FROM public.profiles GROUP BY 2
UNION ALL
SELECT 'flashcards.target_course', target_course, COUNT(*) FROM public.flashcards GROUP BY 2
UNION ALL
SELECT 'disciplines.name', name, 1 FROM public.disciplines
ORDER BY source, n DESC;

-- ── D. Every function that reads/writes my_cards_enrollment (all must be reviewed) ──
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prosrc ILIKE '%my_cards_enrollment%'
ORDER BY p.proname;

-- ── E1. All-user sweep: students whose ACTIVE enrollments include cards of a course other
--        than their current profile course. (Exact affected-user list for approval.) ──
SELECT pr.id AS user_id, pr.full_name, pr.role, pr.course_level AS current_course,
       f.target_course AS card_course,
       COUNT(*) AS active_enrollments,
       COUNT(*) FILTER (WHERE f.user_id = pr.id) AS own_cards
FROM public.my_cards_enrollment e
JOIN public.profiles pr  ON pr.id = e.user_id
JOIN public.flashcards f ON f.id = e.flashcard_id
WHERE e.status = 'active'
  AND f.question_type <> 'concept_card'
  AND pr.course_level IS NOT NULL
  AND f.target_course IS DISTINCT FROM pr.course_level
GROUP BY pr.id, pr.full_name, pr.role, pr.course_level, f.target_course
ORDER BY active_enrollments DESC;

-- E2. Totals for the same population, plus each affected card's review state (orthogonality check:
--     the Active/Paused/Mastered state lives in reviews, and must survive archival untouched).
SELECT COALESCE(r.status, 'never_graded') AS review_status, COUNT(*) AS enrollments, COUNT(DISTINCT e.user_id) AS users
FROM public.my_cards_enrollment e
JOIN public.profiles pr  ON pr.id = e.user_id
JOIN public.flashcards f ON f.id = e.flashcard_id
LEFT JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
WHERE e.status = 'active'
  AND f.question_type <> 'concept_card'
  AND pr.course_level IS NOT NULL
  AND f.target_course IS DISTINCT FROM pr.course_level
GROUP BY 1 ORDER BY 2 DESC;

-- E3. Students with NO course_level, or enrollments on cards with NULL target_course (cannot be
--     classified either way - shown so nothing is silently skipped).
SELECT 'profiles with null course_level' AS what, COUNT(*) AS n FROM public.profiles WHERE course_level IS NULL
UNION ALL
SELECT 'active enrollments on cards with null target_course', COUNT(*)
FROM public.my_cards_enrollment e JOIN public.flashcards f ON f.id = e.flashcard_id
WHERE e.status = 'active' AND f.target_course IS NULL;
