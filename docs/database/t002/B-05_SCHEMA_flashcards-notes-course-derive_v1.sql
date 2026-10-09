-- Name: [SCHEMA] T-002 B-05 (v1) - flashcards and notes: derive discipline and course text from the subject, and composite subject-discipline keys
--
-- Description: PERSISTENT DDL. Implements brief B v10 (0fe77dec72dc) section 6.1 to 6.3 and plan v18 section 7 (B-05). Tier 1: QA audits this exact file by hash, at most two rounds; the Founder authorizes the run by
-- hash. One selection in the Supabase SQL Editor = ONE transaction. F0 is live (the due guard covers subject_id and discipline_id, Gate 7 complete 09/10/2026), B-01, B-02a and B-04a are live (the unique pair on
-- subjects is the target of the composite keys).
--
-- WHAT IT DOES
--   1. One SECURITY DEFINER function fn_course_derive_guard (pinned search_path, owner only), attached to flashcards and to notes as BEFORE INSERT OR UPDATE OF subject_id, discipline_id, target_course
--      (triggers trg_flashcards_course_derive_guard and trg_notes_course_derive_guard). target_course is a DERIVED label for platform rows: S = subject_id, D = discipline_id, T = target_course, DS = the discipline of S.
--      The function returns at once when none of S, D, T changed (so an unrelated edit of a legacy row never fires it and never rewrites it). Otherwise: (1) it evaluates the OLD row first: a row that is already a conflict
--      (S set and D differs from DS or T differs from the name of DS; or S NULL, D set and T differs from the name of D; a NULL T on a platform row is a conflict) is refused when S, D or T changes (SQLSTATE 23514), never
--      accepted and never repaired; (2) otherwise S set gives D := DS and T := the exact name of DS (an explicit D that differs from DS is refused, 23514; an unknown subject is 23503); S NULL and D NULL with a T that
--      resolves to a discipline name (resolve_canonical_course_label) gives D := that discipline and T := its exact name, any other T is left alone; S NULL and D explicit gives T := the name of D (unknown D is 23503); S NULL
--      with D carried unchanged and S changed to NULL or T changed resolves the new T (a discipline name gives D and the exact name, anything else gives D := NULL and T as supplied).
--   2. Composite foreign keys, NOT VALID, on both tables: (discipline_id, subject_id) -> subjects (discipline_id, id). Rows with a NULL discipline_id (every existing row, D2 P5) are skipped by the key; updates that do not
--      touch the key columns skip the check.
-- No existing row is changed or rewritten (proved by a hash over every column of every row before and after, taken under the lock); legacy rows stay editable. Behaviour change to know: for a row with a platform subject,
-- target_course is now always written as the subject's discipline name (a different text sent by a writer is replaced, because the course text is derived).
-- The pre-flight aborts, changing nothing, unless the live state equals what D2 recorded (columns, constraints and triggers of both tables), the B-01 functions equal the identities saved by the B-04a VERIFY run, the
-- B-02a index is the exact recorded one and the B-04a unique pair exists, and the executing role is postgres. Locks: SHARE ROW EXCLUSIVE on flashcards and notes under lock_timeout 5 s and statement_timeout 30 s; on
-- timeout nothing is applied and the file can be run again at a quiet moment.

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.flashcards, public.notes IN SHARE ROW EXCLUSIVE MODE;

DO $preflight$
DECLARE
  v text;
  r record;
