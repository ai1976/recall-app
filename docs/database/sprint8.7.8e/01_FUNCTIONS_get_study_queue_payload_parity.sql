-- Name: [FUNCTIONS] get_study_queue — Review-queue objective-card payload parity
--
-- Description: Sprint 8.7.8e. The normal SRS "Review due cards" flow
-- (ReviewSession.jsx -> get_study_queue -> StudyMode.jsx) has never returned
-- `options`, `correct_answer`, `explanation`, `scenario`, or `subtype` on
-- flashcards. Confirmed live by reading the current deployed signature
-- (docs/database/sprint8.7.4/04_FUNCTIONS_get_study_queue_batch_id.sql) and by
-- grepping every `currentCard.*` reference StudyMode.jsx actually makes —
-- `options`, `correct_answer`, `explanation`, `scenario` are read and were
-- silently undefined for any card reaching StudyMode via this path (mcq,
-- mcq_multi, correct_incorrect, case_study_mcq, fitb, match_the_following all
-- render with no options/no scenario/no explanation today). `subtype` is not
-- yet read by StudyMode.jsx, but is added now on the Quality Auditor's
-- direction: it is an already-defined semantic classification on `theory`
-- rows (pure_theory / descriptive_case_study), not a speculative field, and
-- 8.7.9's renderer is expected to key off `subtype` rather than infer content
-- shape from whether `scenario` happens to be populated.
--
-- This is the THIRD additive touch to this function's return shape (Sprint
-- 6.0 baseline -> SRS Ladder Epic added `rung` -> Sprint 8.7.4 added
-- `batch_id` -> this sprint adds five more). Same DROP+CREATE discipline as
-- both prior changes (a plain CREATE OR REPLACE cannot add columns to
-- RETURNS TABLE). Body is byte-identical to the live 8.7.4 version except:
--   (a) five columns appended to RETURNS TABLE: options jsonb,
--       correct_answer text, explanation jsonb, scenario text, subtype text
--   (b) the same five columns appended to the final SELECT list, sourced
--       directly from flashcards (f.options, f.correct_answer, f.explanation,
--       f.scenario, f.subtype)
-- Nothing else changes: due-eligibility WHERE clause, course filter,
-- visibility guard, concept_card exclusion, ORDER BY, and the IDOR guard are
-- all unchanged, character-for-character, from the live 8.7.4 version. No
-- write path, no reviews/ladder table, no scheduling logic is touched.
--
-- Column types matched to get_practice_cards' existing signature for the
-- same four already-proven columns (docs/database/sprint8.7.8c/
-- 01_FUNCTIONS_get_practice_cards.sql) so both read paths agree on shape.
--
-- STEP 0 — run this first and confirm the live body matches
-- docs/database/sprint8.7.4/04_FUNCTIONS_get_study_queue_batch_id.sql before
-- applying the DROP/CREATE below:
--   SELECT pg_get_functiondef(p.oid)
--   FROM pg_proc p
--   JOIN pg_namespace n ON n.oid = p.pronamespace
--   WHERE n.nspname = 'public' AND p.proname = 'get_study_queue';

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
   batch_id         uuid,
   options          jsonb,
   correct_answer   text,
   explanation      jsonb,
   scenario         text,
   subtype          text
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
    f.batch_id,
    f.options,
    f.correct_answer,
    f.explanation,
    f.scenario,
    f.subtype
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
