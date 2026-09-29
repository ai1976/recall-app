-- Name: [TEST] Verify get_study_heatmap v2 (Sprint 8.8.5b)
-- Description: Post-deploy verification of 03_FUNCTIONS. Read-only (BEGIN...ROLLBACK, nothing written).
--   Impersonates Aarya Bapat (bf13ff54-...) and checks: (a) her study-only days now appear with
--   study_seconds > 0 and review_count 0; (b) a cross-user call still raises Access denied;
--   (c) a user with real reviews still reports review_count > 0 (v1 behaviour preserved).
--   Run as its own script; the final SELECT is the result table.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_aarya uuid := 'bf13ff54-fb3e-44b8-beb1-8ad55376faf6';
  v_other uuid; v_err text; v_n int; v_secs int; v_reviews int; v_rev_user uuid;
BEGIN
  SELECT id INTO v_other FROM public.profiles WHERE role = 'student' AND id <> v_aarya LIMIT 1;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_aarya, 'role', 'authenticated')::text, true);

  SELECT COUNT(*), COALESCE(SUM(h.study_seconds), 0) INTO v_n, v_secs
  FROM public.get_study_heatmap(v_aarya, 90) h WHERE h.study_seconds > 0;
  INSERT INTO _r VALUES ('Aarya has study-time days', '>= 2 days', v_n::text, CASE WHEN v_n >= 2 THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('Aarya study_seconds total', '>= 9000', v_secs::text, CASE WHEN v_secs >= 9000 THEN 'PASS' ELSE 'FAIL' END);

  SELECT COUNT(*) INTO v_n FROM public.get_study_heatmap(v_aarya, 90) h
  WHERE h.study_seconds > 0 AND h.review_count = 0;
  INSERT INTO _r VALUES ('study-only days report review_count 0', '>= 1 row', v_n::text, CASE WHEN v_n >= 1 THEN 'PASS' ELSE 'FAIL' END);

  IF v_other IS NOT NULL THEN
    BEGIN PERFORM * FROM public.get_study_heatmap(v_other, 90);
      INSERT INTO _r VALUES ('cross-user call [CRITICAL]', 'Access denied', 'no error', 'FAIL');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      INSERT INTO _r VALUES ('cross-user call [CRITICAL]', 'Access denied', left(v_err, 20),
        CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END);
    END;
  END IF;

  -- v1 behaviour preserved: a student with active reviews still gets review_count > 0
  SELECT rv.user_id INTO v_rev_user FROM public.reviews rv
  WHERE rv.status = 'active' AND rv.created_at >= NOW() - interval '30 days' LIMIT 1;
  IF v_rev_user IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_rev_user, 'role', 'authenticated')::text, true);
    SELECT COALESCE(SUM(h.review_count), 0) INTO v_reviews FROM public.get_study_heatmap(v_rev_user, 90) h;
    INSERT INTO _r VALUES ('reviewer still has review_count > 0', '> 0', v_reviews::text, CASE WHEN v_reviews > 0 THEN 'PASS' ELSE 'FAIL' END);
  END IF;
END $$;

SELECT * FROM _r;
ROLLBACK;
