-- Name: [FUNCTIONS] Migrate skip_topic_cards + suspend_topic_cards off flashcards.is_public
-- Description: L2 Stage B prerequisite. 14_DIAGNOSTIC found these two SECURITY DEFINER RPCs are
-- the ONLY functions that reference flashcards.is_public (the four other is_public hits are
-- user_badges.is_public, a different column). Both had the same target_cards predicate:
--   AND (fc.is_public = true OR fc.user_id = p_user_id OR fc.visibility = 'friends'
--        OR fc.visibility = 'public')
-- Since fc.is_public = true <=> fc.visibility = 'public' (09 Block 5, zero drift) and
-- `fc.visibility = 'public'` is ALREADY in that OR, the `fc.is_public = true` clause is purely
-- REDUNDANT. This migration deletes only that one line from each function — no other logic change,
-- full bodies otherwise reproduced verbatim from pg_get_functiondef (14 query 3). Result is
-- data-equivalent. After this deploys, no function references flashcards/notes.is_public, so
-- 12_SCHEMA can drop the column.
--
-- Signatures preserved exactly (CREATE OR REPLACE in place):
--   skip_topic_cards(p_user_id uuid, p_topic_id uuid DEFAULT NULL, p_custom_topic text DEFAULT NULL)
--   suspend_topic_cards(same signature)

CREATE OR REPLACE FUNCTION public.skip_topic_cards(p_user_id uuid, p_topic_id uuid DEFAULT NULL::uuid, p_custom_topic text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_tomorrow DATE := CURRENT_DATE + 1;
  v_count    INTEGER;
BEGIN
  WITH target_cards AS (
    SELECT fc.id
    FROM   flashcards fc
    WHERE  (
             (p_topic_id     IS NOT NULL AND fc.topic_id     =  p_topic_id)
          OR (p_topic_id     IS NULL
              AND p_custom_topic IS NOT NULL
              AND fc.custom_topic = p_custom_topic)
           )
      AND  (fc.user_id   = p_user_id
            OR fc.visibility = 'friends'
            OR fc.visibility = 'public')
  ),
  upserted AS (
    INSERT INTO reviews (
      user_id, flashcard_id,
      quality, easiness, interval, repetition,
      next_review_date, status, skip_until
    )
    SELECT
      p_user_id, t.id,
      0, 2.5, 1, 0,
      CURRENT_DATE, 'active', v_tomorrow
    FROM target_cards t
    ON CONFLICT (user_id, flashcard_id) DO UPDATE
      SET skip_until = v_tomorrow
      WHERE reviews.status = 'active'
    RETURNING reviews.flashcard_id
  )
  SELECT COUNT(*) INTO v_count FROM upserted;

  RETURN v_count;
END;
$function$;

CREATE OR REPLACE FUNCTION public.suspend_topic_cards(p_user_id uuid, p_topic_id uuid DEFAULT NULL::uuid, p_custom_topic text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count INTEGER;
BEGIN
  WITH target_cards AS (
    SELECT fc.id
    FROM   flashcards fc
    WHERE  (
             (p_topic_id     IS NOT NULL AND fc.topic_id     =  p_topic_id)
          OR (p_topic_id     IS NULL
              AND p_custom_topic IS NOT NULL
              AND fc.custom_topic = p_custom_topic)
           )
      AND  (fc.user_id   = p_user_id
            OR fc.visibility = 'friends'
            OR fc.visibility = 'public')
  ),
  upserted AS (
    INSERT INTO reviews (
      user_id, flashcard_id,
      quality, easiness, interval, repetition,
      next_review_date, status
    )
    SELECT
      p_user_id, t.id,
      0, 2.5, 1, 0,
      CURRENT_DATE, 'suspended'
    FROM target_cards t
    ON CONFLICT (user_id, flashcard_id) DO UPDATE
      SET status = 'suspended'
    RETURNING reviews.flashcard_id
  )
  SELECT COUNT(*) INTO v_count FROM upserted;

  RETURN v_count;
END;
$function$;

NOTIFY pgrst, 'reload schema';
