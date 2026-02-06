-- Name: [FUNCTIONS] Get Browsable Notes
-- Description: Returns all notes visible to the current user in a single query.
-- Visibility rules: own notes + public + friends-only (if friends) + group-shared.
-- Replaces the 3-query client-side merge in BrowseNotes.jsx.
-- SECURITY DEFINER to bypass RLS and apply visibility logic in SQL.

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
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

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
    p.full_name AS author_name,
    p.role AS author_role,
    COALESCE(s.name, n.custom_subject, 'Other') AS subject_name,
    COALESCE(top.name, n.custom_topic, 'General') AS topic_name
  FROM notes n
  JOIN profiles p ON p.id = n.user_id
  LEFT JOIN subjects s ON s.id = n.subject_id
  LEFT JOIN topics top ON top.id = n.topic_id
  WHERE
    -- User's own notes (any visibility)
    n.user_id = v_user_id
    -- Public notes
    OR n.visibility = 'public'
    -- Friends-only notes (user is an accepted friend of the author)
    OR (
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
    -- Group-shared notes (note is shared with a group the user belongs to)
    OR EXISTS (
      SELECT 1 FROM content_group_shares cgs
      JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
      WHERE cgs.content_type = 'note'
        AND cgs.content_id = n.id
        AND sgm.user_id = v_user_id
    )
  ORDER BY n.created_at DESC;
END;
$$;
