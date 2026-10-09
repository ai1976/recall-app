-- Name: [TEST] T-002 B-05 TEST (v1) - verify the flashcards and notes course trigger and the composite keys (rollback-only)
--
-- Description: Verification for B-05_SCHEMA_flashcards-notes-course-derive_v1.sql, run AFTER it. Sets transaction-local lock_timeout 5 s and statement_timeout 30 s first. Persists nothing: one temporary function and one
-- temporary table; every row it creates lives in a sub-transaction that is rolled back (one sub-transaction per case), and the file proves at the end that flashcards and notes are byte-for-byte what they were (row
-- count and a hash over every column of every row). Run the whole file as ONE selection; it returns one row per check with pass true or false, then a summary row (a missing result counts as false). Every check must
-- be true. Stop and report on any false or any SQL error; do not edit and re-run.
-- It proves, on BOTH tables with the same cases: the trigger, function and ACL as built; the older triggers and all constraints unchanged; the two composite NOT VALID keys; every insert and update case of plan v18
-- section 7 (the seven subsets of S, D, T with valid, NULL and unknown identifiers, platform to custom and custom to platform edits, legacy rows that stay editable, conflict rows that are refused when S, D or T changes
-- and are never repaired, unrelated edits that do not fire the trigger); and, as the real role authenticated (JWT claims plus SET LOCAL ROLE), a note insert with a subject only and a flashcard update of S.
-- Fixture contract (plan v18 section 7, NB3): legacy-shaped and conflict rows cannot be created through the trigger, so inside the case's own sub-transaction, as the owner, only the exact B-05 trigger of that table
-- is disabled with ALTER TABLE ... DISABLE TRIGGER (bounded by the timeouts above), the fixture row is inserted, the trigger is re-enabled and its enabled state is asserted before the case runs; the sub-transaction is
-- always rolled back, so the trigger state is restored by the rollback and re-asserted at the end. These owner-run cases never claim real-role coverage.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

CREATE OR REPLACE FUNCTION pg_temp.b05_run_case(p_tbl text, p_case jsonb, p_user uuid, p_s1 uuid, p_s2 uuid, p_s3 uuid, p_d1 uuid, p_d2 uuid, p_n1 text, p_n2 text, p_tag text)
RETURNS text
LANGUAGE plpgsql
AS $c$
DECLARE
  v_trg   text := CASE p_tbl WHEN 'flashcards' THEN 'trg_flashcards_course_derive_guard' ELSE 'trg_notes_course_derive_guard' END;
  v_cols  text := CASE p_tbl WHEN 'flashcards' THEN '(user_id, front_text, back_text, subject_id, discipline_id, target_course)' ELSE '(user_id, title, content_source_type, content_source_name, subject_id, discipline_id, target_course)' END;
  v_pre   text := CASE p_tbl WHEN 'flashcards' THEN quote_literal(p_user) || ', ''ZZ b05'', ''ZZ b05''' ELSE quote_literal(p_user) || ', ''ZZ b05 ' || p_tag || ''', ''original_creator'', ''ZZ b05''' END;
  v_setup text := p_case->>'s';
  v_op    text := p_case->>'o';
  v_x     text := p_case->>'x';
  v_id    uuid;
  v_res   text;
  v_d     uuid;
  v_t     text;
  v_cu    text := 'ZZ Custom ' || p_tag;
  v_en    text;
  a       text[];
