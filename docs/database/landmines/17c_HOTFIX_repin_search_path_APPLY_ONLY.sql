-- Name: [FUNCTIONS] HOTFIX v2 — re-pin search_path, APPLY ONLY (no rollback)
-- Description: 17b re-pinned correctly but its trailing BEGIN...ROLLBACK verification ran in the SAME
-- Supabase editor submission — the editor wraps the whole script in ONE transaction, so that ROLLBACK
-- reverted the ALTER FUNCTIONs as well. (Its write-smoke passed because it ran BEFORE the rollback,
-- within the txn = false positive.) The malformed single-quoted pin is therefore still live and
-- flashcard/note/review writes are still failing. This script contains ONLY the re-pin plus a
-- READ-ONLY verification — NO ROLLBACK, NO write inside a transaction — so the ALTERs commit.
-- Run the whole file once. Lesson: never mix persistent DDL with a verification ROLLBACK in one
-- editor submission.

-- ============================================
-- 1. RE-PIN every our-owned pinned function/procedure with correct UNQUOTED list syntax. Commits.
-- ============================================
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid, p.proname, p.prokind, pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind IN ('f','p')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
      AND EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig,'{}')) c WHERE c LIKE 'search_path=%')
  LOOP
    EXECUTE format('ALTER %s public.%I(%s) SET search_path TO public, extensions;',
                   CASE r.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
                   r.proname, r.args);
  END LOOP;
END $$;

-- ============================================
-- 2. READ-ONLY verify — count pinned functions that still lack 'public' as a STANDALONE schema in
--    their search_path. Expected: 0. (A malformed "public, extensions" single element does not
--    match 'public' and would be counted.) No transaction, no rollback — safe.
-- ============================================
SELECT count(*) AS pinned_fns_missing_standalone_public
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind IN ('f','p')
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
  AND EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig,'{}')) c WHERE c LIKE 'search_path=%')
  AND NOT ('public' = ANY (
    SELECT btrim(elem)
    FROM unnest(coalesce(p.proconfig,'{}')) c,
         regexp_split_to_table(split_part(c, '=', 2), ',') AS elem
    WHERE c LIKE 'search_path=%'
  ));

-- ============================================
-- 3. Confirm the three canaries now carry a proper two-schema path.
-- ============================================
SELECT proname, proconfig
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('update_deck_card_count', 'get_browsable_decks', 'fn_update_flashcards_counter');
