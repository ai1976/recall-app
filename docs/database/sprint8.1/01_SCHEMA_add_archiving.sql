-- Name: [SCHEMA] Sprint 8.1 — batch group archiving schema
-- Description: Adds archived_at/archived_by to study_groups, a distinct
-- 'closed' membership status (with closure metadata) so archiving can close
-- outstanding requests/invitations without deleting or mislabeling them, and
-- a server-side snapshot table for the frozen archived report/roster. Also
-- closes three pre-existing bypass gaps found during pre-flight (none
-- introduced by this sprint, all now relevant to it):
--   1. sg_delete_creator (study_groups DELETE) had no batch-group clause —
--      any admin who created a batch group could delete it directly.
--   2. sg_update_creator (study_groups UPDATE) had no batch-group clause —
--      a batch group's creator could set archived_at directly via a plain
--      client update, skipping the snapshot capture entirely.
--   3. sgm_insert_admin (study_group_members INSERT) had no archived check —
--      a client with local group-admin rights could insert members into an
--      archived batch, bypassing enroll_user_in_batch_group's guard.
-- Run once, in order, before 02_FUNCTIONS and 03_FUNCTIONS.

-- ============================================================================
-- 1. archived_at / archived_by on study_groups
-- ============================================================================
ALTER TABLE study_groups ADD COLUMN archived_at timestamptz;
ALTER TABLE study_groups ADD COLUMN archived_by uuid REFERENCES profiles(id) ON DELETE SET NULL;

CREATE INDEX idx_study_groups_archived_at ON study_groups(archived_at) WHERE is_batch_group = true;

-- ============================================================================
-- 2. Distinct 'closed' status for study_group_members, with closure metadata.
-- Archiving closes outstanding 'requested'/'invited' rows to this status
-- instead of deleting them or leaving them as active — preserves the record
-- and lets join_group_by_token safely reactivate one on an explicit re-request
-- after restore, without losing the prior closure history.
-- ============================================================================
ALTER TABLE study_group_members DROP CONSTRAINT study_group_members_status_check;
ALTER TABLE study_group_members ADD CONSTRAINT study_group_members_status_check
  CHECK (status = ANY (ARRAY['invited'::text, 'active'::text, 'requested'::text, 'closed'::text]));

ALTER TABLE study_group_members ADD COLUMN closed_at timestamptz;
ALTER TABLE study_group_members ADD COLUMN closed_reason text;

-- ============================================================================
-- 3. Snapshot storage for the archived report + roster. One row per archive
-- event (group_id, archived_at) — a later archive/restore cycle adds a new
-- row rather than overwriting, so earlier snapshots remain as historical
-- records (no history-browser UI this sprint, just the data). Sized to the
-- actual shape of get_batch_group_member_stats (~5 small fields per member,
-- capped at real batch roster sizes) — not raw review history.
-- RLS enabled with zero policies: no direct client access at all, by design.
-- All reads go through get_batch_group_archive() (SECURITY DEFINER), which
-- gates on the same professor/admin/super_admin + is_batch_group check as
-- the existing live report RPC — "same authorized viewers", nothing broader.
-- ============================================================================
CREATE TABLE batch_group_archives (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id uuid NOT NULL REFERENCES study_groups(id) ON DELETE CASCADE,
  archived_at timestamptz NOT NULL,
  archived_by uuid REFERENCES profiles(id) ON DELETE SET NULL,
  report jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW(),
  UNIQUE (group_id, archived_at)
);

CREATE INDEX idx_batch_group_archives_group ON batch_group_archives(group_id, archived_at DESC);

ALTER TABLE batch_group_archives ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. Close the three pre-existing RLS bypass gaps (see header).
-- ============================================================================
DROP POLICY sg_delete_creator ON study_groups;
CREATE POLICY sg_delete_creator ON study_groups FOR DELETE TO authenticated
  USING (created_by = auth.uid() AND is_batch_group = false);

DROP POLICY sg_update_creator ON study_groups;
CREATE POLICY sg_update_creator ON study_groups FOR UPDATE TO authenticated
  USING (created_by = auth.uid() AND is_batch_group = false)
  WITH CHECK (created_by = auth.uid() AND is_batch_group = false);

DROP POLICY sgm_insert_admin ON study_group_members;
CREATE POLICY sgm_insert_admin ON study_group_members FOR INSERT TO authenticated
  WITH CHECK (
    group_id IN (
      SELECT study_group_members_1.group_id
      FROM study_group_members study_group_members_1
      WHERE study_group_members_1.user_id = auth.uid() AND study_group_members_1.role = 'admin'
    )
    AND NOT EXISTS (
      SELECT 1 FROM study_groups sg WHERE sg.id = group_id AND sg.archived_at IS NOT NULL
    )
  );

-- Batch groups have no direct-edit UI today (AdminDashboard's batch tab is
-- read-only display), so narrowing sg_update_creator/sg_delete_creator to
-- is_batch_group = false does not remove any existing capability — all batch
-- group metadata changes (including archived_at) now go exclusively through
-- the SECURITY DEFINER RPCs in 02_FUNCTIONS, which run as the function owner
-- and are unaffected by this RLS narrowing.
