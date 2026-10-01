-- [FUNCTIONS] ROLLBACK for 03 (Sprint 8.8.5f step 1). Run only if the frontend that calls the new functions is also reverted.
-- Drops the two new functions and restores get_author_profile to the LIVE body read on 01/10/2026 (returns email, trusts p_viewer_id).
-- Do NOT run this after step 3 (06) without first running 08, or the old get_author_profile (definer) is unaffected but screens that
-- read email directly would still be locked out.

-- ACL note: the live get_author_profile already had anon = no, authenticated = yes (00/01 diagnostics), which is exactly what 03
-- now enforces explicitly, so restoring the old body needs no ACL change.

DROP FUNCTION IF EXISTS public.admin_read_profiles(uuid[], text[], text[], uuid[], integer);
DROP FUNCTION IF EXISTS public.search_users_for_group_invite(uuid, text);

CREATE OR REPLACE FUNCTION public.get_author_profile(p_author_id uuid, p_viewer_id uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_profile    JSON;
  v_badges     JSON;
  v_friendship JSON;
  v_is_own     BOOLEAN;
  v_teaching   JSON;
BEGIN
  v_is_own := (p_author_id = p_viewer_id);

  SELECT row_to_json(t) INTO v_profile
  FROM (
    SELECT id, full_name, email, role, course_level, institution, created_at
    FROM profiles
    WHERE id = p_author_id
  ) t;

  IF v_profile IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(
    json_agg(d.name ORDER BY pc.is_primary DESC, d.name ASC),
    '[]'::json
  )
  INTO v_teaching
  FROM profile_courses pc
  JOIN disciplines d ON d.id = pc.discipline_id
  WHERE pc.user_id = p_author_id;

  IF v_teaching IS NULL THEN
    v_teaching := '[]'::json;
  END IF;

  IF v_is_own THEN
    SELECT COALESCE(json_agg(row_to_json(b)), '[]'::json) INTO v_badges
    FROM (
      SELECT ub.id, ub.badge_id, ub.earned_at, ub.is_public,
             bd.name AS badge_name, bd.description AS badge_description, bd.icon_key AS badge_icon_key
      FROM user_badges ub
      JOIN badge_definitions bd ON bd.id = ub.badge_id
      WHERE ub.user_id = p_author_id
      ORDER BY ub.earned_at DESC
    ) b;
  ELSE
    SELECT COALESCE(json_agg(row_to_json(b)), '[]'::json) INTO v_badges
    FROM (
      SELECT ub.id, ub.badge_id, ub.earned_at, ub.is_public,
             bd.name AS badge_name, bd.description AS badge_description, bd.icon_key AS badge_icon_key
      FROM user_badges ub
      JOIN badge_definitions bd ON bd.id = ub.badge_id
      WHERE ub.user_id = p_author_id
        AND ub.is_public = TRUE
      ORDER BY ub.earned_at DESC
    ) b;
  END IF;

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

  RETURN json_build_object(
    'profile',          v_profile,
    'teaching_courses', v_teaching,
    'badges',           v_badges,
    'friendship',       v_friendship,
    'is_own',           v_is_own
  );
END;
$function$;
