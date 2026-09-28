-- Name: [FUNCTIONS] get_browsable_decks v9 — added_count (My Study enrollment)
--
-- Description: Sprint 8.8.5a, D-41 Area D. Adds ONE additive return column, added_count, at the
-- END of the RETURNS TABLE — the number of cards in the deck the viewer has ACTIVELY enrolled in
-- My Study (an active my_cards_enrollment row), scoped to the SAME viewer-visible + p_question_type
-- -filtered universe as matching_card_count (D-41 Area C: "added_count must count enrolled cards
-- from the SAME current card/deck/filter universe used for the corresponding browsable/matching
-- count — do not calculate an all-deck added count against a filtered matching-card total"). With
-- p_question_type NULL, added_count is scoped to the same set visible_card_count/matching_card_count
-- both cover. card_count, matching_card_count, visible_card_count, deck inclusion rule, provenance
-- columns, ordering, SECURITY DEFINER and search_path are all UNCHANGED from v8.
--
-- Why: D-41 Area B/C — Browse/Discover must show "N added · M remaining" per deck (M = matching -
-- added), computed from get_my_cards's own enrollment semantics (active my_cards_enrollment row),
-- never from reviews.status/rung/due/skip. Read-only extension; does not touch get_study_queue,
-- SRS ladder, review intervals, apply_review, or skip/suspend semantics (D-41 Area D/I).
--
-- Reproduced verbatim from v8 (docs/database/sprint8.7.7/11_FUNCTIONS_get_browsable_decks_v8_matching_card_count.sql)
-- with two additive edits, each marked "v9": the new RETURNS TABLE column, and one new aggregate
-- in the existing vc lateral (added_count, scoped through the identical p_question_type FILTER
-- condition matching_card_count already uses, per D-41 Area C's internal-consistency requirement).
-- As in v5-v8, changing the return type means CREATE OR REPLACE cannot be used — the existing
-- one-arg overload is DROPped first. DROP + CREATE resets the function's ACL to schema defaults —
-- confirm grants after deploying (see STEP 2 below), same lesson v8's own header already documents.
--
-- STEP 0 — before applying, confirm the live body still matches v8 exactly (no undocumented drift):
--   SELECT pg_get_functiondef(p.oid)
--   FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
--   WHERE n.nspname = 'public' AND p.proname = 'get_browsable_decks';
--
-- STEP 1 — run this file alone.
--
-- STEP 2 — re-grant EXECUTE explicitly (DROP FUNCTION resets ACL — v8's own file hit this):
--   REVOKE ALL ON FUNCTION get_browsable_decks(TEXT) FROM PUBLIC;
--   REVOKE ALL ON FUNCTION get_browsable_decks(TEXT) FROM anon;
--   GRANT  EXECUTE ON FUNCTION get_browsable_decks(TEXT) TO authenticated;
--
-- STEP 3 — confirm the deployed signature/result on a real deck before any frontend wiring begins
-- (D-41 Area D's SQL-first requirement): pick a deck you know has both enrolled and unenrolled
-- cards for your account and confirm added_count + (matching_card_count - added_count) accounts
-- for every card, and that added_count only moves on an actual Add/Remove — never on
-- Suspend/Resume/Skip.
--
-- Deployment: run STEP 0 first, run THIS file, then STEP 2, then STEP 3, then confirm before the
-- frontend push (CLAUDE.md Pre-Push Dependency Checklist).
-- Rollback: re-run docs/database/sprint8.7.7/11_FUNCTIONS_get_browsable_decks_v8_matching_card_count.sql
-- verbatim (frontend must be rolled back first if this v9 has already been wired in).

DROP FUNCTION IF EXISTS get_browsable_decks(TEXT);

CREATE OR REPLACE FUNCTION get_browsable_decks(p_question_type TEXT DEFAULT NULL)
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
  topic_name TEXT,
  has_concept_card BOOLEAN,
  provenance_source_type TEXT,
  provenance_source_name TEXT,
  matching_card_count INTEGER,
  added_count INTEGER
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
    COALESCE(top.name, fd.custom_topic,   'General') AS topic_name,
    vc.has_concept_card,
    bp.content_source_type AS provenance_source_type,
    bp.content_source_name AS provenance_source_name,
    vc.matching_card_count,                         -- v8: viewer-visible cards of the requested type
    vc.added_count                                  -- v9: of those, actively My-Study-enrolled by viewer
  FROM flashcard_decks fd
  JOIN profiles p     ON p.id   = fd.user_id
  LEFT JOIN subjects s   ON s.id   = fd.subject_id
  LEFT JOIN topics   top ON top.id = fd.topic_id
  -- Count of cards in this deck (5-grouping-column join) that the VIEWER may see,
  -- whether any of those visible cards is a concept_card (Sprint 7.12), and
  -- (Sprint 8.7.4) the single batch_id shared by ALL of them, if there is one.
  CROSS JOIN LATERAL (
    SELECT count(*)::INTEGER AS visible_card_count,
           bool_or(fc.question_type = 'concept_card') AS has_concept_card,
           -- v8 (Sprint 8.7.7): same viewer-visibility row set as visible_card_count, narrowed to the
           -- requested type. With no filter every visible card matches, so it equals visible_card_count.
           count(*) FILTER (WHERE p_question_type IS NULL OR fc.question_type = p_question_type)::INTEGER AS matching_card_count,
           -- v9 (Sprint 8.8.5a, D-41 Area D): of the SAME type-filtered row set matching_card_count
           -- counts, how many the viewer has an ACTIVE my_cards_enrollment row for. Deliberately the
           -- identical "p_question_type IS NULL OR fc.question_type = p_question_type" condition as
           -- matching_card_count, so added_count is always drawn from the same filtered universe
           -- (D-41 Area C's internal-consistency requirement) — never the unfiltered visible_card_count.
           count(*) FILTER (
             WHERE (p_question_type IS NULL OR fc.question_type = p_question_type)
               AND EXISTS (
                 SELECT 1 FROM my_cards_enrollment mce
                 WHERE mce.user_id = v_user_id
                   AND mce.flashcard_id = fc.id
                   AND mce.status = 'active'
               )
           )::INTEGER AS added_count,
           -- min(uuid) does not exist in Postgres (uuid has no ordering operator
           -- class by default) — array_agg()[1] picks an arbitrary element
           -- instead, which is fine here since we've already gated on
           -- count(DISTINCT fc.batch_id) = 1, so every element is identical.
           CASE WHEN count(DISTINCT fc.batch_id) = 1 THEN (array_agg(fc.batch_id))[1] ELSE NULL END AS sole_batch_id
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
  LEFT JOIN flashcard_batch_provenance bp ON bp.batch_id = vc.sole_batch_id
  WHERE
    vc.visible_card_count > 0                        -- was fd.card_count > 0

    -- QUESTION TYPE FILTER (Sprint 7.6, additive): NULL = no filter (v4 behavior).
    -- Deck included if it has at least one visible-to-viewer card of the requested type —
    -- same visibility predicate as vc above, re-checked here since vc's count must stay
    -- type-agnostic (it feeds the returned card_count, which covers the whole deck).
    AND (
      p_question_type IS NULL
      OR EXISTS (
        SELECT 1
        FROM flashcards fc2
        WHERE fc2.user_id = fd.user_id
          AND (fc2.subject_id     IS NOT DISTINCT FROM fd.subject_id)
          AND (fc2.topic_id       IS NOT DISTINCT FROM fd.topic_id)
          AND (fc2.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
          AND (fc2.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
          AND fc2.question_type = p_question_type
          AND (
            fc2.visibility = 'public'
            OR fc2.user_id = v_user_id
            OR (fc2.visibility = 'friends' AND EXISTS (
                 SELECT 1 FROM friendships f
                  WHERE f.status = 'accepted'
                    AND ((f.user_id = v_user_id AND f.friend_id = fc2.user_id)
                      OR (f.friend_id = v_user_id AND f.user_id = fc2.user_id))))
            OR v_user_role IN ('admin', 'super_admin')
            OR EXISTS (
                 SELECT 1 FROM content_group_shares cgs
                 JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
                  WHERE cgs.content_type = 'flashcard_deck'
                    AND cgs.content_id   = fd.id
                    AND sgm.user_id      = v_user_id
                    AND sgm.status       = 'active')
          )
      )
    )

    -- VISIBILITY GATE (unchanged from v4): deck must pass at least one visibility rule
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

    -- COURSE GATE (unchanged from v4): professors/admins bypass; students see own course + own content
    AND (
      v_user_role IN ('professor', 'admin', 'super_admin')
      OR fd.user_id      = v_user_id
      OR fd.target_course = v_user_course
    )

  ORDER BY fd.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION get_browsable_decks(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_browsable_decks(TEXT) FROM anon;
GRANT  EXECUTE ON FUNCTION get_browsable_decks(TEXT) TO authenticated;

-- PostgREST: pick up the changed return signature
NOTIFY pgrst, 'reload schema';