BEGIN
  v_x := replace(replace(replace(replace(replace(replace(replace(replace(replace(v_x, '%s1%', quote_literal(p_s1)), '%s2%', quote_literal(p_s2)), '%s3%', quote_literal(p_s3)), '%d1%', quote_literal(p_d1)), '%d2%', quote_literal(p_d2)), '%n1%', quote_literal(p_n1)), '%n2%', quote_literal(p_n2)), '%TAG%', p_tag), 'ZZ Custom ' || p_tag, 'ZZ Custom ' || p_tag);
  BEGIN
    IF v_setup IN ('L', 'C1', 'C2', 'FK') THEN
      EXECUTE format('ALTER TABLE public.%I DISABLE TRIGGER %I', p_tbl, v_trg);
    END IF;
    IF v_setup = 'L' THEN
      EXECUTE format('INSERT INTO public.%I %s VALUES (%s, %L, NULL, %L) RETURNING id', p_tbl, v_cols, v_pre, p_s1, p_n1) INTO v_id;
    ELSIF v_setup = 'C1' THEN
      EXECUTE format('INSERT INTO public.%I %s VALUES (%s, %L, NULL, NULL) RETURNING id', p_tbl, v_cols, v_pre, p_s1) INTO v_id;
    ELSIF v_setup = 'C2' THEN
      EXECUTE format('INSERT INTO public.%I %s VALUES (%s, NULL, %L, NULL) RETURNING id', p_tbl, v_cols, v_pre, p_d1) INTO v_id;
    ELSIF v_setup = 'Dn' THEN
      EXECUTE format('INSERT INTO public.%I %s VALUES (%s, NULL, %L, NULL) RETURNING id', p_tbl, v_cols, v_pre, p_d1) INTO v_id;
    ELSIF v_setup = 'Cu' THEN
      EXECUTE format('INSERT INTO public.%I %s VALUES (%s, NULL, NULL, %L) RETURNING id', p_tbl, v_cols, v_pre, v_cu) INTO v_id;
    END IF;
    IF v_setup IN ('L', 'C1', 'C2', 'FK') THEN
      IF v_setup <> 'FK' THEN
        EXECUTE format('ALTER TABLE public.%I ENABLE TRIGGER %I', p_tbl, v_trg);
        SELECT t.tgenabled::text INTO v_en FROM pg_trigger t WHERE t.tgrelid = ('public.' || p_tbl)::regclass AND t.tgname = v_trg;
        IF v_en IS DISTINCT FROM 'O' THEN
          RAISE EXCEPTION 'b05_fixture_error: trigger not re-enabled';
        END IF;
      END IF;
    END IF;
    BEGIN
      IF v_op = 'I' THEN
        a := string_to_array(v_x, '|');
        EXECUTE format('INSERT INTO public.%I %s VALUES (%s, %s, %s, %s) RETURNING id', p_tbl, v_cols, v_pre, a[1], a[2], a[3]) INTO v_id;
      ELSE
        EXECUTE format('UPDATE public.%I SET %s WHERE id = %L', p_tbl, v_x, v_id);
      END IF;
      EXECUTE format('SELECT discipline_id, target_course FROM public.%I WHERE id = %L', p_tbl, v_id) INTO v_d, v_t;
      v_res := 'D=' || CASE WHEN v_d IS NULL THEN 'NULL' WHEN v_d = p_d1 THEN 'd1' WHEN v_d = p_d2 THEN 'd2' ELSE 'other' END
            || ';T=' || CASE WHEN v_t IS NULL THEN 'NULL' WHEN v_t = p_n1 THEN 'n1' WHEN v_t = p_n2 THEN 'n2' WHEN v_t = v_cu THEN 'CU' ELSE v_t END;
    EXCEPTION WHEN OTHERS THEN
      v_res := SQLSTATE;
    END;
    RAISE EXCEPTION 'b05_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'b05_rollback_marker' THEN
      v_res := 'fixture-error:' || SQLERRM;
    END IF;
  WHEN OTHERS THEN
    v_res := 'setup-error:' || SQLSTATE;
  END;
  RETURN v_res;
END;
$c$;

