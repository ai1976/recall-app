-- Name: [DIAGNOSTIC] Sprint 7.5 Pre-flight — grants, flashcards RLS, mcq row count
--
-- Description: Run before any 7.5 DDL. Confirms (1) the two Sprint 7.4 analytics
-- RPCs still have correct grants (REVOKE ALL FROM PUBLIC/anon, GRANT EXECUTE TO
-- authenticated) and their IDOR guards intact, (2) the exact live RLS policies on
-- flashcards for INSERT/UPDATE (names + definitions, so D-10's new RESTRICTIVE
-- policy layers on cleanly instead of guessing), (3) whether RLS is even enabled
-- on flashcards, (4) zero pre-existing question_type='mcq' rows (7.5-B
-- assumption), and (5) the live question_type column constraint (NOT NULL /
-- default / any CHECK enum) so the authoring + bulk-upload code targets the
-- real shape. Read-only, no writes.

-- 1. Grants + guard on the two 7.4 analytics RPCs
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_can_exec,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_can_exec,
  (SELECT string_agg(l, ' | ') FROM unnest(string_to_array(pg_get_functiondef(p.oid), E'\n')) AS l
     WHERE l ILIKE '%Access denied%') AS guard_line_found
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_question_type_performance', 'get_educator_accuracy_by_qtype');

-- 2. Is RLS enabled on flashcards?
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname = 'flashcards';

-- 3. Every live RLS policy on flashcards (name, command, permissive/restrictive, roles, using/with check)
SELECT
  polname,
  CASE polcmd WHEN 'r' THEN 'SELECT' WHEN 'a' THEN 'INSERT' WHEN 'w' THEN 'UPDATE' WHEN 'd' THEN 'DELETE' WHEN '*' THEN 'ALL' END AS command,
  CASE WHEN polpermissive THEN 'PERMISSIVE' ELSE 'RESTRICTIVE' END AS type,
  (SELECT array_agg(rolname) FROM pg_roles WHERE oid = ANY(polroles)) AS roles,
  pg_get_expr(polqual, polrelid) AS using_expr,
  pg_get_expr(polwithcheck, polrelid) AS with_check_expr
FROM pg_policy
WHERE polrelid = 'public.flashcards'::regclass
ORDER BY command, polname;

-- 4. Any pre-existing mcq rows? (7.5-B expects zero)
SELECT question_type, COUNT(*) FROM flashcards GROUP BY question_type ORDER BY 2 DESC;

-- 5. question_type column definition (NOT NULL, default, and any CHECK constraint enumerating allowed values)
SELECT column_name, is_nullable, column_default, data_type
FROM information_schema.columns
WHERE table_name = 'flashcards' AND column_name IN ('question_type', 'options', 'correct_answer', 'back_text', 'points_to_remember');

SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.flashcards'::regclass AND contype = 'c';

-- 6. is_admin() — confirm it exists and its exact role check, so is_professor_or_admin() mirrors the real pattern
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'is_admin' AND pronamespace = 'public'::regnamespace;
