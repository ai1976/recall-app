-- Name: [DIAGNOSTIC] L5 revoke gate — RLS function deps + bodies to finalize
-- Description: The gate that must pass BEFORE any REVOKE EXECUTE (04_SCHEMA). Confirms:
--   (1) which functions are referenced inside RLS policy expressions — those MUST keep EXECUTE for
--       the roles that trigger the policies (e.g. is_admin/is_super_admin), or RLS breaks for all
--       users. This is the single biggest revoke hazard.
--   (2) the live bodies of the three single-card RPCs, so they can be given the same IDOR guard as
--       02_FUNCTIONS (their bodies aren't in the repo).
--   (3) the bodies of the three "ambiguous" functions (public route but mutating / oddly named), to
--       decide whether they belong in the anon public allowlist or authenticated-only.
-- Read-only. Paste all three blocks.

-- ============================================
-- 1. Functions referenced in ANY RLS policy expression (qual or with_check). These MUST retain
--    EXECUTE for anon/authenticated as applicable — do NOT revoke them. Expect at least is_admin,
--    is_super_admin; flag anything else so the revoke lists exclude them.
-- ============================================
SELECT DISTINCT p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND EXISTS (
    SELECT 1
    FROM pg_policies pol
    WHERE pol.schemaname = 'public'
      AND (coalesce(pol.qual, '') || ' ' || coalesce(pol.with_check, ''))
          ~ ('\m' || p.proname || '\s*\(')
  )
ORDER BY p.proname;

-- ============================================
-- 2. Live bodies of the single-card scheduling RPCs — to add the IDOR guard (same as 02) next.
-- ============================================
SELECT proname, pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname IN ('skip_card', 'suspend_card', 'reset_card')
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;

-- ============================================
-- 3. Bodies of the 3 ambiguous functions. Key question per function: does it require a session
--    (references auth.uid() and/or RAISEs when it's null)? If yes -> authenticated-only (revoke
--    anon). If it legitimately runs for logged-out visitors -> keep in the anon allowlist.
--      - join_group_by_token: a logged-out visitor opening an invite link — do they join before or
--        after logging in?
--      - submit_access_request: the content-preview "request access" wall — shown to anon?
--      - get_anonymous_class_stats: only called from the authenticated Dashboard in the grep, despite
--        the name — confirm it doesn't need anon.
-- ============================================
SELECT proname, pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname IN ('join_group_by_token', 'submit_access_request', 'get_anonymous_class_stats')
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;
