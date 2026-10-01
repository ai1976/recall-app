-- [FUNCTIONS] Profile privacy - STEP 1 of 3: replacement server functions (Sprint 8.8.5f, deferred privacy item). ADDITIVE and SAFE to run first.
-- Description: Today every signed-in user can read every profile's email (policy users_read_all_profiles + a table-wide SELECT grant).
--   Step 3 (06) will lock that down. Before that, the screens that legitimately need an email must have a server-side replacement, so
--   nothing breaks. This file adds / replaces three functions and changes NO table privilege:
--     admin_read_profiles(p_ids, p_roles, p_emails, p_refs, p_limit)   admin / super_admin ONLY (checked server-side, suspended admins
--                                                                      refused); returns whole profile rows incl. email and
--                                                                      access_request_ref. Replaces the direct profile reads on the
--                                                                      Admin Dashboard and Super Admin Dashboard.
--     search_users_for_group_invite(p_group_id, p_query)               caller must be an ACTIVE ADMIN of that group (same rule as
--                                                                      invite_to_group). Partial NAME search (>= 2 chars, max 10
--                                                                      rows); EMAIL only by exact full-address match (a query that
--                                                                      contains '@'); returns a MASKED email, never the raw one;
--                                                                      skips the caller and anyone already active/invited. The caller
--                                                                      must also have an ACTIVE (not suspended) platform profile.
--     get_author_profile(p_author_id, p_viewer_id)                     SAME signature and return type (json), so CREATE OR REPLACE is
--                                                                      safe (no dependent objects were found: only diagnostics mention
--                                                                      it). Its ACL is ALSO set explicitly here (PUBLIC/anon revoked,
--                                                                      authenticated granted). Changes: the raw email is no longer
--                                                                      returned (AuthorProfile.jsx never displays it), and the viewer
--                                                                      is taken from auth.uid() - the caller-supplied p_viewer_id is
--                                                                      IGNORED (it let anyone pass viewer = author and read another
--                                                                      user's private badges / friendship).
--   All SECURITY DEFINER, fixed search_path (unquoted: public, extensions), EXECUTE only for signed-in users (anon revoked).
-- Rollback: 05. Test: 04.

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_read_profiles(
  p_ids    uuid[]  DEFAULT NULL,
  p_roles  text[]  DEFAULT NULL,
  p_emails text[]  DEFAULT NULL,
  p_refs   uuid[]  DEFAULT NULL,
  p_limit  integer DEFAULT 1000)
 RETURNS SETOF public.profiles
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_role   text;
  v_status text;
  v_emails text[];
BEGIN
  SELECT p.role, p.status INTO v_role, v_status FROM public.profiles p WHERE p.id = auth.uid();
  IF v_role IS NULL OR v_role NOT IN ('admin', 'super_admin') OR COALESCE(v_status, 'active') = 'suspended' THEN
    RAISE EXCEPTION 'Access denied: not_admin' USING ERRCODE = '42501';
  END IF;

  IF p_emails IS NOT NULL THEN
    SELECT COALESCE(array_agg(lower(btrim(e))), ARRAY[]::text[]) INTO v_emails FROM unnest(p_emails) AS e;
  END IF;

  RETURN QUERY
  SELECT p.*
    FROM public.profiles p
   WHERE (p_ids   IS NULL OR p.id = ANY (p_ids))
     AND (p_roles IS NULL OR p.role = ANY (p_roles))
     AND (v_emails IS NULL OR lower(p.email) = ANY (v_emails))
     AND (p_refs  IS NULL OR p.access_request_ref = ANY (p_refs))
   ORDER BY p.created_at DESC
   LIMIT LEAST(GREATEST(COALESCE(p_limit, 1000), 1), 5000);
END;
$function$;

REVOKE ALL ON FUNCTION public.admin_read_profiles(uuid[], text[], text[], uuid[], integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_read_profiles(uuid[], text[], text[], uuid[], integer) TO authenticated;

-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_users_for_group_invite(p_group_id uuid, p_query text)
 RETURNS TABLE (user_id uuid, full_name text, masked_email text, course_level text, role text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_caller uuid := auth.uid();
  v_q      text;
  v_like   text;
BEGIN
  IF v_caller IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  -- The caller needs an ACTIVE platform profile too (a suspended group admin must not be able to probe for accounts).
  IF NOT EXISTS (SELECT 1 FROM public.profiles c WHERE c.id = v_caller AND COALESCE(c.status, 'active') <> 'suspended') THEN
    RAISE EXCEPTION 'Account is not active' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.study_group_members m
     WHERE m.group_id = p_group_id AND m.user_id = v_caller AND m.role = 'admin' AND m.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Only group admins can search for people to invite' USING ERRCODE = '42501';
  END IF;

  v_q := left(btrim(COALESCE(p_query, '')), 100);
  IF char_length(v_q) < 2 THEN
    RETURN;
  END IF;

  IF position('@' IN v_q) > 0 THEN
    -- Exact full-address lookup only (never a partial email match).
    RETURN QUERY
    SELECT p.id, p.full_name, left(p.email, 1) || '***@' || split_part(p.email, '@', 2), p.course_level, p.role
      FROM public.profiles p
     WHERE lower(p.email) = lower(v_q)
       AND p.id <> v_caller
       AND NOT EXISTS (SELECT 1 FROM public.study_group_members m
                        WHERE m.group_id = p_group_id AND m.user_id = p.id AND m.status IN ('active', 'invited'))
     LIMIT 10;
  ELSE
    v_like := '%' || replace(replace(replace(v_q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
    RETURN QUERY
    SELECT p.id, p.full_name, left(p.email, 1) || '***@' || split_part(p.email, '@', 2), p.course_level, p.role
      FROM public.profiles p
     WHERE p.full_name ILIKE v_like
       AND p.id <> v_caller
       AND NOT EXISTS (SELECT 1 FROM public.study_group_members m
                        WHERE m.group_id = p_group_id AND m.user_id = p.id AND m.status IN ('active', 'invited'))
     ORDER BY p.full_name
     LIMIT 10;
  END IF;
END;
$function$;

REVOKE ALL ON FUNCTION public.search_users_for_group_invite(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users_for_group_invite(uuid, text) TO authenticated;

-- ---------------------------------------------------------------------------
-- get_author_profile: body identical to the live one (read 01/10/2026) EXCEPT (1) no email column, (2) viewer = auth.uid().
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
  v_viewer     UUID := auth.uid();   -- p_viewer_id is kept for call compatibility only and is IGNORED
BEGIN
  IF v_viewer IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;
  v_is_own := (p_author_id = v_viewer);

  -- Profile (no email)
  SELECT row_to_json(t) INTO v_profile
  FROM (
    SELECT id, full_name, role, course_level, institution, created_at
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
      WHERE (user_id = v_viewer AND friend_id = p_author_id)
         OR (user_id = p_author_id AND friend_id = v_viewer)
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

-- Enforce the intended ACL explicitly (do not rely on whatever grants happened to exist before): signed-in users only.
REVOKE ALL ON FUNCTION public.get_author_profile(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_author_profile(uuid, uuid) TO authenticated;
