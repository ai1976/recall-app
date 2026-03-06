-- Name: [FUNCTIONS] Get Browsable Decks v3 (course-aware for students)
-- Description: Returns flashcard decks visible to the current user, now with a course gate
-- layered on top of the existing visibility gate.
--
-- VISIBILITY GATE (unchanged from v2):
--   own decks + public + friends-only (accepted friends) + group-shared (active members only)
--
-- COURSE GATE (NEW in v3):
--   Professors / admins / super_admins: bypass — see all courses
--   Students: see only decks where target_course = their enrolled course_level
--             OR they are the author (creator can always see own content)
--
-- This enforces the business rule: students consume only their enrolled course,
-- while creators can author content for any course and still see it.

CREATE OR REPLACE FUNCTION get_browsable_decks()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  subject_id UUID,
  custom_subject TEXT,
  topic_id UUID,
  custom_topic TEXT,
  target_course TEXT,
  visibility TEXT,
  card_count INTEGER,
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
  v_user_id    UUID;
  v_user_role  TEXT;
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
    fd.id,
    fd.user_id,
    fd.subject_id,
    fd.custom_subject,
    fd.topic_id,
    fd.custom_topic,
    fd.target_course,
    fd.visibility,
    fd.card_count,
    fd.upvote_count,
    fd.created_at,
    p.full_name  AS author_name,
    p.role       AS author_role,
    COALESCE(s.name,   fd.custom_subject, 'Other')   AS subject_name,
    COALESCE(top.name, fd.custom_topic,   'General') AS topic_name
  FROM flashcard_decks fd
  JOIN profiles p     ON p.id   = fd.user_id
  LEFT JOIN subjects s   ON s.id   = fd.subject_id
  LEFT JOIN topics   top ON top.id = fd.topic_id
  WHERE
    fd.card_count > 0

    -- VISIBILITY GATE: must pass at least one visibility rule
    AND (
      fd.user_id = v_user_id                          -- own decks (any visibility)
      OR fd.visibility = 'public'                     -- public decks
      OR (                                            -- friends-only decks
        fd.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM friendships f
           WHERE f.status = 'accepted'
             AND (
               (f.user_id = v_user_id AND f.friend_id = fd.user_id)
               OR (f.friend_id = v_user_id AND f.user_id = fd.user_id)
             )
        )
      )
      OR EXISTS (                                     -- group-shared decks (active members only)
        SELECT 1 FROM content_group_shares cgs
        JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
         WHERE cgs.content_type = 'flashcard_deck'
           AND cgs.content_id   = fd.id
           AND sgm.user_id      = v_user_id
           AND sgm.status       = 'active'
      )
    )

    -- COURSE GATE (NEW): professors/admins bypass; students see own course + own content
    AND (
      v_user_role IN ('professor', 'admin', 'super_admin')
      OR fd.user_id      = v_user_id          -- author always sees own creation
      OR fd.target_course = v_user_course     -- matches student's enrolled course
    )

  ORDER BY fd.created_at DESC;
END;
$$;
