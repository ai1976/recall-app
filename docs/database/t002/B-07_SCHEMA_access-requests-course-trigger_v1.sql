-- Name: [SCHEMA] T-002 B-07 (v1) - access_requests.course trigger: validate and write the canonical course text (student access requests)
--
-- Description: PERSISTENT DDL. Implements brief B v10 sections 5.1 to 5.3a and plan v18 section 6 (B-07, table-trigger mechanism: it covers every writer of student access requests). Tier 1; the Founder authorizes the run
-- by hash. One selection = ONE transaction. Run after B-03 (same contract) and after F0 is live (done). The pre-flight aborts, changing nothing, unless access_requests, its writers and the B-01 functions equal what
-- D2, D3 and the B-04a VERIFY run recorded; access_requests must have NO trigger today (D2 P2).
--
-- WHAT IT DOES: trigger trg_access_requests_course_label_guard (BEFORE INSERT OR UPDATE OF course, only for request_type student_access) with SECURITY DEFINER function fn_access_requests_course_label_guard (pinned
-- search_path, owner only). Same contract as B-03: unchanged value on UPDATE returns at once; otherwise trim outer spaces; refuse empty, over 120 characters or a control character (SQLSTATE 23514); rewrite a
-- normalized match of a discipline name or a CMA or CS catalogue label to its exact text; any other text stored trimmed; no rule about the word Other.
-- DESIGN DEVIATION TO CONFIRM (plan v18 says the trigger covers every writer): the column course is also written by submit_institute_inquiry (course, or the text General inquiry) and submit_educator_application
-- (course or courses taught, free text, or Not specified), whose values are not one course label and may be longer than 120 characters. Applying the rule there would break those live forms, so the trigger is limited
-- to request_type = student_access, the type written by submit_access_request (the access form F0 fixed). Both other functions are bound by source hash in the pre-flight, so a change to them stops this file.
-- No data is changed: the six existing rows (max length 15, no whitespace or control character problem, D2 P5) are untouched (the trigger fires only on insert or when course is in the UPDATE list and changes).

SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';

LOCK TABLE public.access_requests IN SHARE ROW EXCLUSIVE MODE;

DO $preflight$
DECLARE
  v text;
  r record;
BEGIN
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
  IF to_regclass('public.disciplines_normalized_name_uidx') IS NULL THEN
    RAISE EXCEPTION 'B-07 stopped: the B-02a unique index does not exist';
  END IF;
  IF to_regprocedure('public.fn_access_requests_course_label_guard()') IS NOT NULL THEN
    RAISE EXCEPTION 'B-07 stopped: fn_access_requests_course_label_guard already exists';
  END IF;

  SELECT string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' ORDER BY a.attnum) INTO v
    FROM pg_attribute a WHERE a.attrelid = 'public.access_requests'::regclass AND a.attnum > 0 AND NOT a.attisdropped;
  IF v IS DISTINCT FROM $lit$id:uuid,name:text,whatsapp_number:text,course:text,content_id:uuid,content_type:text,content_name:text,requester_user_id:uuid,requested_at:timestamp with time zone,status:text,email:text,ref_token:uuid,request_type:text,message:text$lit$ THEN RAISE EXCEPTION 'B-07 stopped: access_requests columns differ from D2. Live: %', v; END IF;

  SELECT string_agg(conname || '|' || pg_get_constraintdef(oid), ';' ORDER BY conname COLLATE "C") INTO v FROM pg_constraint WHERE conrelid = 'public.access_requests'::regclass;
  IF v IS DISTINCT FROM $lit$access_requests_content_type_check|CHECK ((content_type = ANY (ARRAY['flashcard_deck'::text, 'note'::text])));access_requests_pkey|PRIMARY KEY (id);access_requests_request_type_check|CHECK ((request_type = ANY (ARRAY['student_access'::text, 'institute_inquiry'::text, 'educator_application'::text])));access_requests_requester_user_id_fkey|FOREIGN KEY (requester_user_id) REFERENCES profiles(id) ON DELETE SET NULL;access_requests_status_check|CHECK ((status = ANY (ARRAY['pending'::text, 'contacted'::text, 'enrolled'::text, 'approved'::text, 'rejected'::text, 'dismissed'::text])))$lit$ THEN RAISE EXCEPTION 'B-07 stopped: access_requests constraints differ from D2. Live: %', v; END IF;

  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'public.access_requests'::regclass AND NOT tgisinternal) THEN
    RAISE EXCEPTION 'B-07 stopped: access_requests has a trigger, which D2 did not record';
  END IF;

  SELECT md5(pg_get_functiondef(to_regprocedure('public.submit_access_request(text,text,text,text,uuid,text,text,uuid)'))) INTO v;
  IF v IS DISTINCT FROM 'df7fbf67a33ae10e29ffd29222f1b64d' THEN RAISE EXCEPTION 'B-07 stopped: submit_access_request differs from D3. Live md5: %', v; END IF;
  SELECT md5(p.prosrc) INTO v FROM pg_proc p WHERE p.proname = 'submit_educator_application' AND p.pronamespace = 'public'::regnamespace;
  IF v IS DISTINCT FROM 'f6e4864a58a84a62b72f38c8f485caa4' THEN RAISE EXCEPTION 'B-07 stopped: submit_educator_application differs from D3. Live src md5: %', v; END IF;
  SELECT md5(p.prosrc) INTO v FROM pg_proc p WHERE p.proname = 'submit_institute_inquiry' AND p.pronamespace = 'public'::regnamespace;
  IF v IS DISTINCT FROM '41325ac5add126889d7cfb55d58a8411' THEN RAISE EXCEPTION 'B-07 stopped: submit_institute_inquiry differs from D3. Live src md5: %', v; END IF;
