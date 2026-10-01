-- [TEST] Professor <-> batch assignment (run AFTER 03, 04, 05 and 06). Rollback-only, safe on production.
-- Description: Runs as the real people through the client role (SET LOCAL ROLE via a temp helper). It builds its OWN temporary batches,
--   a personal group, an archived batch + snapshot and join-link groups; every row, audit entry and role/status tweak is undone by the final
--   ROLLBACK. Real professors used: Kaustubh Atre (p1, assigned), Abhay More (p2, UNASSIGNED but an active member), Niraj Mahajan (p3).
--   B0  the 6 approved backfill assignments exist, assigned_by NULL, source 'migration_backfill'      T0  the 6 changed bodies contain the new rules
--   T1  effective privileges of every new / changed-ACL function (anon + PUBLIC refused, authenticated can run; helper internal only)
--   T2  table: RLS on, zero policies, nothing for anon / authenticated / PUBLIC (table or column)    D1-D3 direct table denial
--   A1-A12  assign: success + audit; idempotent; super_admin ok; student / professor / suspended admin refused; non-professor target,
--           personal group, archived batch, suspended target professor, unknown batch, anon all refused
--   U1-U5   unassign: success + audit; idempotent; student / professor refused; admin may clean an archived batch
--   L1-L4   professor list / assignable list: admin ok; professor / student refused; demoted professor flagged
--   V1  ASSIGNED professor who is NOT a member opens the batch page       V2  UNASSIGNED professor WITH an active membership is REFUSED
--   V3  cross-batch refused    V4  students keep membership access    V5-V7 stats: assigned ok, STUDENTS ONLY, unassigned / member / student
--   refused, no existence leak    V8  archive snapshot returned verbatim (staff row kept) to assigned only    V9 my batches list is assignment-scoped
--   V10 demoted professor refused    V11 suspended professor refused    V12 suspended admin refused    V14 get_admin_batch_groups ACL
--   V15 anon refused on every batch function
--   J1-J8   join link: professor + batch refused, no membership; student -> requested; professor + personal -> active; admin / super_admin
--           unchanged; archived refused first; a DRIFTED batch (is_batch_group true, group_type 'custom') is still treated as a batch
--   E1-E5   admin direct add: student ok; professor / unknown user refused with no row; non-admin refused

BEGIN;

CREATE FUNCTION pg_temp.t_call(p_uid uuid, p_role text, p_sql text) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_out text;
BEGIN
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN json_build_object('role', 'anon')::text ELSE json_build_object('sub', p_uid, 'role', 'authenticated')::text END, true);
  EXECUTE format('SET LOCAL ROLE %I', p_role);
  BEGIN
    EXECUTE p_sql INTO v_out;
    RESET ROLE;
    RETURN 'OK:' || COALESCE(v_out, '');
  EXCEPTION WHEN OTHERS THEN
    RESET ROLE;
    RETURN 'ERR:' || SQLSTATE || ':' || SQLERRM;
  END;
END $f$;

CREATE FUNCTION pg_temp.rw(p_name text, p_expected text, p_actual text, p_ok boolean) RETURNS text LANGUAGE sql AS $f$
  SELECT p_name || '|' || p_expected || '|' || replace(replace(left(COALESCE(p_actual, 'NULL'), 90), '|', '/'), chr(10), ' ') || '|' || CASE WHEN COALESCE(p_ok, false) THEN 'PASS' ELSE 'FAIL' END
$f$;

DO $t$
DECLARE
  adm uuid; sup uuid; s1 uuid; s2 uuid; s3 uuid; s4 uuid;
  p1 constant uuid := 'fa44711a-8877-47fd-9541-2829cc896908';   -- Kaustubh Atre
  p2 constant uuid := 'd3050e85-d37d-42b5-8ea5-7e4f47894033';   -- Abhay More
  p3 constant uuid := '795f7baf-91f6-4ee3-958a-50d9094403a8';   -- Niraj Mahajan
  b1 uuid; b2 uuid; barch uuid; gpers uuid; jb uuid; jd uuid; ja uuid;
  tkb uuid; tkd uuid; tka uuid; tkp uuid;
  v_res text[] := '{}'; r text; n0 int; n1 int; n2 int; bad text; fn text; fo oid;
