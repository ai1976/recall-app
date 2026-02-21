-- ============================================================
-- Name: [FUNCTIONS] Update get_author_profile to include teaching_courses
-- Description: Extends the existing get_author_profile() RPC with a new
--   teaching_courses JSON array (array of course name strings, primary first).
--   For students or users with no profile_courses rows, returns [].
--   All existing return keys (profile, badges, friendship, is_own) are preserved
--   with identical shape — this is additive only.
--
-- Run order: 04 of 04 (run LAST, after 01_SCHEMA_profile_courses.sql)
-- Safe to re-run: uses CREATE OR REPLACE FUNCTION.
-- ============================================================

CREATE OR REPLACE FUNCTION get_author_profile(
  p_author_id UUID,
  p_viewer_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_profile        JSON;
  v_badges         JSON;
  v_friendship     JSON;
  v_is_own         BOOLEAN;
  v_teaching       JSON;
BEGIN
  v_is_own := (p_author_id = p_viewer_id);

  -- ── Profile ───────────────────────────────────────────────
  SELECT row_to_json(t) INTO v_profile
  FROM (
    SELECT
      id, full_name, email, role,
      course_level, institution, created_at
    FROM profiles
    WHERE id = p_author_id
  ) t;

  -- Author not found
  IF v_profile IS NULL THEN
    RETURN NULL;
  END IF;

  -- ── Teaching courses ──────────────────────────────────────
  -- Returns an array of course name strings, primary course first.
  -- Empty array [] for students or users with no profile_courses rows.
  SELECT COALESCE(
    json_agg(d.name ORDER BY pc.is_primary DESC, d.name ASC),
    '[]'::json
  )
  INTO v_teaching
  FROM profile_courses pc
  JOIN disciplines d ON d.id = pc.discipline_id
  WHERE pc.user_id = p_author_id;

  -- Ensure we never return null for teaching_courses
  IF v_teaching IS NULL THEN
    v_teaching := '[]'::json;
  END IF;

  -- ── Badges ───────────────────────────────────────────────
  -- Own profile: all badges (for privacy management in My Achievements)
  -- Others: public badges only
  IF v_is_own THEN
    SELECT COALESCE(json_agg(row_to_json(b)), '[]'::json) INTO v_badges
    FROM (
      SELECT
        ub.id,
        ub.badge_key,
        ub.earned_at,
        ub.is_public,
        bd.name        AS badge_name,
        bd.description AS badge_description,
        bd.icon_key    AS badge_icon_key
      FROM user_badges ub
      JOIN badge_definitions bd ON bd.key = ub.badge_key
      WHERE ub.user_id = p_author_id
      ORDER BY ub.earned_at DESC
    ) b;
  ELSE
    SELECT COALESCE(json_agg(row_to_json(b)), '[]'::json) INTO v_badges
    FROM (
      SELECT
        ub.id,
        ub.badge_key,
        ub.earned_at,
        ub.is_public,
        bd.name        AS badge_name,
        bd.description AS badge_description,
        bd.icon_key    AS badge_icon_key
      FROM user_badges ub
      JOIN badge_definitions bd ON bd.key = ub.badge_key
      WHERE ub.user_id = p_author_id
        AND ub.is_public = TRUE
      ORDER BY ub.earned_at DESC
    ) b;
  END IF;

  -- ── Friendship ────────────────────────────────────────────
  -- Skipped for own profile (viewer and author are the same)
  IF NOT v_is_own THEN
    SELECT row_to_json(f) INTO v_friendship
    FROM (
      SELECT id, user_id, friend_id, status, created_at
      FROM friendships
      WHERE
        (user_id = p_viewer_id AND friend_id = p_author_id)
        OR (user_id = p_author_id AND friend_id = p_viewer_id)
      LIMIT 1
    ) f;
  END IF;

  -- ── Return ────────────────────────────────────────────────
  RETURN json_build_object(
    'profile',          v_profile,
    'teaching_courses', v_teaching,
    'badges',           v_badges,
    'friendship',       v_friendship,
    'is_own',           v_is_own
  );
END;
$$;

-- ── Test query ────────────────────────────────────────────
-- Replace <your_user_id> with an actual UUID to verify the output:
-- SELECT get_author_profile('<author_uuid>', '<viewer_uuid>');
-- Verify: result.teaching_courses should be an array of strings.
