-- Name: [TEST] Verify read-IDOR guards (08 + 09 + 10)
-- Description: Post-deploy verification. Impersonates a student and confirms a cross-user call to
-- each guarded family RAISEs 'Access denied', while a self-call succeeds. Representative sample
-- across group A (reads + the unsuspend_card write), the professor analytics, and get_user_badges.
-- Read-only intent; BEGIN...ROLLBACK (unsuspend_card touches nothing that survives).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_a uuid; v_b uuid; v_card uuid; v_course text; v_err text; v_ok boolean;
BEGIN
  SELECT id INTO v_a FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_b FROM public.profiles WHERE role = 'student' AND id <> v_a LIMIT 1;
  SELECT id INTO v_card FROM public.flashcards LIMIT 1;
  SELECT target_course INTO v_course FROM public.flashcards WHERE target_course IS NOT NULL LIMIT 1;

  IF v_a IS NULL OR v_b IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', '2 students', 'missing', 'SKIP: need 2 students');
    RETURN;
  END IF;

  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- Helper pattern: each cross-user call must RAISE 'Access denied'.
  BEGIN PERFORM * FROM public.get_suspended_cards(v_b);
    INSERT INTO _r VALUES ('get_suspended_cards cross-user [CRITICAL]','Access denied','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_suspended_cards cross-user [CRITICAL]','Access denied',left(v_err,20),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  BEGIN PERFORM * FROM public.get_user_badges(v_b);
    INSERT INTO _r VALUES ('get_user_badges cross-user [CRITICAL]','Access denied','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_user_badges cross-user [CRITICAL]','Access denied',left(v_err,20),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  BEGIN PERFORM * FROM public.get_recent_notifications(v_b, 5);
    INSERT INTO _r VALUES ('get_recent_notifications cross-user [CRITICAL]','Access denied','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_recent_notifications cross-user [CRITICAL]','Access denied',left(v_err,20),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  IF v_card IS NOT NULL THEN
    BEGIN PERFORM public.unsuspend_card(v_b, v_card);
      INSERT INTO _r VALUES ('unsuspend_card cross-user (write) [CRITICAL]','Access denied','no error','FAIL');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      INSERT INTO _r VALUES ('unsuspend_card cross-user (write) [CRITICAL]','Access denied',left(v_err,20),
        CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;
  END IF;

  BEGIN PERFORM * FROM public.get_professor_overview(v_b, COALESCE(v_course,'x'));
    INSERT INTO _r VALUES ('get_professor_overview cross-user [CRITICAL]','Access denied','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_professor_overview cross-user [CRITICAL]','Access denied',left(v_err,20),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- Self-calls must still work (no Access-denied).
  BEGIN PERFORM * FROM public.get_suspended_cards(v_a);
    INSERT INTO _r VALUES ('get_suspended_cards own','ok','ok','PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_suspended_cards own','ok',left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'FAIL: guard blocked self' ELSE 'PASS (non-guard: '||left(v_err,20)||')' END); END;

  BEGIN PERFORM * FROM public.get_user_badges(v_a);
    INSERT INTO _r VALUES ('get_user_badges own','ok','ok','PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('get_user_badges own','ok',left(v_err,30),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'FAIL: guard blocked self' ELSE 'PASS (non-guard: '||left(v_err,20)||')' END); END;

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
