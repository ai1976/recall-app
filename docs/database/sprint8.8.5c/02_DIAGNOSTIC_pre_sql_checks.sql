-- ============================================================================
-- Name: [DIAGNOSTIC] Sprint 8.8.5c pre-SQL checks - NULL-course users, live reader predicates, approved backfill population
-- Description: READ ONLY. Answers the three DB-side pre-SQL questions before any 8.8.5c SQL is written:
--   (1) do the 2 users with NULL course_level have My Study enrollments?
--   (2) do the LIVE definitions of every enrollment reader compare status to 'active' (fail-closed) or
--       could any of them let a new 'course_archived' value leak (e.g. status <> 'removed')?
--   (3) the exact approved backfill population, with test accounts and ambiguous users separated.
--   Run each block separately and paste each result under its label.
-- ============================================================================

-- ── 1. NULL-course users: who are they, and what do they have? ───────────────
SELECT pr.id, pr.full_name, pr.role, pr.created_at,
       COUNT(e.*) FILTER (WHERE e.status = 'active')  AS enrollments_active,
       COUNT(e.*) FILTER (WHERE e.status = 'removed') AS enrollments_removed,
       (SELECT COUNT(*) FROM public.reviews r WHERE r.user_id = pr.id) AS review_rows
FROM public.profiles pr
LEFT JOIN public.my_cards_enrollment e ON e.user_id = pr.id
WHERE pr.course_level IS NULL
GROUP BY pr.id, pr.full_name, pr.role, pr.created_at;

-- ── 2. LIVE reader predicates: every line mentioning "status" in each function that reads or writes
--       my_cards_enrollment. Look for '<> ''removed''', 'NOT IN', or any comparison other than = 'active'. ──
SELECT p.proname, x.line_no, btrim(x.line) AS line
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN LATERAL unnest(string_to_array(p.prosrc, E'\n')) WITH ORDINALITY AS x(line, line_no)
WHERE n.nspname = 'public'
  AND p.prosrc ILIKE '%my_cards_enrollment%'
  AND x.line ~* 'status'
ORDER BY p.proname, x.line_no;

-- 2b. Anything ELSE that references the table: views, other-schema functions, policies (none expected).
SELECT 'view' AS kind, c.relname AS name
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE c.relkind IN ('v','m') AND pg_get_viewdef(c.oid) ILIKE '%my_cards_enrollment%'
UNION ALL
SELECT 'function in ' || n.nspname, p.proname
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname <> 'public' AND p.prosrc ILIKE '%my_cards_enrollment%'
UNION ALL
SELECT 'policy', policyname FROM pg_policies WHERE tablename = 'my_cards_enrollment';

-- ── 3a. The approved PRODUCTION backfill population (per-user). Rule, applied ONLY to these rows:
--        role = student, profile course = CA Intermediate, card course = CA Foundation, enrollment active,
--        not a concept card, and NOT one of the three test accounts (Manish, Adhiraj, TestOutlook).
--        Expected from the sweep: 23 users / 1,882 enrollments. ──
WITH excluded(user_id, why) AS (VALUES
  ('037a340d-6dd1-4cf4-8801-1f475ebea529'::uuid, 'test account: Manish Sawant'),
  ('d2845195-ce98-4767-915c-78deb3a73187'::uuid, 'test account: Adhiraj Anand More'),
  ('26507dc7-5ceb-4940-878e-f4cdd2f6eab3'::uuid, 'test account: TestOutlook')
)
SELECT pr.id AS user_id, pr.full_name,
       COUNT(*)                                          AS enrollments_to_archive,
       COUNT(*) FILTER (WHERE f.user_id = pr.id)         AS own_cards,
       COUNT(*) FILTER (WHERE r.status = 'suspended')    AS paused_review_rows,
       COUNT(*) FILTER (WHERE r.status = 'mastered')     AS mastered_review_rows,
       COUNT(*) FILTER (WHERE r.status IS NULL)          AS never_graded
FROM public.my_cards_enrollment e
JOIN public.profiles  pr ON pr.id = e.user_id
JOIN public.flashcards f ON f.id = e.flashcard_id
LEFT JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
WHERE e.status = 'active'
  AND pr.role = 'student'
  AND pr.course_level = 'CA Intermediate'
  AND f.target_course = 'CA Foundation'
  AND f.question_type <> 'concept_card'
  AND pr.id NOT IN (SELECT user_id FROM excluded)
GROUP BY pr.id, pr.full_name
ORDER BY enrollments_to_archive DESC;

-- 3b. Same population, one-row totals (must equal the sum of 3a).
WITH excluded(user_id) AS (VALUES
  ('037a340d-6dd1-4cf4-8801-1f475ebea529'::uuid),
  ('d2845195-ce98-4767-915c-78deb3a73187'::uuid),
  ('26507dc7-5ceb-4940-878e-f4cdd2f6eab3'::uuid)
)
SELECT COUNT(DISTINCT e.user_id) AS users, COUNT(*) AS enrollments
FROM public.my_cards_enrollment e
JOIN public.profiles  pr ON pr.id = e.user_id
JOIN public.flashcards f ON f.id = e.flashcard_id
WHERE e.status = 'active' AND pr.role = 'student' AND pr.course_level = 'CA Intermediate'
  AND f.target_course = 'CA Foundation' AND f.question_type <> 'concept_card'
  AND pr.id NOT IN (SELECT user_id FROM excluded);

-- ── 3c. Confirm the three AMBIGUOUS real users are NOT matched by the rule above (must return 0 rows). ──
SELECT pr.id, pr.full_name, pr.course_level, f.target_course, COUNT(*) AS n
FROM public.my_cards_enrollment e
JOIN public.profiles  pr ON pr.id = e.user_id
JOIN public.flashcards f ON f.id = e.flashcard_id
WHERE e.status = 'active' AND pr.role = 'student' AND pr.course_level = 'CA Intermediate'
  AND f.target_course = 'CA Foundation'
  AND pr.id IN ('3a0062e1-e914-403b-b515-85a1dc6e1613',   -- Aarya Santosh Kulkarni
                'b4440313-5621-46bd-a9b2-7307dc01252f',   -- Aaryaman More
                'da84461a-2d45-4899-a8d4-da1f1c105b49')   -- Anshul Tiwari
GROUP BY pr.id, pr.full_name, pr.course_level, f.target_course;

-- ── 3d. The three test accounts: their current enrollments by card course and review state (for the
--        separate normalisation plan; TestOutlook is intended as the disposable regression account). ──
SELECT pr.full_name, pr.course_level AS profile_course, f.target_course AS card_course,
       COALESCE(r.status, 'never_graded') AS review_status, COUNT(*) AS enrollments
FROM public.my_cards_enrollment e
JOIN public.profiles  pr ON pr.id = e.user_id
JOIN public.flashcards f ON f.id = e.flashcard_id
LEFT JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
WHERE e.status = 'active'
  AND pr.id IN ('037a340d-6dd1-4cf4-8801-1f475ebea529',
                'd2845195-ce98-4767-915c-78deb3a73187',
                '26507dc7-5ceb-4940-878e-f4cdd2f6eab3')
GROUP BY pr.full_name, pr.course_level, f.target_course, COALESCE(r.status, 'never_graded')
ORDER BY pr.full_name, f.target_course;
