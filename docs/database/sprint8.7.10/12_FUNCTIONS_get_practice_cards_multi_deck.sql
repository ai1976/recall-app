-- Name: [FUNCTIONS] Sprint 8.7.10 Scope C - get_practice_cards, subject-wide Practice All
-- Description: Closes the "Study All" mislabeling. Today's ReviewFlashcards.jsx "Study All (N)"
-- button shows N = sum of get_browsable_decks' matching_card_count across every deck in that
-- subject (the Browse-visible population), but navigates to Study Mode, whose actual pool is
-- get_my_cards() (own u2229 actively-enrolled) -- a much smaller, unrelated set. The displayed
-- count never matched what the button actually opened.
--
-- Fix: rename to "Practice All (N)" (frontend, separate file) and change its destination to
-- Practice Mode, extended here to accept multiple deck ids in one call so N is guaranteed to
-- match the population opened -- both numbers now come from literally the same deck list and the
-- same per-card visibility predicate as get_browsable_decks v8 (already true for the single-deck
-- case; this extends it to hold for a whole subject too). Practice Mode never enrolls a card
-- merely by opening it -- that invariant is unchanged.
--
-- SIGNATURE CHANGE: p_deck_id uuid -> p_deck_ids uuid[]. This is a different function identity to
-- Postgres (different arg count/type), so DROP FUNCTION is required first -- CREATE OR REPLACE
-- would leave two live overloads and silently never call this new body for 3-positional-arg
-- callers (the exact ambiguous-overload class of bug this codebase already hit with apply_review's
-- Sprint 8.6c parameter addition). The one live caller (PracticeMode.jsx) is updated in the same
-- release to always pass an array (a single deck becomes a 1-element array) -- see the paired
-- frontend commit.
--
-- Single-deck behavior is preserved exactly: a 1-element p_deck_ids array that fails the gate
-- still raises 'Study Set not accessible' (ERRCODE 42501), matching today's hard-error contract
-- PracticeMode.jsx's isAccessError() already handles. For a multi-deck (subject-wide) call, an
-- individual deck that's since become inaccessible is silently skipped rather than erroring the
-- whole batch -- only a call where EVERY deck fails validation raises. This means a mid-air
-- visibility change (race between Browse fetch and click) degrades gracefully to "practice what's
-- still accessible" instead of blocking the whole subject over one stale deck.
--
-- Card selection, visibility predicates, is_own/is_enrolled/can_add_to_my_cards computation, and
-- concept_card exclusion are otherwise byte-identical logic to the live 10_FIX version -- just
-- evaluated against a validated-decks set instead of a single validated deck.
--
-- STEP 0 -- run this first and confirm the live body matches
-- docs/database/sprint8.7.8c/10_FIX_add_scenario_to_get_practice_cards.sql before applying the
-- DROP/CREATE below:
--   SELECT pg_get_functiondef(p.oid)
--   FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--   WHERE n.nspname = 'public' AND p.proname = 'get_practice_cards';

DROP FUNCTION IF EXISTS public.get_practice_cards(uuid, uuid, text);

