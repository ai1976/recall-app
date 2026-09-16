-- ============================================================================
-- Name: [TEST] Verify create_batch_group + TEST batch fix
-- Description: Run after 02_FIX_create_batch_group_type.sql. Confirms (1)
--   the existing TEST batch was backfilled to group_type='batch', and (2)
--   the live function now inserts group_type into its column list (static
--   check of the function body — the real end-to-end proof is creating a
--   fresh batch group from the Admin Dashboard afterward and re-running
--   query 1 to see it land as 'batch', not 'custom').
-- Run in: Supabase Dashboard -> SQL Editor -> New Query. Read-only.
-- ============================================================================

-- 1. All batch groups should now show group_type = 'batch'
SELECT id, name, is_batch_group, group_type, created_at
FROM study_groups
WHERE is_batch_group = true
ORDER BY created_at;

-- 2. Function body should now list group_type among the inserted columns
SELECT
  pg_get_functiondef(oid) LIKE '%group_type%' AS inserts_group_type
FROM pg_proc
WHERE proname = 'create_batch_group';
