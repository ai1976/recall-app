-- Name: [FUNCTIONS] HOTFIX — re-pin search_path with correct unquoted list syntax
-- Description: URGENT. L3's 17_SCHEMA set `SET search_path TO 'public, extensions'` (single-quoted).
-- For the search_path GUC, a quoted comma-string is parsed as ONE schema named "public, extensions"
-- (GUC_LIST_QUOTE gotcha), NOT two schemas — so `public` dropped out of the path and every
-- unqualified reference in the 50 pinned functions began failing (e.g. update_deck_card_count →
-- `relation "flashcard_decks" does not exist`, breaking flashcard/note/review writes). Correct
-- syntax is an UNQUOTED identifier list: `SET search_path TO public, extensions`. This re-pins every
-- our-owned pinned function/procedure correctly. Idempotent and safe to re-run.
--
-- Deploy immediately, then re-run 18_TEST (now with a real write smoke) or 21_TEST.

-- ============================================
-- 1. SMOKING GUN (before) — the malformed value. Expect proconfig to show the comma INSIDE one
--    quoted element, i.e. a single bogus schema.
-- ============================================
SELECT proname, proconfig
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('update_deck_card_count', 'get_browsable_decks', 'fn_update_flashcards_counter');

-- ============================================
-- 2. FIX — re-pin every our-owned, currently-pinned public function/procedure using the correct
--    unquoted list. (Re-pinning the earlier-correct 'public'-only ones to 'public, extensions' is
--    harmless.) One transaction.
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
    -- NOTE: unquoted `public, extensions` (NOT %L) — this is the whole point of the hotfix.
    EXECUTE format('ALTER %s public.%I(%s) SET search_path TO public, extensions;',
                   CASE r.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
                   r.proname, r.args);
  END LOOP;
END $$;

-- ============================================
-- 3. VERIFY (after) — same three functions should now show a proper two-schema list, and a live
--    flashcard insert (which fires update_deck_card_count) should succeed. BEGIN/ROLLBACK.
-- ============================================
SELECT proname, proconfig
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('update_deck_card_count', 'get_browsable_decks', 'fn_update_flashcards_counter');

BEGIN;
CREATE TEMP TABLE _h(verdict text);
DO $$
DECLARE v_owner uuid; v_id uuid;
BEGIN
  SELECT id INTO v_owner FROM public.profiles LIMIT 1;
  BEGIN
    INSERT INTO public.flashcards
      (user_id, contributed_by, creator_id, target_course, front_text, back_text, visibility, is_verified, difficulty, batch_id)
    VALUES
      (v_owner, NULL, v_owner, 'test_course', '_HOTFIX_smoke_card', 'x', 'private', false, 'medium', gen_random_uuid())
    RETURNING id INTO v_id;
    INSERT INTO _h VALUES ('PASS: flashcard insert fired update_deck_card_count OK, id=' || v_id);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _h VALUES ('FAIL: ' || SQLERRM);
  END;
END $$;
SELECT * FROM _h;
ROLLBACK;
