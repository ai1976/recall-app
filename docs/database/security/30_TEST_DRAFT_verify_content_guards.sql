-- Name: [TEST] DRAFT - verify the content/badge privileged-column guards (28)
-- Status: DRAFT - run only AFTER 28 is deployed. Rollback-only (BEGIN...ROLLBACK), safe on production.
-- Description: Client-role impersonation (SET LOCAL ROLE authenticated + JWT sub). Proves BOTH halves:
--   PART G - the attacks proven open by 29 are now BLOCKED (owner adds 1000 upvotes; owner self-features a note
--            and a deck; student marks own card professor-verified; badge re-labelled as another badge).
--   PART W - the real workflows still work:
--     W1 owner changes a FEATURED note's visibility to private (trg_autoclear_featured_* clears the flags BEFORE
--        the guard runs; the guard must accept a clear-only change)
--     W2 professor nominates public content via nominate_featured_content (definer RPC writing featured_*)
--     W3 admin approves it via approve_featured_nomination (definer RPC writing is_featured_on_landing)
--     W4 a different student upvotes public content via toggle_upvote (definer trigger writes upvote_count)
--     W5 a professor marks their OWN card verified (allowed by is_professor_or_admin)
--     W6 badge owner toggles is_public (MyAchievements)
--   NOT covered here (state honestly): client INSERT of notes/decks. FlashcardCreate inserts decks with
--   card_count 0 / upvote_count 0 and NoteUpload inserts no counters/featured columns, which the INSERT rules
--   allow by construction - confirm with a live Create Deck + Upload Note after deploy.
--   Results use explicit ::text casts and are returned via a transaction-local setting (no temp table).

BEGIN;

DO $$
DECLARE
  v_res text[] := '{}';
  v_note_s uuid; v_note_owner uuid; v_note_w1 uuid;
  v_deck_s uuid; v_deck_owner uuid;
  v_card_s uuid; v_card_owner uuid;
  v_prof uuid; v_prof_card uuid; v_admin uuid;
  v_note_pub uuid; v_note_pub_owner uuid; v_voter uuid;
  v_ub uuid; v_badge_owner uuid; v_other_badge uuid;
  v_n int; v_err text; v_feat boolean; v_cnt_before int; v_cnt_after int; v_uptype text;
