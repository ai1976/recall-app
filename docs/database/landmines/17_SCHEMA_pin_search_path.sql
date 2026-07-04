-- Name: [SCHEMA] Pin function search_path to 'public, extensions' (L3 hardening)
-- Description: Resolves the Advisor "Function Search Path Mutable" finding by pinning every
-- our-owned, currently-unpinned public function/procedure to a fixed BEHAVIOR-PRESERVING
-- search_path of 'public, extensions'. No function body changes → zero runtime behavior change;
-- 'extensions' is included so unqualified extension calls (uuid_generate_v4, crypt, digest, …
-- surfaced by 16 Block 3) keep resolving. Signatures unchanged → no PostgREST reload needed.
--
-- HARD PREREQUISITE: run 16_DIAGNOSTIC first and confirm:
--   - Block 1: 'public, extensions' matches the live API-role search_path (adjust the literal
--     below if your live default differs, e.g. includes a custom schema).
--   - Block 3: every extension-using function is covered by including 'extensions' (it is).
--   - Block 4: anon/authenticated CANNOT create in public (expected FALSE/FALSE).
--
-- DEPLOY IN TWO PASSES: review Block A's generated list, then run Block B (which applies
-- SECURITY DEFINER functions FIRST — the actual risk — then the rest). Block B is idempotent:
-- re-running only touches still-unpinned functions.

-- ============================================
-- BLOCK A — GENERATE & REVIEW (read-only). Emits the exact ALTER statements that Block B will run.
-- Eyeball this list before applying. SECDEF-first.
-- ============================================
-- NOTE: search_path must be an UNQUOTED identifier list. Do NOT use %L / single-quote the whole
-- value — `SET search_path TO 'public, extensions'` is parsed as ONE schema named
-- "public, extensions" (GUC_LIST_QUOTE gotcha), dropping `public` from the path and breaking every
-- unqualified reference. See 17b_HOTFIX. Correct form: `SET search_path TO public, extensions`.
SELECT format(
         'ALTER %s public.%I(%s) SET search_path TO public, extensions;',
         CASE p.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
         p.proname,
         pg_get_function_identity_arguments(p.oid)
       ) AS alter_statement
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind IN ('f', 'p')  -- functions + procedures (aggregates/window can't take SET this way)
  AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) c WHERE c LIKE 'search_path=%')
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
ORDER BY p.prosecdef DESC, p.proname;

-- ============================================
-- BLOCK B — APPLY. Dynamically ALTERs each unpinned function/procedure, SECDEF-first.
-- Wrapped so the whole batch is one transaction (all-or-nothing).
-- ============================================
DO $$
DECLARE
  r RECORD;
  v_sql text;
BEGIN
  FOR r IN
    SELECT
      p.oid,
      p.proname,
      p.prokind,
      pg_get_function_identity_arguments(p.oid) AS args
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.prokind IN ('f', 'p')
      AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) c WHERE c LIKE 'search_path=%')
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
    ORDER BY p.prosecdef DESC, p.proname
  LOOP
    -- UNQUOTED list — see the note on Block A. Never %L here.
    v_sql := format(
      'ALTER %s public.%I(%s) SET search_path TO public, extensions;',
      CASE r.prokind WHEN 'p' THEN 'PROCEDURE' ELSE 'FUNCTION' END,
      r.proname, r.args
    );
    EXECUTE v_sql;
  END LOOP;
END $$;

-- ROLLBACK (per function): ALTER FUNCTION public.<name>(<args>) RESET search_path;
--   Generate the RESET batch by re-running Block A with `RESET search_path` in place of
--   `SET search_path TO 'public, extensions'`. Behavior-preserving pin means rollback should
--   never be needed, but it is instant and safe.
