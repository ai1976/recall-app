-- Name: [FUNCTIONS] get_browsable_decks v7 — deck-level provenance badge
--
-- Description: Sprint 8.7.4 adds two additive, non-breaking-for-callers return
-- columns, provenance_source_type / provenance_source_name, so ReviewFlashcards.jsx
-- (Browse Study Sets) can render a source badge on a deck tile without an
-- extra round-trip per deck.
--
-- DESIGN DECISION (deck-level provenance is inherently ambiguous, flagging the
-- reasoning explicitly since the sprint brief only specified card/batch-level
-- provenance, not deck-level aggregation): a "deck" here is a 5-grouping-column
-- bucket (subject/topic/custom_subject/custom_topic + user), not a batch — a
-- single deck routinely spans MANY batch_ids (a student adds cards to the same
-- subject/topic across many sessions). Showing one badge for a multi-source
-- deck would misattribute cards that don't share that source. Rule applied:
-- the deck only gets a provenance badge when EVERY card the viewer can see in
-- that deck belongs to the SAME batch_id (a single-batch deck — the common
-- case for a bulk upload or a single manual card). Any deck spanning more than
-- one batch_id, or where the sole batch has no provenance row (legacy),
-- returns NULL for both columns — same "render nothing" rule as everywhere
-- else in this sprint, not a new "mixed sources" treatment.
--
-- Computed via a second LATERAL joined to the existing per-viewer visible-card
-- lateral (vc): vc gains `sole_batch_id`, set only when count(DISTINCT
-- fc.batch_id) = 1 across the same filtered row set that already computes
-- visible_card_count/has_concept_card — no extra scan of flashcards. The new
-- LEFT JOIN to flashcard_batch_provenance runs inside this SECURITY DEFINER
-- function (owner postgres), so it does not depend on the authenticated
-- SELECT policy added in 01_SCHEMA — RLS on flashcard_batch_provenance is
-- bypassed here exactly as flashcards'/notes' own RLS already is throughout
-- this function.
--
-- CORRECTION (inherited from v5/v6's own note): adding a return column changes
-- the function's result type, so plain CREATE OR REPLACE does NOT work —
-- Postgres refuses to alter an existing function's return type via REPLACE.
-- The existing one-arg overload (p_question_type TEXT DEFAULT NULL) must be
-- DROPped explicitly first.
--
-- Every existing caller is unaffected by the two new columns — callers that
-- don't read provenance_source_type/provenance_source_name off the returned
-- rows see no behavior change at all.
--
-- Reproduced verbatim from v6 (docs/database/sprint7.12/01_FUNCTIONS_get_browsable_decks_v6_has_concept_card.sql)
-- with two additive SELECT-list columns and one additive lateral-subquery column.
--
-- REAL BUG, found live (18/09/2026, not caught by review — the operator's live
-- run of this exact file hit it): the original `sole_batch_id` expression used
-- min(fc.batch_id), but Postgres has no default ordering operator class for
-- uuid, so min()/max() over a uuid column raises `42883: function min(uuid)
-- does not exist` at RETURN QUERY time — i.e. the DROP+CREATE succeeds
-- (no syntax error), but EVERY call to get_browsable_decks() then fails.
-- Fixed below: (array_agg(fc.batch_id))[1] picks an arbitrary element instead,
-- which is safe here specifically because the CASE already gated on
-- count(DISTINCT fc.batch_id) = 1, so every element in that array is identical.

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
  provenance_source_name TEXT
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
    bp.content_source_name AS provenance_source_name
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

-- PostgREST: pick up the changed return signature
NOTIFY pgrst, 'reload schema';

-- Manual smoke (run as the operator in Supabase SQL Editor — SECURITY DEFINER
-- means auth.uid() is NULL outside a real authenticated session, so this will
-- RAISE 'Not authenticated' here; that's expected — full verification is via
-- 05_TEST's role-impersonation pattern, or the app itself):
--   SELECT * FROM public.get_browsable_decks() LIMIT 1;   -> RAISE (expected in SQL Editor)