BEGIN
  -- ── fixtures (as the server) ──────────────────────────────────────────────
  -- Prefer a student who owns at least TWO notes, so W1 (owner makes a featured note private) has its own note.
  SELECT n.id, n.user_id INTO v_note_s, v_note_owner FROM public.notes n
   WHERE EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = n.user_id AND p.role = 'student')
     AND (SELECT COUNT(*) FROM public.notes x WHERE x.user_id = n.user_id) >= 2
   ORDER BY n.created_at LIMIT 1;
  IF v_note_s IS NULL THEN
    SELECT n.id, n.user_id INTO v_note_s, v_note_owner FROM public.notes n
     WHERE EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = n.user_id AND p.role = 'student') ORDER BY n.created_at LIMIT 1;
  END IF;
  SELECT n.id INTO v_note_w1 FROM public.notes n
   WHERE n.user_id = v_note_owner AND n.id <> v_note_s LIMIT 1;
  SELECT d.id, d.user_id INTO v_deck_s, v_deck_owner FROM public.flashcard_decks d
   WHERE EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = d.user_id AND p.role = 'student') LIMIT 1;
  SELECT f.id, f.user_id INTO v_card_s, v_card_owner FROM public.flashcards f
   WHERE f.is_verified = false AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = f.user_id AND p.role = 'student') LIMIT 1;
  SELECT id INTO v_prof  FROM public.profiles WHERE role = 'professor' ORDER BY created_at LIMIT 1;
  SELECT id INTO v_admin FROM public.profiles WHERE role = 'admin' LIMIT 1;
  SELECT f.id INTO v_prof_card FROM public.flashcards f WHERE f.user_id = v_prof AND f.is_verified = false LIMIT 1;
  SELECT ub.id, ub.user_id INTO v_ub, v_badge_owner FROM public.user_badges ub
   JOIN public.profiles p ON p.id = ub.user_id AND p.role = 'student' LIMIT 1;
  SELECT bd.id INTO v_other_badge FROM public.badge_definitions bd
   WHERE v_ub IS NOT NULL AND NOT EXISTS (SELECT 1 FROM public.user_badges x WHERE x.user_id = v_badge_owner AND x.badge_id = bd.id) LIMIT 1;

  -- A public, un-featured note owned by someone, plus a different student to vote on it (W2-W4).
  SELECT n.id, n.user_id INTO v_note_pub, v_note_pub_owner FROM public.notes n
   WHERE n.visibility = 'public' AND n.is_featured_on_landing = false LIMIT 1;
  IF v_note_pub IS NULL THEN
    UPDATE public.notes SET visibility = 'public', is_featured_on_landing = false WHERE id = v_note_s;
    v_note_pub := v_note_s; v_note_pub_owner := v_note_owner;
  END IF;
  SELECT id INTO v_voter FROM public.profiles WHERE role = 'student' AND id <> v_note_pub_owner ORDER BY created_at LIMIT 1;

  -- Attack targets must be PUBLIC and un-featured. On non-public content trg_autoclear_featured_* (fires BEFORE
  -- the guard) wipes the featured flags, the UPDATE "succeeds" but sets nothing, and the guard has nothing to
  -- refuse - which made the first run of G2/G3 (and 29's C2/C3) look like open holes when they were inconclusive.
  UPDATE public.notes
     SET visibility = 'public', is_featured_on_landing = false,
         featured_nominated_by = NULL, featured_nominated_at = NULL, featured_approved_by = NULL, featured_approved_at = NULL
   WHERE id = v_note_s;
  IF v_deck_s IS NOT NULL THEN
    UPDATE public.flashcard_decks
       SET visibility = 'public', is_featured_on_landing = false,
           featured_nominated_by = NULL, featured_nominated_at = NULL, featured_approved_by = NULL, featured_approved_at = NULL
     WHERE id = v_deck_s;
  END IF;

  -- W1 fixture: make v_note_w1 public AND featured, as the server.
  IF v_note_w1 IS NOT NULL THEN
    UPDATE public.notes
       SET visibility = 'public', is_featured_on_landing = true,
           featured_nominated_by = v_prof, featured_nominated_at = now(),
           featured_approved_by = v_admin, featured_approved_at = now()
     WHERE id = v_note_w1;
  END IF;

  -- ══ PART G: attacks (student / owner) ═══════════════════════════════════
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_note_owner, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  BEGIN UPDATE public.notes SET upvote_count = COALESCE(upvote_count, 0) + 1000 WHERE id = v_note_s;
    v_res := v_res || 'G1 note owner adds 1000 upvotes|blocked|WRITE SUCCEEDED|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('G1 note owner adds 1000 upvotes|blocked|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  BEGIN UPDATE public.notes SET is_featured_on_landing = true, featured_approved_by = v_note_owner, featured_approved_at = now() WHERE id = v_note_s;
    SELECT 'WRITE SUCCEEDED (visibility=' || n.visibility || ', featured=' || COALESCE(n.is_featured_on_landing::text, 'NULL') || ')'
      INTO v_err FROM public.notes n WHERE n.id = v_note_s;
    v_res := v_res || ('G2 note owner self-features [CRITICAL]|blocked|' || v_err || '|FAIL')::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('G2 note owner self-features [CRITICAL]|blocked|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;

  -- W1 (as the owner of the featured note): a visibility change must still work; autoclear clears the flags.
  IF v_note_w1 IS NOT NULL THEN
    BEGIN UPDATE public.notes SET visibility = 'private' WHERE id = v_note_w1;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('W1 owner makes a FEATURED note private (autoclear then guard)|allowed|' || v_n || ' row|' ||
               CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('W1 owner makes a FEATURED note private (autoclear then guard)|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
  ELSE
    v_res := v_res || 'W1 owner makes a FEATURED note private|allowed|SKIP: owner has only one note|fixture missing'::text;
  END IF;

  IF v_deck_s IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_deck_owner, 'role', 'authenticated')::text, true);
    BEGIN UPDATE public.flashcard_decks SET is_featured_on_landing = true, featured_approved_by = v_deck_owner, featured_approved_at = now() WHERE id = v_deck_s;
      SELECT 'WRITE SUCCEEDED (visibility=' || d.visibility || ', featured=' || COALESCE(d.is_featured_on_landing::text, 'NULL') || ')'
        INTO v_err FROM public.flashcard_decks d WHERE d.id = v_deck_s;
      v_res := v_res || ('G3 deck owner self-features [CRITICAL]|blocked|' || v_err || '|FAIL')::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('G3 deck owner self-features [CRITICAL]|blocked|' || left(v_err, 40) || '|' ||
               CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
    BEGIN UPDATE public.flashcard_decks SET upvote_count = COALESCE(upvote_count, 0) + 1000 WHERE id = v_deck_s;
      v_res := v_res || 'G3b deck owner adds 1000 upvotes|blocked|WRITE SUCCEEDED|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('G3b deck owner adds 1000 upvotes|blocked|' || left(v_err, 40) || '|' ||
               CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  END IF;

  IF v_card_s IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_card_owner, 'role', 'authenticated')::text, true);
    BEGIN UPDATE public.flashcards SET is_verified = true WHERE id = v_card_s;
      v_res := v_res || 'G4 student marks own card verified|blocked|WRITE SUCCEEDED|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('G4 student marks own card verified|blocked|' || left(v_err, 40) || '|' ||
               CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  END IF;

  IF v_ub IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_badge_owner, 'role', 'authenticated')::text, true);
    BEGIN UPDATE public.user_badges SET is_public = NOT COALESCE(is_public, true) WHERE id = v_ub;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('W6 badge owner toggles is_public (MyAchievements)|allowed|' || v_n || ' row|' ||
               CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('W6 badge owner toggles is_public (MyAchievements)|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
    IF v_other_badge IS NOT NULL THEN
      BEGIN UPDATE public.user_badges SET badge_id = v_other_badge WHERE id = v_ub;
        v_res := v_res || 'G5 badge re-labelled as another badge [CRITICAL]|blocked|WRITE SUCCEEDED|FAIL'::text;
      EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
        v_res := v_res || ('G5 badge re-labelled as another badge [CRITICAL]|blocked|' || left(v_err, 40) || '|' ||
                 CASE WHEN v_err ILIKE '%Not permitted%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
    END IF;
  END IF;

  -- ══ PART W: real workflows ══════════════════════════════════════════════
  -- W2 professor nominates public content (definer RPC writes featured_nominated_*).
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
  BEGIN PERFORM public.nominate_featured_content('note', v_note_pub);
    v_res := v_res || 'W2 professor nominates public note (definer RPC)|allowed|allowed|PASS'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('W2 professor nominates public note (definer RPC)|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;

  -- W3 admin approves it (definer RPC writes is_featured_on_landing).
  IF v_admin IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.approve_featured_nomination('note', v_note_pub);
      v_res := v_res || 'W3 admin approves the nomination (definer RPC)|allowed|allowed|PASS'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('W3 admin approves the nomination (definer RPC)|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
  END IF;

  -- W5 professor marks their OWN card verified.
  IF v_prof_card IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
    BEGIN UPDATE public.flashcards SET is_verified = true WHERE id = v_prof_card;
      GET DIAGNOSTICS v_n = ROW_COUNT;
      v_res := v_res || ('W5 professor verifies own card|allowed|' || v_n || ' row|' ||
               CASE WHEN v_n = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('W5 professor verifies own card|allowed|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;
  END IF;

  -- W4 another student upvotes public content via the real RPC; count must move by the definer trigger.
  RESET ROLE;
  SELECT upvote_count INTO v_cnt_before FROM public.notes WHERE id = v_note_pub;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_voter, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN PERFORM public.toggle_upvote('note', v_note_pub);
    RESET ROLE;
    SELECT upvote_count INTO v_cnt_after FROM public.notes WHERE id = v_note_pub;
    v_res := v_res || ('W4 student upvotes public note via toggle_upvote (count via definer trigger)|count +1|' ||
             COALESCE(v_cnt_before, 0) || ' -> ' || COALESCE(v_cnt_after, 0) || '|' ||
             CASE WHEN COALESCE(v_cnt_after, 0) = COALESCE(v_cnt_before, 0) + 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    RESET ROLE;
    v_res := v_res || ('W4 student upvotes public note via toggle_upvote (count via definer trigger)|count +1|' || left(v_err, 40) || '|FAIL: ' || v_err)::text; END;

  -- read back what W1 / W3 did
  RESET ROLE;
  IF v_note_w1 IS NOT NULL THEN
    SELECT is_featured_on_landing INTO v_feat FROM public.notes WHERE id = v_note_w1;
    v_res := v_res || ('W1b featured flag was cleared by autoclear when the owner made it private|false|' || COALESCE(v_feat::text, 'NULL') || '|' ||
             CASE WHEN v_feat = false THEN 'PASS' ELSE 'FAIL' END)::text;
  END IF;
  SELECT is_featured_on_landing INTO v_feat FROM public.notes WHERE id = v_note_pub;
  v_res := v_res || ('W3b note is now featured after nominate + approve|true|' || COALESCE(v_feat::text, 'NULL') || '|' ||
           CASE WHEN v_feat THEN 'PASS' ELSE 'FAIL' END)::text;

  -- Hand the results to the final SELECT through a transaction-local setting. A temp table is unreachable
  -- while the session role is switched (and 30's first run hit exactly that: relation "_r" does not exist).
  PERFORM set_config('app.t30_results',
    array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t30_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