BEGIN
  IF current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'stopped: run this file as the migration owner postgres (current_user %, session_user %)', current_user, session_user;
  END IF;
  FOR r IN SELECT x.sig, x.expected FROM (VALUES
    ('public.course_catalogue_labels()', 'owner=postgres; volatility=i; secdef=false; strict=false; config=-; src_md5=931e3f507c8fc967c8940d4b77a12188; acl={postgres=X/postgres}'),
    ('public.normalize_course_text(text)', 'owner=postgres; volatility=i; secdef=false; strict=true; config=-; src_md5=41f75fecfa300bb0588c677885ce16bb; acl={postgres=X/postgres,authenticated=X/postgres}'),
    ('public.resolve_canonical_course_label(text)', 'owner=postgres; volatility=s; secdef=false; strict=false; config={"search_path=pg_catalog, public"}; src_md5=303aab7dc4bfbb832c57682538aa6cfe; acl={postgres=X/postgres}')
  ) AS x(sig, expected) LOOP
    SELECT 'owner=' || pg_get_userbyid(p.proowner) || '; volatility=' || p.provolatile::text || '; secdef=' || p.prosecdef || '; strict=' || p.proisstrict
           || '; config=' || coalesce(p.proconfig::text, '-') || '; src_md5=' || md5(p.prosrc) || '; acl=' || coalesce(p.proacl::text, '-')
      INTO v FROM pg_proc p WHERE p.oid = to_regprocedure(r.sig);
    IF v IS DISTINCT FROM r.expected THEN
      RAISE EXCEPTION 'stopped: % differs from the identity recorded by the B-04a VERIFY run. Live: %', r.sig, v;
    END IF;
  END LOOP;
  SELECT pg_get_indexdef(x.indexrelid) || '|' || x.indisunique || '|' || x.indisvalid || '|' || x.indisready INTO v
    FROM pg_index x WHERE x.indexrelid = to_regclass('public.disciplines_normalized_name_uidx');
  IF v IS DISTINCT FROM 'CREATE UNIQUE INDEX disciplines_normalized_name_uidx ON public.disciplines USING btree (normalize_course_text(name))|true|true|true' THEN
    RAISE EXCEPTION 'stopped: the B-02a unique index differs from the recorded one. Live: %', v;
  END IF;
  SELECT pg_get_constraintdef(c.oid) || '|' || c.convalidated INTO v FROM pg_constraint c WHERE c.conrelid = 'public.subjects'::regclass AND c.conname = 'subjects_discipline_id_id_key';
  IF v IS DISTINCT FROM 'UNIQUE (discipline_id, id)|true' THEN
    RAISE EXCEPTION 'stopped: the B-04a unique pair on subjects differs from the recorded one. Live: %', coalesce(v, '(missing)');
  END IF;
  IF to_regprocedure('public.fn_course_derive_guard()') IS NOT NULL THEN
    RAISE EXCEPTION 'B-05 stopped: fn_course_derive_guard already exists';
  END IF;

  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum) INTO v FROM pg_attribute a WHERE a.attrelid = 'public.flashcards'::regclass AND a.attnum > 0 AND NOT a.attisdropped;
  IF v IS DISTINCT FROM $lit$id:uuid,user_id:uuid,note_id:uuid,front_text:text,front_image_url:text,back_text:text,back_image_url:text,discipline_id:uuid,subject_id:uuid,topic_id:uuid,created_at:timestamp with time zone,tags:text[],custom_subject:text,custom_topic:text,contributed_by:uuid,target_course:text,difficulty:text,is_verified:boolean,batch_id:uuid,batch_description:text,creator_id:uuid,content_creator_id:uuid,visibility:text,deck_id:uuid,question_type:text,options:jsonb,correct_answer:text,hints:jsonb,points_to_remember:jsonb,scenario:text,subtype:text,source:text,explanation:jsonb$lit$ THEN RAISE EXCEPTION 'B-05 stopped: flashcards columns differ from D2. Live: %', v; END IF;
  SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") INTO v FROM pg_constraint WHERE conrelid = 'public.flashcards'::regclass;
  IF v IS DISTINCT FROM $lit$chk_flashcards_question_type|CHECK ((question_type = ANY (ARRAY['flashcard'::text, 'mcq'::text, 'correct_incorrect'::text, 'theory'::text, 'case_study_mcq'::text, 'match_the_following'::text, 'fitb'::text, 'concept_card'::text, 'mcq_multi'::text])));chk_flashcards_source|CHECK ((source = ANY (ARRAY['manual'::text, 'gemini_import'::text, 'bulk_upload'::text])));flashcards_content_creator_id_fkey|FOREIGN KEY (content_creator_id) REFERENCES content_creators(id);flashcards_contributed_by_fkey|FOREIGN KEY (contributed_by) REFERENCES profiles(id) ON DELETE SET NULL;flashcards_creator_id_fkey|FOREIGN KEY (creator_id) REFERENCES profiles(id) ON DELETE SET NULL;flashcards_deck_id_fkey|FOREIGN KEY (deck_id) REFERENCES flashcard_decks(id) ON DELETE SET NULL;flashcards_difficulty_check|CHECK ((difficulty = ANY (ARRAY['easy'::text, 'medium'::text, 'hard'::text])));flashcards_discipline_id_fkey|FOREIGN KEY (discipline_id) REFERENCES disciplines(id);flashcards_note_id_fkey|FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE SET NULL;flashcards_pkey|PRIMARY KEY (id);flashcards_subject_id_fkey|FOREIGN KEY (subject_id) REFERENCES subjects(id);flashcards_topic_id_fkey|FOREIGN KEY (topic_id) REFERENCES topics(id);flashcards_user_id_fkey|FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;flashcards_visibility_check|CHECK ((visibility = ANY (ARRAY['private'::text, 'friends'::text, 'public'::text])))$lit$ THEN RAISE EXCEPTION 'B-05 stopped: flashcards constraints differ from D2. Live: %', v; END IF;
  SELECT string_agg(tgname || '|' || pg_get_triggerdef(oid), ';' ORDER BY tgname COLLATE "C") INTO v FROM pg_trigger WHERE tgrelid = 'public.flashcards'::regclass AND NOT tgisinternal;
  IF v IS DISTINCT FROM $lit$trg_aaa_counter_flashcards|CREATE TRIGGER trg_aaa_counter_flashcards AFTER INSERT OR DELETE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION fn_update_flashcards_counter();trg_auto_resolve_flashcard_flags|CREATE TRIGGER trg_auto_resolve_flashcard_flags AFTER UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION auto_resolve_content_error_flags('flashcard');trg_badge_flashcard_create|CREATE TRIGGER trg_badge_flashcard_create AFTER INSERT ON public.flashcards FOR EACH ROW EXECUTE FUNCTION fn_badge_check_flashcards();trg_cleanup_orphan_batch_provenance|CREATE TRIGGER trg_cleanup_orphan_batch_provenance AFTER UPDATE ON public.flashcards REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION fn_cleanup_orphan_batch_provenance();trg_guard_flashcard_batch_move|CREATE TRIGGER trg_guard_flashcard_batch_move BEFORE UPDATE OF batch_id ON public.flashcards FOR EACH ROW WHEN ((old.batch_id IS DISTINCT FROM new.batch_id)) EXECUTE FUNCTION fn_guard_flashcard_batch_move();trg_guard_flashcards_is_verified|CREATE TRIGGER trg_guard_flashcards_is_verified BEFORE INSERT OR UPDATE ON public.flashcards FOR EACH ROW EXECUTE FUNCTION fn_guard_flashcards_is_verified();trigger_update_deck_card_count|CREATE TRIGGER trigger_update_deck_card_count AFTER INSERT OR DELETE OR UPDATE OF deck_id ON public.flashcards FOR EACH ROW EXECUTE FUNCTION update_deck_card_count()$lit$ THEN RAISE EXCEPTION 'B-05 stopped: flashcards triggers differ from D2. Live: %', v; END IF;

  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum) INTO v FROM pg_attribute a WHERE a.attrelid = 'public.notes'::regclass AND a.attnum > 0 AND NOT a.attisdropped;
  IF v IS DISTINCT FROM $lit$id:uuid,user_id:uuid,discipline_id:uuid,subject_id:uuid,topic_id:uuid,title:text,content_type:text,image_url:text,extracted_text:text,tags:text[],view_count:integer,upvote_count:integer,created_at:timestamp with time zone,updated_at:timestamp with time zone,custom_subject:text,custom_topic:text,description:text,contributed_by:uuid,target_course:text,visibility:text,is_featured_on_landing:boolean,featured_nominated_by:uuid,featured_nominated_at:timestamp with time zone,featured_approved_by:uuid,featured_approved_at:timestamp with time zone,content_source_type:text,content_source_name:text$lit$ THEN RAISE EXCEPTION 'B-05 stopped: notes columns differ from D2. Live: %', v; END IF;
  SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") INTO v FROM pg_constraint WHERE conrelid = 'public.notes'::regclass;
  IF v IS DISTINCT FROM $lit$notes_check|CHECK (((is_featured_on_landing = false) OR (visibility = 'public'::text)));notes_content_source_type_check|CHECK (((content_source_type IS NULL) OR (content_source_type = ANY (ARRAY['official_body'::text, 'original_creator'::text]))));notes_content_type_check|CHECK ((content_type = ANY (ARRAY['text'::text, 'table'::text, 'math'::text, 'diagram'::text, 'mixed'::text])));notes_contributed_by_fkey|FOREIGN KEY (contributed_by) REFERENCES profiles(id) ON DELETE SET NULL;notes_discipline_id_fkey|FOREIGN KEY (discipline_id) REFERENCES disciplines(id);notes_featured_approved_by_fkey|FOREIGN KEY (featured_approved_by) REFERENCES profiles(id) ON DELETE SET NULL;notes_featured_nominated_by_fkey|FOREIGN KEY (featured_nominated_by) REFERENCES profiles(id) ON DELETE SET NULL;notes_pkey|PRIMARY KEY (id);notes_subject_id_fkey|FOREIGN KEY (subject_id) REFERENCES subjects(id);notes_topic_id_fkey|FOREIGN KEY (topic_id) REFERENCES topics(id);notes_user_id_fkey|FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;notes_visibility_check|CHECK ((visibility = ANY (ARRAY['private'::text, 'friends'::text, 'public'::text])))$lit$ THEN RAISE EXCEPTION 'B-05 stopped: notes constraints differ from D2. Live: %', v; END IF;
  SELECT string_agg(tgname || '|' || pg_get_triggerdef(oid), ';' ORDER BY tgname COLLATE "C") INTO v FROM pg_trigger WHERE tgrelid = 'public.notes'::regclass AND NOT tgisinternal;
  IF v IS DISTINCT FROM $lit$trg_aaa_counter_notes|CREATE TRIGGER trg_aaa_counter_notes AFTER INSERT OR DELETE ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_update_notes_counter();trg_auto_resolve_note_flags|CREATE TRIGGER trg_auto_resolve_note_flags AFTER UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION auto_resolve_content_error_flags('note');trg_autoclear_featured_notes|CREATE TRIGGER trg_autoclear_featured_notes BEFORE UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_autoclear_featured_on_visibility_change();trg_badge_note_upload|CREATE TRIGGER trg_badge_note_upload AFTER INSERT ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_badge_check_notes();trg_guard_notes_privileged_columns|CREATE TRIGGER trg_guard_notes_privileged_columns BEFORE INSERT OR UPDATE ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_guard_notes_decks_privileged_columns();trg_require_note_provenance|CREATE TRIGGER trg_require_note_provenance BEFORE INSERT ON public.notes FOR EACH ROW EXECUTE FUNCTION fn_require_note_provenance()$lit$ THEN RAISE EXCEPTION 'B-05 stopped: notes triggers differ from D2. Live: %', v; END IF;
