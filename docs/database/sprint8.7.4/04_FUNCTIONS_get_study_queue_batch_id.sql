-- Name: [FUNCTIONS] get_study_queue — add batch_id to return shape
--
-- Description: Sprint 8.7.4 needs flashcards.batch_id in StudyMode.jsx for
-- every entry path, not just the direct-deck-browse fetch (which already
-- does `SELECT *` and has it). ReviewSession.jsx feeds StudyMode via this RPC
-- (`get_study_queue`), and its return shape did not include batch_id at all —
-- confirmed by reading the live srs-ladder version of this function
-- (docs/database/srs-ladder/02_FUNCTIONS_srs_ladder_engine.sql), not assumed.
-- Without this, cards studied via the normal "Review due cards" flow (the
-- most common study entry point) would never show a provenance badge even
-- when one exists, while cards studied via a direct deck click would.
--
-- Body is byte-identical to the live srs-ladder version except: `batch_id uuid`
-- added to RETURNS TABLE and `f.batch_id` added to the SELECT list. Same
-- additive, non-breaking-for-callers pattern as when `rung` was added
-- (docs/database/srs-ladder/02_FUNCTIONS_srs_ladder_engine.sql) — existing
-- callers that don't read the new column see no behavior change.
--
-- Grants reproduced exactly as the live function has them (REVOKE ALL FROM
-- PUBLIC, REVOKE ALL FROM anon, GRANT EXECUTE TO authenticated only) — DROP
-- FUNCTION removes all grants, so they must be re-applied here, not assumed
-- to survive.

DROP FUNCTION IF EXISTS public.get_study_queue(uuid);

CREATE FUNCTION public.get_study_queue(p_user_id uuid)
 RETURNS TABLE (
   flashcard_id     uuid,
   card_user_id     uuid,
   contributed_by   uuid,
   target_course    text,
   subject_id       uuid,
   subject_name     text,
   topic_id         uuid,
   topic_name       text,
   custom_subject   text,
   custom_topic     text,
   front_text       text,
   front_image_url  text,
   back_text        text,
   back_image_url   text,
   difficulty       text,
   is_verified      boolean,
   question_type    text,
   next_review_date date,
   skip_until       date,
   last_reviewed_at timestamptz,
   rung             smallint,
   batch_id         uuid
 )
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_today        date;
  v_course_level text;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s study queue';
  END IF;

  SELECT
    (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date,
    p.course_level
  INTO v_today, v_course_level
  FROM profiles p
  WHERE p.id = p_user_id;

  IF v_today IS NULL THEN
    v_today := CURRENT_DATE;
  END IF;

  RETURN QUERY
  SELECT
    f.id,
    f.user_id,
    f.contributed_by,
    f.target_course,
    f.subject_id,
    s.name,
    f.topic_id,
    t.name,
    f.custom_subject,
    f.custom_topic,
    f.front_text,
    f.front_image_url,
    f.back_text,
    f.back_image_url,
    f.difficulty,
    f.is_verified,
    f.question_type,
    r.next_review_date,
    r.skip_until,
    r.last_reviewed_at,
    r.rung,
    f.batch_id
  FROM reviews r
  JOIN flashcards f            ON f.id = r.flashcard_id
  LEFT JOIN subjects s         ON s.id = f.subject_id
  LEFT JOIN topics   t         ON t.id = f.topic_id
  WHERE r.user_id = p_user_id
    AND r.status = 'active'
    AND r.next_review_date <= v_today
    AND (r.skip_until IS NULL OR r.skip_until <= v_today)
    AND f.question_type <> 'concept_card'
    AND (
      v_course_level IS NULL
      OR f.target_course IS NULL
      OR f.target_course = v_course_level
    )
    AND (
      f.user_id = p_user_id
      OR f.visibility = 'public'
      OR (
        f.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM friendships fr
          WHERE fr.status = 'accepted'
            AND (
              (fr.user_id = p_user_id AND fr.friend_id = f.user_id)
              OR (fr.friend_id = p_user_id AND fr.user_id = f.user_id)
            )
        )
      )
    )
  ORDER BY s.name NULLS LAST, f.custom_subject NULLS LAST, f.created_at;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_study_queue(uuid) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.get_study_queue(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_study_queue(uuid) TO authenticated;

-- PostgREST: pick up the changed return signature
NOTIFY pgrst, 'reload schema';