BEGIN
  SELECT id INTO adm FROM public.profiles WHERE role = 'admin' ORDER BY id LIMIT 1;
  SELECT id INTO sup FROM public.profiles WHERE role = 'super_admin' ORDER BY id LIMIT 1;
  SELECT id INTO s1 FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT id INTO s2 FROM public.profiles WHERE role = 'student' AND id <> s1 ORDER BY id LIMIT 1;
  SELECT id INTO s3 FROM public.profiles WHERE role = 'student' AND id NOT IN (s1, s2) ORDER BY id LIMIT 1;
  SELECT id INTO s4 FROM public.profiles WHERE role = 'student' AND id NOT IN (s1, s2, s3) ORDER BY id LIMIT 1;
  IF adm IS NULL OR sup IS NULL OR s4 IS NULL
     OR (SELECT count(*) FROM public.profiles WHERE id IN (p1, p2, p3) AND role = 'professor') <> 3 THEN
    PERFORM set_config('app.t07d_results', 'SETUP|admin, super_admin, 4 students and professors p1-p3|missing|SKIP', true);
    RETURN;
  END IF;

  -- Positive-path accounts are made explicitly ACTIVE inside this rolled-back transaction (never persisted).
  UPDATE public.profiles SET status = 'active' WHERE id IN (adm, sup, p1, p2, p3, s1, s2, s3, s4);

  -- ---------- fixtures ----------
  INSERT INTO public.study_groups (name, group_type, is_batch_group, batch_course, batch_institution, created_by) VALUES ('ZZ 8.8.5d B1', 'batch', true, 'ZZ Course', 'ZZ Inst', adm) RETURNING id INTO b1;
  INSERT INTO public.study_groups (name, group_type, is_batch_group, batch_course, batch_institution, created_by) VALUES ('ZZ 8.8.5d B2', 'batch', true, 'ZZ Course', 'ZZ Inst', adm) RETURNING id INTO b2;
  INSERT INTO public.study_groups (name, group_type, is_batch_group, batch_course, batch_institution, created_by, archived_at, archived_by) VALUES ('ZZ 8.8.5d Archived', 'batch', true, 'ZZ Course', 'ZZ Inst', adm, now(), adm) RETURNING id INTO barch;
  INSERT INTO public.study_groups (name, group_type, is_batch_group, created_by) VALUES ('ZZ 8.8.5d Personal', 'custom', false, adm) RETURNING id INTO gpers;
  INSERT INTO public.study_groups (name, group_type, is_batch_group, batch_course, batch_institution, created_by) VALUES ('ZZ 8.8.5d JoinBatch', 'batch', true, 'ZZ Course', 'ZZ Inst', adm) RETURNING id, invite_token INTO jb, tkb;
  INSERT INTO public.study_groups (name, group_type, is_batch_group, batch_course, batch_institution, created_by) VALUES ('ZZ 8.8.5d JoinDrift', 'custom', true, 'ZZ Course', 'ZZ Inst', adm) RETURNING id, invite_token INTO jd, tkd;
  INSERT INTO public.study_groups (name, group_type, is_batch_group, batch_course, batch_institution, created_by, archived_at, archived_by) VALUES ('ZZ 8.8.5d JoinEnded', 'batch', true, 'ZZ Course', 'ZZ Inst', adm, now(), adm) RETURNING id, invite_token INTO ja, tka;
  SELECT invite_token INTO tkp FROM public.study_groups WHERE id = gpers;

  INSERT INTO public.study_group_members (group_id, user_id, role, status) VALUES
    (b1, s1, 'member', 'active'), (b1, s2, 'member', 'active'), (b1, p2, 'member', 'active'),   -- p2 = UNASSIGNED professor with a stray membership
    (b2, s1, 'member', 'active'), (b2, p2, 'member', 'active');

  INSERT INTO public.batch_group_archives (group_id, archived_at, archived_by, report)
  VALUES (barch, (SELECT archived_at FROM public.study_groups WHERE id = barch), adm,
          jsonb_build_object('group', jsonb_build_object('name', 'ZZ 8.8.5d Archived'), 'member_count', 2,
            'members', jsonb_build_array(jsonb_build_object('user_id', s1, 'full_name', 'Student Row'),
                                         jsonb_build_object('user_id', p2, 'full_name', 'Legacy Professor Row'))));

  -- ---------- B0 / T0 ----------
  SELECT count(*) INTO n0 FROM public.batch_group_professors
   WHERE assignment_source = 'migration_backfill' AND assigned_by IS NULL
     AND (professor_id, group_id) IN (
       ('fa44711a-8877-47fd-9541-2829cc896908'::uuid, '7067cc26-fb43-4538-8a3f-7788641aafaf'::uuid),
       ('075ad481-13e8-45e4-9deb-3c38907eb3e6'::uuid, '7067cc26-fb43-4538-8a3f-7788641aafaf'::uuid),
       ('075ad481-13e8-45e4-9deb-3c38907eb3e6'::uuid, '77ff6271-16b3-488c-abb3-5f495eed740d'::uuid),
       ('075ad481-13e8-45e4-9deb-3c38907eb3e6'::uuid, '7c4df0e5-c08a-4b67-b682-a012d6fb5139'::uuid),
       ('795f7baf-91f6-4ee3-958a-50d9094403a8'::uuid, '77ff6271-16b3-488c-abb3-5f495eed740d'::uuid),
       ('d3050e85-d37d-42b5-8ea5-7e4f47894033'::uuid, '77ff6271-16b3-488c-abb3-5f495eed740d'::uuid));
  v_res := v_res || pg_temp.rw('B0 approved backfill: 6 rows, assigned_by NULL, source migration_backfill', '6', n0::text, n0 = 6);
  SELECT count(*) INTO n0 FROM public.batch_group_professors WHERE group_id = 'a8856030-8306-4290-887e-6150b1e86217';
  v_res := v_res || pg_temp.rw('B0b nobody assigned to the archived Intermediate batch', '0', n0::text, n0 = 0);

  bad := '';
  IF pg_get_functiondef('public.get_batch_group_member_stats(uuid)'::regprocedure) NOT ILIKE '%batch_group_access_denial%' OR pg_get_functiondef('public.get_batch_group_member_stats(uuid)'::regprocedure) NOT ILIKE '%p.role = ''student''%' THEN bad := bad || 'stats; '; END IF;
  IF pg_get_functiondef('public.get_batch_group_archive(uuid)'::regprocedure) NOT ILIKE '%batch_group_access_denial%' THEN bad := bad || 'archive; '; END IF;
  IF pg_get_functiondef('public.get_group_detail(uuid)'::regprocedure) NOT ILIKE '%batch_group_access_denial%' THEN bad := bad || 'detail; '; END IF;
  IF pg_get_functiondef('public.get_my_batch_groups()'::regprocedure) NOT ILIKE '%batch_group_professors%' THEN bad := bad || 'my_batch_groups; '; END IF;
  IF pg_get_functiondef('public.join_group_by_token(uuid)'::regprocedure) NOT ILIKE '%Batch access for professors is granted by an admin.%' THEN bad := bad || 'join; '; END IF;
  IF pg_get_functiondef('public.enroll_user_in_batch_group(uuid,uuid)'::regprocedure) NOT ILIKE '%Only students can be added to a batch%' THEN bad := bad || 'enroll; '; END IF;
  v_res := v_res || pg_temp.rw('T0 the 6 changed functions contain the new rules', 'none missing', CASE WHEN bad = '' THEN 'none missing' ELSE bad END, bad = '');

  -- ---------- T1: effective privileges ----------
  bad := '';
  FOREACH fn IN ARRAY ARRAY['public.assign_professor_to_batch(uuid,uuid)', 'public.unassign_professor_from_batch(uuid,uuid)',
                            'public.get_batch_group_professors(uuid)', 'public.get_assignable_professors()', 'public.get_admin_batch_groups()'] LOOP
    fo := to_regprocedure(fn);
    IF fo IS NULL THEN bad := bad || fn || ' missing; '; CONTINUE; END IF;
    IF has_function_privilege('anon', fo, 'EXECUTE') THEN bad := bad || fn || ' anon can run; '; END IF;
    IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = fo AND a.grantee = 0 AND a.privilege_type = 'EXECUTE') THEN bad := bad || fn || ' PUBLIC can run; '; END IF;
    IF NOT has_function_privilege('authenticated', fo, 'EXECUTE') THEN bad := bad || fn || ' authenticated cannot run; '; END IF;
    IF fn <> 'public.get_admin_batch_groups()' THEN
      IF NOT (SELECT prosecdef FROM pg_proc WHERE oid = fo) THEN bad := bad || fn || ' not SECURITY DEFINER; '; END IF;
      IF NOT COALESCE((SELECT array_to_string(proconfig, ',') ILIKE '%search_path=public, extensions%' FROM pg_proc WHERE oid = fo), false) THEN bad := bad || fn || ' search_path not fixed; '; END IF;
    END IF;
  END LOOP;
  fo := to_regprocedure('public.batch_group_access_denial(uuid,uuid,text)');
  IF has_function_privilege('anon', fo, 'EXECUTE') OR has_function_privilege('authenticated', fo, 'EXECUTE') THEN bad := bad || 'helper is callable by a client role; '; END IF;
  IF EXISTS (SELECT 1 FROM pg_proc p, aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a WHERE p.oid = fo AND a.grantee = 0 AND a.privilege_type = 'EXECUTE') THEN bad := bad || 'helper: PUBLIC can run; '; END IF;
  v_res := v_res || pg_temp.rw('T1 effective privileges: anon/PUBLIC refused, authenticated ok, helper internal, definer + fixed search_path', 'no problems', CASE WHEN bad = '' THEN 'none' ELSE bad END, bad = '');

  -- ---------- T2: table ----------
  bad := '';
  IF NOT (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.batch_group_professors'::regclass) THEN bad := bad || 'RLS off; '; END IF;
  SELECT count(*) INTO n0 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'batch_group_professors';
  IF n0 <> 0 THEN bad := bad || n0 || ' policies; '; END IF;
  SELECT count(*) INTO n0 FROM unnest(ARRAY['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','TRIGGER','REFERENCES']) AS privname
   WHERE has_table_privilege('anon', 'public.batch_group_professors', privname) OR has_table_privilege('authenticated', 'public.batch_group_professors', privname);
  IF n0 <> 0 THEN bad := bad || n0 || ' table privileges; '; END IF;
  SELECT count(*) INTO n0 FROM pg_attribute a WHERE a.attrelid = 'public.batch_group_professors'::regclass AND a.attnum > 0 AND NOT a.attisdropped
     AND (has_column_privilege('anon', a.attrelid, a.attnum, 'SELECT') OR has_column_privilege('authenticated', a.attrelid, a.attnum, 'SELECT')
          OR has_column_privilege('authenticated', a.attrelid, a.attnum, 'UPDATE') OR has_column_privilege('authenticated', a.attrelid, a.attnum, 'INSERT'));
  IF n0 <> 0 THEN bad := bad || n0 || ' column privileges; '; END IF;
  SELECT count(*) INTO n0 FROM pg_class c, aclexplode(c.relacl) a WHERE c.oid = 'public.batch_group_professors'::regclass AND a.grantee = 0;
  IF n0 <> 0 THEN bad := bad || 'granted to PUBLIC; '; END IF;
  v_res := v_res || pg_temp.rw('T2 table: RLS on, 0 policies, nothing for anon / authenticated / PUBLIC', 'no problems', CASE WHEN bad = '' THEN 'none' ELSE bad END, bad = '');

  r := pg_temp.t_call(s1, 'authenticated', $q$SELECT count(*)::text FROM public.batch_group_professors$q$);
  v_res := v_res || pg_temp.rw('D1 student cannot read the assignment table directly [CRITICAL]', '42501', r, r LIKE 'ERR:42501%');
  r := pg_temp.t_call(adm, 'authenticated', $q$SELECT count(*)::text FROM public.batch_group_professors$q$);
  v_res := v_res || pg_temp.rw('D2 even an admin cannot read it directly (only via functions)', '42501', r, r LIKE 'ERR:42501%');
  r := pg_temp.t_call(NULL, 'anon', $q$SELECT count(*)::text FROM public.batch_group_professors$q$);
  v_res := v_res || pg_temp.rw('D3 anon cannot read it', '42501', r, r LIKE 'ERR:42501%');
  r := pg_temp.t_call(s1, 'authenticated', format($q$INSERT INTO public.batch_group_professors (group_id, professor_id) VALUES (%L, %L) RETURNING group_id::text$q$, b1, p1));
  v_res := v_res || pg_temp.rw('D4 student cannot write the table directly [CRITICAL]', '42501', r, r LIKE 'ERR:42501%');

  -- ---------- A: assign ----------
  SELECT count(*) INTO n0 FROM public.admin_audit_log WHERE action = 'assign_professor_to_batch' AND target_user_id = p1;
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT (public.assign_professor_to_batch(%L, %L))->>'changed'$q$, b1, p1));
  SELECT count(*) INTO n1 FROM public.admin_audit_log WHERE action = 'assign_professor_to_batch' AND target_user_id = p1 AND admin_id = adm AND (details->>'group_id')::uuid = b1;
  SELECT count(*) INTO n2 FROM public.batch_group_professors WHERE group_id = b1 AND professor_id = p1 AND assigned_by = adm AND assignment_source = 'admin';
  v_res := v_res || pg_temp.rw('A1 admin assigns professor: changed, row (assigned_by = admin), +1 audit', 'OK:true, 1 row, +1', r || ', ' || n2 || ' row, +' || (n1 - n0), r = 'OK:true' AND n2 = 1 AND n1 - n0 = 1);
  SELECT count(*) INTO n0 FROM public.admin_audit_log WHERE action = 'assign_professor_to_batch' AND target_user_id = p1;   -- new baseline for A2
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT (public.assign_professor_to_batch(%L, %L))->>'changed'$q$, b1, p1));
  SELECT count(*) INTO n2 FROM public.admin_audit_log WHERE action = 'assign_professor_to_batch' AND target_user_id = p1;
  v_res := v_res || pg_temp.rw('A2 same assignment again: no change, NO new audit', 'OK:false, +0', r || ', +' || (n2 - n0), r = 'OK:false' AND n2 - n0 = 0);
  r := pg_temp.t_call(sup, 'authenticated', format($q$SELECT (public.assign_professor_to_batch(%L, %L))->>'changed'$q$, b1, p3));
  v_res := v_res || pg_temp.rw('A3 super_admin assigns a professor', 'OK:true', r, r = 'OK:true');
  r := pg_temp.t_call(s1, 'authenticated', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, b2, p1));
  v_res := v_res || pg_temp.rw('A4 student cannot assign [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, b1, p2));
  v_res := v_res || pg_temp.rw('A5 even an ASSIGNED professor cannot assign others [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, b2, s2));
  v_res := v_res || pg_temp.rw('A6 target must be a professor (a student is refused)', 'Target must be an active professor', r, r LIKE 'ERR:%Target must be an active professor%');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, gpers, p2));
  v_res := v_res || pg_temp.rw('A7 a personal (non-batch) group is refused', 'not_a_batch', r, r LIKE 'ERR:%not_a_batch%');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, barch, p2));
  v_res := v_res || pg_temp.rw('A8 an ARCHIVED batch is refused', 'batch_archived', r, r LIKE 'ERR:%batch_archived%');
  UPDATE public.profiles SET status = 'suspended' WHERE id = adm;
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, b2, p2));
  v_res := v_res || pg_temp.rw('A9 a SUSPENDED admin is refused [CRITICAL]', 'account_inactive', r, r LIKE 'ERR:%account_inactive%');
  UPDATE public.profiles SET status = 'active' WHERE id = adm;
  UPDATE public.profiles SET status = 'suspended' WHERE id = p2;
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, b2, p2));
  v_res := v_res || pg_temp.rw('A10 a SUSPENDED target professor is refused', 'Target must be an active professor', r, r LIKE 'ERR:%Target must be an active professor%');
  UPDATE public.profiles SET status = 'active' WHERE id = p2;
  r := pg_temp.t_call(NULL, 'anon', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, b1, p2));
  v_res := v_res || pg_temp.rw('A11 anon cannot assign', '42501', r, r LIKE 'ERR:42501%');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT public.assign_professor_to_batch(%L, %L)::text$q$, gen_random_uuid(), p2));
  v_res := v_res || pg_temp.rw('A12 unknown batch id is refused', 'batch_not_found', r, r LIKE 'ERR:%batch_not_found%');

  -- ---------- U: unassign ----------
  SELECT count(*) INTO n0 FROM public.admin_audit_log WHERE action = 'unassign_professor_from_batch' AND target_user_id = p3;
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT (public.unassign_professor_from_batch(%L, %L))->>'changed'$q$, b1, p3));
  SELECT count(*) INTO n1 FROM public.admin_audit_log WHERE action = 'unassign_professor_from_batch' AND target_user_id = p3 AND admin_id = adm;
  SELECT count(*) INTO n2 FROM public.batch_group_professors WHERE group_id = b1 AND professor_id = p3;
  v_res := v_res || pg_temp.rw('U1 admin unassigns: changed, row gone, +1 audit', 'OK:true, 0 rows, +1', r || ', ' || n2 || ' rows, +' || (n1 - n0), r = 'OK:true' AND n2 = 0 AND n1 - n0 = 1);
  SELECT count(*) INTO n0 FROM public.admin_audit_log WHERE action = 'unassign_professor_from_batch' AND target_user_id = p3;   -- new baseline for U2
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT (public.unassign_professor_from_batch(%L, %L))->>'changed'$q$, b1, p3));
  SELECT count(*) INTO n2 FROM public.admin_audit_log WHERE action = 'unassign_professor_from_batch' AND target_user_id = p3;
  v_res := v_res || pg_temp.rw('U2 unassign again: no change, NO new audit', 'OK:false, +0', r || ', +' || (n2 - n0), r = 'OK:false' AND n2 - n0 = 0);
  r := pg_temp.t_call(s1, 'authenticated', format($q$SELECT public.unassign_professor_from_batch(%L, %L)::text$q$, b1, p1));
  v_res := v_res || pg_temp.rw('U3 student cannot unassign [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT public.unassign_professor_from_batch(%L, %L)::text$q$, b1, p1));
  v_res := v_res || pg_temp.rw('U4 a professor cannot unassign (not even themselves) [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');

  -- ---------- L: lists ----------
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_professors(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('L1 admin lists the batch professors', 'OK:1', r, r = 'OK:1');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_professors(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('L2 an assigned professor cannot list assignments [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(s1, 'authenticated', $q$SELECT count(*)::text FROM public.get_assignable_professors()$q$);
  v_res := v_res || pg_temp.rw('L3 student cannot list assignable professors', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(adm, 'authenticated', $q$SELECT count(*)::text FROM public.get_assignable_professors()$q$);
  v_res := v_res || pg_temp.rw('L4 admin lists assignable professors', '>= 3', r, CASE WHEN r LIKE 'OK:%' THEN substr(r, 4)::int >= 3 ELSE false END);

  -- ---------- V: access (p1 is assigned to b1 only and is NOT a member of anything; p2 is an unassigned ACTIVE member of b1 + b2) ----------
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT (public.get_group_detail(%L)::jsonb)->'group'->>'name'$q$, b1));
  v_res := v_res || pg_temp.rw('V1 ASSIGNED professor WITHOUT membership opens the batch page', 'OK:ZZ 8.8.5d B1', r, r = 'OK:ZZ 8.8.5d B1');
  r := pg_temp.t_call(p2, 'authenticated', format($q$SELECT public.get_group_detail(%L)::text$q$, b2));
  v_res := v_res || pg_temp.rw('V2 UNASSIGNED professor WITH an active membership is REFUSED [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(p2, 'authenticated', format($q$SELECT public.get_group_detail(%L)::text$q$, b1));
  v_res := v_res || pg_temp.rw('V2b same professor, other batch with membership: REFUSED', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT public.get_group_detail(%L)::text$q$, b2));
  v_res := v_res || pg_temp.rw('V3 cross-batch: professor assigned to B1 is refused on B2 [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(s1, 'authenticated', format($q$SELECT (public.get_group_detail(%L)::jsonb)->'group'->>'name'$q$, b1));
  v_res := v_res || pg_temp.rw('V4 a student MEMBER still opens the batch page', 'OK:ZZ 8.8.5d B1', r, r = 'OK:ZZ 8.8.5d B1');
  r := pg_temp.t_call(s3, 'authenticated', format($q$SELECT public.get_group_detail(%L)::text$q$, b1));
  v_res := v_res || pg_temp.rw('V4b a student who is NOT a member is refused', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT (public.get_group_detail(%L)::jsonb)->'group'->>'name'$q$, b2));
  v_res := v_res || pg_temp.rw('V4c admin opens any batch page (unchanged)', 'OK:ZZ 8.8.5d B2', r, r = 'OK:ZZ 8.8.5d B2');
  r := pg_temp.t_call(sup, 'authenticated', format($q$SELECT (public.get_group_detail(%L)::jsonb)->'group'->>'name'$q$, b2));
  v_res := v_res || pg_temp.rw('V4d super_admin opens any batch page (unchanged)', 'OK:ZZ 8.8.5d B2', r, r = 'OK:ZZ 8.8.5d B2');

  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('V5 assigned professor sees the report: 2 STUDENT rows (the member professor is excluded)', 'OK:2', r, r = 'OK:2');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L) s JOIN public.profiles pp ON pp.id = s.user_id WHERE pp.role <> 'student'$q$, b1));
  v_res := v_res || pg_temp.rw('V5b no staff row in the student report', 'OK:0', r, r = 'OK:0');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('V5c admin sees the same student-only report', 'OK:2', r, r = 'OK:2');
  r := pg_temp.t_call(sup, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('V5d super_admin sees the report', 'OK:2', r, r = 'OK:2');
  r := pg_temp.t_call(p2, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('V6 UNASSIGNED professor who is a member is refused the report [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(s1, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('V6b a student is refused the report [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b2));
  v_res := v_res || pg_temp.rw('V6c cross-batch report is refused [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, gen_random_uuid()));
  v_res := v_res || pg_temp.rw('V7 unknown id as a professor says only "Access denied" (no existence leak)', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, gen_random_uuid()));
  v_res := v_res || pg_temp.rw('V7b unknown id as an admin', 'Not a batch group', r, r LIKE 'ERR:%Not a batch group%');

  INSERT INTO public.batch_group_professors (group_id, professor_id, assigned_by, assignment_source) VALUES (barch, p1, adm, 'admin');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT jsonb_array_length(public.get_batch_group_archive(%L)->'report'->'members')::text$q$, barch));
  v_res := v_res || pg_temp.rw('V8 assigned professor reads the archive snapshot: all 2 stored rows', 'OK:2', r, r = 'OK:2');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT public.get_batch_group_archive(%L)->'report'->'members'->1->>'full_name'$q$, barch));
  v_res := v_res || pg_temp.rw('V8b snapshot returned VERBATIM (legacy staff row untouched, not filtered)', 'OK:Legacy Professor Row', r, r = 'OK:Legacy Professor Row');
  r := pg_temp.t_call(p2, 'authenticated', format($q$SELECT public.get_batch_group_archive(%L)::text$q$, barch));
  v_res := v_res || pg_temp.rw('V8c unassigned professor refused the archive [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(s1, 'authenticated', format($q$SELECT public.get_batch_group_archive(%L)::text$q$, barch));
  v_res := v_res || pg_temp.rw('V8d student refused the archive', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT jsonb_array_length(public.get_batch_group_archive(%L)->'report'->'members')::text$q$, barch));
  v_res := v_res || pg_temp.rw('V8e admin reads the archive', 'OK:2', r, r = 'OK:2');

  r := pg_temp.t_call(p1, 'authenticated', $q$SELECT COALESCE(string_agg(name, ',' ORDER BY name), '') FROM public.get_my_batch_groups() WHERE name LIKE 'ZZ 8.8.5d B_'$q$);
  v_res := v_res || pg_temp.rw('V9 assigned professor lists ONLY the assigned batch', 'OK:ZZ 8.8.5d B1', r, r = 'OK:ZZ 8.8.5d B1');
  r := pg_temp.t_call(p2, 'authenticated', $q$SELECT COALESCE(string_agg(name, ',' ORDER BY name), '') FROM public.get_my_batch_groups() WHERE name LIKE 'ZZ 8.8.5d B_'$q$);
  v_res := v_res || pg_temp.rw('V9b unassigned professor (member of both) lists NONE of them', 'OK:', r, r = 'OK:');
  r := pg_temp.t_call(adm, 'authenticated', $q$SELECT COALESCE(string_agg(name, ',' ORDER BY name), '') FROM public.get_my_batch_groups() WHERE name LIKE 'ZZ 8.8.5d B_'$q$);
  v_res := v_res || pg_temp.rw('V9c admin lists every active batch (unchanged)', 'OK:ZZ 8.8.5d B1,ZZ 8.8.5d B2', r, r = 'OK:ZZ 8.8.5d B1,ZZ 8.8.5d B2');

  -- demotion / suspension (done as postgres inside the rolled-back transaction)
  UPDATE public.profiles SET role = 'student' WHERE id = p1;
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT public.get_group_detail(%L)::text$q$, b1));
  v_res := v_res || pg_temp.rw('V10 DEMOTED professor (row still present) refused the page [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('V10b demoted professor refused the report [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT is_active_professor::text FROM public.get_batch_group_professors(%L) WHERE professor_id = %L$q$, b1, p1));
  v_res := v_res || pg_temp.rw('L5 admin list flags the demoted professor (not hidden)', 'OK:false', r, r = 'OK:false');
  UPDATE public.profiles SET role = 'professor' WHERE id = p1;

  UPDATE public.profiles SET status = 'suspended' WHERE id = p1;
  r := pg_temp.t_call(p1, 'authenticated', format($q$SELECT public.get_group_detail(%L)::text$q$, b1));
  v_res := v_res || pg_temp.rw('V11 SUSPENDED assigned professor refused the page [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(p1, 'authenticated', $q$SELECT COALESCE(string_agg(name, ','), '') FROM public.get_my_batch_groups() WHERE name LIKE 'ZZ 8.8.5d B_'$q$);
  v_res := v_res || pg_temp.rw('V11b suspended professor lists no batches', 'OK:', r, r = 'OK:');
  UPDATE public.profiles SET status = 'active' WHERE id = p1;

  UPDATE public.profiles SET status = 'suspended' WHERE id = adm;
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b1));
  v_res := v_res || pg_temp.rw('V12 SUSPENDED admin refused the report [CRITICAL]', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  UPDATE public.profiles SET status = 'active' WHERE id = adm;

  SELECT count(*) INTO n0 FROM public.admin_audit_log WHERE action = 'unassign_professor_from_batch' AND target_user_id = p1;
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT (public.unassign_professor_from_batch(%L, %L))->>'changed'$q$, barch, p1));
  SELECT count(*) INTO n1 FROM public.admin_audit_log WHERE action = 'unassign_professor_from_batch' AND target_user_id = p1;
  v_res := v_res || pg_temp.rw('U5 admin may unassign from an ARCHIVED batch (+1 audit)', 'OK:true, +1', r || ', +' || (n1 - n0), r = 'OK:true' AND n1 - n0 = 1);

  r := pg_temp.t_call(adm, 'authenticated', $q$SELECT (count(*) >= 2)::text FROM public.get_admin_batch_groups()$q$);
  v_res := v_res || pg_temp.rw('V14 admin still uses get_admin_batch_groups', 'OK:true', r, r = 'OK:true');
  r := pg_temp.t_call(s1, 'authenticated', $q$SELECT count(*)::text FROM public.get_admin_batch_groups()$q$);
  v_res := v_res || pg_temp.rw('V14b student refused by its internal check', 'Access denied', r, r LIKE 'ERR:%Access denied%');
  r := pg_temp.t_call(NULL, 'anon', $q$SELECT count(*)::text FROM public.get_admin_batch_groups()$q$);
  v_res := v_res || pg_temp.rw('V14c anon cannot even execute it (ACL revoked)', '42501', r, r LIKE 'ERR:42501%');

  bad := '';
  r := pg_temp.t_call(NULL, 'anon', $q$SELECT count(*)::text FROM public.get_my_batch_groups()$q$);       IF r NOT LIKE 'ERR:42501%' THEN bad := bad || 'my_batch_groups; '; END IF;
  r := pg_temp.t_call(NULL, 'anon', format($q$SELECT public.get_group_detail(%L)::text$q$, b1));            IF r NOT LIKE 'ERR:42501%' THEN bad := bad || 'detail; '; END IF;
  r := pg_temp.t_call(NULL, 'anon', format($q$SELECT count(*)::text FROM public.get_batch_group_member_stats(%L)$q$, b1)); IF r NOT LIKE 'ERR:42501%' THEN bad := bad || 'stats; '; END IF;
  r := pg_temp.t_call(NULL, 'anon', format($q$SELECT public.get_batch_group_archive(%L)::text$q$, barch)); IF r NOT LIKE 'ERR:42501%' THEN bad := bad || 'archive; '; END IF;
  v_res := v_res || pg_temp.rw('V15 anon refused on my_batch_groups / detail / stats / archive', 'all 42501', CASE WHEN bad = '' THEN 'all refused' ELSE bad END, bad = '');

  -- ---------- J: join link ----------
  r := pg_temp.t_call(p3, 'authenticated', format($q$SELECT public.join_group_by_token(%L)::text$q$, tkb));
  SELECT count(*) INTO n0 FROM public.study_group_members WHERE group_id = jb AND user_id = p3;
  v_res := v_res || pg_temp.rw('J1 professor + batch link: REFUSED with the exact message, NO membership [CRITICAL]', 'refused, 0 rows', r || ', ' || n0 || ' rows', r LIKE 'ERR:%Batch access for professors is granted by an admin.%' AND n0 = 0);
  r := pg_temp.t_call(s2, 'authenticated', format($q$SELECT public.join_group_by_token(%L)->>'status'$q$, tkb));
  v_res := v_res || pg_temp.rw('J2 student + batch link: still goes to the approval queue', 'OK:requested', r, r = 'OK:requested');
  r := pg_temp.t_call(p3, 'authenticated', format($q$SELECT public.join_group_by_token(%L)->>'status'$q$, tkp));
  v_res := v_res || pg_temp.rw('J3 professor + PERSONAL group link: active as before', 'OK:active', r, r = 'OK:active');
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT public.join_group_by_token(%L)->>'status'$q$, tkb));
  v_res := v_res || pg_temp.rw('J4 admin + batch link: unchanged (active)', 'OK:active', r, r = 'OK:active');
  r := pg_temp.t_call(sup, 'authenticated', format($q$SELECT public.join_group_by_token(%L)->>'status'$q$, tkb));
  v_res := v_res || pg_temp.rw('J4b super_admin + batch link: unchanged (active)', 'OK:active', r, r = 'OK:active');
  r := pg_temp.t_call(p3, 'authenticated', format($q$SELECT public.join_group_by_token(%L)::text$q$, tka));
  SELECT count(*) INTO n0 FROM public.study_group_members WHERE group_id = ja AND user_id = p3;
  v_res := v_res || pg_temp.rw('J5 ARCHIVED batch refused first (ended), no row', 'This batch has ended, 0 rows', r || ', ' || n0 || ' rows', r LIKE 'ERR:%This batch has ended%' AND n0 = 0);
  r := pg_temp.t_call(p3, 'authenticated', format($q$SELECT public.join_group_by_token(%L)::text$q$, tkd));
  SELECT count(*) INTO n0 FROM public.study_group_members WHERE group_id = jd AND user_id = p3;
  v_res := v_res || pg_temp.rw('J6 DRIFTED batch (is_batch_group true, group_type custom): professor still refused [CRITICAL]', 'refused, 0 rows', r || ', ' || n0 || ' rows', r LIKE 'ERR:%Batch access for professors is granted by an admin.%' AND n0 = 0);
  r := pg_temp.t_call(s2, 'authenticated', format($q$SELECT public.join_group_by_token(%L)->>'status'$q$, tkd));
  v_res := v_res || pg_temp.rw('J7 drifted batch + student: approval queue (not instant)', 'OK:requested', r, r = 'OK:requested');
  r := pg_temp.t_call(s4, 'authenticated', format($q$SELECT public.join_group_by_token(%L)->>'status'$q$, tkp));
  v_res := v_res || pg_temp.rw('J8 student + personal group link: active as before', 'OK:active', r, r = 'OK:active');

  -- ---------- E: admin direct add ----------
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT 'added'::text FROM (SELECT public.enroll_user_in_batch_group(%L, %L)) x$q$, s3, b1));
  SELECT count(*) INTO n0 FROM public.study_group_members WHERE group_id = b1 AND user_id = s3 AND status = 'active';
  v_res := v_res || pg_temp.rw('E1 admin adds a STUDENT: still works', 'OK:added, 1 active row', r || ', ' || n0 || ' row', r = 'OK:added' AND n0 = 1);
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT 'added'::text FROM (SELECT public.enroll_user_in_batch_group(%L, %L)) x$q$, p3, b1));
  SELECT count(*) INTO n0 FROM public.study_group_members WHERE group_id = b1 AND user_id = p3;
  v_res := v_res || pg_temp.rw('E2 admin adds a PROFESSOR: refused, no row [CRITICAL]', 'Only students, 0 rows', r || ', ' || n0 || ' rows', r LIKE 'ERR:%Only students can be added to a batch%' AND n0 = 0);
  r := pg_temp.t_call(adm, 'authenticated', format($q$SELECT 'added'::text FROM (SELECT public.enroll_user_in_batch_group(%L, %L)) x$q$, gen_random_uuid(), b1));
  v_res := v_res || pg_temp.rw('E3 unknown user id: refused', 'Only students', r, r LIKE 'ERR:%Only students can be added to a batch%');
  r := pg_temp.t_call(sup, 'authenticated', format($q$SELECT 'added'::text FROM (SELECT public.enroll_user_in_batch_group(%L, %L)) x$q$, adm, b1));
  v_res := v_res || pg_temp.rw('E4 an admin account as the target: refused (student concept)', 'Only students', r, r LIKE 'ERR:%Only students can be added to a batch%');
  r := pg_temp.t_call(s1, 'authenticated', format($q$SELECT 'added'::text FROM (SELECT public.enroll_user_in_batch_group(%L, %L)) x$q$, s4, b1));
  v_res := v_res || pg_temp.rw('E5 a student cannot call it', 'admin only', r, r LIKE 'ERR:%admin only%');

  PERFORM set_config('app.t07d_results', array_to_string(v_res, chr(10)), true);
END $t$;

SELECT split_part(l, '|', 1) AS test, split_part(l, '|', 2) AS expected, split_part(l, '|', 3) AS actual, split_part(l, '|', 4) AS result
FROM unnest(string_to_array(current_setting('app.t07d_results', true), chr(10))) AS l;

ROLLBACK;