CREATE FUNCTION public.get_practice_cards(
  p_user_id       uuid,
  p_deck_ids      uuid[],
  p_question_type text DEFAULT NULL
)
RETURNS TABLE (
  id                  uuid,
  user_id             uuid,
  subject_id          uuid,
  topic_id            uuid,
  custom_subject      text,
  custom_topic        text,
  subject_name        text,
  topic_name          text,
  question_type       text,
  subtype             text,
  front_text          text,
  back_text           text,
  options             jsonb,
  correct_answer      text,
  explanation         jsonb,
  visibility          text,
  scenario            text,
  created_at          timestamptz,
  is_own              boolean,
  is_enrolled         boolean,
  can_add_to_my_cards boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public, extensions
AS $function$
DECLARE
  v_user_role      text;
  v_user_course    text;
  v_validated_count integer;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot fetch Practice cards for another user';
  END IF;

  IF p_deck_ids IS NULL OR array_length(p_deck_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'p_deck_ids must be a non-empty array';
  END IF;

  SELECT p.role, p.course_level INTO v_user_role, v_user_course
  FROM public.profiles p WHERE p.id = p_user_id;

  -- Deck-level access re-check, per deck -- get_browsable_decks v8's VISIBILITY GATE + COURSE GATE,
  -- reproduced verbatim (docs/database/sprint8.7.7/11_...sql:166-196), scoped to every deck in the
  -- array instead of one.
  SELECT COUNT(*) INTO v_validated_count
  FROM public.flashcard_decks fd
  WHERE fd.id = ANY(p_deck_ids)
    AND (
      fd.user_id = p_user_id
      OR fd.visibility = 'public'
      OR (
        fd.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM public.friendships f
          WHERE f.status = 'accepted'
            AND ((f.user_id = p_user_id AND f.friend_id = fd.user_id)
              OR (f.friend_id = p_user_id AND f.user_id = fd.user_id))
        )
      )
      OR EXISTS (
        SELECT 1 FROM public.content_group_shares cgs
        JOIN public.study_group_members sgm ON sgm.group_id = cgs.group_id
        WHERE cgs.content_type = 'flashcard_deck'
          AND cgs.content_id = fd.id
          AND sgm.user_id = p_user_id
          AND sgm.status = 'active'
      )
    )
    AND (
      v_user_role IN ('professor', 'admin', 'super_admin')
      OR fd.user_id = p_user_id
      OR fd.target_course = v_user_course
    );

  IF v_validated_count = 0 THEN
    RAISE EXCEPTION 'Study Set not accessible' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH validated_decks AS (
    SELECT fd.id, fd.user_id, fd.subject_id, fd.topic_id, fd.custom_subject, fd.custom_topic
    FROM public.flashcard_decks fd
    WHERE fd.id = ANY(p_deck_ids)
      AND (
        fd.user_id = p_user_id
        OR fd.visibility = 'public'
        OR (
          fd.visibility = 'friends'
          AND EXISTS (
            SELECT 1 FROM public.friendships f
            WHERE f.status = 'accepted'
              AND ((f.user_id = p_user_id AND f.friend_id = fd.user_id)
                OR (f.friend_id = p_user_id AND f.user_id = fd.user_id))
          )
        )
        OR EXISTS (
          SELECT 1 FROM public.content_group_shares cgs
          JOIN public.study_group_members sgm ON sgm.group_id = cgs.group_id
          WHERE cgs.content_type = 'flashcard_deck'
            AND cgs.content_id = fd.id
            AND sgm.user_id = p_user_id
            AND sgm.status = 'active'
        )
      )
      AND (
        v_user_role IN ('professor', 'admin', 'super_admin')
        OR fd.user_id = p_user_id
        OR fd.target_course = v_user_course
      )
  )
  SELECT DISTINCT
    fc.id, fc.user_id, fc.subject_id, fc.topic_id, fc.custom_subject, fc.custom_topic,
    COALESCE(s.name, fc.custom_subject, 'Other')   AS subject_name,
    COALESCE(t.name, fc.custom_topic,   'General') AS topic_name,
    fc.question_type, fc.subtype, fc.front_text, fc.back_text, fc.options, fc.correct_answer,
    fc.explanation, fc.visibility, fc.scenario, fc.created_at,
    (fc.user_id = p_user_id) AS is_own,
    EXISTS (
      SELECT 1 FROM public.my_cards_enrollment e
      WHERE e.user_id = p_user_id AND e.flashcard_id = fc.id AND e.status = 'active'
    ) AS is_enrolled,
    -- can_add_to_my_cards: add_to_my_cards's exact predicate (narrower than Practice visibility
    -- below — no admin override, no group-share). A card can be Practice-visible (via admin
    -- override or group-share) while this is false — that is the intended, documented gap.
    (
      fc.user_id = p_user_id
      OR fc.visibility = 'public'
      OR (
        fc.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM public.friendships fr
          WHERE fr.status = 'accepted'
            AND ((fr.user_id = p_user_id AND fr.friend_id = fc.user_id)
              OR (fr.friend_id = p_user_id AND fr.user_id = fc.user_id))
        )
      )
    ) AS can_add_to_my_cards
  FROM public.flashcards fc
  LEFT JOIN public.subjects s ON s.id = fc.subject_id
  LEFT JOIN public.topics   t ON t.id = fc.topic_id
  WHERE EXISTS (
    SELECT 1 FROM validated_decks vd
    WHERE fc.user_id = vd.user_id
      AND (fc.subject_id     IS NOT DISTINCT FROM vd.subject_id)
      AND (fc.topic_id       IS NOT DISTINCT FROM vd.topic_id)
      AND (fc.custom_subject IS NOT DISTINCT FROM vd.custom_subject)
      AND (fc.custom_topic   IS NOT DISTINCT FROM vd.custom_topic)
  )
    AND fc.question_type <> 'concept_card'
    AND (p_question_type IS NULL OR fc.question_type = p_question_type)
    -- Card-level Practice visibility: log_practice_attempt's predicate, verbatim (own + public +
    -- accepted-friends + admin override + group-shared, matching get_browsable_decks v8's
    -- card-level vc lateral). Re-checked per card, independent of the deck-level gate above.
    AND (
      fc.user_id = p_user_id
      OR fc.visibility = 'public'
      OR (
        fc.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM public.friendships fr
          WHERE fr.status = 'accepted'
            AND ((fr.user_id = p_user_id AND fr.friend_id = fc.user_id)
              OR (fr.friend_id = p_user_id AND fr.user_id = fc.user_id))
        )
      )
      OR v_user_role IN ('admin', 'super_admin')
      OR EXISTS (
        SELECT 1
        FROM public.content_group_shares cgs
        JOIN public.study_group_members sgm ON sgm.group_id = cgs.group_id
        JOIN public.flashcard_decks fd2 ON fd2.id = cgs.content_id
        WHERE cgs.content_type = 'flashcard_deck'
          AND sgm.user_id = p_user_id
          AND sgm.status = 'active'
          AND fd2.user_id = fc.user_id
          AND (fd2.subject_id     IS NOT DISTINCT FROM fc.subject_id)
          AND (fd2.topic_id       IS NOT DISTINCT FROM fc.topic_id)
          AND (fd2.custom_subject IS NOT DISTINCT FROM fc.custom_subject)
          AND (fd2.custom_topic   IS NOT DISTINCT FROM fc.custom_topic)
      )
    )
  ORDER BY fc.created_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_practice_cards(uuid, uuid[], text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_practice_cards(uuid, uuid[], text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_practice_cards(uuid, uuid[], text) TO authenticated;

NOTIFY pgrst, 'reload schema';
