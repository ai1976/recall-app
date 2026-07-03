-- Name: [DIAGNOSTIC] is_public Function-Dependency Audit (L2 Stage B pre-drop)
-- Description: Before dropping notes.is_public / flashcards.is_public (L2 Stage B, 12_SCHEMA),
-- confirm NO function body still references those columns. The Stage A policy check (09 query 2)
-- and the pg_depend view/rule check (09 query 3) do NOT catch references inside FUNCTION bodies
-- (a function names a table in SQL text, which is not a hard pg_depend dependency) — this is the
-- same class of hidden dependency that broke 05_SCHEMA on the vw_study_items view in L1. Prompted
-- by the L2 deck-listing observation (03/07/2026).
--
-- ⚠️ user_badges has its OWN unrelated is_public column (per-badge privacy) which is NOT being
-- dropped — so a raw name match is not enough; query 2 classifies each hit by table alias
-- (`ub.` = user_badges = safe; `fc.`/`n.` = flashcards/notes = must migrate before the drop).
--
-- Result on 03/07/2026: query 1 returned 6 functions; query 2 showed 4 are user_badges (award_badge,
-- get_author_profile, get_public_user_badges, get_user_badges) and 2 reference fc.is_public
-- (skip_topic_cards, suspend_topic_cards); query 3 dumped those two bodies for migration. notes.is_public
-- had zero function references.
--
-- Read-only — safe to run anytime.

-- ============================================
-- 1. Every function whose body mentions is_public (raw name scan)
-- ============================================
SELECT proname
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND pg_get_functiondef(oid) ILIKE '%is_public%';

-- ============================================
-- 2. Classify each is_public reference by table context (30 chars before the match) — tells us
--    which table alias each belongs to (ub. = user_badges = safe; fc./n. = flashcards/notes = fix)
-- ============================================
SELECT p.proname, m.match
FROM pg_proc p,
LATERAL regexp_matches(pg_get_functiondef(p.oid), '(.{30})is_public', 'g') AS m(match)
WHERE p.pronamespace = 'public'::regnamespace
  AND p.proname IN ('get_user_badges','get_public_user_badges','award_badge',
                    'get_author_profile','suspend_topic_cards','skip_topic_cards')
ORDER BY p.proname;

-- ============================================
-- 3. Full bodies of the functions that reference flashcards.is_public (fc.), for migration to
--    visibility before Stage B. (Overloaded functions return all signatures.)
-- ============================================
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname IN ('skip_topic_cards','suspend_topic_cards')
  AND pronamespace = 'public'::regnamespace;
