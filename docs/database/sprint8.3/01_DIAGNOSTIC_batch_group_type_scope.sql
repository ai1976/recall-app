-- ============================================================================
-- Name: [DIAGNOSTIC] Scope of the group_type != 'batch' bug across all batches
-- Description: Root cause found (see 00_DIAGNOSTIC): join_group_by_token only
--   routes a student into the 'requested' approval queue when
--   study_groups.group_type = 'batch'. The TEST batch created this session via
--   "Create Batch Group" actually has group_type = 'custom' (is_batch_group is
--   correctly true, but group_type is a separate column create_batch_group
--   never sets) — so the student-approval gate never fired for it at all, for
--   ANY student, not just the test one. This script checks whether the
--   pre-existing real batches (CA Final, CA Foundation, CA Intermediate) have
--   the same problem, which determines whether the approval gate has ever
--   actually worked in production or has been silently dead since Sprint 8.0.
--   Also pulls the live create_batch_group definition to confirm it's the
--   write path responsible.
-- Run in: Supabase Dashboard -> SQL Editor -> New Query. Read-only, safe.
-- ============================================================================

-- 1. group_type for every batch group that currently exists
SELECT id, name, is_batch_group, group_type, archived_at, created_at
FROM study_groups
WHERE is_batch_group = true
ORDER BY created_at;

-- 2. Live create_batch_group definition (confirms whether it sets group_type)
SELECT pg_get_functiondef(oid) AS live_function_body
FROM pg_proc
WHERE proname = 'create_batch_group';

-- 3. The study_groups.group_type column's default value and constraints
SELECT column_name, column_default, is_nullable, data_type
FROM information_schema.columns
WHERE table_name = 'study_groups' AND column_name = 'group_type';
