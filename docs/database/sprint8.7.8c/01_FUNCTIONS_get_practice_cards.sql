-- Name: [FUNCTIONS] get_practice_cards
--
-- Description: Sprint 8.7.8c Step 0 batched Practice-card retrieval + eligibility RPC. Replaces
-- StudyMode.jsx's direct client-side `.from('flashcards')` fetch (narrow 3-clause visibility, no
-- eligibility info, no group-share) as the data source for the new Practice/Explore surface.
--
-- Design, per Step 0 findings and Anand's three amendments (22/09/2026):
--   1. Returns is_own, is_enrolled (active my_cards_enrollment row only), and can_add_to_my_cards
--      as three independent server-computed booleans. Practice Mode must never infer any of these
--      client-side, and must be able to tell "already in My Cards" from "eligible to add" so it
--      never re-offers Add for a card the student has already enrolled.
--   2. p_deck_id itself is validated against get_browsable_decks v8's exact deck-level VISIBILITY
--      GATE + COURSE GATE (docs/database/sprint8.7.7/11_..._v8_matching_card_count.sql:166-196)
--      BEFORE resolving its five grouping columns. Filtering only the returned cards would (a) let
--      a caller distinguish "inaccessible deck" from "empty deck" by response shape, and (b) skip
--      the course gate entirely, since the course gate is deck-level only (get_study_queue does its
--      own separate null-safe course check; there is no card-level course predicate anywhere in
--      this schema to fall back on).
--   3. question_type = 'concept_card' is excluded unconditionally — concept cards are browse-only
--      under the approved architecture (D-06) and must never surface as a Practice attempt or an
--      Add-to-My-Cards candidate. No code path in ConceptCardViewer.jsx or elsewhere reads this RPC,
--      so there is no consumer that needs concept cards returned here.
--
-- Two different predicates are reused verbatim from their live sources, per this epic's own rule
-- (proposal §2.2/§11 — never invent a sixth inconsistent model):
--   - Card-level Practice visibility = log_practice_attempt's predicate (own + public +
--     accepted-friends + admin override + group-shared), copied from
--     docs/database/sprint8.7.8b/02_FUNCTIONS_my_cards_rpcs.sql:253-287.
--   - can_add_to_my_cards = add_to_my_cards's predicate (own + public + accepted-friends only, no
--     admin override, no group-share — the get_study_queue-compatible, narrower predicate), copied
--     from docs/database/sprint8.7.8b/02_FUNCTIONS_my_cards_rpcs.sql:60-82.
--
-- Deck grouping: the established 5-grouping-column join (CLAUDE.md / DATABASE_SCHEMA.md
-- flashcard_decks section) is used throughout, never flashcards.deck_id — deck_id is NULL for
-- bulk-uploaded cards and must not be relied on as a filter.
--
-- No changes to add_to_my_cards, remove_from_my_cards, get_my_cards, log_practice_attempt,
-- get_browsable_decks, get_study_queue, apply_review, or any frozen SRS object. This is a new,
-- additive read-only RPC.

DROP FUNCTION IF EXISTS public.get_practice_cards(uuid, uuid, text);

CREATE OR REPLACE FUNCTION public.get_practice_cards(
  p_user_id       uuid,
  p_deck_id       uuid,
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
  v_user_role   text;
  v_user_course text;
  v_deck        record;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot fetch Practice cards for another user';
  END IF;

  -- Column reference must be qualified: RETURNS TABLE(id uuid, ...) implicitly declares `id` (and
  -- every other returned column name) as a PL/pgSQL variable in this function's body, so a bare
  -- `id` here would be ambiguous against profiles.id (42702), not just a style preference.
  SELECT p.role, p.course_level INTO v_user_role, v_user_course
  FROM public.profiles p WHERE p.id = p_user_id;

  -- Deck-level access re-check — get_browsable_decks v8's VISIBILITY GATE + COURSE GATE,
  -- reproduced verbatim (docs/database/sprint8.7.7/11_...sql:166-196), scoped to this one deck.
  -- Must pass BEFORE the five grouping columns are trusted and used to select cards (amendment 2).
  SELECT fd.* INTO v_deck
  FROM public.flashcard_decks fd
  WHERE fd.id = p_deck_id
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

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Study Set not accessible' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    fc.id, fc.user_id, fc.subject_id, fc.topic_id, fc.custom_subject, fc.custom_topic,
    COALESCE(s.name, fc.custom_subject, 'Other')   AS subject_name,
    COALESCE(t.name, fc.custom_topic,   'General') AS topic_name,
    fc.question_type, fc.subtype, fc.front_text, fc.back_text, fc.options, fc.correct_answer,
    fc.explanation, fc.visibility, fc.created_at,
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
  WHERE fc.user_id = v_deck.user_id
    AND (fc.subject_id     IS NOT DISTINCT FROM v_deck.subject_id)
    AND (fc.topic_id       IS NOT DISTINCT FROM v_deck.topic_id)
    AND (fc.custom_subject IS NOT DISTINCT FROM v_deck.custom_subject)
    AND (fc.custom_topic   IS NOT DISTINCT FROM v_deck.custom_topic)
    AND fc.question_type <> 'concept_card'
    AND (p_question_type IS NULL OR fc.question_type = p_question_type)
    -- Card-level Practice visibility: log_practice_attempt's predicate, verbatim (own + public +
    -- accepted-friends + admin override + group-shared, matching get_browsable_decks v8's
    -- card-level vc lateral). Re-checked per card, independent of the deck-level gate above,
    -- exactly as get_browsable_decks re-checks card-level visibility inside its vc lateral even
    -- though the deck already passed its own visibility gate (defense in depth, not redundancy —
    -- a deck can contain cards with mixed visibility).
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

-- Least-privilege grants (L5 "REVOKE FROM PUBLIC/anon + GRANT to authenticated" pattern, verbatim
-- convention from get_study_queue / get_my_cards / security/04).
REVOKE ALL ON FUNCTION public.get_practice_cards(uuid, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_practice_cards(uuid, uuid, text) FROM anon;
GRANT  EXECUTE ON FUNCTION public.get_practice_cards(uuid, uuid, text) TO authenticated;

-- PostgREST: pick up the new function
NOTIFY pgrst, 'reload schema';
