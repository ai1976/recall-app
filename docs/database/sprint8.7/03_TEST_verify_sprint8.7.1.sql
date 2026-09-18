-- Name: [TEST] Verify Sprint 8.7.1 — provenance foundation (T1-T8)
--
-- Description: Post-deploy live verification for 01_SCHEMA + 02_FUNCTIONS.
-- Impersonates real profiles via request.jwt.claims + SET LOCAL ROLE authenticated
-- (same idiom as sprint8.6c/03_TEST, itself following sprint7.5/02_TEST — the
-- Supabase SQL Editor connection is a superuser/table-owner role, and RLS is
-- bypassed entirely for that role regardless of jwt claims, so every RLS-relevant
-- statement below is wrapped in SET LOCAL ROLE authenticated / RESET ROLE).
-- Everything runs inside BEGIN...ROLLBACK — nothing is committed, including the
-- T6 happy-path rows and the T4 legacy-note edit.
--
-- Run AFTER 01_SCHEMA and 02_FUNCTIONS are both committed.
-- Requires: at least 2 profiles with role='student' and 1 profile with role IN
-- ('professor','admin','super_admin'), and at least 1 existing note with
-- content_source_type IS NULL (any legacy note). If any fixture is missing the
-- relevant test rows SKIP rather than false-PASS/FAIL.

BEGIN;

CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);
CREATE TEMP TABLE _fx(k text PRIMARY KEY, v text);
GRANT SELECT, INSERT, UPDATE ON _r, _fx TO authenticated;

-- ══ Fixtures ════════════════════════════════════════════════════════════
DO $$
DECLARE v_student uuid; v_student2 uuid; v_prof uuid; v_note uuid; v_note_owner uuid; v_note_desc text;
BEGIN
  SELECT id INTO v_prof FROM public.profiles WHERE role IN ('professor','admin','super_admin') LIMIT 1;
  SELECT id INTO v_student FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_student2 FROM public.profiles WHERE role = 'student' AND id <> COALESCE(v_student, '00000000-0000-0000-0000-000000000000'::uuid) LIMIT 1;
  SELECT id, user_id, description INTO v_note, v_note_owner, v_note_desc
  FROM public.notes WHERE content_source_type IS NULL LIMIT 1;

  IF v_prof IS NOT NULL THEN INSERT INTO _fx VALUES ('prof', v_prof::text); END IF;
  IF v_student IS NOT NULL THEN INSERT INTO _fx VALUES ('student', v_student::text); END IF;
  IF v_student2 IS NOT NULL THEN INSERT INTO _fx VALUES ('student2', v_student2::text); END IF;
  IF v_note IS NOT NULL THEN
    INSERT INTO _fx VALUES ('note', v_note::text), ('note_owner', v_note_owner::text), ('note_desc', COALESCE(v_note_desc, ''));
  END IF;
END $$;