END
$preflight$;

CREATE TEMP TABLE b05_proof ON COMMIT DROP AS
SELECT (SELECT count(*) FROM public.flashcards)::integer AS fn0, (SELECT md5(coalesce(string_agg(to_jsonb(f)::text, '|' ORDER BY f.id), '')) FROM public.flashcards f) AS fh0,
       (SELECT count(*) FROM public.notes)::integer AS nn0, (SELECT md5(coalesce(string_agg(to_jsonb(n)::text, '|' ORDER BY n.id), '')) FROM public.notes n) AS nh0;

CREATE FUNCTION public.fn_course_derive_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v_ds         uuid;
  v_dsname     text;
  v_did        uuid;
  v_dname      text;
  v_label      text;
  v_old_ds     uuid;
  v_old_name   text;
  v_old_bad    boolean := false;
  v_d_explicit boolean;
BEGIN
  -- the rule applies only when subject_id, discipline_id or target_course is inserted or changed
  IF TG_OP = 'UPDATE'
     AND NEW.subject_id IS NOT DISTINCT FROM OLD.subject_id
     AND NEW.discipline_id IS NOT DISTINCT FROM OLD.discipline_id
     AND NEW.target_course IS NOT DISTINCT FROM OLD.target_course THEN
    RETURN NEW;
  END IF;

  -- the OLD row first: a row already in conflict is never edited into another state and never repaired here
  IF TG_OP = 'UPDATE' THEN
    IF OLD.subject_id IS NOT NULL THEN
      SELECT s.discipline_id INTO v_old_ds FROM public.subjects s WHERE s.id = OLD.subject_id;
      SELECT d.name INTO v_old_name FROM public.disciplines d WHERE d.id = v_old_ds;
      v_old_bad := (OLD.discipline_id IS NOT NULL AND OLD.discipline_id IS DISTINCT FROM v_old_ds) OR OLD.target_course IS DISTINCT FROM v_old_name;
    ELSIF OLD.discipline_id IS NOT NULL THEN
      SELECT d.name INTO v_old_name FROM public.disciplines d WHERE d.id = OLD.discipline_id;
      v_old_bad := OLD.target_course IS DISTINCT FROM v_old_name;
    END IF;
    IF v_old_bad THEN
      RAISE EXCEPTION '%: this row is flagged as a course conflict (subject, discipline and course text disagree); reconciliation is a separate reviewed fix', TG_TABLE_NAME USING ERRCODE = '23514';
    END IF;
  END IF;

  v_d_explicit := (TG_OP = 'INSERT' AND NEW.discipline_id IS NOT NULL) OR (TG_OP = 'UPDATE' AND NEW.discipline_id IS DISTINCT FROM OLD.discipline_id);

  IF NEW.subject_id IS NOT NULL THEN
    SELECT s.discipline_id INTO v_ds FROM public.subjects s WHERE s.id = NEW.subject_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION '%: unknown subject', TG_TABLE_NAME USING ERRCODE = '23503';
    END IF;
    IF v_ds IS NULL THEN
      RAISE EXCEPTION '%: the subject has no discipline', TG_TABLE_NAME USING ERRCODE = '23514';
    END IF;
    IF v_d_explicit AND NEW.discipline_id IS NOT NULL AND NEW.discipline_id IS DISTINCT FROM v_ds THEN
      RAISE EXCEPTION '%: the discipline does not match the subject', TG_TABLE_NAME USING ERRCODE = '23514';
    END IF;
    SELECT d.name INTO v_dsname FROM public.disciplines d WHERE d.id = v_ds;
    NEW.discipline_id := v_ds;
    NEW.target_course := v_dsname;
  ELSIF NEW.discipline_id IS NULL THEN
    IF NEW.target_course IS NOT NULL THEN
      v_label := public.resolve_canonical_course_label(NEW.target_course);
      SELECT d.id, d.name INTO v_did, v_dname FROM public.disciplines d WHERE d.name = v_label;
      IF FOUND THEN
        NEW.discipline_id := v_did;
        NEW.target_course := v_dname;
      END IF;
    END IF;
  ELSE
    IF v_d_explicit THEN
      SELECT d.name INTO v_dname FROM public.disciplines d WHERE d.id = NEW.discipline_id;
      IF NOT FOUND THEN
        RAISE EXCEPTION '%: unknown discipline', TG_TABLE_NAME USING ERRCODE = '23503';
      END IF;
      NEW.target_course := v_dname;
    ELSIF OLD.subject_id IS DISTINCT FROM NEW.subject_id OR NEW.target_course IS DISTINCT FROM OLD.target_course THEN
      v_did := NULL;
      IF NEW.target_course IS NOT NULL THEN
        v_label := public.resolve_canonical_course_label(NEW.target_course);
        SELECT d.id, d.name INTO v_did, v_dname FROM public.disciplines d WHERE d.name = v_label;
        IF FOUND THEN
          NEW.target_course := v_dname;
        END IF;
      END IF;
      NEW.discipline_id := v_did;
    ELSE
      SELECT d.name INTO v_dname FROM public.disciplines d WHERE d.id = NEW.discipline_id;
      NEW.target_course := v_dname;
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_course_derive_guard() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_flashcards_course_derive_guard
  BEFORE INSERT OR UPDATE OF subject_id, discipline_id, target_course ON public.flashcards
  FOR EACH ROW EXECUTE FUNCTION public.fn_course_derive_guard();

