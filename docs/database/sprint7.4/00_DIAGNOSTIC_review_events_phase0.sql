-- Name: [DIAGNOSTIC] Sprint 7.4 — review_events Phase 0 ground-truth measurements
--
-- Description:
--   Read-only introspection for Sprint 7.4 (review_events + apply_review +
--   analytics semantics). Run each block separately in the Supabase SQL Editor
--   and paste ALL results back into the Sprint 7.4 thread before any DDL is
--   written. Nothing here writes. No ROLLBACK needed — every block is a pure
--   SELECT. This project has been burned before by writing DDL against
--   assumed/stale schema — this file exists to prevent a repeat.
--
--   Blocks:
--     Q1  reviews.flashcard_id + reviews.user_id FK actions (ON DELETE) —
--         review_events must match, not assume CASCADE.
--     Q2  reviews.status CHECK constraint — confirm 'mastered' is already a
--         live allowed value (per the SRS Ladder Epic).
--     Q3  Full live column list: reviews, flashcards.
--     Q4  Confirm public.review_events does NOT already exist.
--     Q5  Live body of submit_review (byte-identical baseline for the
--         apply_review "verbatim absorption" requirement).
--     Q6  Live body + exact signature of get_question_type_performance and
--         get_educator_accuracy_by_qtype (docs can drift from live).
--     Q7  Confirm no pre-existing apply_review overload of any signature.
--     Q8  flashcards.question_type distinct values (what "graded" types
--         could look like — informational only, none exist yet pre-7.5).
--     Q9  reviews/day volume baseline (for the 7.4-E storage projection —
--         do not guess this number).
--     Q10 study_sessions row/day baseline (cross-check for Q9).
--     Q11 Current Supabase project storage usage + plan limit context
--         (informational — exact plan limit is checked in the Dashboard,
--         this just gives current total DB size for the projection).
--
-- ============================================================================
-- Q1 — FK actions on reviews.flashcard_id and reviews.user_id
-- ============================================================================
SELECT
  con.conname,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE rel.relname = 'reviews'
  AND nsp.nspname = 'public'
  AND con.contype = 'f'
ORDER BY con.conname;

-- ============================================================================
-- Q2 — reviews.status CHECK constraint (confirm 'mastered' already live)
-- ============================================================================
SELECT con.conname, pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE rel.relname = 'reviews'
  AND nsp.nspname = 'public'
  AND con.contype = 'c'
ORDER BY con.conname;

-- ============================================================================
-- Q3a — full live column list: reviews
-- ============================================================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'reviews'
ORDER BY ordinal_position;

-- ============================================================================
-- Q3b — full live column list: flashcards
-- ============================================================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'flashcards'
ORDER BY ordinal_position;

-- ============================================================================
-- Q4 — confirm public.review_events does not already exist
-- ============================================================================
SELECT to_regclass('public.review_events') AS existing_table;

-- ============================================================================
-- Q5 — live body of submit_review (baseline for apply_review's "verbatim
--      absorption" — the byte-identical transition-maths proof)
-- ============================================================================
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'submit_review';

-- ============================================================================
-- Q6a — live get_question_type_performance (signature + body)
-- ============================================================================
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_question_type_performance';

-- ============================================================================
-- Q6b — live get_educator_accuracy_by_qtype (signature + body)
-- ============================================================================
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'get_educator_accuracy_by_qtype';

-- ============================================================================
-- Q7 — confirm no pre-existing apply_review overload
-- ============================================================================
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname IN ('apply_review', 'submit_review');

-- ============================================================================
-- Q8 — flashcards.question_type distinct values + counts (informational)
-- ============================================================================
SELECT COALESCE(question_type, 'flashcard') AS question_type, COUNT(*) AS rows
FROM flashcards
GROUP BY 1
ORDER BY rows DESC;

-- ============================================================================
-- Q9 — reviews/day volume baseline (last 14 days) — drives the 7.4-E
--      storage projection. Do not guess this number from vibes.
-- ============================================================================
SELECT
  created_at::date AS day,
  COUNT(*) AS reviews_that_day
FROM reviews
WHERE created_at >= now() - interval '14 days'
GROUP BY 1
ORDER BY 1;

-- Also: total reviews row count + current table size, for context
SELECT
  (SELECT COUNT(*) FROM reviews) AS total_review_rows,
  pg_size_pretty(pg_total_relation_size('public.reviews')) AS reviews_total_size,
  pg_size_pretty(pg_relation_size('public.reviews')) AS reviews_table_only_size;

-- ============================================================================
-- Q10 — study_sessions/day baseline (cross-check for Q9's daily-actives proxy)
-- ============================================================================
SELECT
  session_date,
  COUNT(*) AS sessions_that_day
FROM study_sessions
WHERE session_date >= CURRENT_DATE - 14
GROUP BY 1
ORDER BY 1;

-- ============================================================================
-- Q11 — current overall database size (informational context for the
--       storage projection; check the Free-plan limit in Supabase
--       Dashboard -> Settings -> Billing separately)
-- ============================================================================
SELECT pg_size_pretty(pg_database_size(current_database())) AS current_db_size;
