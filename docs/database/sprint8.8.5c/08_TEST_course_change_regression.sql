-- ============================================================================
-- Name: [TEST] Sprint 8.8.5c - course-change archive / restore regression matrix
-- Description: Run AFTER 03, 04, 05 (and 06). Rollback-only (BEGIN ... ROLLBACK): nothing survives, safe on production.
--   Uses TestOutlook (26507dc7-...) as the disposable regression account - profile CA Intermediate with enrollments
--   in CA Foundation, CA Intermediate and CA Final - and the professor CA Anand More (075ad481-...) for the
--   exclusion check. Course changes are made as the real client role where it matters (SET LOCAL ROLE authenticated
--   + JWT sub); enrollment tables have zero client grants, so state is read as the server.
--   MATRIX (each row below is one or more result lines):
--     P    preview counts (both effects) equal what the real change then does
--     S1-S5 A->B->A and A->B->C->A: I->F, F->I, I->Fin, Fin->I, I->F with exact archived/restored counts
--     M    manually removed card stays 'removed' through the whole cycle (never restored)
--     R    Paused (suspended) and Mastered review state survive archive + restore untouched
--     X    archived cards cannot be surfaced or graded: not in get_my_cards, not in get_study_queue,
--          apply_review raises 42501
--     Z    same-course update is a complete no-op (preview zeros, counts identical)
--     N    clearing the course (NULL) changes nothing
--     PR   a PROFESSOR's course change archives nothing
--     AT   an error during archival rolls the course update back too (temporary poison trigger)
--     RA   re-adding an archived card via add_to_my_cards and via add_batch_to_my_cards makes it 'active' and
--          clears archived_course / archived_at
--   Results are returned through a transaction-local setting (a temp table is unreachable while the role is switched)
--   and all appended strings are cast ::text.
-- ============================================================================

BEGIN;

CREATE FUNCTION pg_temp.cnt(p_uid uuid, p_course text, p_status text) RETURNS int
LANGUAGE sql AS $f$
  SELECT COUNT(*)::int FROM public.my_cards_enrollment e
  JOIN public.flashcards f ON f.id = e.flashcard_id
  WHERE e.user_id = p_uid AND f.target_course = p_course AND e.status = p_status
$f$;

DO $$
DECLARE
  uid  uuid := '26507dc7-5ceb-4940-878e-f4cdd2f6eab3';  -- TestOutlook
  prof uuid := '075ad481-13e8-45e4-9deb-3c38907eb3e6';  -- CA Anand More (professor)
  I text := 'CA Intermediate'; F text := 'CA Foundation'; FIN text := 'CA Final';
  v_res text[] := '{}';
  v_role text; v_course0 text;
  n_i int; n_f int; n_fin int;
  v_removed uuid; v_paused uuid; v_mast uuid; v_arch_card uuid;
  v_prev jsonb; v_err text; v_state text; v_c int; v_c2 int; v_st text; v_ac text;
  v_a uuid; v_b uuid; v_prof_before int; v_prof_arch int; v_course_now text;
  v_arch_ids uuid[];
