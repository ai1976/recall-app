-- [DIAGNOSTIC] Students see the "Welcome to RevisOp - Get Started" first-time view instead of their dashboard/leaderboard
-- Description: READ-ONLY. Reported 30/09/2026 by at least 5 students (incl. Aarya Bapat, bf13ff54-fb3e-44b8-beb1-8ad55376faf6).
-- What the code does (src/pages/Dashboard.jsx ~314-332): `isNewUser` = the student has ZERO rows in `reviews`, ZERO in
--   `notes` and ZERO in `flashcards` (own rows, direct client counts; a failed count also reads as zero). When true the
--   dashboard hides the leaderboard, Study Time and the forward ledger. Since Sprint 8.7.8 a student only gets a
--   `reviews` row when they actually grade a card, so a student who enrolled cards / logged offline study but has not
--   graded one yet lands in this view.
-- These blocks test that hypothesis from live data and check the alternative (a broken read).
-- Run each block separately and paste all results.

-- Block 1: Aarya - what does she actually have?
SELECT
  (SELECT count(*) FROM public.reviews  WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6') AS reviews_rows,
  (SELECT count(*) FROM public.notes    WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6') AS notes_rows,
  (SELECT count(*) FROM public.flashcards WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6') AS flashcards_rows,
  (SELECT count(*) FROM public.my_cards_enrollment WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6') AS enrollment_rows_any_status,
  (SELECT count(*) FROM public.my_cards_enrollment WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6' AND status = 'active') AS enrollment_active,
  (SELECT count(*) FROM public.my_cards_enrollment WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6' AND status = 'course_archived') AS enrollment_course_archived,
  (SELECT count(*) FROM public.study_sessions WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6') AS study_session_rows,
  (SELECT count(*) FROM public.user_activity_log WHERE user_id = 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6' AND activity_type = 'review') AS review_activity_logged;

-- Block 2: how many active students are classified "new" today although they have real activity?
WITH s AS (
  SELECT p.id, p.full_name, p.created_at,
         (SELECT count(*) FROM public.reviews r WHERE r.user_id = p.id)     AS reviews_n,
         (SELECT count(*) FROM public.notes n WHERE n.user_id = p.id)       AS notes_n,
         (SELECT count(*) FROM public.flashcards f WHERE f.user_id = p.id)  AS cards_n,
         (SELECT count(*) FROM public.my_cards_enrollment e WHERE e.user_id = p.id AND e.status IN ('active','course_archived')) AS enrolled_n,
         (SELECT count(*) FROM public.study_sessions ss WHERE ss.user_id = p.id) AS sessions_n
  FROM public.profiles p
  WHERE p.role = 'student' AND COALESCE(p.status, 'active') = 'active'
)
SELECT
  count(*) FILTER (WHERE reviews_n = 0 AND notes_n = 0 AND cards_n = 0)                                   AS classified_new_total,
  count(*) FILTER (WHERE reviews_n = 0 AND notes_n = 0 AND cards_n = 0 AND enrolled_n > 0)                AS new_but_have_enrolled_cards,
  count(*) FILTER (WHERE reviews_n = 0 AND notes_n = 0 AND cards_n = 0 AND sessions_n > 0)                AS new_but_have_study_sessions,
  count(*) FILTER (WHERE reviews_n = 0 AND notes_n = 0 AND cards_n = 0 AND enrolled_n = 0 AND sessions_n = 0) AS genuinely_new,
  count(*) AS active_students
FROM s;

-- Block 3: the affected students themselves (first 40) - names only from your own admin data
WITH s AS (
  SELECT p.id, p.full_name, p.created_at,
         (SELECT count(*) FROM public.reviews r WHERE r.user_id = p.id)     AS reviews_n,
         (SELECT count(*) FROM public.notes n WHERE n.user_id = p.id)       AS notes_n,
         (SELECT count(*) FROM public.flashcards f WHERE f.user_id = p.id)  AS cards_n,
         (SELECT count(*) FROM public.my_cards_enrollment e WHERE e.user_id = p.id AND e.status IN ('active','course_archived')) AS enrolled_n,
         (SELECT count(*) FROM public.study_sessions ss WHERE ss.user_id = p.id) AS sessions_n,
         (SELECT max(a.created_at) FROM public.user_activity_log a WHERE a.user_id = p.id) AS last_activity
  FROM public.profiles p
  WHERE p.role = 'student' AND COALESCE(p.status, 'active') = 'active'
)
SELECT id, full_name, created_at::date AS joined, reviews_n, notes_n, cards_n, enrolled_n, sessions_n, last_activity::date AS last_activity
FROM s
WHERE reviews_n = 0 AND notes_n = 0 AND cards_n = 0 AND (enrolled_n > 0 OR sessions_n > 0)
ORDER BY last_activity DESC NULLS LAST
LIMIT 40;

-- Block 4: alternative hypothesis - did reviews rows disappear? Users with review activity logged but no reviews rows now.
SELECT count(DISTINCT a.user_id) AS users_with_review_activity_but_zero_reviews_rows
FROM public.user_activity_log a
WHERE a.activity_type = 'review'
  AND NOT EXISTS (SELECT 1 FROM public.reviews r WHERE r.user_id = a.user_id);

-- Block 5: alternative hypothesis - a broken read. Can the client role still SELECT the three tables the check counts?
SELECT t.tbl,
       has_table_privilege('authenticated', 'public.' || t.tbl, 'SELECT') AS authenticated_can_select
FROM (VALUES ('reviews'), ('notes'), ('flashcards')) AS t(tbl);

SELECT tablename, policyname, cmd, roles, qual
FROM pg_policies
WHERE schemaname = 'public' AND tablename IN ('reviews', 'notes', 'flashcards') AND cmd IN ('SELECT', 'ALL')
ORDER BY tablename, policyname;
