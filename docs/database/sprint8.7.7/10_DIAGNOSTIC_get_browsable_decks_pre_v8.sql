-- [DIAGNOSTIC] get_browsable_decks - state BEFORE deploying v8
-- Description: READ-ONLY. Sprint 8.7.7. Run BEFORE 11_FUNCTIONS and paste the result. Records the current overloads,
--   return columns, SECURITY DEFINER flag, search_path setting and ACL, so 12_TEST T1 can prove v8 changed only the
--   return type (ACL/flags identical after the DROP + CREATE). Expect exactly one row, ending in
--   provenance_source_name text (v7).
SELECT p.oid::regprocedure                      AS signature,
       pg_get_function_result(p.oid)            AS returns,
       p.prosecdef                              AS security_definer,
       p.proconfig                              AS settings,
       p.proacl::text                           AS acl
FROM pg_proc p
WHERE p.proname = 'get_browsable_decks'
  AND p.pronamespace = 'public'::regnamespace;
