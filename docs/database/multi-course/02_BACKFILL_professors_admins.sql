-- ============================================================
-- Name: [DATA] Backfill profile_courses from course_level for professors and admins
-- Description: One-time migration. For every existing professor, admin, and
--   super_admin with a valid course_level, inserts one row in profile_courses
--   (is_primary = TRUE) by matching course_level text to disciplines.name
--   (case-insensitive). Safe to re-run — uses ON CONFLICT DO NOTHING.
--
-- Run order: 02 of 04 (run AFTER 01_SCHEMA_profile_courses.sql)
-- Prerequisite: 03_DISCIPLINES_verify_active.sql should show all 3 CA
--   disciplines as is_active = TRUE before running this.
-- ============================================================

INSERT INTO profile_courses (user_id, discipline_id, is_primary)
SELECT
  p.id   AS user_id,
  d.id   AS discipline_id,
  TRUE   AS is_primary
FROM profiles p
JOIN disciplines d
  ON LOWER(TRIM(d.name)) = LOWER(TRIM(p.course_level))
WHERE
  p.role IN ('professor', 'admin', 'super_admin')
  AND p.course_level IS NOT NULL
  AND p.course_level <> ''
ON CONFLICT (user_id, discipline_id) DO NOTHING;

-- ── Verification: show what was backfilled ────────────────
SELECT
  p.full_name,
  p.role,
  p.course_level                AS profiles_course_level,
  d.name                        AS matched_discipline,
  pc.is_primary,
  pc.created_at
FROM profile_courses pc
JOIN profiles    p ON p.id = pc.user_id
JOIN disciplines d ON d.id = pc.discipline_id
ORDER BY p.role, p.full_name;

-- ── If a professor's course_level did not match any discipline ─────
-- (i.e. they have a custom/free-text value), they will NOT appear above.
-- Find unmapped professors with:
-- SELECT p.full_name, p.role, p.course_level
-- FROM profiles p
-- LEFT JOIN profile_courses pc ON pc.user_id = p.id
-- WHERE p.role IN ('professor', 'admin', 'super_admin')
--   AND pc.id IS NULL
--   AND p.course_level IS NOT NULL;
-- Then either fix disciplines.name or insert manually.
