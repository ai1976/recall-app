-- [TEST] rename_batch_group (run AFTER 02). Rollback-only: everything below is undone by the final ROLLBACK.
-- Description: Runs as the real people (SET LOCAL ROLE authenticated). It creates its OWN temporary batches, so no live name changes.
--   R1 admin renames -> changed, name saved, +1 audit      R2 same name again -> no-op, no new audit
--   R3 messy spaces -> stored trimmed + collapsed          R4 blank refused    R5 101 chars refused
--   R6 duplicate (different case/spaces) in same course+institution refused
--   R7 same name allowed when the institution differs      R8 NULL course+institution: duplicate refused (NULL = NULL)
--   R9 student refused [CRITICAL]   R10 professor refused [CRITICAL]   R11 archived batch refused   R12 anon cannot execute
BEGIN;

DO $t$
DECLARE
  adm uuid; stu uuid; prof uuid;
  a uuid; b uuid; c uuid; d uuid; e uuid; arch uuid;
  v_res text[] := '{}'; r jsonb; v_err text; n0 int; n1 int; nm text;
BEGIN
  SELECT id INTO adm  FROM public.profiles WHERE role = 'admin' LIMIT 1;
  SELECT id INTO stu  FROM public.profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO prof FROM public.profiles WHERE role = 'professor' LIMIT 1;
  INSERT INTO public.study_groups (name, is_batch_group, group_type, batch_course, batch_institution, created_by) VALUES ('ZZ Rename A', true, 'batch', 'ZZ Course', 'ZZ Inst', adm) RETURNING id INTO a;
  INSERT INTO public.study_groups (name, is_batch_group, group_type, batch_course, batch_institution, created_by) VALUES ('ZZ Rename B', true, 'batch', 'ZZ Course', 'ZZ Inst', adm) RETURNING id INTO b;
  INSERT INTO public.study_groups (name, is_batch_group, group_type, batch_course, batch_institution, created_by) VALUES ('ZZ Rename C', true, 'batch', 'ZZ Course', 'ZZ Other Inst', adm) RETURNING id INTO c;
  INSERT INTO public.study_groups (name, is_batch_group, group_type, batch_course, batch_institution, created_by) VALUES ('ZZ Null One', true, 'batch', NULL, NULL, adm) RETURNING id INTO d;
  INSERT INTO public.study_groups (name, is_batch_group, group_type, batch_course, batch_institution, created_by) VALUES ('ZZ Null Two', true, 'batch', NULL, NULL, adm) RETURNING id INTO e;
  INSERT INTO public.study_groups (name, is_batch_group, group_type, batch_course, batch_institution, created_by, archived_at) VALUES ('ZZ Rename Archived', true, 'batch', 'ZZ Course', 'ZZ Inst', adm, NOW()) RETURNING id INTO arch;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);

  -- R1
  SELECT count(*) INTO n0 FROM public.admin_audit_log WHERE action = 'rename_batch_group';
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.rename_batch_group(a, 'ZZ Renamed A'); RESET ROLE;
    SELECT count(*) INTO n1 FROM public.admin_audit_log WHERE action = 'rename_batch_group';
    SELECT name INTO nm FROM public.study_groups WHERE id = a;
    v_res := v_res || ('R1 admin renames|changed, saved, +1 audit|' || (r->>'changed') || ', ' || nm || ', +' || (n1 - n0) || '|' ||
             CASE WHEN (r->>'changed')::boolean AND nm = 'ZZ Renamed A' AND n1 - n0 = 1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R1|ok|' || v_err || '|FAIL')::text; END;

  -- R2
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.rename_batch_group(a, 'ZZ Renamed A'); RESET ROLE;
    SELECT count(*) INTO n0 FROM public.admin_audit_log WHERE action = 'rename_batch_group';
    v_res := v_res || ('R2 same name is a no-op|changed=false, no new audit|' || (r->>'changed') || ', audit ' || n0 || ' (was ' || n1 || ')|' ||
             CASE WHEN NOT (r->>'changed')::boolean AND n0 = n1 THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R2|ok|' || v_err || '|FAIL')::text; END;

  -- R3
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.rename_batch_group(a, E'   ZZ   Renamed \t  A2  '); RESET ROLE;
    v_res := v_res || ('R3 spaces trimmed and collapsed|ZZ Renamed A2|' || (r->>'name') || '|' ||
             CASE WHEN r->>'name' = 'ZZ Renamed A2' THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R3|ok|' || v_err || '|FAIL')::text; END;

  -- R4
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rename_batch_group(a, '   '); RESET ROLE;
    v_res := v_res || 'R4 blank refused|error|accepted|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R4 blank refused|error|' || v_err || '|' || CASE WHEN v_err ILIKE '%blank%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  -- R5
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rename_batch_group(a, repeat('x', 101)); RESET ROLE;
    v_res := v_res || 'R5 101 chars refused|error|accepted|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R5 101 chars refused|error|' || v_err || '|' || CASE WHEN v_err ILIKE '%too long%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  -- R6
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rename_batch_group(b, '  zz RENAMED a2 '); RESET ROLE;
    v_res := v_res || 'R6 duplicate (case/space) refused|error|accepted|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R6 duplicate (case/space) refused|error|' || v_err || '|' || CASE WHEN v_err ILIKE '%already uses%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  -- R7
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    r := public.rename_batch_group(c, 'ZZ Renamed A2'); RESET ROLE;
    v_res := v_res || ('R7 same name, different institution allowed|changed|' || (r->>'changed') || '|' ||
             CASE WHEN (r->>'changed')::boolean THEN 'PASS' ELSE 'FAIL' END)::text;
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE; v_res := v_res || ('R7|allowed|' || v_err || '|FAIL')::text; END;

  -- R8
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rename_batch_group(e, 'zz null one'); RESET ROLE;
    v_res := v_res || 'R8 NULL course+institution duplicate refused|error|accepted|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R8 NULL course+institution duplicate refused|error|' || v_err || '|' || CASE WHEN v_err ILIKE '%already uses%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  -- R9 student
  PERFORM set_config('request.jwt.claims', json_build_object('sub', stu, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rename_batch_group(b, 'ZZ Hacked'); RESET ROLE;
    v_res := v_res || 'R9 student refused [CRITICAL]|not_admin|accepted|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R9 student refused [CRITICAL]|not_admin|' || v_err || '|' || CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  -- R10 professor
  PERFORM set_config('request.jwt.claims', json_build_object('sub', prof, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rename_batch_group(b, 'ZZ Hacked'); RESET ROLE;
    v_res := v_res || 'R10 professor refused [CRITICAL]|not_admin|accepted|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R10 professor refused [CRITICAL]|not_admin|' || v_err || '|' || CASE WHEN v_err ILIKE '%not_admin%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  -- R11 archived batch, as admin
  PERFORM set_config('request.jwt.claims', json_build_object('sub', adm, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.rename_batch_group(arch, 'ZZ Whatever'); RESET ROLE;
    v_res := v_res || 'R11 archived batch refused|batch_archived|accepted|FAIL';
  EXCEPTION WHEN OTHERS THEN v_err := SQLERRM; RESET ROLE;
    v_res := v_res || ('R11 archived batch refused|batch_archived|' || v_err || '|' || CASE WHEN v_err ILIKE '%batch_archived%' THEN 'PASS' ELSE 'FAIL' END)::text; END;

  -- R12 anon cannot execute
  v_res := v_res || ('R12 anon cannot execute|false|' || has_function_privilege('anon', 'public.rename_batch_group(uuid,text)', 'EXECUTE') || '|' ||
           CASE WHEN NOT has_function_privilege('anon', 'public.rename_batch_group(uuid,text)', 'EXECUTE') THEN 'PASS' ELSE 'FAIL' END)::text;

  PERFORM set_config('app.t03e_results', array_to_string(v_res, chr(10)), true);
END $t$;

SELECT split_part(l, '|', 1) AS test, split_part(l, '|', 2) AS expected, split_part(l, '|', 3) AS actual, split_part(l, '|', 4) AS result
FROM unnest(string_to_array(current_setting('app.t03e_results', true), chr(10))) AS l;

ROLLBACK;