BEGIN
  SELECT p.role, p.course_level INTO v_role, v_course0 FROM public.profiles p WHERE p.id = uid;
  IF v_role IS DISTINCT FROM 'student' OR v_course0 IS DISTINCT FROM I THEN
    v_res := v_res || ('0 fixture|student on CA Intermediate|' || COALESCE(v_role,'NULL') || '/' || COALESCE(v_course0,'NULL') || '|SKIP')::text;
    PERFORM set_config('app.t08_results', array_to_string(v_res, chr(10)), true);
    RETURN;
  END IF;

  -- ── fixtures: one manually removed card, one Paused, one Mastered (all CA Intermediate) ──
  SELECT e.flashcard_id INTO v_removed FROM public.my_cards_enrollment e JOIN public.flashcards f ON f.id = e.flashcard_id
   WHERE e.user_id = uid AND e.status = 'active' AND f.target_course = I ORDER BY e.id LIMIT 1;
  SELECT e.flashcard_id INTO v_paused FROM public.my_cards_enrollment e JOIN public.flashcards f ON f.id = e.flashcard_id
   JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
   WHERE e.user_id = uid AND e.status = 'active' AND f.target_course = I AND r.status = 'active' AND e.flashcard_id <> v_removed
   ORDER BY e.id LIMIT 1;
  SELECT e.flashcard_id INTO v_mast FROM public.my_cards_enrollment e JOIN public.flashcards f ON f.id = e.flashcard_id
   JOIN public.reviews r ON r.user_id = e.user_id AND r.flashcard_id = e.flashcard_id
   WHERE e.user_id = uid AND e.status = 'active' AND f.target_course = I AND r.status = 'mastered' LIMIT 1;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.remove_from_my_cards(uid, v_removed);          -- real single-card Remove
    IF v_paused IS NOT NULL THEN PERFORM public.suspend_card(uid, v_paused); END IF;   -- real Pause
  EXCEPTION WHEN OTHERS THEN
    v_res := v_res || ('0 fixture actions (remove/pause as the student)|allowed|' || left(SQLERRM, 60) || '|FAIL')::text;
  END;
  RESET ROLE;

  n_i := pg_temp.cnt(uid, I, 'active'); n_f := pg_temp.cnt(uid, F, 'active'); n_fin := pg_temp.cnt(uid, FIN, 'active');
  v_res := v_res || ('0 fixtures ready (active I / F / Fin)|>0 for I and F|' || n_i || ' / ' || n_f || ' / ' || n_fin || '|' ||
           CASE WHEN n_i > 0 AND n_f > 0 THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ══ S1  I -> F  (real path: client role; preview first, then the update) ══
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    v_prev := public.preview_course_change(F);
    UPDATE public.profiles SET course_level = F WHERE id = uid;
  EXCEPTION WHEN OTHERS THEN
    v_res := v_res || ('S1 I->F as the student|allowed|' || left(SQLERRM, 60) || '|FAIL')::text;
  END;
  RESET ROLE;
  v_res := v_res || ('P  preview shows archive_count = ' || n_i || ' and restore_count = 0|' || n_i || '/0|' ||
           COALESCE(v_prev->>'archive_count', 'NULL') || '/' || COALESCE(v_prev->>'restore_count', 'NULL') || '|' ||
           CASE WHEN (v_prev->>'archive_count')::int = n_i AND (v_prev->>'restore_count')::int = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  v_c := pg_temp.cnt(uid, I, 'course_archived');
  v_res := v_res || ('S1 I->F archives every active I card|' || n_i || '|' || v_c || '|' || CASE WHEN v_c = n_i THEN 'PASS' ELSE 'FAIL' END)::text;
  v_res := v_res || ('S1 no I card left active|0|' || pg_temp.cnt(uid, I, 'active') || '|' || CASE WHEN pg_temp.cnt(uid, I, 'active') = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  v_res := v_res || ('S1 F and Fin cards untouched|' || n_f || '/' || n_fin || '|' || pg_temp.cnt(uid, F, 'active') || '/' || pg_temp.cnt(uid, FIN, 'active') || '|' ||
           CASE WHEN pg_temp.cnt(uid, F, 'active') = n_f AND pg_temp.cnt(uid, FIN, 'active') = n_fin THEN 'PASS' ELSE 'FAIL' END)::text;
  SELECT COUNT(*) INTO v_c FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.status = 'course_archived' AND e.archived_course = I AND e.archived_at IS NOT NULL;
  v_res := v_res || ('S1 archived rows tagged archived_course = CA Intermediate + archived_at set|' || n_i || '|' || v_c || '|' || CASE WHEN v_c = n_i THEN 'PASS' ELSE 'FAIL' END)::text;

  SELECT e.status INTO v_st FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.flashcard_id = v_removed;
  v_res := v_res || ('M  manually removed card is still removed (not archived)|removed|' || COALESCE(v_st,'NULL') || '|' || CASE WHEN v_st = 'removed' THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ── X: archived cards cannot be surfaced or graded ──
  SELECT array_agg(e.flashcard_id) INTO v_arch_ids FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.status = 'course_archived';
  v_arch_card := v_arch_ids[1];
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    SELECT COUNT(*) INTO v_c FROM public.get_my_cards(uid) g WHERE g.id = ANY (v_arch_ids);
    v_res := v_res || ('X  archived cards absent from get_my_cards|0|' || v_c || '|' || CASE WHEN v_c = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('X  archived cards absent from get_my_cards|0|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;
  BEGIN
    SELECT COUNT(*) INTO v_c2 FROM public.get_study_queue(uid) q WHERE q.flashcard_id = ANY (v_arch_ids);
    v_res := v_res || ('X  archived cards absent from get_study_queue|0|' || v_c2 || '|' || CASE WHEN v_c2 = 0 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    v_res := v_res || ('X  archived cards absent from get_study_queue|0|' || left(v_err, 50) || '|FAIL: ' || v_err)::text; END;
  BEGIN
    PERFORM public.apply_review(uid, v_arch_card, 'medium', true, 'review_session', NULL::jsonb);
    v_res := v_res || 'X  apply_review on an archived card is refused|42501|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN v_state := SQLSTATE;
    v_res := v_res || ('X  apply_review on an archived card is refused|42501|' || v_state || '|' || CASE WHEN v_state = '42501' THEN 'PASS' ELSE 'FAIL: ' || SQLERRM END)::text; END;
  RESET ROLE;

  -- ══ S2  F -> I ══
  UPDATE public.profiles SET course_level = I WHERE id = uid;
  v_res := v_res || ('S2 F->I archives every active F card|' || n_f || '|' || pg_temp.cnt(uid, F, 'course_archived') || '|' || CASE WHEN pg_temp.cnt(uid, F, 'course_archived') = n_f THEN 'PASS' ELSE 'FAIL' END)::text;
  v_res := v_res || ('S2 F->I restores the I cards|' || n_i || '|' || pg_temp.cnt(uid, I, 'active') || '|' || CASE WHEN pg_temp.cnt(uid, I, 'active') = n_i THEN 'PASS' ELSE 'FAIL' END)::text;
  v_res := v_res || ('S2 Fin untouched|' || n_fin || '|' || pg_temp.cnt(uid, FIN, 'active') || '|' || CASE WHEN pg_temp.cnt(uid, FIN, 'active') = n_fin THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ══ S3  I -> Fin ══
  UPDATE public.profiles SET course_level = FIN WHERE id = uid;
  v_res := v_res || ('S3 I->Fin archives I; F stays archived; Fin active|' || n_i || '/' || n_f || '/' || n_fin || '|' ||
           pg_temp.cnt(uid, I, 'course_archived') || '/' || pg_temp.cnt(uid, F, 'course_archived') || '/' || pg_temp.cnt(uid, FIN, 'active') || '|' ||
           CASE WHEN pg_temp.cnt(uid, I, 'course_archived') = n_i AND pg_temp.cnt(uid, F, 'course_archived') = n_f AND pg_temp.cnt(uid, FIN, 'active') = n_fin THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ══ S4  Fin -> I ══
  UPDATE public.profiles SET course_level = I WHERE id = uid;
  v_res := v_res || ('S4 Fin->I archives Fin and restores I|' || n_fin || '/' || n_i || '|' ||
           pg_temp.cnt(uid, FIN, 'course_archived') || '/' || pg_temp.cnt(uid, I, 'active') || '|' ||
           CASE WHEN pg_temp.cnt(uid, FIN, 'course_archived') = n_fin AND pg_temp.cnt(uid, I, 'active') = n_i THEN 'PASS' ELSE 'FAIL' END)::text;

  -- R: Paused / Mastered survive the round trip (state lives on reviews, which is never touched)
  IF v_paused IS NOT NULL THEN
    SELECT r.status INTO v_st FROM public.reviews r WHERE r.user_id = uid AND r.flashcard_id = v_paused;
    SELECT e.status INTO v_ac FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.flashcard_id = v_paused;
    v_res := v_res || ('R  Paused card: review suspended, enrollment active again|suspended/active|' || COALESCE(v_st,'NULL') || '/' || COALESCE(v_ac,'NULL') || '|' ||
             CASE WHEN v_st = 'suspended' AND v_ac = 'active' THEN 'PASS' ELSE 'FAIL' END)::text;
  END IF;
  IF v_mast IS NOT NULL THEN
    SELECT r.status INTO v_st FROM public.reviews r WHERE r.user_id = uid AND r.flashcard_id = v_mast;
    v_res := v_res || ('R  Mastered card still mastered|mastered|' || COALESCE(v_st,'NULL') || '|' || CASE WHEN v_st = 'mastered' THEN 'PASS' ELSE 'FAIL' END)::text;
  END IF;

  -- ══ S5  I -> F  (closes A -> B -> C -> A: F restored, I archived again, Fin archived) ══
  UPDATE public.profiles SET course_level = F WHERE id = uid;
  v_res := v_res || ('S5 I->F restores F; I and Fin archived|' || n_f || '/' || n_i || '/' || n_fin || '|' ||
           pg_temp.cnt(uid, F, 'active') || '/' || pg_temp.cnt(uid, I, 'course_archived') || '/' || pg_temp.cnt(uid, FIN, 'course_archived') || '|' ||
           CASE WHEN pg_temp.cnt(uid, F, 'active') = n_f AND pg_temp.cnt(uid, I, 'course_archived') = n_i AND pg_temp.cnt(uid, FIN, 'course_archived') = n_fin THEN 'PASS' ELSE 'FAIL' END)::text;
  SELECT e.status INTO v_st FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.flashcard_id = v_removed;
  v_res := v_res || ('M  removed card still removed after the whole A->B->C->A cycle|removed|' || COALESCE(v_st,'NULL') || '|' || CASE WHEN v_st = 'removed' THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ══ Z  same-course update is a complete no-op ══
  v_c := pg_temp.cnt(uid, F, 'active'); v_c2 := pg_temp.cnt(uid, I, 'course_archived');
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_prev := public.preview_course_change(F);
  UPDATE public.profiles SET course_level = F WHERE id = uid;
  RESET ROLE;
  v_res := v_res || ('Z  same-course: preview is all zeros and flagged same_course|0/0/true|' ||
           (v_prev->>'archive_count') || '/' || (v_prev->>'restore_count') || '/' || (v_prev->>'same_course') || '|' ||
           CASE WHEN (v_prev->>'archive_count') = '0' AND (v_prev->>'restore_count') = '0' AND (v_prev->>'same_course') = 'true' THEN 'PASS' ELSE 'FAIL' END)::text;
  v_res := v_res || ('Z  same-course update changes no enrollment|' || v_c || '/' || v_c2 || '|' || pg_temp.cnt(uid, F, 'active') || '/' || pg_temp.cnt(uid, I, 'course_archived') || '|' ||
           CASE WHEN pg_temp.cnt(uid, F, 'active') = v_c AND pg_temp.cnt(uid, I, 'course_archived') = v_c2 THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ══ N  clearing the course (NULL) changes nothing ══
  UPDATE public.profiles SET course_level = NULL WHERE id = uid;
  v_res := v_res || ('N  course cleared to NULL changes no enrollment|' || v_c || '/' || v_c2 || '|' || pg_temp.cnt(uid, F, 'active') || '/' || pg_temp.cnt(uid, I, 'course_archived') || '|' ||
           CASE WHEN pg_temp.cnt(uid, F, 'active') = v_c AND pg_temp.cnt(uid, I, 'course_archived') = v_c2 THEN 'PASS' ELSE 'FAIL' END)::text;
  UPDATE public.profiles SET course_level = F WHERE id = uid;   -- back to F (NULL -> F: nothing archived, nothing to restore for F)
  v_res := v_res || ('N  NULL -> first course archives nothing|' || v_c || '|' || pg_temp.cnt(uid, F, 'active') || '|' || CASE WHEN pg_temp.cnt(uid, F, 'active') = v_c THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ══ PR  professor: course change archives nothing ══
  SELECT COUNT(*) INTO v_prof_before FROM public.my_cards_enrollment e WHERE e.user_id = prof AND e.status = 'active';
  UPDATE public.profiles SET course_level = CASE WHEN course_level = F THEN FIN ELSE F END WHERE id = prof;
  SELECT COUNT(*) INTO v_prof_arch FROM public.my_cards_enrollment e WHERE e.user_id = prof AND e.status = 'course_archived';
  SELECT COUNT(*) INTO v_c FROM public.my_cards_enrollment e WHERE e.user_id = prof AND e.status = 'active';
  v_res := v_res || ('PR professor course change archives nothing|' || v_prof_before || ' active, 0 archived|' || v_c || ' active, ' || v_prof_arch || ' archived|' ||
           CASE WHEN v_c = v_prof_before AND v_prof_arch = 0 THEN 'PASS' ELSE 'FAIL' END)::text;

  -- ══ AT  an error during archival rolls the course update back too ══
  EXECUTE $q$CREATE FUNCTION public.zz_boom() RETURNS trigger LANGUAGE plpgsql AS $b$ BEGIN RAISE EXCEPTION 'boom'; END $b$ $q$;
  EXECUTE 'CREATE TRIGGER zz_boom BEFORE UPDATE ON public.my_cards_enrollment FOR EACH ROW EXECUTE FUNCTION public.zz_boom()';
  v_c := pg_temp.cnt(uid, F, 'active');
  BEGIN
    UPDATE public.profiles SET course_level = FIN WHERE id = uid;    -- would archive the F rows -> boom
    v_res := v_res || 'AT error during archival aborts the course change|error|no error|FAIL'::text;
  EXCEPTION WHEN OTHERS THEN
    SELECT p.course_level INTO v_course_now FROM public.profiles p WHERE p.id = uid;
    v_res := v_res || ('AT error during archival aborts the course change (course still Foundation, F rows still active)|' || F || '/' || v_c || '|' ||
             COALESCE(v_course_now,'NULL') || '/' || pg_temp.cnt(uid, F, 'active') || '|' ||
             CASE WHEN v_course_now = F AND pg_temp.cnt(uid, F, 'active') = v_c THEN 'PASS' ELSE 'FAIL' END)::text;
  END;
  EXECUTE 'DROP TRIGGER zz_boom ON public.my_cards_enrollment';
  EXECUTE 'DROP FUNCTION public.zz_boom()';

  -- ══ RA  re-adding archived cards restores them and clears the archive columns ══
  SELECT e.flashcard_id INTO v_a FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.status = 'course_archived' AND e.archived_course = I ORDER BY e.id LIMIT 1;
  SELECT e.flashcard_id INTO v_b FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.status = 'course_archived' AND e.archived_course = I AND e.flashcard_id <> v_a ORDER BY e.id LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.add_to_my_cards(uid, v_a);
    RESET ROLE;
    SELECT e.status, e.archived_course INTO v_st, v_ac FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.flashcard_id = v_a;
    v_res := v_res || ('RA add_to_my_cards on an archived card|active/NULL|' || COALESCE(v_st,'NULL') || '/' || COALESCE(v_ac,'NULL') || '|' ||
             CASE WHEN v_st = 'active' AND v_ac IS NULL THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('RA add_to_my_cards on an archived card|active/NULL|' || left(v_err, 50) || '|FAIL (or card not accessible): ' || v_err)::text; END;
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.add_batch_to_my_cards(uid, ARRAY[v_b]);
    RESET ROLE;
    SELECT e.status, e.archived_course INTO v_st, v_ac FROM public.my_cards_enrollment e WHERE e.user_id = uid AND e.flashcard_id = v_b;
    v_res := v_res || ('RA add_batch_to_my_cards on an archived card|active/NULL|' || COALESCE(v_st,'NULL') || '/' || COALESCE(v_ac,'NULL') || '|' ||
             CASE WHEN v_st = 'active' AND v_ac IS NULL THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('RA add_batch_to_my_cards on an archived card|active/NULL|' || left(v_err, 50) || '|FAIL (or card not accessible): ' || v_err)::text; END;

  PERFORM set_config('app.t08_results', array_to_string(ARRAY(SELECT replace(e, chr(10), ' ') FROM unnest(v_res) AS e), chr(10)), true);
END $$;

RESET ROLE;

SELECT ord AS seq,
       split_part(x_, '|', 1) AS check_name,
       split_part(x_, '|', 2) AS expected,
       split_part(x_, '|', 3) AS actual,
       split_part(x_, '|', 4) AS verdict
FROM unnest(string_to_array(current_setting('app.t08_results', true), chr(10))) WITH ORDINALITY AS t(x_, ord)
ORDER BY ord;

ROLLBACK;
