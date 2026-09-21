-- Name: [TEST] Verify Sprint 8.7.6 merge provenance guard (self-rolling-back)
-- Description: Runs real writes on disposable rows inside ONE DO block, then raises an exception at the
--   end so EVERYTHING (test cards, test provenance, temp helpers) is rolled back. The exception message
--   IS the report: expect "RESULT: ALL PASS". Contains no persistent DDL (temp helpers only).
--   Run only AFTER 01 is deployed. Needs 1 profile (2 for the cross-owner case; skipped otherwise).
--   Test cards use custom_subject 't876-subject'. If a NOT NULL column I did not include rejects the
--   insert, paste me the error and I will adjust.

CREATE FUNCTION pg_temp.t_mk(p_batch uuid, p_n int, p_uid uuid, p_type text, p_name text) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_type IS NOT NULL THEN
    INSERT INTO public.flashcard_batch_provenance (batch_id, content_source_type, content_source_name, created_by)
    VALUES (p_batch, p_type, p_name, p_uid);
  END IF;
  INSERT INTO public.flashcards (user_id, contributed_by, creator_id, front_text, back_text, question_type,
                                 visibility, difficulty, batch_id, custom_subject, custom_topic)
  SELECT p_uid, p_uid, p_uid, 't876 q ' || g, 't876 a', 'flashcard', 'private', 'medium', p_batch,
         't876-subject', 't876-topic'
  FROM generate_series(1, p_n) g;
END $$;

CREATE FUNCTION pg_temp.t_try(p_sql text) RETURNS text LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE p_sql;
  RETURN 'OK';
EXCEPTION WHEN OTHERS THEN
  RETURN SQLSTATE || '|' || split_part(SQLERRM, ':', 1);
END $$;

CREATE FUNCTION pg_temp.t_prov(p_batch uuid) RETURNS boolean LANGUAGE sql AS $$
  SELECT EXISTS (SELECT 1 FROM public.flashcard_batch_provenance WHERE batch_id = p_batch) $$;

DO $$
DECLARE
  u1 uuid; u2 uuid;
  a uuid; b uuid; c uuid; r text; res text := ''; fails int := 0;
  mv text := 'UPDATE public.flashcards SET batch_id = %L WHERE batch_id IN (%L, %L)';
