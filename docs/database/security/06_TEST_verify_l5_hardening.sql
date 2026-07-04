-- Name: [TEST] Verify L5 API-surface hardening
-- Description: Post-deploy verification for 02/02b (IDOR guards) + 04 (revokes). Confirms:
--   - a caller cannot skip/suspend/reset ANOTHER user's cards (guard RAISEs);
--   - a caller CAN act on their own cards (guard passes);
--   - anon lost EXECUTE on internal + authenticated-only functions, kept it on the allowlist;
--   - authenticated kept EXECUTE where needed; is_admin/is_super_admin still executable (RLS).
-- Row-returning verdict, BEGIN...ROLLBACK (the IDOR probe writes nothing that survives).

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

-- ---- IDOR guards (02 / 02b) ----
DO $$
DECLARE
  v_a uuid; v_b uuid; v_card uuid; v_err text;
BEGIN
  SELECT id INTO v_a FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_b FROM public.profiles WHERE role = 'student' AND id <> v_a LIMIT 1;
  SELECT id INTO v_card FROM public.flashcards LIMIT 1;

  IF v_a IS NULL OR v_b IS NULL OR v_card IS NULL THEN
    INSERT INTO _r VALUES ('idor fixtures', 'a,b,card', 'missing', 'SKIP: not enough fixtures');
    RETURN;
  END IF;

  -- Impersonate user A.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_a, 'role', 'authenticated')::text, true);

  -- A tries to act on B's cards -> must RAISE 'Access denied'.
  BEGIN
    PERFORM public.skip_card(v_b, v_card);
    INSERT INTO _r VALUES ('skip_card cross-user blocked [CRITICAL]', 'Access denied', 'no error',
      'FAIL: cross-user skip allowed');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('skip_card cross-user blocked [CRITICAL]', 'Access denied',
      left(v_err, 30), CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END);
  END;

  BEGIN
    PERFORM public.suspend_topic_cards(v_b, NULL, '__l5_no_such_topic__');
    INSERT INTO _r VALUES ('suspend_topic_cards cross-user blocked [CRITICAL]', 'Access denied', 'no error',
      'FAIL: cross-user suspend allowed');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('suspend_topic_cards cross-user blocked [CRITICAL]', 'Access denied',
      left(v_err, 30), CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END);
  END;

  -- A acts on their OWN cards -> guard passes (no Access-denied error). reset_card is side-effect
  -- safe (deletes a review row if present; none here) and rolled back.
  BEGIN
    PERFORM public.reset_card(v_a, v_card);
    INSERT INTO _r VALUES ('reset_card own cards allowed', 'ok', 'ok', 'PASS');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('reset_card own cards allowed', 'ok', left(v_err,40),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'FAIL: guard blocked own action' ELSE 'PASS (non-guard note: '||left(v_err,30)||')' END);
  END;

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

-- ---- Grant checks (04) ----
DO $$
DECLARE
  v int := 0;
  b boolean;
BEGIN
  -- anon must NOT execute an internal fn
  b := has_function_privilege('anon', 'public.award_badge(uuid, text)', 'EXECUTE');
  INSERT INTO _r VALUES ('anon cannot exec award_badge (internal)', 'false', b::text,
    CASE WHEN b = false THEN 'PASS' ELSE 'FAIL' END);

  -- anon must NOT execute an authenticated-only fn
  b := has_function_privilege('anon', 'public.get_browsable_decks()', 'EXECUTE');
  INSERT INTO _r VALUES ('anon cannot exec get_browsable_decks', 'false', b::text,
    CASE WHEN b = false THEN 'PASS' ELSE 'FAIL' END);

  -- authenticated MUST keep the authenticated-only fn
  b := has_function_privilege('authenticated', 'public.get_browsable_decks()', 'EXECUTE');
  INSERT INTO _r VALUES ('authenticated keeps get_browsable_decks', 'true', b::text,
    CASE WHEN b THEN 'PASS' ELSE 'FAIL' END);

  -- anon MUST keep an allowlist fn
  b := has_function_privilege('anon', 'public.get_featured_landing_content()', 'EXECUTE');
  INSERT INTO _r VALUES ('anon keeps allowlist get_featured_landing_content', 'true', b::text,
    CASE WHEN b THEN 'PASS' ELSE 'FAIL' END);

  -- authenticated MUST keep is_admin (RLS)
  b := has_function_privilege('authenticated', 'public.is_admin()', 'EXECUTE');
  INSERT INTO _r VALUES ('authenticated keeps is_admin (RLS)', 'true', b::text,
    CASE WHEN b THEN 'PASS' ELSE 'FAIL' END);

  -- authenticated must NOT keep an internal fn
  b := has_function_privilege('authenticated', 'public.award_badge(uuid, text)', 'EXECUTE');
  INSERT INTO _r VALUES ('authenticated cannot exec award_badge (internal)', 'false', b::text,
    CASE WHEN b = false THEN 'PASS' ELSE 'FAIL' END);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
