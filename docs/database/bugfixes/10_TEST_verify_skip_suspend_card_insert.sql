-- Name: [TEST] Verify skip_card + suspend_card create a review row (no 42703)
-- Description: Post-deploy verification for 09_FUNCTIONS. Exercises the previously-broken NOT FOUND
-- INSERT branch: picks a (user, flashcard) pair with NO existing review row, impersonates the user
-- (so the IDOR guard passes), calls skip_card / suspend_card, and asserts a review row is created
-- with the right status — proving the corrected easiness/repetition columns work. BEGIN...ROLLBACK;
-- row-returning verdict. get_ functions are SECURITY DEFINER + read auth.uid(), set via
-- set_config('request.jwt.claims', ...).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_user  uuid;
  v_card1 uuid;
  v_card2 uuid;
  v_status text;
  v_skip   date;
  v_err    text;
BEGIN
  SELECT id INTO v_user FROM public.profiles WHERE role = 'student' LIMIT 1;

  -- Two flashcards this user has NOT reviewed (so the NOT FOUND branch fires).
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

  -- ---- skip_card creates an active review with skip_until = tomorrow ----
  BEGIN
    PERFORM public.skip_card(v_user, v_card1);
    SELECT status, skip_until INTO v_status, v_skip
      FROM public.reviews WHERE user_id = v_user AND flashcard_id = v_card1;
    INSERT INTO _r VALUES ('skip_card creates review (no 42703) [CRITICAL]', 'active row',
      COALESCE(v_status,'<none>'),
      CASE WHEN v_status = 'active' AND v_skip IS NOT NULL THEN 'PASS'
           ELSE 'FAIL: status=' || COALESCE(v_status,'null') || ' skip_until=' || COALESCE(v_skip::text,'null') END);
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('skip_card creates review (no 42703) [CRITICAL]', 'active row',
      left(v_err, 40), 'FAIL: ' || v_err);
  END;

  -- ---- suspend_card creates a suspended review ----
  BEGIN
    PERFORM public.suspend_card(v_user, v_card2);
    SELECT status INTO v_status
      FROM public.reviews WHERE user_id = v_user AND flashcard_id = v_card2;
    INSERT INTO _r VALUES ('suspend_card creates review (no 42703) [CRITICAL]', 'suspended row',
      COALESCE(v_status,'<none>'),
      CASE WHEN v_status = 'suspended' THEN 'PASS' ELSE 'FAIL: status=' || COALESCE(v_status,'null') END);
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('suspend_card creates review (no 42703) [CRITICAL]', 'suspended row',
      left(v_err, 40), 'FAIL: ' || v_err);
  END;

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
