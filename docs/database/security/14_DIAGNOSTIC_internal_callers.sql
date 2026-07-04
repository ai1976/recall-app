-- Name: [DIAGNOSTIC] Internal callers of the 3 unguarded writers (guard-safety gate)
-- Description: Before guarding enroll_user_in_batch_group / notify_access_granted / log_review_activity,
-- find every OTHER function whose body calls them. Critical: if a signup/trigger path (e.g.
-- fn_auto_enroll_batch_group, fn_create_profile_on_signup) calls enroll_user_in_batch_group, an
-- is_admin()/auth.uid() guard would break that path (no session at signup) — we'd guard differently
-- (or leave the internal path and only lock the RPC). Also dump fn_auto_enroll_batch_group to see
-- whether it does its OWN enrollment or delegates. Read-only.

-- 1. Functions that reference each target in their body (internal callers).
SELECT p.proname AS caller, t.target
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
CROSS JOIN (VALUES ('enroll_user_in_batch_group'),('notify_access_granted'),('log_review_activity')) AS t(target)
WHERE n.nspname = 'public'
  AND p.proname <> t.target
  AND pg_get_functiondef(p.oid) ILIKE '%' || t.target || '%'
ORDER BY t.target, p.proname;

-- 2. Body of fn_auto_enroll_batch_group — does it call enroll_user_in_batch_group or enroll directly?
SELECT pg_get_functiondef(oid) AS fn_auto_enroll_batch_group
FROM pg_proc
WHERE proname = 'fn_auto_enroll_batch_group' AND pronamespace = 'public'::regnamespace;

-- 3. Any TRIGGER wired to these? (a trigger caller means non-RPC invocation to preserve.)
SELECT tgname, tgrelid::regclass AS table_name, p.proname AS trigger_fn
FROM pg_trigger tg
JOIN pg_proc p ON p.oid = tg.tgfoid
WHERE NOT tg.tgisinternal
  AND p.proname IN ('enroll_user_in_batch_group','notify_access_granted','log_review_activity');