END
$preflight$;

CREATE TEMP TABLE b07_proof ON COMMIT DROP AS
SELECT count(*)::integer AS n0, md5(coalesce(string_agg(to_jsonb(a)::text, '|' ORDER BY a.id), '')) AS h0 FROM public.access_requests a;

CREATE FUNCTION public.fn_access_requests_course_label_guard()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $function$
DECLARE
  v text;
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.course IS NOT DISTINCT FROM NEW.course THEN
    RETURN NEW;
  END IF;
  IF NEW.course IS NULL THEN
    RETURN NEW;
  END IF;
  v := pg_catalog.btrim(NEW.course);
  IF v = '' THEN
    RAISE EXCEPTION 'access_requests: the course is empty' USING ERRCODE = '23514';
  END IF;
  IF pg_catalog.char_length(v) > 120 THEN
    RAISE EXCEPTION 'access_requests: the course is longer than 120 characters' USING ERRCODE = '23514';
  END IF;
  IF v ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'access_requests: the course contains a control character' USING ERRCODE = '23514';
  END IF;
  NEW.course := public.resolve_canonical_course_label(v);
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.fn_access_requests_course_label_guard() FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER trg_access_requests_course_label_guard
  BEFORE INSERT OR UPDATE OF course ON public.access_requests
  FOR EACH ROW
  WHEN (NEW.request_type = 'student_access')
  EXECUTE FUNCTION public.fn_access_requests_course_label_guard();

DO $postcheck$
DECLARE
  p b07_proof%ROWTYPE;
  v_n integer;
  v_h text;
BEGIN
  SELECT * INTO p FROM b07_proof;
  SELECT count(*), md5(coalesce(string_agg(to_jsonb(q)::text, '|' ORDER BY q.id), '')) INTO v_n, v_h FROM public.access_requests q;
  IF v_n <> p.n0 OR v_h <> p.h0 THEN
    RAISE EXCEPTION 'B-07 stopped: access_requests changed during the run (rows % -> %); nothing is applied', p.n0, v_n;
  END IF;
END
$postcheck$;

SELECT p.n0 AS rows_before, (SELECT count(*) FROM public.access_requests) AS rows_after, p.h0 AS table_hash_before,
       (SELECT md5(coalesce(string_agg(to_jsonb(q)::text, '|' ORDER BY q.id), '')) FROM public.access_requests q) AS table_hash_after
  FROM b07_proof p;