BEGIN
  SELECT id INTO u1 FROM public.profiles ORDER BY id LIMIT 1;
  SELECT id INTO u2 FROM public.profiles ORDER BY id OFFSET 1 LIMIT 1;

  -- T1 identical provenance: allowed, old row gone, target row stays
  a := gen_random_uuid(); b := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,2,u1,'official_body','ICAI'); PERFORM pg_temp.t_mk(b,2,u1,'official_body','ICAI');
  r := pg_temp.t_try(format(mv,a,a,b));
  IF r = 'OK' AND pg_temp.t_prov(a) AND NOT pg_temp.t_prov(b)
     AND (SELECT count(*) FROM public.flashcards WHERE batch_id=a)=4 THEN res:=res||E'\nT1 identical merge: PASS';
  ELSE res:=res||E'\nT1 identical merge: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T2 different source type: blocked, nothing changed
  a := gen_random_uuid(); b := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,1,u1,'official_body','ICAI'); PERFORM pg_temp.t_mk(b,1,u1,'original_creator','ICAI');
  r := pg_temp.t_try(format(mv,a,a,b));
  IF r = 'RV601|MERGE_PROVENANCE_MISMATCH' AND pg_temp.t_prov(b) AND (SELECT count(*) FROM public.flashcards WHERE batch_id=b)=1
  THEN res:=res||E'\nT2 different type blocked: PASS'; ELSE res:=res||E'\nT2 different type blocked: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T3 different source name: blocked
  a := gen_random_uuid(); b := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,1,u1,'official_body','ICAI'); PERFORM pg_temp.t_mk(b,1,u1,'official_body','ICMAI');
  r := pg_temp.t_try(format(mv,a,a,b));
  IF r = 'RV601|MERGE_PROVENANCE_MISMATCH' AND pg_temp.t_prov(b)
  THEN res:=res||E'\nT3 different name blocked: PASS'; ELSE res:=res||E'\nT3 different name blocked: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T3b name differs only by capitals: strict = blocked
  a := gen_random_uuid(); b := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,1,u1,'official_body','ICAI'); PERFORM pg_temp.t_mk(b,1,u1,'official_body','icai');
  r := pg_temp.t_try(format(mv,a,a,b));
  IF r = 'RV601|MERGE_PROVENANCE_MISMATCH' THEN res:=res||E'\nT3b strict name match: PASS'; ELSE res:=res||E'\nT3b strict name match: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T4 provenance vs legacy, both directions: blocked
  a := gen_random_uuid(); b := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,1,u1,'official_body','ICAI'); PERFORM pg_temp.t_mk(b,1,u1,NULL,NULL);
  r := pg_temp.t_try(format(mv,a,a,b));
  IF r = 'RV601|MERGE_PROVENANCE_MISMATCH' AND pg_temp.t_try(format(mv,b,a,b)) = 'RV601|MERGE_PROVENANCE_MISMATCH' AND pg_temp.t_prov(a)
  THEN res:=res||E'\nT4 provenance vs legacy blocked (both ways): PASS'; ELSE res:=res||E'\nT4 provenance vs legacy: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T5 legacy vs legacy: allowed
  a := gen_random_uuid(); b := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,1,u1,NULL,NULL); PERFORM pg_temp.t_mk(b,2,u1,NULL,NULL);
  r := pg_temp.t_try(format(mv,a,a,b));
  IF r = 'OK' AND (SELECT count(*) FROM public.flashcards WHERE batch_id=a)=3
  THEN res:=res||E'\nT5 legacy merge: PASS'; ELSE res:=res||E'\nT5 legacy merge: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T6 partial move: row stays while any card remains
  a := gen_random_uuid(); b := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,1,u1,'original_creator','Me'); PERFORM pg_temp.t_mk(b,2,u1,'original_creator','Me');
  r := pg_temp.t_try(format('UPDATE public.flashcards SET batch_id=%L WHERE id=(SELECT id FROM public.flashcards WHERE batch_id=%L LIMIT 1)',a,b));
  IF r = 'OK' AND pg_temp.t_prov(b) AND (SELECT count(*) FROM public.flashcards WHERE batch_id=b)=1
  THEN res:=res||E'\nT6 partial move keeps row: PASS'; ELSE res:=res||E'\nT6 partial move: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T7 three batches in one statement (a is target; b and c merged away)
  a := gen_random_uuid(); b := gen_random_uuid(); c := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,1,u1,'official_body','ICAI'); PERFORM pg_temp.t_mk(b,1,u1,'official_body','ICAI'); PERFORM pg_temp.t_mk(c,1,u1,'official_body','ICAI');
  r := pg_temp.t_try(format('UPDATE public.flashcards SET batch_id=%L WHERE batch_id IN (%L,%L,%L)',a,a,b,c));
  IF r = 'OK' AND pg_temp.t_prov(a) AND NOT pg_temp.t_prov(b) AND NOT pg_temp.t_prov(c)
  THEN res:=res||E'\nT7 three-way merge: PASS'; ELSE res:=res||E'\nT7 three-way merge: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T8 invented target batch (no cards): blocked
  a := gen_random_uuid(); b := gen_random_uuid();
  PERFORM pg_temp.t_mk(b,1,u1,'official_body','ICAI');
  r := pg_temp.t_try(format('UPDATE public.flashcards SET batch_id=%L WHERE batch_id=%L',a,b));
  IF r = 'RV601|MERGE_TARGET_INVALID' AND pg_temp.t_prov(b) THEN res:=res||E'\nT8 invented target blocked: PASS'; ELSE res:=res||E'\nT8 invented target: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T9 move to NULL blocked
  r := pg_temp.t_try(format('UPDATE public.flashcards SET batch_id=NULL WHERE batch_id=%L',b));
  IF r = 'RV601|MERGE_TARGET_INVALID' THEN res:=res||E'\nT9 NULL batch blocked: PASS'; ELSE res:=res||E'\nT9 NULL batch: FAIL ('||r||')'; fails:=fails+1; END IF;

  -- T10 another owner's batch as target: blocked (needs 2 profiles)
  IF u2 IS NOT NULL THEN
    a := gen_random_uuid(); b := gen_random_uuid();
    PERFORM pg_temp.t_mk(a,1,u2,'official_body','ICAI'); PERFORM pg_temp.t_mk(b,1,u1,'official_body','ICAI');
    r := pg_temp.t_try(format('UPDATE public.flashcards SET batch_id=%L WHERE batch_id=%L',a,b));
    IF r = 'RV601|MERGE_TARGET_INVALID' THEN res:=res||E'\nT10 foreign-owner target blocked: PASS'; ELSE res:=res||E'\nT10 foreign-owner target: FAIL ('||r||')'; fails:=fails+1; END IF;
  ELSE res:=res||E'\nT10 skipped (only one profile)'; END IF;

  -- T11 ordinary edit with no batch change: fine, provenance untouched
  a := gen_random_uuid();
  PERFORM pg_temp.t_mk(a,2,u1,'official_body','ICAI');
  r := pg_temp.t_try(format('UPDATE public.flashcards SET back_text=%L, batch_id=batch_id WHERE batch_id=%L','edited',a));
  IF r = 'OK' AND pg_temp.t_prov(a) THEN res:=res||E'\nT11 no-op edit: PASS'; ELSE res:=res||E'\nT11 no-op edit: FAIL ('||r||')'; fails:=fails+1; END IF;

  RAISE EXCEPTION E'8.7.6 TEST REPORT (all test data rolled back):%\nRESULT: %', res,
    CASE WHEN fails = 0 THEN 'ALL PASS' ELSE fails || ' FAILED' END;
END $$;