CREATE OR REPLACE FUNCTION pg_temp.b05_checks()
RETURNS TABLE(check_name text, pass boolean, detail text)
LANGUAGE plpgsql
AS $test$
DECLARE
  v_user    uuid;
  v_d1      uuid;
  v_d2      uuid;
  v_n1      text;
  v_n2      text;
  v_s1      uuid;
  v_s2      uuid;
  v_s3      uuid;
  v_tag     text := to_char(clock_timestamp(), 'HH24MISSUS');
  v_fn0     integer;
  v_fh0     text;
  v_nn0     integer;
  v_nh0     text;
  v_bad     text;
  v_res     text;
  v_state   text;
  v_id      uuid;
  v_d       uuid;
  v_t       text;
  v_cases   jsonb := $j$[
 {
  "n": "insert S only",
  "s": "N",
  "o": "I",
  "x": "%s1%|NULL|NULL",
  "e": "D=d1;T=n1"
 },
 {
  "n": "insert S and the right T",
  "s": "N",
  "o": "I",
  "x": "%s1%|NULL|%n1%",
  "e": "D=d1;T=n1"
 },
 {
  "n": "insert S and a wrong T (T is replaced)",
  "s": "N",
  "o": "I",
  "x": "%s1%|NULL|'ZZ Foo'",
  "e": "D=d1;T=n1"
 },
 {
  "n": "insert S and D = DS",
  "s": "N",
  "o": "I",
  "x": "%s1%|%d1%|NULL",
  "e": "D=d1;T=n1"
 },
 {
  "n": "insert S and D different from DS refused",
  "s": "N",
  "o": "I",
  "x": "%s1%|%d2%|NULL",
  "e": "23514"
 },
 {
  "n": "insert S, D and T consistent",
  "s": "N",
  "o": "I",
  "x": "%s1%|%d1%|%n1%",
  "e": "D=d1;T=n1"
 },
 {
  "n": "insert S of the other discipline",
  "s": "N",
  "o": "I",
  "x": "%s3%|NULL|NULL",
  "e": "D=d2;T=n2"
 },
 {
  "n": "insert D only",
  "s": "N",
  "o": "I",
  "x": "NULL|%d1%|NULL",
  "e": "D=d1;T=n1"
 },
 {
  "n": "insert D and a wrong T (T is replaced)",
  "s": "N",
  "o": "I",
  "x": "NULL|%d1%|'ZZ Foo'",
  "e": "D=d1;T=n1"
 },
 {
  "n": "insert T only, a discipline name in other case and spacing",
  "s": "N",
  "o": "I",
  "x": "NULL|NULL|regexp_replace(lower(%n1%), ' ', '   ', 'g')",
  "e": "D=d1;T=n1"
 },
 {
  "n": "insert T only, a custom course (untouched)",
  "s": "N",
  "o": "I",
  "x": "NULL|NULL|'ZZ Custom %TAG%'",
  "e": "D=NULL;T=CU"
 },
 {
  "n": "insert nothing (untouched)",
  "s": "N",
  "o": "I",
  "x": "NULL|NULL|NULL",
  "e": "D=NULL;T=NULL"
 },
 {
  "n": "insert an unknown subject refused",
  "s": "N",
  "o": "I",
  "x": "gen_random_uuid()|NULL|NULL",
  "e": "23503"
 },
 {
  "n": "insert an unknown discipline refused",
  "s": "N",
  "o": "I",
  "x": "NULL|gen_random_uuid()|NULL",
  "e": "23503"
 },
 {
  "n": "insert S, D and a wrong T",
  "s": "N",
  "o": "I",
  "x": "%s1%|%d1%|'ZZ Foo'",
  "e": "D=d1;T=n1"
 },
 {
  "n": "legacy row: an unrelated edit does not fire and does not rewrite it",
  "s": "L",
  "o": "U",
  "x": "tags = ARRAY['zz']",
  "e": "D=NULL;T=n1"
 },
 {
  "n": "legacy row: S to another subject of the same discipline",
  "s": "L",
  "o": "U",
  "x": "subject_id = %s2%",
  "e": "D=d1;T=n1"
 },
 {
  "n": "legacy row: S to a subject of the other discipline",
  "s": "L",
  "o": "U",
  "x": "subject_id = %s3%",
  "e": "D=d2;T=n2"
 },
 {
  "n": "legacy row: T only to another discipline name (derived value wins)",
  "s": "L",
  "o": "U",
  "x": "target_course = %n2%",
  "e": "D=d1;T=n1"
 },
 {
  "n": "legacy row: D only = DS",
  "s": "L",
  "o": "U",
  "x": "discipline_id = %d1%",
  "e": "D=d1;T=n1"
 },
 {
  "n": "legacy row: D only different from DS refused",
  "s": "L",
  "o": "U",
  "x": "discipline_id = %d2%",
  "e": "23514"
 },
 {
  "n": "legacy row: D set to NULL when it is already NULL is a no-op",
  "s": "L",
  "o": "U",
  "x": "discipline_id = NULL",
  "e": "D=NULL;T=n1"
 },
 {
  "n": "legacy row: S to NULL, T unchanged resolves to the discipline",
  "s": "L",
  "o": "U",
  "x": "subject_id = NULL",
  "e": "D=d1;T=n1"
 },
 {
  "n": "legacy row: S to NULL and T to a custom course (platform to custom)",
  "s": "L",
  "o": "U",
  "x": "subject_id = NULL, target_course = 'ZZ X'",
  "e": "D=NULL;T=ZZ X"
 },
 {
  "n": "legacy row: S and T together (the batch edit of the screens)",
  "s": "L",
  "o": "U",
  "x": "subject_id = %s2%, target_course = %n1%",
  "e": "D=d1;T=n1"
 },
 {
  "n": "legacy row: S, D and T all changed consistently",
  "s": "L",
  "o": "U",
  "x": "subject_id = %s3%, discipline_id = %d2%, target_course = %n2%",
  "e": "D=d2;T=n2"
 },
 {
  "n": "legacy row: an unknown subject refused",
  "s": "L",
  "o": "U",
  "x": "subject_id = gen_random_uuid()",
  "e": "23503"
 },
 {
  "n": "legacy row: D different from DS together with T refused",
  "s": "L",
  "o": "U",
  "x": "discipline_id = %d2%, target_course = %n2%",
  "e": "23514"
 },
 {
  "n": "legacy row: S of the other discipline with D = the old discipline refused",
  "s": "L",
  "o": "U",
  "x": "subject_id = %s3%, discipline_id = %d1%",
  "e": "23514"
 },
 {
  "n": "legacy row: T set to NULL while S is set (derived value restored)",
  "s": "L",
  "o": "U",
  "x": "target_course = NULL",
  "e": "D=d1;T=n1"
 },
 {
  "n": "discipline-only row: an unrelated edit",
  "s": "Dn",
  "o": "U",
  "x": "tags = ARRAY['zz']",
  "e": "D=d1;T=n1"
 },
 {
  "n": "discipline-only row: T to a custom course (platform to custom)",
  "s": "Dn",
  "o": "U",
  "x": "target_course = 'ZZ Y'",
  "e": "D=NULL;T=ZZ Y"
 },
 {
  "n": "discipline-only row: T to the other discipline name",
  "s": "Dn",
  "o": "U",
  "x": "target_course = %n2%",
  "e": "D=d2;T=n2"
 },
 {
  "n": "discipline-only row: S of the same discipline",
  "s": "Dn",
  "o": "U",
  "x": "subject_id = %s1%",
  "e": "D=d1;T=n1"
 },
 {
  "n": "discipline-only row: S of the other discipline (D follows the subject)",
  "s": "Dn",
  "o": "U",
  "x": "subject_id = %s3%",
  "e": "D=d2;T=n2"
 },
 {
  "n": "discipline-only row: D to the other discipline",
  "s": "Dn",
  "o": "U",
  "x": "discipline_id = %d2%",
  "e": "D=d2;T=n2"
 },
 {
  "n": "discipline-only row: D to NULL resolves from T",
  "s": "Dn",
  "o": "U",
  "x": "discipline_id = NULL",
  "e": "D=d1;T=n1"
 },
 {
  "n": "discipline-only row: S and D of the other discipline",
  "s": "Dn",
  "o": "U",
  "x": "subject_id = %s3%, discipline_id = %d2%",
  "e": "D=d2;T=n2"
 },
 {
  "n": "discipline-only row: S of the other discipline with the old D carried unchanged (D follows the subject)",
  "s": "Dn",
  "o": "U",
  "x": "subject_id = %s3%, discipline_id = %d1%",
  "e": "D=d2;T=n2"
 },
 {
  "n": "discipline-only row: T to NULL leaves it unassigned",
  "s": "Dn",
  "o": "U",
  "x": "target_course = NULL",
  "e": "D=NULL;T=NULL"
 },
 {
  "n": "discipline-only row: an unknown subject refused",
  "s": "Dn",
  "o": "U",
  "x": "subject_id = gen_random_uuid()",
  "e": "23503"
 },
 {
  "n": "custom row: T to a discipline name in other case and spacing",
  "s": "Cu",
  "o": "U",
  "x": "target_course = regexp_replace(lower(%n1%), ' ', '   ', 'g')",
  "e": "D=d1;T=n1"
 },
 {
  "n": "custom row: S set (T is replaced by the derived name)",
  "s": "Cu",
  "o": "U",
  "x": "subject_id = %s1%",
  "e": "D=d1;T=n1"
 },
 {
  "n": "custom row: D set",
  "s": "Cu",
  "o": "U",
  "x": "discipline_id = %d2%",
  "e": "D=d2;T=n2"
 },
 {
  "n": "custom row: an unrelated edit",
  "s": "Cu",
  "o": "U",
  "x": "tags = ARRAY['zz']",
  "e": "D=NULL;T=CU"
 },
 {
  "n": "conflict row (S set, T NULL): an unrelated edit still succeeds",
  "s": "C1",
  "o": "U",
  "x": "tags = ARRAY['zz']",
  "e": "D=NULL;T=NULL"
 },
 {
  "n": "conflict row (S set, T NULL): S change refused",
  "s": "C1",
  "o": "U",
  "x": "subject_id = %s2%",
  "e": "23514"
 },
 {
  "n": "conflict row (S set, T NULL): T change refused",
  "s": "C1",
  "o": "U",
  "x": "target_course = %n1%",
  "e": "23514"
 },
 {
  "n": "conflict row (S set, T NULL): D change refused",
  "s": "C1",
  "o": "U",
  "x": "discipline_id = %d1%",
  "e": "23514"
 },
 {
  "n": "conflict row (D set, S NULL, T NULL): an unrelated edit still succeeds",
  "s": "C2",
  "o": "U",
  "x": "tags = ARRAY['zz']",
  "e": "D=d1;T=NULL"
 },
 {
  "n": "conflict row (D set, S NULL, T NULL): T change refused",
  "s": "C2",
  "o": "U",
  "x": "target_course = %n1%",
  "e": "23514"
 },
 {
  "n": "conflict row (D set, S NULL, T NULL): D to NULL refused",
  "s": "C2",
  "o": "U",
  "x": "discipline_id = NULL",
  "e": "23514"
 },
 {
  "n": "conflict row (D set, S NULL, T NULL): S set refused",
  "s": "C2",
  "o": "U",
  "x": "subject_id = %s1%",
  "e": "23514"
 },
 {
  "n": "composite key: S with a different D is refused by the key even with the trigger disabled",
  "s": "FK",
  "o": "I",
  "x": "%s1%|%d2%|%n1%",
  "e": "23503"
 }
]$j$;
  r         record;
  tbl       text;
