-- Name: [TEST] Sprint 8.8.5c - bulk Pause / Resume / Remove RPCs
-- Description: Run AFTER 07. Rollback-only (BEGIN ... ROLLBACK), safe on production. Uses TestOutlook as the
--   client-role caller (SET LOCAL ROLE authenticated + JWT sub). Proves each bulk RPC uses the existing single-card
--   semantics in one transaction, reports processed/skipped correctly, and keeps the guards:
--     B1 pause  : only graded ('active' review) enrolled cards are paused; reviews.status becomes 'suspended'
--     B2 resume : reviews.status back to 'active', enrollment stays 'active'
--     B3 remove : enrollment -> 'removed' (Remove is offered on any active enrollment)
--     B4 skips  : an id that is not enrolled and a duplicate id are counted as skipped, not errors
--     B5 IDOR   : another user's id -> Access denied
--     B6 cap    : 501 ids -> refused
--     B7 empty  : empty array -> refused
--   Independent of the course-change work (03-06). Results via a transaction-local setting; strings cast ::text.

BEGIN;

DO $$
DECLARE
  uid   uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';  -- TestOutlook
  other uuid;
  v_res text[] := '{}';
  v_ids uuid[]; v_n int; v_out jsonb; v_c int; v_err text; v_bad uuid := gen_random_uuid();
BEGIN
  SELECT p.id INTO other FROM public.profiles p WHERE p.role = 'student' AND p.id <> uid ORDER BY p.created_at LIMIT 1;

  SELECT array_agg(x.flashcard_id) INTO v_ids FROM (
    SELECT e.flashcard_id FROM public.my_cards_enrollment e
    JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
    WHERE e.user_id = uid AND e.status = 'active' AND r.status = 'active'
    ORDER BY e.id LIMIT 3) x;
  v_n := COALESCE(array_length(v_ids, 1), 0);
  IF v_n = 0 THEN
    v_res := v_res || '0 fixture|>=1 graded active card|0|SKIP'::text;
    PERFORM set_config('app.t09_results', array_to_string(v_res, chr(10)), true);
    RETURN;
  END IF;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';

  -- B1 pause
  BEGIN
    v_out := public.bulk_pause_my_cards(uid, v_ids || v_ids[1] || v_bad);   -- + a duplicate + a non-enrolled id
    RESET ROLE;
    SELECT COUNT(*) INTO v_c FROM public.reviews r WHERE r.user_id = uid AND r.flashcard_id = ANY (v_ids) AND r.status = 'suspended';
    v_res := v_res || ('B1 bulk pause: processed / suspended|' || v_n || '/' || v_n || '|' || (v_out->>'processed') || '/' || v_c || '|' ||
             CASE WHEN (v_out->>'processed')::int = v_n AND v_c = v_n THEN 'PASS' ELSE 'FAIL' END)::text;
    v_res := v_res || ('B4 duplicate + non-enrolled id are skipped, not errors|2 skipped|' || (v_out->>'skipped') || ' skipped|' ||
             CASE WHEN (v_out->>'skipped')::int = 2 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B1 bulk pause|processed|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- B2 resume
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    v_out := public.bulk_resume_my_cards(uid, v_ids);
    RESET ROLE;
    SELECT COUNT(*) INTO v_c FROM public.reviews r WHERE r.user_id = uid AND r.flashcard_id = ANY (v_ids) AND r.status = 'active';
    v_res := v_res || ('B2 bulk resume: processed / active again|' || v_n || '/' || v_n || '|' || (v_out->>'processed') || '/' || v_c || '|' ||
             CASE WHEN (v_out->>'processed')::int = v_n AND v_c = v_n THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B2 bulk resume|processed|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- B3 remove
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    v_out := public.bulk_remove_from_my_cards(uid, v_ids);
    RESET ROLE;
    SELECT COUNT(*) INTO v_c FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.flashcard_id = ANY (v_ids) AND e.status = 'removed';
    v_res := v_res || ('B3 bulk remove: processed / removed|' || v_n || '/' || v_n || '|' || (v_out->>'processed') || '/' || v_c || '|' ||
             CASE WHEN (v_out->>'processed')::int = v_n AND v_c = v_n THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('B3 bulk remove|processed|' || left(v_err, 60) || '|FAIL: ' || v_err)::text; END;

  -- B5 / B6 / B7 guards
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  IF other IS NOT NULL THEN
    BEGIN PERFORM public.bulk_pause_my_cards(other, ARRAY[v_bad]);
      v_res := v_res || 'B5 bulk pause on another user [CRITICAL]|Access denied|no error|FAIL'::text;
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      v_res := v_res || ('B5 bulk pause on another user [CRITICAL]|Access denied|' || left(v_err, 30) || '|' ||
               CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  END IF;
  BEGIN PERFORM public.bulk_remove_from_my_cards(uid, ARRAY(SELECT gen_random_uuid() FROM generate_series(1, 501)));
    v_res := v_res || 'B6 501 ids in one call|refused|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('B6 501 ids in one call|refused (max 500)|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%max 500%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  BEGIN PERFORM public.bulk_resume_my_cards(uid, ARRAY[]::uuid[]);
    v_res := v_res || 'B7 empty array|refused|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('B7 empty array|refused|' || left(v_err, 40) || '|' ||
             CASE WHEN v_err ILIKE '%non-empty%' THEN 'PASS' ELSE 'FAIL: ' || v_err END)::text; END;
  RESET ROLE;

  PERFORM set_config('app.t09_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t09_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
