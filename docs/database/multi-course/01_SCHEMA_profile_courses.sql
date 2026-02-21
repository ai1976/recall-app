-- ============================================================
-- Name: [SCHEMA] Create profile_courses table
-- Description: Stores multiple teaching courses per professor/admin/super_admin.
--   profiles.course_level is KEPT as the "primary course" column for full
--   backward compatibility with all existing RLS policies and frontend logic.
--   This table is additive — it extends, not replaces, course_level.
--
-- Run order: 01 of 04 (run this FIRST)
-- ============================================================

CREATE TABLE IF NOT EXISTS profile_courses (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  discipline_id UUID        NOT NULL REFERENCES disciplines(id) ON DELETE CASCADE,
  is_primary    BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, discipline_id)
);

-- ── Indexes ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profile_courses_user_id
  ON profile_courses(user_id);

-- Partial index: quickly find each user's primary course
CREATE INDEX IF NOT EXISTS idx_profile_courses_primary
  ON profile_courses(user_id)
  WHERE is_primary = TRUE;

-- ── Row Level Security ────────────────────────────────────
ALTER TABLE profile_courses ENABLE ROW LEVEL SECURITY;

-- Each user reads their own courses
CREATE POLICY pc_select_own
  ON profile_courses FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Admins and super_admins can read all (for admin tools)
CREATE POLICY pc_select_admin
  ON profile_courses FOR SELECT
  TO authenticated
  USING (
    (SELECT role FROM profiles WHERE id = auth.uid()) IN ('super_admin', 'admin')
  );

-- Users manage their own rows only
CREATE POLICY pc_insert_own
  ON profile_courses FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY pc_update_own
  ON profile_courses FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY pc_delete_own
  ON profile_courses FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());

-- ── Verification query ────────────────────────────────────
-- Run after creation to confirm table exists:
-- SELECT table_name, column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'profile_courses'
-- ORDER BY ordinal_position;