BEGIN
  SELECT count(*), md5(coalesce(string_agg(to_jsonb(f)::text, '|' ORDER BY f.id), '')) INTO v_fn0, v_fh0 FROM public.flashcards f;
  SELECT count(*), md5(coalesce(string_agg(to_jsonb(n)::text, '|' ORDER BY n.id), '')) INTO v_nn0, v_nh0 FROM public.notes n;
  SELECT id INTO v_user FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT d.id, d.name INTO v_d1, v_n1 FROM public.disciplines d WHERE (SELECT count(*) FROM public.subjects s WHERE s.discipline_id = d.id) >= 2 ORDER BY d.name LIMIT 1;
  SELECT d.id, d.name INTO v_d2, v_n2 FROM public.disciplines d WHERE d.id <> v_d1 AND EXISTS (SELECT 1 FROM public.subjects s WHERE s.discipline_id = d.id) ORDER BY d.name LIMIT 1;
  SELECT s.id INTO v_s1 FROM public.subjects s WHERE s.discipline_id = v_d1 ORDER BY s.id LIMIT 1;
  SELECT s.id INTO v_s2 FROM public.subjects s WHERE s.discipline_id = v_d1 AND s.id <> v_s1 ORDER BY s.id LIMIT 1;
  SELECT s.id INTO v_s3 FROM public.subjects s WHERE s.discipline_id = v_d2 ORDER BY s.id LIMIT 1;

  check_name := 'setup: a student, two disciplines (one with two subjects) with subjects; baseline recorded for flashcards and notes';
  pass := v_user IS NOT NULL AND v_d1 IS NOT NULL AND v_d2 IS NOT NULL AND v_s1 IS NOT NULL AND v_s2 IS NOT NULL AND v_s3 IS NOT NULL;
  detail := v_fn0 || ' flashcards, ' || v_nn0 || ' notes; fixture tag ' || v_tag; RETURN NEXT;

  check_name := 'triggers: both BEFORE INSERT OR UPDATE OF subject_id, discipline_id, target_course, enabled, calling the guard function';
  pass := (SELECT count(*) FROM pg_trigger t WHERE t.tgenabled = 'O' AND NOT t.tgisinternal AND t.tgrelid = 'public.flashcards'::regclass AND t.tgname = 'trg_flashcards_course_derive_guard'
             AND pg_get_triggerdef(t.oid) = 'CREATE TRIGGER trg_flashcards_course_derive_guard BEFORE INSERT OR UPDATE OF subject_id, discipline_id, target_course ON public.flashcards FOR EACH ROW EXECUTE FUNCTION fn_course_derive_guard()') = 1
      AND (SELECT count(*) FROM pg_trigger t WHERE t.tgenabled = 'O' AND NOT t.tgisinternal AND t.tgrelid = 'public.notes'::regclass AND t.tgname = 'trg_notes_course_derive_guard'
             AND pg_get_triggerdef(t.oid) = 'CREATE TRIGGER trg_notes_course_derive_guard BEFORE INSERT OR UPDATE OF subject_id, discipline_id, target_course ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_course_derive_guard()') = 1;
  detail := (SELECT string_agg(pg_get_triggerdef(oid), ' ; ') FROM pg_trigger WHERE tgname IN ('trg_flashcards_course_derive_guard', 'trg_notes_course_derive_guard')); RETURN NEXT;

  check_name := 'function: the derive body, SECURITY DEFINER, owner postgres, pinned search_path, owner-only ACL, no client EXECUTE';
  pass := (SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; secdef=' || p.prosecdef || '; config=' || coalesce(p.proconfig::text, '-') || '; acl=' || coalesce(p.proacl::text, '-')
                  || '; language=' || (SELECT l.lanname FROM pg_language l WHERE l.oid = p.prolang) || '; result=' || pg_get_function_result(p.oid) || '; volatility=' || p.provolatile::text
                  || '; body_md5_without_carriage_returns=' || md5(replace(p.prosrc, chr(13), ''))
             FROM pg_proc p WHERE p.oid = to_regprocedure('public.fn_course_derive_guard()'))
        = 'owner=postgres; secdef=true; config={"search_path=pg_catalog, public"}; acl={postgres=X/postgres}; language=plpgsql; result=trigger; volatility=v; body_md5_without_carriage_returns=0d633f1e0410f0a1271880ce183fdc7d'
      AND NOT has_function_privilege('anon', 'public.fn_course_derive_guard()', 'EXECUTE')
      AND NOT has_function_privilege('authenticated', 'public.fn_course_derive_guard()', 'EXECUTE')
      AND NOT has_function_privilege('service_role', 'public.fn_course_derive_guard()', 'EXECUTE');
  detail := ''; RETURN NEXT;

  check_name := 'coexistence: the older triggers of both tables and every older constraint are unchanged (name and definition, as D2)';
  pass := (SELECT string_agg(tgname || '|' || pg_get_triggerdef(oid), ';' ORDER BY tgname COLLATE "C") FROM pg_trigger WHERE tgrelid = 'public.flashcards'::regclass AND NOT tgisinternal AND tgname <> 'trg_flashcards_course_derive_guard') = $lit$trg_aaa_counter_flashcards|CREATE TRIGGER trg_aaa_counter_flashcards AFTER INSERT OR DELETE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION fn_update_flashcards_counter();trg_auto_resolve_flashcard_flags|CREATE TRIGGER trg_auto_resolve_flashcard_flags AFTER UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION auto_resolve_content_error_flags('flashcard');trg_badge_flashcard_create|CREATE TRIGGER trg_badge_flashcard_create AFTER INSERT ON public.flashcards FOR EACH ROW EXECUTE FUNCTION fn_badge_check_flashcards();trg_cleanup_orphan_batch_provenance|CREATE TRIGGER trg_cleanup_orphan_batch_provenance AFTER UPDATE ON public.flashcards REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION fn_cleanup_orphan_batch_provenance();trg_guard_flashcard_batch_move|CREATE TRIGGER trg_guard_flashcard_batch_move BEFORE UPDATE OF batch_id ON public.flashcards FOR EACH ROW WHEN ((old.batch_id IS DISTINCT FROM new.batch_id)) EXECUTE FUNCTION fn_guard_flashcard_batch_move();trg_guard_flashcards_is_verified|CREATE TRIGGER trg_guard_flashcards_is_verified BEFORE INSERT OR UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION fn_guard_flashcards_is_verified();trigger_update_deck_card_count|CREATE TRIGGER trigger_update_deck_card_count AFTER INSERT OR DELETE OR UPDATE OF deck_id ON public.flashcards FOR EACH ROW EXECUTE FUNCTION update_deck_card_count()$lit$
      AND (SELECT string_agg(tgname || '|' || pg_get_triggerdef(oid), ';' ORDER BY tgname COLLATE "C") FROM pg_trigger WHERE tgrelid = 'public.notes'::regclass AND NOT tgisinternal AND tgname <> 'trg_notes_course_derive_guard') = $lit$trg_aaa_counter_notes|CREATE TRIGGER trg_aaa_counter_notes AFTER INSERT OR DELETE ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_update_notes_counter();trg_auto_resolve_note_flags|CREATE TRIGGER trg_auto_resolve_note_flags AFTER UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION auto_resolve_content_error_flags('note');trg_autoclear_featured_notes|CREATE TRIGGER trg_autoclear_featured_notes BEFORE UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_autoclear_featured_on_visibility_change();trg_badge_note_upload|CREATE TRIGGER trg_badge_note_upload AFTER INSERT ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_badge_check_notes();trg_guard_notes_privileged_columns|CREATE TRIGGER trg_guard_notes_privileged_columns BEFORE INSERT OR UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_guard_notes_decks_privileged_columns();trg_require_note_provenance|CREATE TRIGGER trg_require_note_provenance BEFORE INSERT ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_require_note_provenance()$lit$
      AND (SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") FROM pg_constraint WHERE conrelid = 'public.flashcards'::regclass AND conname <> 'flashcards_discipline_subject_fkey') = $lit$chk_flashcards_question_type|CHECK ((question_type = ANY (ARRAY['flashcard'::text, 'mcq'::text, 'correct_incorrect'::text, 'theory'::text, 'case_study_mcq'::text, 'match_the_following'::text, 'fitb'::text, 'concept_card'::text, 'mcq_multi'::text])));chk_flashcards_source|CHECK ((source = ANY (ARRAY['manual'::text, 'gemini_import'::text, 'bulk_upload'::text])));flashcards_content_creator_id_fkey|FOREIGN KEY (content_creator_id) REFERENCES content_creators(id);flashcards_contributed_by_fkey|FOREIGN KEY (contributed_by) REFERENCES profiles(id) ON DELETE SET NULL;flashcards_creator_id_fkey|FOREIGN KEY (creator_id) REFERENCES profiles(id) ON DELETE SET NULL;flashcards_deck_id_fkey|FOREIGN KEY (deck_id) REFERENCES flashcard_decks(id) ON DELETE SET NULL;flashcards_difficulty_check|CHECK ((difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text])));flashcards_discipline_id_fkey|FOREIGN KEY (discipline_id) REFERENCES disciplines(id);flashcards_note_id_fkey|FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE SET NULL;flashcards_pkey|PRIMARY KEY (id);flashcards_subject_id_fkey|FOREIGN KEY (subject_id) REFERENCES subjects(id);flashcards_topic_id_fkey|FOREIGN KEY (topic_id) REFERENCES topics(id);flashcards_user_id_fkey|FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;flashcards_visibility_check|CHECK ((visibility = ANY (ARRAY['private'::text, 'friends'::text, 'public'::text])))$lit$
      AND (SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") FROM pg_constraint WHERE conrelid = 'public.notes'::regclass AND conname <> 'notes_discipline_subject_fkey') = $lit$notes_check|CHECK (((is_featured_on_landing = false) OR (visibility = 'public'::text)));notes_content_source_type_check|CHECK (((content_source_type IS NULL) OR (content_source_type = ANY (ARRAY['official_body'::text, 'original_creator'::text]))));notes_content_type_check|CHECK ((content_type = ANY (ARRAY['text'::text, 'table'::text, 'math'::text, 'diagram'::text, 'mixed'::text])));notes_contributed_by_fkey|FOREIGN KEY (contributed_by) REFERENCES profiles(id) ON DELETE SET NULL;notes_discipline_id_fkey|FOREIGN KEY (discipline_id) REFERENCES disciplines(id);notes_featured_approved_by_fkey|FOREIGN KEY (featured_approved_by) REFERENCES profiles(id) ON DELETE SET NULL;notes_featured_nominated_by_fkey|FOREIGN KEY (featured_nominated_by) REFERENCES profiles(id) ON DELETE SET NULL;notes_pkey|PRIMARY KEY (id);notes_subject_id_fkey|FOREIGN KEY (subject_id) REFERENCES subjects(id);notes_topic_id_fkey|FOREIGN KEY (topic_id) REFERENCES topics(id);notes_user_id_fkey|FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;notes_visibility_check|CHECK ((visibility = ANY (ARRAY['private'::text, 'friends'::text, 'public'::text])))$lit$;
  detail := ''; RETURN NEXT;

  check_name := 'composite keys: both NOT VALID, (discipline_id, subject_id) to subjects (discipline_id, id), no cascade';
  pass := (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'public.flashcards'::regclass AND conname = 'flashcards_discipline_subject_fkey' AND NOT convalidated) = 'FOREIGN KEY (discipline_id, subject_id) REFERENCES subjects(discipline_id, id) NOT VALID'
      AND (SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conrelid = 'public.notes'::regclass AND conname = 'notes_discipline_subject_fkey' AND NOT convalidated) = 'FOREIGN KEY (discipline_id, subject_id) REFERENCES subjects(discipline_id, id) NOT VALID';
  detail := ''; RETURN NEXT;

  FOREACH tbl IN ARRAY ARRAY['flashcards', 'notes'] LOOP
    check_name := tbl || ': every insert and update case gives its expected result (derived D and T, or the SQLSTATE)';
    v_bad := '';
    FOR r IN SELECT x AS c FROM jsonb_array_elements(v_cases) x LOOP
      v_res := pg_temp.b05_run_case(tbl, r.c, v_user, v_s1, v_s2, v_s3, v_d1, v_d2, v_n1, v_n2, v_tag);
      IF v_res IS DISTINCT FROM (r.c->>'e') THEN v_bad := v_bad || (r.c->>'n') || ' -> ' || coalesce(v_res, '?') || '; '; END IF;
    END LOOP;
    pass := v_bad = ''; detail := jsonb_array_length(v_cases) || ' cases. ' || v_bad; RETURN NEXT;
  END LOOP;

  check_name := 'the B-05 triggers are enabled again after every case (the fixture sub-transactions were rolled back)';
  pass := (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_flashcards_course_derive_guard', 'trg_notes_course_derive_guard') AND tgenabled = 'O') = 2
      AND (SELECT count(*) FROM pg_trigger WHERE tgrelid IN ('public.flashcards'::regclass, 'public.notes'::regclass) AND NOT tgisinternal AND tgenabled <> 'O') = 0;
  detail := ''; RETURN NEXT;

  -- ---- real role: a note insert with a subject only, and a flashcard update of S, as the student
  check_name := 'real role student: a note inserted with a subject only gets the discipline and course text; a flashcard S edit derives them';
  v_state := '';
  BEGIN
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
    PERFORM set_config('request.jwt.claim.sub', v_user::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN
      INSERT INTO public.notes (user_id, title, content_source_type, content_source_name, subject_id) VALUES (v_user, 'ZZ b05 real ' || v_tag, 'original_creator', 'ZZ b05', v_s3);
      v_state := v_state || 'note-insert-ok;';
    EXCEPTION WHEN OTHERS THEN v_state := v_state || 'note-insert-' || SQLSTATE || ';'; END;
    RESET ROLE;
    SELECT discipline_id, target_course INTO v_d, v_t FROM public.notes WHERE title = 'ZZ b05 real ' || v_tag;
    v_state := v_state || 'note=' || CASE WHEN v_d = v_d2 THEN 'd2' ELSE coalesce(v_d::text, 'NULL') END || '/' || CASE WHEN v_t = v_n2 THEN 'n2' ELSE coalesce(v_t, 'NULL') END || ';';
    EXECUTE 'ALTER TABLE public.flashcards DISABLE TRIGGER trg_flashcards_course_derive_guard';
    INSERT INTO public.flashcards (user_id, front_text, back_text, subject_id, discipline_id, target_course) VALUES (v_user, 'ZZ b05 real', 'ZZ b05', v_s1, NULL, v_n1) RETURNING id INTO v_id;
    EXECUTE 'ALTER TABLE public.flashcards ENABLE TRIGGER trg_flashcards_course_derive_guard';
    PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    BEGIN UPDATE public.flashcards SET tags = ARRAY['zz'] WHERE id = v_id; v_state := v_state || 'card-unrelated-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'card-unrelated-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.flashcards SET subject_id = v_s2 WHERE id = v_id; v_state := v_state || 'card-s-ok;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'card-s-' || SQLSTATE || ';'; END;
    BEGIN UPDATE public.flashcards SET discipline_id = v_d2 WHERE id = v_id; v_state := v_state || 'card-bad-d-allowed;'; EXCEPTION WHEN OTHERS THEN v_state := v_state || 'card-bad-d-' || SQLSTATE || ';'; END;
    RESET ROLE;
    SELECT discipline_id, target_course INTO v_d, v_t FROM public.flashcards WHERE id = v_id;
    v_state := v_state || 'card=' || CASE WHEN v_d = v_d1 THEN 'd1' ELSE coalesce(v_d::text, 'NULL') END || '/' || CASE WHEN v_t = v_n1 THEN 'n1' ELSE coalesce(v_t, 'NULL') END || ';';
    RAISE EXCEPTION 'b05_rollback_marker';
  EXCEPTION WHEN raise_exception THEN
    RESET ROLE;
    IF SQLERRM <> 'b05_rollback_marker' THEN RAISE; END IF;
  END;
  pass := v_state = 'note-insert-ok;note=d2/n2;card-unrelated-ok;card-s-ok;card-bad-d-23514;card=d1/n1;'; detail := v_state; RETURN NEXT;

  check_name := 'live rows: count and a hash over every column of every flashcard and note equal the baseline; no fixture row remains; the B-05 triggers are enabled';
  pass := (SELECT count(*) FROM public.flashcards) = v_fn0 AND (SELECT md5(coalesce(string_agg(to_jsonb(f)::text, '|' ORDER BY f.id), '')) FROM public.flashcards f) = v_fh0
      AND (SELECT count(*) FROM public.notes) = v_nn0 AND (SELECT md5(coalesce(string_agg(to_jsonb(n)::text, '|' ORDER BY n.id), '')) FROM public.notes n) = v_nh0
      AND NOT EXISTS (SELECT 1 FROM public.flashcards WHERE front_text LIKE 'ZZ b05%') AND NOT EXISTS (SELECT 1 FROM public.notes WHERE title LIKE 'ZZ b05%')
      AND (SELECT count(*) FROM pg_trigger WHERE tgname IN ('trg_flashcards_course_derive_guard', 'trg_notes_course_derive_guard') AND tgenabled = 'O') = 2;
  detail := (SELECT count(*) FROM public.flashcards) || ' flashcards, ' || (SELECT count(*) FROM public.notes) || ' notes'; RETURN NEXT;
END;
$test$;

CREATE TEMP TABLE b05_results AS SELECT * FROM pg_temp.b05_checks();

SELECT check_name, pass, detail FROM b05_results
UNION ALL
SELECT 'SUMMARY: every check passed', (SELECT bool_and(pass IS TRUE) FROM b05_results), (SELECT count(*) || ' checks' FROM b05_results);
