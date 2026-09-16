-- ============================================================================
-- Name: [FIX] Restore group_type='batch' in create_batch_group
-- Description: Confirmed root cause of the student-instant-join bug found
--   during Sprint 8.3 screenshot prep: the live create_batch_group() never
--   sets study_groups.group_type, which defaults to 'custom' (see
--   01_DIAGNOSTIC's query 3). join_group_by_token only routes a student into
--   the 'requested' approval queue when group_type = 'batch' (see
--   00_DIAGNOSTIC's query 1) — so every batch group created through the
--   Admin Dashboard's "Create Batch Group" button since this function was
--   last replaced has silently skipped the approval gate: ANY student with
--   the invite link becomes an active member instantly, no admin action
--   needed. The three original batches (CA Final, CA Foundation, CA
--   Intermediate, all created 18-19/03/2026) are unaffected — they already
--   carry group_type='batch', so they predate this regression or were seeded
--   directly. Only a batch created via the live function is at risk; this
--   fix adds the one missing column so create_batch_group matches its own
--   documented contract in docs/database/sprint8.0/02_FUNCTIONS_batch_join_approval.sql
--   (comment block explicitly describes the approval gate as load-bearing).
-- Change: adds `group_type` to the INSERT's column list and value list.
--   Everything else byte-identical to the live definition pulled in
--   01_DIAGNOSTIC's query 2.
-- Run in: Supabase Dashboard -> SQL Editor -> New Query. Single statement,
--   no data migration needed for the 3 real batches (already correct).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.create_batch_group(p_course_level text, p_name text, p_description text DEFAULT ''::text, p_institution text DEFAULT 'More Classes Commerce'::text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_group_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  INSERT INTO study_groups (name, description, is_batch_group, group_type, batch_course, batch_institution, created_by)
  VALUES (p_name, p_description, true, 'batch', p_course_level, p_institution, auth.uid())
  RETURNING id INTO v_group_id;

  RETURN v_group_id;
END;
$function$;

-- ============================================================================
-- Backfill: the one existing bad row (Sprint 8.3's TEST screenshot-sandbox
-- batch, created before this fix). None of the 3 real batches need this —
-- confirmed already group_type='batch' in 01_DIAGNOSTIC. Safe: WHERE clause
-- targets a single known id, only flips a mis-set column, touches no
-- membership rows.
-- ============================================================================
UPDATE study_groups
SET group_type = 'batch'
WHERE id = 'cdc50a1c-a6f6-4d84-9e48-9517edc4f0d5'
  AND group_type = 'custom';
