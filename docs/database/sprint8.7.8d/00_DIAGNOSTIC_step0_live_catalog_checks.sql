-- Name: [DIAGNOSTIC] Sprint 8.7.8d Step 0 — live catalog checks for My Cards page
--
-- Description: Confirms, against live Postgres catalogs (not docs/code inference, per CLAUDE.md's
-- "absence of a constraint/trigger/policy/grant must be catalog-verified" rule), the facts Sprint
-- 8.7.8d's Step 0 needs before any frontend or backend decision:
--   1. Exact reviews.status CHECK values (confirm 'mastered' really is accepted, not just documented).
--   2. Live SELECT RLS policies on flashcards, reviews, my_cards_enrollment (confirm the "zero
--      client-facing policies" claim in the 8.7.8b schema file comments is actually true today).
--   3. Realistic per-user collection sizes (flashcards owned, reviews rows, my_cards_enrollment rows)
--      to size the Option C chunked-lookup decision.
--   4. Whether get_my_cards currently returns own concept_card rows (it should, per its SQL body —
--      no question_type filter on the f.user_id = p_user_id branch — this proves it against live data).
--   5. A live mastered -> suspend -> unsuspend round trip is NOT run here (destructive to real student
--      data) — that consequence is proven by static SQL body inspection instead (see chat summary);
--      this file only confirms the schema-level facts that inspection can't fully cover.
--
-- Run in Supabase SQL Editor. Read-only. Safe to run anytime.

-- 1. reviews.status CHECK constraint — live definition, not the doc's paraphrase
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.reviews'::regclass
  AND contype = 'c';

-- 2. RLS policies — flashcards, reviews, my_cards_enrollment, practice_attempts
SELECT schemaname, tablename, policyname, cmd, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('flashcards', 'reviews', 'my_cards_enrollment', 'practice_attempts')
ORDER BY tablename, cmd;

-- 2b. Table-level RLS enabled flag + direct grants (ACL), to confirm "zero direct grants" claim
SELECT c.relname,
       c.relrowsecurity  AS rls_enabled,
       c.relforcerowsecurity AS rls_forced,
       (SELECT array_agg(DISTINCT grantee || ':' || privilege_type)
        FROM information_schema.role_table_grants g
        WHERE g.table_schema = 'public' AND g.table_name = c.relname) AS grants
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('flashcards', 'reviews', 'my_cards_enrollment', 'practice_attempts');

-- 3. Realistic collection sizes — largest few users by owned-flashcard count and reviews count
-- (sizes the Option C chunked lookup: worst case number of ids to chunk through)
SELECT
  f.user_id,
  COUNT(DISTINCT f.id) FILTER (WHERE f.question_type <> 'concept_card') AS owned_non_concept_cards,
  COUNT(DISTINCT f.id) FILTER (WHERE f.question_type = 'concept_card') AS owned_concept_cards,
  (SELECT COUNT(*) FROM public.reviews r WHERE r.user_id = f.user_id) AS reviews_rows,
  (SELECT COUNT(*) FROM public.my_cards_enrollment e WHERE e.user_id = f.user_id AND e.status = 'active') AS active_enrollments
FROM public.flashcards f
GROUP BY f.user_id
ORDER BY owned_non_concept_cards DESC
LIMIT 15;

-- 4. Does get_my_cards return own concept cards today, for a user who actually owns one?
-- (Proves the SQL-body reading above against live data rather than static inspection alone.)
WITH sample_user AS (
  SELECT user_id FROM public.flashcards WHERE question_type = 'concept_card' LIMIT 1
)
SELECT gmc.id, gmc.question_type
FROM sample_user su
CROSS JOIN LATERAL public.get_my_cards(su.user_id) gmc
WHERE gmc.question_type = 'concept_card';

-- 5. reviews.status distribution among currently-enrolled external cards (none expected yet —
-- confirms remove_from_my_cards / add_to_my_cards haven't been exercised against real students,
-- so all verification in this sprint must use disposable fixtures, not live data)
SELECT r.status, COUNT(*)
FROM public.reviews r
JOIN public.my_cards_enrollment e
  ON e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
GROUP BY r.status;
