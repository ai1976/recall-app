-- Name: [FUNCTIONS] Get Group Shared Content
-- Description: Returns all content shared with a specific group, with content details.
-- Only accessible by group members. Returns notes and flashcard decks separately.
-- Used on GroupDetail page to display shared content.

CREATE OR REPLACE FUNCTION get_group_shared_content(
  p_group_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_is_member BOOLEAN;
  v_notes JSON;
  v_decks JSON;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Check membership
  SELECT EXISTS(
    SELECT 1 FROM study_group_members
    WHERE group_id = p_group_id AND user_id = v_user_id
  ) INTO v_is_member;

  IF NOT v_is_member THEN
    RAISE EXCEPTION 'Not a member of this group';
  END IF;

  -- Get shared notes
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_notes
  FROM (
    SELECT
      n.id,
      n.title,
      n.description,
      n.image_url,
      n.target_course,
      n.created_at,
      n.upvote_count,
      p.full_name AS author_name,
      p.role AS author_role,
      n.user_id AS author_id,
      s.name AS subject_name,
      top.name AS topic_name,
      cgs.shared_at
    FROM content_group_shares cgs
    JOIN notes n ON n.id = cgs.content_id
    JOIN profiles p ON p.id = n.user_id
    LEFT JOIN subjects s ON s.id = n.subject_id
    LEFT JOIN topics top ON top.id = n.topic_id
    WHERE cgs.group_id = p_group_id AND cgs.content_type = 'note'
    ORDER BY cgs.shared_at DESC
  ) t;

  -- Get shared flashcard decks
  SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_decks
  FROM (
    SELECT
      fd.id,
      fd.card_count,
      fd.target_course,
      fd.visibility,
      fd.upvote_count,
      fd.created_at,
      p.full_name AS author_name,
      p.role AS author_role,
      fd.user_id AS author_id,
      s.name AS subject_name,
      COALESCE(fd.custom_subject, s.name, 'Other') AS display_subject,
      top.name AS topic_name,
      COALESCE(fd.custom_topic, top.name, 'General') AS display_topic,
      cgs.shared_at
    FROM content_group_shares cgs
    JOIN flashcard_decks fd ON fd.id = cgs.content_id
    JOIN profiles p ON p.id = fd.user_id
    LEFT JOIN subjects s ON s.id = fd.subject_id
    LEFT JOIN topics top ON top.id = fd.topic_id
    WHERE cgs.group_id = p_group_id AND cgs.content_type = 'flashcard_deck'
    ORDER BY cgs.shared_at DESC
  ) t;

  RETURN json_build_object(
    'notes', v_notes,
    'decks', v_decks
  );
END;
$$;