-- ══ T1 — direct flashcard bypass: fresh batch_id, no provenance row → fail ═
DO $$
DECLARE v_student uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN
    INSERT INTO _r VALUES ('T1 direct flashcard insert w/o provenance', 'RLS rejection', 'no student fixture', 'SKIP'); RETURN;
  END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_student uuid; v_batch uuid; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN RETURN; END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  v_batch := gen_random_uuid();
  BEGIN
    INSERT INTO public.flashcards (user_id, front_text, back_text, visibility, question_type, batch_id)
    VALUES (v_student, 'T1 front', 'T1 back', 'private', 'flashcard', v_batch);
    INSERT INTO _r VALUES ('T1 direct flashcard insert w/o provenance [CRITICAL]', 'RLS rejection', 'insert succeeded', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T1 direct flashcard insert w/o provenance [CRITICAL]', 'RLS rejection', left(v_err, 60),
      CASE WHEN v_err ILIKE '%row-level security%' OR v_err ILIKE '%policy%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
END $$;

RESET ROLE;

-- ══ T2 — provenance-table bypass: ordinary authenticated cannot INSERT/UPDATE/DELETE ═
DO $$
DECLARE v_student uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN RETURN; END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN
    INSERT INTO _r VALUES ('T2 direct provenance INSERT blocked', 'denied', 'no student fixture', 'SKIP'); RETURN;
  END IF;
  BEGIN
    INSERT INTO public.flashcard_batch_provenance (batch_id, content_source_type, content_source_name)
    VALUES (gen_random_uuid(), 'official_body', 'T2 bypass attempt');
    INSERT INTO _r VALUES ('T2 direct provenance INSERT blocked [CRITICAL]', 'denied', 'insert succeeded', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T2 direct provenance INSERT blocked [CRITICAL]', 'denied', left(v_err, 60), 'PASS');
  END;
END $$;

DO $$
DECLARE v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN
    INSERT INTO _r VALUES ('T2b direct provenance UPDATE blocked', 'denied', 'no student fixture', 'SKIP'); RETURN;
  END IF;
  BEGIN
    UPDATE public.flashcard_batch_provenance SET content_source_name = 'tampered' WHERE true;
    INSERT INTO _r VALUES ('T2b direct provenance UPDATE blocked', 'denied', 'update succeeded (or 0 rows, not an error)', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T2b direct provenance UPDATE blocked', 'denied', left(v_err, 60), 'PASS');
  END;
END $$;

DO $$
DECLARE v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN
    INSERT INTO _r VALUES ('T2c direct provenance DELETE blocked', 'denied', 'no student fixture', 'SKIP'); RETURN;
  END IF;
  BEGIN
    DELETE FROM public.flashcard_batch_provenance WHERE true;
    INSERT INTO _r VALUES ('T2c direct provenance DELETE blocked', 'denied', 'delete succeeded (or 0 rows, not an error)', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T2c direct provenance DELETE blocked', 'denied', left(v_err, 60), 'PASS');
  END;
END $$;

RESET ROLE;

-- ══ T3 — missing note provenance: valid note insert omitting provenance → fail ═
DO $$
DECLARE v_student uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN RETURN; END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_student uuid; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN
    INSERT INTO _r VALUES ('T3 note insert w/o provenance blocked by trigger', 'trigger rejection', 'no student fixture', 'SKIP'); RETURN;
  END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  BEGIN
    INSERT INTO public.notes (user_id, title) VALUES (v_student, 'T3 note w/o provenance');
    INSERT INTO _r VALUES ('T3 note insert w/o provenance blocked by trigger [CRITICAL]', 'trigger rejection', 'insert succeeded', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T3 note insert w/o provenance blocked by trigger [CRITICAL]', 'trigger rejection', left(v_err, 70),
      CASE WHEN v_err ILIKE '%content_source_type and content_source_name are required%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
END $$;

RESET ROLE;

-- ══ T4 — legacy note edit: owner updates a harmless field on a NULL-provenance note → succeeds ═
DO $$
DECLARE v_owner uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'note') THEN RETURN; END IF;
  SELECT v::uuid INTO v_owner FROM _fx WHERE k = 'note_owner';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_owner, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_note uuid; v_owner uuid; v_desc text; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'note') THEN
    INSERT INTO _r VALUES ('T4 legacy note edit stays allowed', 'update succeeds', 'no legacy-note fixture', 'SKIP'); RETURN;
  END IF;
  SELECT v::uuid INTO v_note FROM _fx WHERE k = 'note';
  SELECT v::uuid INTO v_owner FROM _fx WHERE k = 'note_owner';
  SELECT v INTO v_desc FROM _fx WHERE k = 'note_desc';
  BEGIN
    UPDATE public.notes SET description = COALESCE(v_desc, '') || ' [t4-touch]' WHERE id = v_note AND user_id = v_owner;
    INSERT INTO _r VALUES ('T4 legacy note edit stays allowed [CRITICAL]', 'update succeeds', 'succeeded', 'PASS');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T4 legacy note edit stays allowed [CRITICAL]', 'update succeeds', 'FAIL: '||left(v_err, 60), 'FAIL');
  END;
END $$;

RESET ROLE;

-- verify content_source_type is still NULL after T4's edit (trigger is INSERT-only)
DO $$
DECLARE v_note uuid; v_type text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'note') THEN RETURN; END IF;
  SELECT v::uuid INTO v_note FROM _fx WHERE k = 'note';
  SELECT content_source_type INTO v_type FROM public.notes WHERE id = v_note;
  INSERT INTO _r VALUES ('T4b legacy note still has NULL provenance after edit', 'NULL', COALESCE(v_type, 'NULL'),
    CASE WHEN v_type IS NULL THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ T5 / T6 — RPC as professor: happy path, duplicate batch_id, invalid-card atomicity ═
DO $$
DECLARE v_prof uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') THEN RETURN; END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_prof uuid; v_batch uuid; v_payload jsonb; v_returned_count int; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') THEN
    INSERT INTO _r VALUES ('T6 happy-path RPC atomicity', 'provenance + 2 cards', 'no professor fixture', 'SKIP'); RETURN;
  END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  v_batch := gen_random_uuid();
  INSERT INTO _fx VALUES ('t6_batch', v_batch::text);

  v_payload := jsonb_build_array(jsonb_build_object(
    'batch_id', v_batch,
    'cards', jsonb_build_array(
      jsonb_build_object('question_type', 'flashcard', 'front_text', 'T6 card 1 front', 'back_text', 'T6 card 1 back', 'visibility', 'private'),
      jsonb_build_object('question_type', 'flashcard', 'front_text', 'T6 card 2 front', 'back_text', 'T6 card 2 back', 'visibility', 'private')
    )
  ));

  BEGIN
    SELECT card_count INTO v_returned_count FROM public.create_flashcard_batches('official_body', 'T6 Test Source', v_payload);
    INSERT INTO _r VALUES ('T6 happy-path RPC atomicity [CRITICAL]', '2 cards', v_returned_count::text,
      CASE WHEN v_returned_count = 2 THEN 'PASS' ELSE 'FAIL' END);
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T6 happy-path RPC atomicity [CRITICAL]', '2 cards', 'FAIL: '||left(v_err, 80), 'FAIL');
  END;
END $$;

RESET ROLE;

-- verify provenance + cards actually landed, and created_by is correct (owner-role introspection)
DO $$
DECLARE v_batch uuid; v_prof uuid; v_prov_count int; v_card_count int; v_created_by uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 't6_batch') THEN RETURN; END IF;
  SELECT v::uuid INTO v_batch FROM _fx WHERE k = 't6_batch';
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';

  SELECT count(*) INTO v_prov_count FROM public.flashcard_batch_provenance WHERE batch_id = v_batch;
  SELECT created_by INTO v_created_by FROM public.flashcard_batch_provenance WHERE batch_id = v_batch LIMIT 1;
  INSERT INTO _r VALUES ('T6b exactly 1 provenance row, created_by correct', '1 row, created_by=prof',
    v_prov_count::text || ' row(s), created_by=' || COALESCE(v_created_by::text, 'NULL'),
    CASE WHEN v_prov_count = 1 AND v_created_by = v_prof THEN 'PASS' ELSE 'FAIL' END);

  SELECT count(*) INTO v_card_count FROM public.flashcards WHERE batch_id = v_batch;
  INSERT INTO _r VALUES ('T6c both cards reference the batch', '2', v_card_count::text,
    CASE WHEN v_card_count = 2 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ T5 — calling RPC again against the same (now-provenanced) batch_id fails ═
DO $$
DECLARE v_prof uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') THEN RETURN; END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_batch uuid; v_payload jsonb; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 't6_batch') THEN
    INSERT INTO _r VALUES ('T5 duplicate batch_id rejected', 'rejected', 'no t6_batch fixture', 'SKIP'); RETURN;
  END IF;
  SELECT v::uuid INTO v_batch FROM _fx WHERE k = 't6_batch';
  v_payload := jsonb_build_array(jsonb_build_object(
    'batch_id', v_batch,
    'cards', jsonb_build_array(jsonb_build_object('question_type', 'flashcard', 'front_text', 'x', 'back_text', 'y'))
  ));
  BEGIN
    PERFORM * FROM public.create_flashcard_batches('official_body', 'T5 reuse attempt', v_payload);
    INSERT INTO _r VALUES ('T5 duplicate batch_id rejected [CRITICAL]', 'rejected', 'succeeded (overwrite!)', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T5 duplicate batch_id rejected [CRITICAL]', 'rejected', left(v_err, 70), 'PASS');
  END;
END $$;

RESET ROLE;

-- ══ T6 (part 2) — multi-card call with one invalid card: zero rows survive ═
DO $$
DECLARE v_prof uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') THEN RETURN; END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_prof, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_prof uuid; v_batch uuid; v_payload jsonb; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'prof') THEN
    INSERT INTO _r VALUES ('T6d invalid-card call fails atomically', 'rejected, 0 rows', 'no professor fixture', 'SKIP'); RETURN;
  END IF;
  SELECT v::uuid INTO v_prof FROM _fx WHERE k = 'prof';
  v_batch := gen_random_uuid();
  INSERT INTO _fx VALUES ('t6d_batch', v_batch::text);

  v_payload := jsonb_build_array(jsonb_build_object(
    'batch_id', v_batch,
    'cards', jsonb_build_array(
      jsonb_build_object('question_type', 'flashcard', 'front_text', 'valid card', 'back_text', 'valid back'),
      jsonb_build_object('question_type', 'flashcard', 'back_text', 'missing front_text — invalid')
    )
  ));
  BEGIN
    PERFORM * FROM public.create_flashcard_batches('official_body', 'T6d Test Source', v_payload);
    INSERT INTO _r VALUES ('T6d invalid-card call fails atomically [CRITICAL]', 'rejected, 0 rows', 'succeeded (should have failed)', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T6d invalid-card call fails atomically [CRITICAL]', 'rejected, 0 rows', left(v_err, 60), 'PASS');
  END;
END $$;

RESET ROLE;

DO $$
DECLARE v_batch uuid; v_prov_count int; v_card_count int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 't6d_batch') THEN RETURN; END IF;
  SELECT v::uuid INTO v_batch FROM _fx WHERE k = 't6d_batch';
  SELECT count(*) INTO v_prov_count FROM public.flashcard_batch_provenance WHERE batch_id = v_batch;
  SELECT count(*) INTO v_card_count FROM public.flashcards WHERE batch_id = v_batch;
  INSERT INTO _r VALUES ('T6e zero provenance + zero cards survive failed call [CRITICAL]', '0, 0',
    v_prov_count::text || ', ' || v_card_count::text,
    CASE WHEN v_prov_count = 0 AND v_card_count = 0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ T7 — privilege escalation attempt: student tries mcq via RPC → rejected ═
DO $$
DECLARE v_student uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN RETURN; END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_student, 'role', 'authenticated')::text, true);
END $$;

SET LOCAL ROLE authenticated;

DO $$
DECLARE v_student uuid; v_batch uuid; v_payload jsonb; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') THEN
    INSERT INTO _r VALUES ('T7 student blocked from mcq via RPC', 'rejected', 'no student fixture', 'SKIP'); RETURN;
  END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  v_batch := gen_random_uuid();
  v_payload := jsonb_build_array(jsonb_build_object(
    'batch_id', v_batch,
    'cards', jsonb_build_array(jsonb_build_object(
      'question_type', 'mcq', 'front_text', 'T7 front', 'back_text', 'T7 back',
      'options', '["a","b"]'::jsonb, 'correct_answer', '0'
    ))
  ));
  BEGIN
    PERFORM * FROM public.create_flashcard_batches('official_body', 'T7 escalation attempt', v_payload);
    INSERT INTO _r VALUES ('T7 student blocked from mcq via RPC [CRITICAL]', 'rejected', 'succeeded (privilege escalation!)', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T7 student blocked from mcq via RPC [CRITICAL]', 'rejected', left(v_err, 70),
      CASE WHEN v_err ILIKE '%verdict-bearing%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
END $$;

-- T7b — student attempts to supply another user's user_id in the card payload
DO $$
DECLARE v_student uuid; v_student2 uuid; v_batch uuid; v_payload jsonb; v_err text;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student') OR NOT EXISTS (SELECT 1 FROM _fx WHERE k = 'student2') THEN
    INSERT INTO _r VALUES ('T7b caller-supplied user_id rejected', 'rejected', 'missing student/student2 fixture', 'SKIP'); RETURN;
  END IF;
  SELECT v::uuid INTO v_student FROM _fx WHERE k = 'student';
  SELECT v::uuid INTO v_student2 FROM _fx WHERE k = 'student2';
  v_batch := gen_random_uuid();
  v_payload := jsonb_build_array(jsonb_build_object(
    'batch_id', v_batch,
    'cards', jsonb_build_array(jsonb_build_object(
      'question_type', 'flashcard', 'front_text', 'T7b front', 'back_text', 'T7b back', 'user_id', v_student2
    ))
  ));
  BEGIN
    PERFORM * FROM public.create_flashcard_batches('official_body', 'T7b escalation attempt', v_payload);
    INSERT INTO _r VALUES ('T7b caller-supplied user_id rejected [CRITICAL]', 'rejected', 'succeeded (ownership injection!)', 'FAIL');
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM;
    INSERT INTO _r VALUES ('T7b caller-supplied user_id rejected [CRITICAL]', 'rejected', left(v_err, 70),
      CASE WHEN v_err ILIKE '%server-derived%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;
END $$;

RESET ROLE;

-- confirm neither T7 nor T7b left any rows behind
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM public.flashcards WHERE front_text IN ('T7 front', 'T7b front');
  INSERT INTO _r VALUES ('T7c no rows survive from either escalation attempt', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ T8 — anon/PUBLIC execution privileges (metadata check, no role needed) ═
DO $$
DECLARE v_authenticated_has boolean; v_anon_has boolean; v_public_has boolean;
BEGIN
  SELECT has_function_privilege('authenticated', 'public.create_flashcard_batches(text,text,jsonb)', 'EXECUTE') INTO v_authenticated_has;
  SELECT has_function_privilege('anon', 'public.create_flashcard_batches(text,text,jsonb)', 'EXECUTE') INTO v_anon_has;
  -- PUBLIC is a pseudo-role, not a nameable role for has_function_privilege's
  -- role argument — check the ACL directly via information_schema instead.
  SELECT EXISTS (
    SELECT 1 FROM information_schema.routine_privileges
    WHERE routine_schema = 'public' AND routine_name = 'create_flashcard_batches' AND grantee = 'PUBLIC'
  ) INTO v_public_has;

  INSERT INTO _r VALUES ('T8a authenticated CAN execute create_flashcard_batches', 'true', v_authenticated_has::text,
    CASE WHEN v_authenticated_has THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('T8b anon CANNOT execute create_flashcard_batches [CRITICAL]', 'false', v_anon_has::text,
    CASE WHEN NOT v_anon_has THEN 'PASS' ELSE 'FAIL' END);
  INSERT INTO _r VALUES ('T8c PUBLIC has no EXECUTE grant [CRITICAL]', 'false', v_public_has::text,
    CASE WHEN NOT v_public_has THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ══ Summary ═════════════════════════════════════════════════════════════
SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;

ROLLBACK;
