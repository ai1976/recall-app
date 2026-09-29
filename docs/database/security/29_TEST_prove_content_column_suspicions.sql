-- ============================================================================
-- Name: [TEST] Prove or disprove owner-writable privileged columns (notes, flashcard_decks, flashcards, user_badges)
-- Description: Rollback-only (BEGIN ... ROLLBACK), safe on production. Same method as 23: impersonate a REAL
--   owner with SET LOCAL ROLE authenticated + JWT sub and attempt the write a malicious client could send.
--   Unlike 23's N1 (a same-value write), these make REAL value changes so the result is unambiguous:
--       'WRITE SUCCEEDED' = the hole is real      'BLOCKED: <error>' = refused (or 0 rows)
--   Baseline B1 (legitimate is_public toggle) must succeed, proving the harness works.
--   Results are collected in a text[] using explicit ::text casts (an untyped literal appended to a text[]
--   is parsed as an array literal and fails) and inserted after RESET ROLE.
-- ============================================================================

BEGIN;
CREATE TEMP TABLE _r(seq int, check_name text, must_succeed boolean, observed text, meaning text);

DO $$
DECLARE
  v_res text[] := '{}';
  v_note_owner uuid; v_note uuid;
  v_deck_owner uuid; v_deck uuid;
  v_card_owner uuid; v_card uuid;
  v_badge_owner uuid; v_ub uuid; v_other_badge uuid;
  v_n int; v_err text;
BEGIN
  SELECT id, user_id INTO v_note, v_note_owner FROM public.notes n
   WHERE EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = n.user_id AND p.role = 'student') LIMIT 1;
  SELECT id, user_id INTO v_deck, v_deck_owner FROM public.flashcard_decks d
   WHERE EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = d.user_id AND p.role = 'student') LIMIT 1;
  SELECT id, user_id INTO v_card, v_card_owner FROM public.flashcards f
   WHERE f.is_verified = false
     AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = f.user_id AND p.role = 'student') LIMIT 1;
  SELECT ub.id, ub.user_id INTO v_ub, v_badge_owner FROM public.user_badges ub
   JOIN public.profiles p ON p.id = ub.user_id AND p.role = 'student' LIMIT 1;
  IF v_ub IS NOT NULL THEN
    SELECT bd.id INTO v_other_badge FROM public.badge_definitions bd
     WHERE NOT EXISTS (SELECT 1 FROM public.user_badges x WHERE x.user_id = v_badge_owner AND x.badge_id = bd.id) LIMIT 1;
  END IF;

  -- ── notes ────────────────────────────────────────────────────────────────
  IF v_note IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_note_owner, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';

    BEGIN
      UPDATE public.notes SET upvote_count = COALESCE(upvote_count, 0) + 1000 WHERE id = v_note;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('C1 note owner ADDS 1000 to upvote_count [real change]|false|' ||
        CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = fake popularity / ranking')::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('C1 note owner ADDS 1000 to upvote_count [real change]|false|BLOCKED: ' || v_err || '|')::text; END;

    BEGIN
      UPDATE public.notes
         SET is_featured_on_landing = true, featured_nominated_by = v_note_owner, featured_nominated_at = now(),
             featured_approved_by = v_note_owner, featured_approved_at = now()
       WHERE id = v_note;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('C2 note owner self-features on the landing page (skips nominate + approve) [CRITICAL]|false|' ||
        CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = curation gate bypassed')::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('C2 note owner self-features on the landing page (skips nominate + approve) [CRITICAL]|false|BLOCKED: ' || v_err || '|')::text; END;

    RESET ROLE;
  ELSE
    v_res := v_res || 'C1/C2 notes|false|SKIP: no student-owned note|fixture missing'::text;
  END IF;

  -- ── flashcard_decks ──────────────────────────────────────────────────────
  IF v_deck IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_deck_owner, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      UPDATE public.flashcard_decks
         SET is_featured_on_landing = true, featured_approved_by = v_deck_owner, featured_approved_at = now()
       WHERE id = v_deck;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('C3 deck owner self-features on the landing page [CRITICAL]|false|' ||
        CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = curation gate bypassed')::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('C3 deck owner self-features on the landing page [CRITICAL]|false|BLOCKED: ' || v_err || '|')::text; END;
    BEGIN
      UPDATE public.flashcard_decks SET upvote_count = COALESCE(upvote_count, 0) + 1000 WHERE id = v_deck;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('C3b deck owner ADDS 1000 to upvote_count|false|' ||
        CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|')::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('C3b deck owner ADDS 1000 to upvote_count|false|BLOCKED: ' || v_err || '|')::text; END;
    RESET ROLE;
  ELSE
    v_res := v_res || 'C3 decks|false|SKIP: no student-owned deck|fixture missing'::text;
  END IF;

  -- ── flashcards.is_verified ───────────────────────────────────────────────
  IF v_card IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_card_owner, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';
    BEGIN
      UPDATE public.flashcards SET is_verified = true WHERE id = v_card;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('C4 STUDENT marks own card "professor-verified"|false|' ||
        CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = fake trust badge')::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('C4 STUDENT marks own card "professor-verified"|false|BLOCKED: ' || v_err || '|')::text; END;
    RESET ROLE;
  ELSE
    v_res := v_res || 'C4 flashcards|false|SKIP: no unverified student-owned card|fixture missing'::text;
  END IF;

  -- ── user_badges ──────────────────────────────────────────────────────────
  IF v_ub IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_badge_owner, 'role', 'authenticated')::text, true);
    EXECUTE 'SET LOCAL ROLE authenticated';

    BEGIN
      UPDATE public.user_badges SET is_public = NOT COALESCE(is_public, true) WHERE id = v_ub;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('B1 badge owner toggles is_public (baseline - MyAchievements does this)|true|' ||
        CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|must succeed')::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('B1 badge owner toggles is_public (baseline - MyAchievements does this)|true|BLOCKED: ' || v_err || '|harness/policy problem')::text; END;

    IF v_other_badge IS NOT NULL THEN
      BEGIN
        UPDATE public.user_badges SET badge_id = v_other_badge WHERE id = v_ub;
        GET DIAGNOSTICS v_n = ROW_COUNT;
        v_res := v_res || ('C5 badge owner re-labels their badge as a different badge [CRITICAL]|false|' ||
          CASE WHEN v_n > 0 THEN 'WRITE SUCCEEDED' ELSE 'BLOCKED: 0 rows' END || '|succeeded = counterfeit achievements')::text;
      EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
        v_res := v_res || ('C5 badge owner re-labels their badge as a different badge [CRITICAL]|false|BLOCKED: ' || v_err || '|')::text; END;
    END IF;
    RESET ROLE;
  ELSE
    v_res := v_res || 'B1/C5 user_badges|false|SKIP: no student badge row|fixture missing'::text;
  END IF;

  INSERT INTO _r
  SELECT ord, split_part(x_, '|', 1), split_part(x_, '|', 2)::boolean, split_part(x_, '|', 3), split_part(x_, '|', 4)
  FROM unnest(v_res) WITH ORDINALITY AS t(x_, ord);
END $$;

SELECT seq, check_name, must_succeed, observed, meaning FROM _r ORDER BY seq;
ROLLBACK;
