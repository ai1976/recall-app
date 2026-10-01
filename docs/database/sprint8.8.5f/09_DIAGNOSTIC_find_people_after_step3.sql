-- [DIAGNOSTIC] Find People page showed "0 of 0 users" for the super admin after Step 3 (01/10/2026). READ-ONLY (rolled back).
-- Description: get_discoverable_users is SECURITY DEFINER, so the profiles column lock-down should not affect it. This returns ONE
--   table: who owns the function (the owner's own privileges are untouched by 06) and how many people it returns for the super admin
--   versus an ordinary student, so we can tell "pre-existing behaviour for that account" from "regression".
BEGIN;
DO $t$
DECLARE
  sa uuid; st uuid; n_sa int; n_st int; own text; secdef boolean;
BEGIN
  SELECT id INTO sa FROM public.profiles WHERE role = 'super_admin' LIMIT 1;
  SELECT id INTO st FROM public.profiles WHERE role = 'student' ORDER BY id LIMIT 1;
  SELECT pg_get_userbyid(p.proowner), p.prosecdef INTO own, secdef
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace WHERE n.nspname = 'public' AND p.proname = 'get_discoverable_users';

  PERFORM set_config('request.jwt.claims', json_build_object('sub', sa, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*) INTO n_sa FROM public.get_discoverable_users();
  RESET ROLE;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', st, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  SELECT count(*) INTO n_st FROM public.get_discoverable_users();
  RESET ROLE;

  PERFORM set_config('app.t09f_results', 'function owner|' || own || chr(10) || 'security definer|' || secdef::text || chr(10) ||
    'returned to super_admin|' || n_sa || chr(10) || 'returned to a student|' || n_st, true);
END $t$;

SELECT split_part(l, '|', 1) AS item, split_part(l, '|', 2) AS value
FROM unnest(string_to_array(current_setting('app.t09f_results', true), chr(10))) AS l;
ROLLBACK;
