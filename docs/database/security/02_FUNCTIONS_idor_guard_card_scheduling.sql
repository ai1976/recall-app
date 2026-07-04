-- Name: [FUNCTIONS] L5 IDOR guard on card-scheduling RPCs (topic-scoped)
-- Description: skip_topic_cards / suspend_topic_cards take p_user_id and write to reviews WITHOUT
-- checking it equals the caller — an authenticated user could pass another student's UUID and
-- tamper with their spaced-repetition schedule (IDOR, found in security/01). Adds a hard-block
-- guard: a caller may only act on their OWN p_user_id (admins/super_admins may act on any, matching
-- the codebase's existing admin-aware pattern). Bodies otherwise reproduced verbatim from
-- 15_FUNCTIONS (the deployed version), with search_path pinned CORRECTLY (unquoted list — see L3
-- 17c). The three single-card RPCs (skip_card, suspend_card, reset_card) get the same guard in a
-- follow-up once 03_DIAGNOSTIC dumps their live bodies.
--
-- Signatures unchanged -> safe in-place CREATE OR REPLACE, no PostgREST reload.

CREATE OR REPLACE FUNCTION public.skip_topic_cards(p_user_id uuid, p_topic_id uuid DEFAULT NULL::uuid, p_custom_topic text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_tomorrow DATE := CURRENT_DATE + 1;
  v_count    INTEGER;
BEGIN
  -- L5 IDOR guard: only the owner (or an admin) may reschedule these cards.
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s review state';
  END IF;

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
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_count INTEGER;
BEGIN
  -- L5 IDOR guard: only the owner (or an admin) may suspend these cards.
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s review state';
  END IF;

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

-- Verify (after deploy): calling with a p_user_id other than your own should RAISE 'Access denied'.
-- Covered by 06_TEST.
