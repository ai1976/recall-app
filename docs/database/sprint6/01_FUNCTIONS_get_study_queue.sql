-- Name: [FUNCTIONS] get_study_queue — single source of truth for the "what's due" review queue
--
-- Description:
--   Sprint 6.0 (a)+(b). Creates ONE SECURITY DEFINER RPC that returns a student's due-review
--   queue, replacing three duplicated client-side "what's due" implementations:
--     • src/pages/Dashboard.jsx            (fetchPersonalStats — reviewsDue count)
--     • src/pages/dashboard/Study/ReviewSession.jsx  (fetchDueCards)
--     • src/pages/dashboard/Study/StudyMode.jsx      (fetchFlashcards — Step 2 SRS filter, standalone mode)
--
--   "Due" definition adopted (the intersection all three call sites already used — see Sprint 6.0
--   report "Deviations" for the reconciliation):
--     a review row exists for (p_user_id, flashcard_id)
--       AND reviews.status      = 'active'
--       AND reviews.next_review_date <= <today in the user's timezone>
--       AND (reviews.skip_until IS NULL OR reviews.skip_until <= <today>)
--   Never-reviewed ("new") cards are NOT part of this queue — StudyMode's standalone
--   subject/topic study flow adds those client-side from its own visible-card fetch; it uses
--   this RPC only to know which already-scheduled cards are due.
--
--   Also enforced here:
--     • Concept cards excluded:  flashcards.question_type <> 'concept_card'
--     • Read-time COURSE FILTER (Sprint 6.0 b, non-destructive — mutates nothing):
--         the row is returned only when the card's course matches the student's current course.
--         Null policy (documented in blueprint.md):
--           - student with course_level IS NULL  -> no course filter applied (sees everything)
--           - card   with target_course IS NULL  -> treated as matching (always in queue)
--     • Visibility guard (SECURITY DEFINER bypasses RLS, so we re-assert the L2 predicates):
--         card is own OR visibility='public' OR (visibility='friends' AND accepted friendship)
--     • IDOR guard: the established L5 idiom (docs/database/security/02,08,10) — a caller may only
--         read their OWN queue; admins/super_admins may read any (matches is_admin()-aware pattern).
--         A NULL session is "IS DISTINCT FROM auth.uid()" and not is_admin(), so it RAISEs.
--
--   Timezone: reviews.next_review_date / skip_until are stored as the user's LOCAL date string
--   (StudyMode builds YYYY-MM-DD from local Y/M/D). "Today" is computed in the user's
--   profiles.timezone (fallback 'Asia/Kolkata'), matching get_user_streak / log_review_activity.
--
--   search_path pinned UNQUOTED (L3 17c outage lesson — never single-quote a multi-schema list).
--   New function -> PostgREST schema reload required (NOTIFY at end).
--
--   NO DATA MIGRATION. This RPC only reads. If a future change needs to write to `reviews`
--   for the course filter, STOP — the filter is read-time by design.
--
-- Deploy order (non-negotiable): run this in Supabase SQL Editor, confirm with 02_TEST,
-- THEN push the frontend that consumes it.

CREATE OR REPLACE FUNCTION public.get_study_queue(p_user_id uuid)
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
   last_reviewed_at timestamptz
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
  -- L5 read-IDOR guard (verbatim idiom from security/08,10)
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
    -- profile row missing (should not happen) — fall back to server date
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
    r.last_reviewed_at
  FROM reviews r
  JOIN flashcards f            ON f.id = r.flashcard_id
  LEFT JOIN subjects s         ON s.id = f.subject_id
  LEFT JOIN topics   t         ON t.id = f.topic_id
  WHERE r.user_id = p_user_id
    AND r.status = 'active'
    AND r.next_review_date <= v_today
    AND (r.skip_until IS NULL OR r.skip_until <= v_today)
    -- concept cards are reference-only, never in any review metric or queue
    AND f.question_type <> 'concept_card'
    -- read-time course filter (Sprint 6.0 b) — null-safe both directions
    AND (
      v_course_level IS NULL
      OR f.target_course IS NULL
      OR f.target_course = v_course_level
    )
    -- visibility guard — re-assert L2 read predicates (SECURITY DEFINER bypasses RLS)
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

-- Least-privilege grants (L5 "REVOKE FROM PUBLIC + GRANT back" pattern)
REVOKE ALL     ON FUNCTION public.get_study_queue(uuid) FROM PUBLIC;
REVOKE ALL     ON FUNCTION public.get_study_queue(uuid) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_study_queue(uuid) TO authenticated;

-- PostgREST: pick up the new function
NOTIFY pgrst, 'reload schema';

-- ─── Manual smoke (run as an authenticated user in the SQL editor is not possible;
--     use 02_TEST or the app). Expected:
--   • SELECT * FROM public.get_study_queue(auth.uid());              -> rows (or none), never error
--   • SELECT * FROM public.get_study_queue('<other-user-uuid>');     -> ERROR: Access denied ...
--   • A concept_card that is otherwise due                           -> absent from the result
--   • After the student switches course_level                       -> only new-course rows appear;
--     reviews rows are UNCHANGED (verify next_review_date before/after — identical).
