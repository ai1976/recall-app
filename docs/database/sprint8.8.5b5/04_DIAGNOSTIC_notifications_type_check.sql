-- [DIAGNOSTIC] notifications.type allowed values (found by 02 test, 30/09/2026)
-- Description: READ-ONLY. The 02 test failed with notifications_type_check when the new batch functions inserted
--   type 'batch_added' / 'batch_approved'. This shows the constraint's exact allowed list and the types actually in use,
--   so the new types can be ADDED without dropping any existing one.
-- Run each block separately and paste all results.

-- Block 1: every CHECK constraint on notifications (catalog)
SELECT conname, convalidated, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'public.notifications'::regclass AND contype = 'c'
ORDER BY conname;

-- Block 2: the types actually stored today
SELECT type, count(*) AS rows
FROM public.notifications
GROUP BY type
ORDER BY rows DESC;

-- Block 3: which functions insert notifications (so the new types are known to every writer)
SELECT p.proname
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prokind = 'f'
  AND pg_get_functiondef(p.oid) ~* 'insert[[:space:]]+into[[:space:]]+(public[.])?notifications'
ORDER BY p.proname;
