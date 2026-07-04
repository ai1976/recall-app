-- Name: [FUNCTIONS] get_browsable_decks v4 — per-viewer visible card count
-- Description: Fixes the deck-listing metadata leak (Review Flashcards grid). v3 gated at the DECK
-- level (fd.visibility) and returned the denormalized fd.card_count, so a PUBLIC deck whose only
-- card is now private (e.g. 1e521de5: public deck, 0 public cards, 1 private) still appeared with
-- "1 card" — and clicking it opened an empty study session. v4 adds a LATERAL count of cards VISIBLE
-- TO THE VIEWER, returns that as card_count, and excludes decks with 0 visible cards. Owners still
-- see their own private cards (fc.user_id = v_user_id), so their own view is unchanged; strangers
-- see only public cards, friends see public+friends, admins see all, and group-shared decks show
-- all cards to group members. Everything else reproduced verbatim from v3
-- (docs/database/study-groups/29_FUNCTION_get_browsable_decks_v3.sql).
--
-- Signature unchanged (no args -> same TABLE shape). SECURITY DEFINER retained.

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
SET search_path TO public, extensions
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
    vc.visible_card_count,                          -- was fd.card_count (denormalized total)
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
  -- Count of cards in this deck (5-grouping-column join) that the VIEWER may see.
  CROSS JOIN LATERAL (
    SELECT count(*)::INTEGER AS visible_card_count
    FROM flashcards fc
    WHERE fc.user_id = fd.user_id
      AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
      AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
      AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
      AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
      AND (
        fc.visibility = 'public'
        OR fc.user_id = v_user_id                           -- owner sees own private cards
        OR (fc.visibility = 'friends' AND EXISTS (
             SELECT 1 FROM friendships f
              WHERE f.status = 'accepted'
                AND ((f.user_id = v_user_id AND f.friend_id = fc.user_id)
                  OR (f.friend_id = v_user_id AND f.user_id = fc.user_id))))
        OR v_user_role IN ('admin', 'super_admin')          -- admin override (mirrors RLS is_admin)
        OR EXISTS (                                          -- deck shared to a group the viewer is in
             SELECT 1 FROM content_group_shares cgs
             JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
              WHERE cgs.content_type = 'flashcard_deck'
                AND cgs.content_id   = fd.id
                AND sgm.user_id      = v_user_id
                AND sgm.status       = 'active')
      )
  ) vc
  WHERE
    vc.visible_card_count > 0                        -- was fd.card_count > 0

    -- VISIBILITY GATE (unchanged from v3): deck must pass at least one visibility rule
    AND (
      fd.user_id = v_user_id
      OR fd.visibility = 'public'
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
      OR EXISTS (
        SELECT 1 FROM content_group_shares cgs
        JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
         WHERE cgs.content_type = 'flashcard_deck'
           AND cgs.content_id   = fd.id
           AND sgm.user_id      = v_user_id
           AND sgm.status       = 'active'
      )
    )

    -- COURSE GATE (unchanged from v3): professors/admins bypass; students see own course + own content
    AND (
      v_user_role IN ('professor', 'admin', 'super_admin')
      OR fd.user_id      = v_user_id
      OR fd.target_course = v_user_course
    )

  ORDER BY fd.created_at DESC;
END;
$$;
