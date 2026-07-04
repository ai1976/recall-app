-- Name: [FUNCTIONS] get_recent_activity_feed — exclude decks with no viewer-visible cards
-- Description: Fixes the dashboard Recent Activity leak. The recent_decks CTE gated only on the DECK
-- visibility (fd.visibility='public' or friends), so a public deck whose only card is now private
-- still produced a feed entry ("<deck> by <user>"). Adds an EXISTS requiring at least one card in the
-- deck that is visible to the viewer (public, or friends-and-actually-a-friend). recent_notes is
-- unchanged (a note is atomic, already gated by its own visibility). Everything else reproduced
-- verbatim from the live body. Function is SECURITY INVOKER (unchanged) with search_path pinned.
--
-- Signature unchanged: (p_user_id uuid, p_course_level text, p_limit integer DEFAULT 5).

CREATE OR REPLACE FUNCTION public.get_recent_activity_feed(p_user_id uuid, p_course_level text, p_limit integer DEFAULT 5)
 RETURNS TABLE(id uuid, content_type text, title text, creator_id uuid, creator_name text, creator_role text, visibility text, upvote_count integer, subject text, created_at timestamp with time zone, count integer)
 LANGUAGE plpgsql
 SET search_path TO public, extensions
AS $function$
BEGIN
  RETURN QUERY

  WITH friend_ids AS (
    SELECT
      CASE WHEN f.user_id = p_user_id THEN f.friend_id ELSE f.user_id END AS friend_id
    FROM friendships f
    WHERE (f.user_id = p_user_id OR f.friend_id = p_user_id)
      AND f.status = 'accepted'
  ),

  recent_notes AS (
    SELECT
      n.id,
      'note'::TEXT                              AS content_type,
      n.title,
      n.user_id                                 AS creator_id,
      p.full_name                               AS creator_name,
      p.role                                    AS creator_role,
      n.visibility,
      COALESCE(n.upvote_count, 0)               AS upvote_count,
      COALESCE(s.name, n.custom_subject)        AS subject,
      n.created_at
    FROM notes n
    JOIN profiles  p ON n.user_id    = p.id
    LEFT JOIN subjects s ON n.subject_id = s.id
    WHERE n.target_course = p_course_level
      AND n.user_id != p_user_id
      AND n.created_at >= NOW() - INTERVAL '7 days'
      AND (
          n.visibility = 'public'
          OR (n.visibility = 'friends' AND n.user_id IN (SELECT friend_id FROM friend_ids))
      )
  ),

  recent_decks AS (
    SELECT
      fd.id,
      'flashcard_deck'::TEXT                    AS content_type,
      COALESCE(
        fd.name,
        COALESCE(s.name, fd.custom_subject, 'Flashcards') ||
        CASE WHEN COALESCE(t.name, fd.custom_topic) IS NOT NULL
             THEN ' - ' || COALESCE(t.name, fd.custom_topic)
             ELSE ''
        END
      )                                         AS title,
      fd.user_id                                AS creator_id,
      p.full_name                               AS creator_name,
      p.role                                    AS creator_role,
      fd.visibility,
      COALESCE(fd.upvote_count, 0)              AS upvote_count,
      COALESCE(s.name, fd.custom_subject)       AS subject,
      fd.created_at
    FROM flashcard_decks fd
    JOIN profiles  p ON fd.user_id   = p.id
    LEFT JOIN subjects s ON fd.subject_id = s.id
    LEFT JOIN topics   t ON fd.topic_id   = t.id
    WHERE fd.target_course = p_course_level
      AND fd.user_id != p_user_id
      AND fd.created_at >= NOW() - INTERVAL '7 days'
      AND (
          fd.visibility = 'public'
          OR (fd.visibility = 'friends' AND fd.user_id IN (SELECT friend_id FROM friend_ids))
      )
      -- NEW: the deck must have at least one card the viewer can actually see, else it's a public
      -- shell around private cards and must not appear in the feed.
      AND EXISTS (
        SELECT 1
        FROM flashcards fc
        WHERE fc.user_id = fd.user_id
          AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
          AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
          AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
          AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
          AND (
            fc.visibility = 'public'
            OR (fc.visibility = 'friends' AND fd.user_id IN (SELECT friend_id FROM friend_ids))
          )
      )
  ),

  combined AS (
    SELECT * FROM recent_notes
    UNION ALL
    SELECT * FROM recent_decks
  ),

  grouped AS (
    SELECT
      (array_agg(c.id      ORDER BY c.created_at DESC))[1]::UUID   AS id,
      c.content_type,
      (array_agg(c.title   ORDER BY c.created_at DESC))[1]         AS title,
      c.creator_id,
      c.creator_name,
      c.creator_role,
      (array_agg(c.visibility ORDER BY c.created_at DESC))[1]      AS visibility,
      SUM(c.upvote_count)::INTEGER                                  AS upvote_count,
      (array_agg(c.subject ORDER BY c.created_at DESC))[1]         AS subject,
      MAX(c.created_at)                                             AS created_at,
      COUNT(*)::INTEGER                                             AS count
    FROM combined c
    GROUP BY
      c.creator_id,
      c.creator_name,
      c.creator_role,
      c.content_type,
      DATE(c.created_at AT TIME ZONE 'UTC')
  )

  SELECT
    g.id, g.content_type, g.title, g.creator_id, g.creator_name, g.creator_role,
    g.visibility, g.upvote_count, g.subject, g.created_at, g.count
  FROM grouped g
  ORDER BY
    CASE WHEN g.creator_role = 'professor' THEN 0 ELSE 1 END,
    g.created_at DESC
  LIMIT p_limit;

END;
$function$;
