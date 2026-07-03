-- Name: [DIAGNOSTIC] Landmine L2 — Pre-Migration RLS Audit
-- Description: Ground-truth introspection for the is_public -> visibility RLS rewrite
-- (blueprint.md §1.11 landmine #2). Run this FIRST, in full, in the Supabase SQL Editor,
-- and share the output before deploying 10_SCHEMA (Stage A) in this folder.
-- Read-only — safe to run anytime, changes nothing.
--
-- Why this is required before writing/deploying the migration: 10_SCHEMA below was
-- drafted from docs/reference/DATABASE_SCHEMA.md + blueprint.md §1.11, which record the
-- policy predicates as prose ("is_public = true", "is_public = true OR visibility =
-- 'public'") rather than the exact live `qual` text. The two documents even disagree on
-- the flashcards predicate. Query 1 below is the tiebreaker — if the live qual differs
-- from what 10_SCHEMA assumes, update the DROP POLICY rollback comments in 10_SCHEMA to
-- match the live text before deploying, so the rollback path is trustworthy.

-- ============================================
-- 1. EVERY current policy on notes + flashcards — exact USING/WITH CHECK, roles, cmd
--    (this is the authoritative source for the rollback comments in 10_SCHEMA)
-- ============================================
SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('notes', 'flashcards')
ORDER BY tablename, cmd, policyname;

-- ============================================
-- 2. EVERY policy anywhere that references is_public — catch hidden dependents beyond
--    notes/flashcards. (comments table's 2 policies were dropped in L1 03_CLEANUP —
--    this should now return zero rows outside notes/flashcards. If it returns anything
--    else, STOP and report it before deploying 10_SCHEMA.)
-- ============================================
SELECT tablename, policyname, qual, with_check
FROM pg_policies
WHERE qual ILIKE '%is_public%' OR with_check ILIKE '%is_public%';

-- ============================================
-- 3. pg_depend: any view/rule/generated-column/constraint depending on is_public
--    (the L1 audit-gap lesson — blueprint.md §1.11 "every column/table drop needs a
--    pg_depend check, not just codebase grep + index/RLS". This predicts whether 12_SCHEMA
--    (Stage B drop) will succeed later; it does not block 10_SCHEMA, which never touches
--    the column itself.)
-- ============================================
SELECT DISTINCT dep.relname, dep.relkind
FROM pg_depend d
JOIN pg_rewrite r ON r.oid = d.objid
JOIN pg_class dep ON dep.oid = r.ev_class
JOIN pg_attribute a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid
WHERE d.refobjid IN ('public.notes'::regclass, 'public.flashcards'::regclass)
  AND a.attname = 'is_public';

-- ============================================
-- 4a. friendships shape (for the friends-tier policy join)
-- ============================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'friendships'
ORDER BY ordinal_position;

-- 4b. is_public column defaults/nullability on notes + flashcards
SELECT table_name, column_default, is_nullable
FROM information_schema.columns
WHERE table_name IN ('notes', 'flashcards') AND column_name = 'is_public';

-- ============================================
-- 5. Drift check — rows where is_public and visibility disagree on "is this public?"
--    Every current frontend writer sets both fields together in the same payload (verified
--    by grep — see L2 report), so this SHOULD return all zeros. A non-zero
--    "public_but_not_flagged" count is fine (Stage A's visibility-only policy already
--    covers it — that's the bug being fixed). A non-zero "flagged_but_not_public" count is
--    the dangerous case: content that is PUBLIC TODAY (is_public=true) would silently stop
--    being public-readable the moment Stage A deploys. If this is non-zero, list the
--    affected rows (uncomment the SELECT * variants) and get founder sign-off before
--    deploying 10_SCHEMA — either fix the drifted rows' visibility first, or adjust the
--    Stage A policy to also OR in is_public=true as a transitional safety net.
-- ============================================
SELECT
  'notes' AS table_name,
  count(*) FILTER (WHERE is_public = true AND visibility <> 'public') AS flagged_but_not_public,
  count(*) FILTER (WHERE is_public IS DISTINCT FROM true AND visibility = 'public') AS public_but_not_flagged
FROM public.notes
UNION ALL
SELECT
  'flashcards',
  count(*) FILTER (WHERE is_public = true AND visibility <> 'public'),
  count(*) FILTER (WHERE is_public IS DISTINCT FROM true AND visibility = 'public')
FROM public.flashcards;

-- Uncomment if query 5 shows a non-zero flagged_but_not_public count, to identify the rows:
-- SELECT id, user_id, visibility, is_public, created_at FROM public.notes
--   WHERE is_public = true AND visibility <> 'public';
-- SELECT id, user_id, visibility, is_public, created_at FROM public.flashcards
--   WHERE is_public = true AND visibility <> 'public';

-- ============================================
-- 6. Sanity check: at least 3 distinct profiles exist (11_TEST's matrix picks 3 real
--    profiles as Owner/Friend/Stranger fixtures rather than fabricating auth.users rows)
-- ============================================
SELECT count(*) AS profile_count FROM public.profiles;
