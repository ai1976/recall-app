-- Name: [DIAGNOSTIC] Function search_path hardening audit (L3)
-- Description: Ground-truth for L3 — resolve the Supabase Advisor "Function Search Path Mutable"
-- finding (blueprint §1.11 Advisor, ~80 functions). A function with no pinned search_path inherits
-- the CALLER's search_path at run time; for SECURITY DEFINER functions that's a privilege-escalation
-- vector. L3 pins each our-owned public function to a fixed, BEHAVIOR-PRESERVING search_path
-- ('public, extensions') — no body rewrites, no runtime change. This audit confirms (a) the exact
-- value to pin to, (b) which functions are unpinned, (c) that 'extensions' must be included, and
-- (d) that pinning to public is safe here. Read-only. Run all four blocks; paste output before 17.

-- ============================================
-- 1. Live search_path of the API roles — the behavior-preserving value to pin to.
--    Expect the effective default to be (something like) "public, extensions". If rolconfig is
--    NULL for a role, its search_path is the cluster default; confirm 'extensions' is present
--    somewhere in the effective path (Block 3 is the real safety gate).
-- ============================================
SELECT rolname, rolconfig
FROM pg_roles
WHERE rolname IN ('anon', 'authenticated', 'service_role', 'postgres', 'authenticator')
ORDER BY rolname;

-- ============================================
-- 2. Every OUR-OWNED, unpinned function/procedure in public, with signature + SECURITY DEFINER
--    flag + kind. Ordered SECDEF-first (highest risk, deploy first). Excludes objects that belong
--    to an installed extension (deptype 'e') — those are not ours to ALTER.
--    prokind: f = function, p = procedure, a = aggregate, w = window.
-- ============================================
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef                               AS security_definer,
  p.prokind                                 AS kind,
  p.proconfig
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND NOT EXISTS (
    SELECT 1 FROM unnest(coalesce(p.proconfig, '{}')) c WHERE c LIKE 'search_path=%'
  )
  AND NOT EXISTS (
    SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e'  -- skip extension-owned
  )
ORDER BY p.prosecdef DESC, p.prokind, p.proname;

-- ============================================
-- 3. EXTENSION-DEPENDENCY SCAN — functions whose body references a known extensions-schema function
--    unqualified. These would BREAK if pinned to 'public' alone → they prove 'extensions' must be in
--    the pinned path. (Also surfaces any function calling an extension func already-qualified, which
--    is safe either way — read the surrounding text.)
-- ============================================
SELECT p.proname, m.match
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace,
LATERAL regexp_matches(
  pg_get_functiondef(p.oid),
  '(.{0,20}(uuid_generate_v[15]|uuid_nil|crypt|gen_salt|digest|hmac|gen_random_bytes|pgp_sym_encrypt|pgp_sym_decrypt)\s*\()',
  'g'
) AS m(match)
WHERE n.nspname = 'public'
  AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
ORDER BY p.proname;

-- ============================================
-- 4. Can anon/authenticated CREATE objects in public? If FALSE, pinning to 'public' is safe against
--    the "attacker shadows an object in public" variant (Supabase revokes this by default).
-- ============================================
SELECT
  has_schema_privilege('anon',          'public', 'CREATE') AS anon_can_create,
  has_schema_privilege('authenticated', 'public', 'CREATE') AS authenticated_can_create;
