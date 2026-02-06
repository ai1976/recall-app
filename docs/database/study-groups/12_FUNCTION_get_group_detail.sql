-- Name: [FUNCTIONS] Get Group Detail
-- Description: Returns complete group detail in a single call: group info, members, shared content.
-- SECURITY DEFINER to bypass RLS. Verifies membership before returning data.
-- Replaces the 3-query pattern in GroupDetail.jsx that failed due to RLS on study_groups table.
--
-- PRIVACY: Member emails are NOT returned. Only safe public fields: user_id, full_name, role, joined_at.
-- SECURITY: Strict membership check before any data access.
-- NULL SAFETY: All arrays use COALESCE to return '[]' instead of null.
--
-- Run this in Supabase SQL Editor.

CREATE OR REPLACE FUNCTION get_group_detail(p_group_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_group JSON;
  v_members JSON;
  v_notes JSON;
  v_decks JSON;
BEGIN
  -- Authentication check
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Strict membership check: non-members cannot access any group data
  IF NOT EXISTS (
    SELECT 1 FROM study_group_members
    WHERE group_id = p_group_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  -- Get group info
  SELECT row_to_json(t) INTO v_group
  FROM (
    SELECT
      sg.id,
      sg.name,
      sg.description,
      sg.created_by,
      sg.created_at,
      sg.updated_at,
      p.full_name AS creator_name
    FROM study_groups sg
    JOIN profiles p ON p.id = sg.created_by
    WHERE sg.id = p_group_id
  ) t;

  IF v_group IS NULL THEN
    RAISE EXCEPTION 'Group not found';
  END IF;

  -- Get members with profiles (NO email — privacy protection)
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.joined_at ASC), '[]'::json) INTO v_members
  FROM (
    SELECT
      sgm.id,
      sgm.user_id,
      sgm.role,
      sgm.joined_at,
      p.full_name,
      p.role AS user_role
    FROM study_group_members sgm
    JOIN profiles p ON p.id = sgm.user_id
    WHERE sgm.group_id = p_group_id
  ) t;

  -- Get shared notes (returns '[]' if none)
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.shared_at DESC), '[]'::json) INTO v_notes
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
  ) t;

  -- Get shared flashcard decks (returns '[]' if none)
  SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.shared_at DESC), '[]'::json) INTO v_decks
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
  ) t;

  RETURN json_build_object(
    'group', v_group,
    'members', COALESCE(v_members, '[]'::json),
    'shared_content', json_build_object(
      'notes', COALESCE(v_notes, '[]'::json),
      'decks', COALESCE(v_decks, '[]'::json)
    )
  );
END;
$$;
