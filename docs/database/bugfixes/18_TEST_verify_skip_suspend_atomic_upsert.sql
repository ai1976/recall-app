-- Name: [TEST] Verify skip_card / suspend_card atomic upsert — no more 23505 on a repeat call
-- Description: Post-deploy verification for 17_FUNCTIONS. Same fixture/impersonation idiom as
-- 10_TEST_verify_skip_suspend_card_insert.sql (which this supersedes — that test only proved the
-- NOT FOUND branch didn't 42703 on column names; it never exercised calling the RPC twice on the
-- same never-reviewed card, so it could not have caught this race). Calling skip_card/suspend_card
-- TWICE in a row on a card with no prior review row deterministically exercises the exact path a
-- concurrent duplicate call takes post-fix (the second call's INSERT now hits ON CONFLICT DO UPDATE
-- instead of racing a plain INSERT) — it does not replay true parallel-transaction timing (that needs
-- two separate DB sessions, out of scope for a single SQL Editor script), but it does prove the fixed
-- function body is idempotent under repeated calls, which the pre-fix body was not.
-- BEGIN...ROLLBACK; row-returning verdict.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_user  uuid;
  v_other uuid;
  v_card1 uuid;
  v_card2 uuid;
  v_status text;
  v_skip   date;
  v_err    text;
BEGIN
  SELECT id INTO v_user FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_other FROM public.profiles WHERE role = 'student' AND id <> v_user LIMIT 1;

  -- Two flashcards this user has NOT reviewed (so the INSERT side of the upsert fires first).
  SELECT id INTO v_card1 FROM public.flashcards fc
   WHERE NOT EXISTS (SELECT 1 FROM public.reviews r WHERE r.user_id = v_user AND r.flashcard_id = fc.id)
   LIMIT 1;
  SELECT id INTO v_card2 FROM public.flashcards fc
   WHERE fc.id <> v_card1
     AND NOT EXISTS (SELECT 1 FROM public.reviews r WHERE r.user_id = v_user AND r.flashcard_id = fc.id)
   LIMIT 1;

  IF v_user IS NULL OR v_card1 IS NULL OR v_card2 IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', 'user + 2 unreviewed cards', 'missing', 'SKIP: not enough fixtures');
    RETURN;
  END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);

  -- ── 1. skip_card: first call creates an active review with skip_until = tomorrow ───────────
  PERFORM public.skip_card(v_user, v_card1);
  SELECT status, skip_until INTO v_status, v_skip
    FROM public.reviews WHERE user_id = v_user AND flashcard_id = v_card1;
  INSERT INTO _r VALUES ('skip_card 1st call creates review', 'active row',
    COALESCE(v_status,'<none>'),
    CASE WHEN v_status = 'active' AND v_skip = CURRENT_DATE + 1 THEN 'PASS'
         ELSE 'FAIL: status=' || COALESCE(v_status,'null') || ' skip_until=' || COALESCE(v_skip::text,'null') END);

  -- ── 2. skip_card: second call on the SAME card — the exact path a race's "loser" call takes
  --    post-fix. Pre-fix this would be a second INSERT -> 23505. Post-fix: ON CONFLICT DO UPDATE,
  --    no error, exactly one row still exists. ─────────────────────────────────────────────────
  BEGIN
    PERFORM public.skip_card(v_user, v_card1);
    INSERT INTO _r VALUES ('skip_card 2nd call (race simulation) [CRITICAL]', 'no error', 'no error', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('skip_card 2nd call (race simulation) [CRITICAL]', 'no error', left(v_err,50), 'FAIL: ' || v_err);
  END;

  INSERT INTO _r
  SELECT 'exactly one reviews row after 2 skip_card calls [CRITICAL]', '1', count(*)::text,
         CASE WHEN count(*) = 1 THEN 'PASS' ELSE 'FAIL' END
  FROM public.reviews WHERE user_id = v_user AND flashcard_id = v_card1;

  -- ── 3. suspend_card: first call creates a suspended review ─────────────────────────────────
  PERFORM public.suspend_card(v_user, v_card2);
  SELECT status INTO v_status FROM public.reviews WHERE user_id = v_user AND flashcard_id = v_card2;
  INSERT INTO _r VALUES ('suspend_card 1st call creates review', 'suspended row',
    COALESCE(v_status,'<none>'), CASE WHEN v_status = 'suspended' THEN 'PASS' ELSE 'FAIL' END);

  -- ── 4. suspend_card: second call on the SAME card — same race simulation ───────────────────
  BEGIN
    PERFORM public.suspend_card(v_user, v_card2);
    INSERT INTO _r VALUES ('suspend_card 2nd call (race simulation) [CRITICAL]', 'no error', 'no error', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('suspend_card 2nd call (race simulation) [CRITICAL]', 'no error', left(v_err,50), 'FAIL: ' || v_err);
  END;

  INSERT INTO _r
  SELECT 'exactly one reviews row after 2 suspend_card calls [CRITICAL]', '1', count(*)::text,
         CASE WHEN count(*) = 1 THEN 'PASS' ELSE 'FAIL' END
  FROM public.reviews WHERE user_id = v_user AND flashcard_id = v_card2;

  -- ── 5. IDOR guard still intact post-fix (cross-user call RAISEs) ───────────────────────────
  IF v_other IS NOT NULL THEN
    BEGIN
      PERFORM public.skip_card(v_other, v_card1);
      INSERT INTO _r VALUES ('cross-user skip_card call [CRITICAL]', 'Access denied', 'no error', 'FAIL');
    EXCEPTION WHEN OTHERS THEN
      v_err := SQLERRM;
      INSERT INTO _r VALUES ('cross-user skip_card call [CRITICAL]', 'Access denied', left(v_err,30),
        CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END);
    END;
  END IF;

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