CREATE TRIGGER trg_notes_course_derive_guard
  BEFORE INSERT OR UPDATE OF subject_id, discipline_id, target_course ON public.notes
  FOR EACH ROW EXECUTE FUNCTION public.fn_course_derive_guard();

ALTER TABLE public.flashcards
  ADD CONSTRAINT flashcards_discipline_subject_fkey FOREIGN KEY (discipline_id, subject_id) REFERENCES public.subjects (discipline_id, id) NOT VALID;
ALTER TABLE public.notes
  ADD CONSTRAINT notes_discipline_subject_fkey FOREIGN KEY (discipline_id, subject_id) REFERENCES public.subjects (discipline_id, id) NOT VALID;

CREATE TEMP TABLE b05_after ON COMMIT DROP AS
SELECT (SELECT count(*) FROM public.flashcards)::integer AS fn1, (SELECT md5(coalesce(string_agg(to_jsonb(f)::text, '|' ORDER BY f.id), '')) FROM public.flashcards f) AS fh1,
       (SELECT count(*) FROM public.notes)::integer AS nn1, (SELECT md5(coalesce(string_agg(to_jsonb(n)::text, '|' ORDER BY n.id), '')) FROM public.notes n) AS nh1;

DO $postcheck$
DECLARE
  p b05_proof%ROWTYPE;
  q b05_after%ROWTYPE;
BEGIN
  SELECT * INTO p FROM b05_proof;
  SELECT * INTO q FROM b05_after;
  IF q.fn1 <> p.fn0 OR q.fh1 <> p.fh0 OR q.nn1 <> p.nn0 OR q.nh1 <> p.nh0 THEN
    RAISE EXCEPTION 'B-05 stopped: flashcards or notes changed during the run (flashcards % -> %, notes % -> %); nothing is applied', p.fn0, q.fn1, p.nn0, q.nn1;
  END IF;
END
$postcheck$;

SELECT p.fn0 AS flashcards_before, q.fn1 AS flashcards_after, p.fh0 AS flashcards_hash_before, q.fh1 AS flashcards_hash_after,
       p.nn0 AS notes_before, q.nn1 AS notes_after, p.nh0 AS notes_hash_before, q.nh1 AS notes_hash_after
  FROM b05_proof p, b05_after q;
