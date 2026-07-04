-- Name: [TEST] Verify admin-writer guards + log_review_activity lockdown
-- Description: Post-deploy verification for 15_FUNCTIONS + 16_SCHEMA. Confirms: non-admin cannot
-- enroll/notify (guard RAISEs); an admin can (no Access-denied); anon+authenticated cannot EXECUTE
-- log_review_activity; and the trigger path still works (a review insert fires fn_badge_check_reviews
-- -> log_review_activity without error, proving the revoke didn't break the internal call).
-- BEGIN...ROLLBACK; row-returning verdict.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_student uuid; v_admin uuid; v_target uuid; v_card uuid; v_err text;
BEGIN
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_admin   FROM public.profiles WHERE role IN ('admin','super_admin') LIMIT 1;
  SELECT id INTO v_target  FROM public.profiles WHERE id <> v_student LIMIT 1;

  -- ---- non-admin blocked ----
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_student, 'role', 'authenticated')::text, true);

  BEGIN PERFORM public.enroll_user_in_batch_group(v_target);
    INSERT INTO _r VALUES ('non-admin enroll blocked [CRITICAL]','Access denied','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('non-admin enroll blocked [CRITICAL]','Access denied',left(v_err,20),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  BEGIN PERFORM public.notify_access_granted(v_target);
    INSERT INTO _r VALUES ('non-admin notify blocked [CRITICAL]','Access denied','no error','FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('non-admin notify blocked [CRITICAL]','Access denied',left(v_err,20),
      CASE WHEN v_err ILIKE '%Access denied%' THEN 'PASS' ELSE 'FAIL: '||v_err END); END;

  -- ---- admin allowed (no Access-denied) ----
  IF v_admin IS NOT NULL THEN
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
    BEGIN PERFORM public.notify_access_granted(v_target);
      INSERT INTO _r VALUES ('admin notify allowed','ok','ok','PASS');
    EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
      INSERT INTO _r VALUES ('admin notify allowed','ok',left(v_err,30),
        CASE WHEN v_err ILIKE '%Access denied%' THEN 'FAIL: guard blocked admin' ELSE 'PASS (non-guard: '||left(v_err,20)||')' END); END;
  ELSE
    INSERT INTO _r VALUES ('admin notify allowed','admin fixture','none','SKIP: no admin profile');
  END IF;

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

-- ---- grants: log_review_activity locked to internal ----
DO $$
DECLARE b boolean;
BEGIN
  b := has_function_privilege('anon', 'public.log_review_activity(uuid, timestamptz)', 'EXECUTE');
  INSERT INTO _r VALUES ('anon cannot exec log_review_activity','false',b::text, CASE WHEN b=false THEN 'PASS' ELSE 'FAIL' END);
  b := has_function_privilege('authenticated', 'public.log_review_activity(uuid, timestamptz)', 'EXECUTE');
  INSERT INTO _r VALUES ('authenticated cannot exec log_review_activity','false',b::text, CASE WHEN b=false THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ---- trigger path intact: a review insert (under the student's OWN session, as the app does)
-- still fires fn_badge_check_reviews -> log_review_activity AND any guarded group-A fn it calls
-- (e.g. get_user_streak with NEW.user_id = auth.uid()) without error. Must set auth.uid()=the
-- reviewing user, exactly like the real app — a postgres insert (auth.uid()=NULL) is not a valid
-- simulation of this path. ----
DO $$
DECLARE v_user uuid; v_card uuid; v_err text;
BEGIN
  SELECT id INTO v_user FROM public.profiles WHERE role='student' LIMIT 1;
  SELECT id INTO v_card FROM public.flashcards fc
   WHERE NOT EXISTS (SELECT 1 FROM reviews r WHERE r.user_id=v_user AND r.flashcard_id=fc.id) LIMIT 1;
  IF v_card IS NULL THEN
    INSERT INTO _r VALUES ('review insert fires log_review_activity','fixture','none','SKIP: no unreviewed card');
    RETURN;
  END IF;
  -- Impersonate the reviewing student (as PostgREST would), so auth.uid() = NEW.user_id in the triggers.
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
  BEGIN
    INSERT INTO reviews (user_id, flashcard_id, quality, status) VALUES (v_user, v_card, 3, 'active');
    INSERT INTO _r VALUES ('review insert fires trigger chain (self session) [CRITICAL]','ok','ok','PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('review insert fires trigger chain (self session) [CRITICAL]','ok',left(v_err,40),
      'FAIL: '||v_err); END;
  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
