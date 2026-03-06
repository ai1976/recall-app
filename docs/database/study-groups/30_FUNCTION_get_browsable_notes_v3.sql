-- Name: [FUNCTIONS] Get Browsable Notes v3 (course-aware for students)
-- Description: Returns notes visible to the current user, now with a course gate
-- layered on top of the existing visibility gate.
--
-- VISIBILITY GATE (unchanged from v2):
--   own notes + public + friends-only (accepted friends) + group-shared (active members only)
--
-- COURSE GATE (NEW in v3):
--   Professors / admins / super_admins: bypass — see all courses
--   Students: see only notes where target_course = their enrolled course_level
--             OR they are the author (creator can always see own content)
--
-- This enforces the business rule: students consume only their enrolled course,
-- while creators can author content for any course and still see it.

CREATE OR REPLACE FUNCTION get_browsable_notes()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  title TEXT,
  description TEXT,
  image_url TEXT,
  target_course TEXT,
  subject_id UUID,
  topic_id UUID,
  custom_subject TEXT,
  custom_topic TEXT,
  tags TEXT[],
  visibility TEXT,
  upvote_count INTEGER,
  created_at TIMESTAMPTZ,
  author_name TEXT,
  author_role TEXT,
  subject_name TEXT,
  topic_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id     UUID;
  v_user_role   TEXT;
  v_user_course TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Fetch the caller's role and enrolled course in one round-trip
  -- NOTE: Must use profiles.id (not bare "id") because RETURNS TABLE declares
  -- an output column also named "id", causing ambiguity error 42702.
  SELECT role, course_level
    INTO v_user_role, v_user_course
    FROM profiles
   WHERE profiles.id = v_user_id;

  RETURN QUERY
  SELECT DISTINCT
    n.id,
    n.user_id,
    n.title,
    n.description,
    n.image_url,
    n.target_course,
    n.subject_id,
    n.topic_id,
    n.custom_subject,
    n.custom_topic,
    n.tags,
    n.visibility,
    n.upvote_count,
    n.created_at,
    p.full_name  AS author_name,
    p.role       AS author_role,
    COALESCE(s.name,   n.custom_subject, 'Other')   AS subject_name,
    COALESCE(top.name, n.custom_topic,   'General') AS topic_name
  FROM notes n
  JOIN profiles p     ON p.id   = n.user_id
  LEFT JOIN subjects s   ON s.id   = n.subject_id
  LEFT JOIN topics   top ON top.id = n.topic_id
  WHERE
    -- VISIBILITY GATE: must pass at least one visibility rule
    (
      n.user_id = v_user_id                          -- own notes (any visibility)
      OR n.visibility = 'public'                     -- public notes
      OR (                                           -- friends-only notes
        n.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM friendships f
           WHERE f.status = 'accepted'
             AND (
               (f.user_id = v_user_id AND f.friend_id = n.user_id)
               OR (f.friend_id = v_user_id AND f.user_id = n.user_id)
             )
        )
      )
      OR EXISTS (                                    -- group-shared notes (active members only)
        SELECT 1 FROM content_group_shares cgs
        JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
         WHERE cgs.content_type = 'note'
           AND cgs.content_id   = n.id
           AND sgm.user_id      = v_user_id
           AND sgm.status       = 'active'
      )
    )

    -- COURSE GATE (NEW): professors/admins bypass; students see own course + own content
    AND (
      v_user_role IN ('professor', 'admin', 'super_admin')
      OR n.user_id      = v_user_id          -- author always sees own creation
      OR n.target_course = v_user_course     -- matches student's enrolled course
    )

  ORDER BY n.created_at DESC;
END;
$$;
