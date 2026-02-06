-- Name: [FUNCTIONS] Get Browsable Decks
-- Description: Returns all flashcard decks visible to the current user in a single query.
-- Visibility rules: own decks + public + friends-only (if friends) + group-shared.
-- Only returns decks with card_count > 0.
-- Replaces the 3-query client-side merge in ReviewFlashcards.jsx.
-- SECURITY DEFINER to bypass RLS and apply visibility logic in SQL.

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
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

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
    p.full_name AS author_name,
    p.role AS author_role,
    COALESCE(s.name, fd.custom_subject, 'Other') AS subject_name,
    COALESCE(top.name, fd.custom_topic, 'General') AS topic_name
  FROM flashcard_decks fd
  JOIN profiles p ON p.id = fd.user_id
  LEFT JOIN subjects s ON s.id = fd.subject_id
  LEFT JOIN topics top ON top.id = fd.topic_id
  WHERE
    fd.card_count > 0
    AND (
      -- User's own decks (any visibility)
      fd.user_id = v_user_id
      -- Public decks
      OR fd.visibility = 'public'
      -- Friends-only decks (user is an accepted friend of the author)
      OR (
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
      -- Group-shared decks (deck is shared with a group the user belongs to)
      OR EXISTS (
        SELECT 1 FROM content_group_shares cgs
        JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
        WHERE cgs.content_type = 'flashcard_deck'
          AND cgs.content_id = fd.id
          AND sgm.user_id = v_user_id
      )
    )
  ORDER BY fd.created_at DESC;
END;
$$;
