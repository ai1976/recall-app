-- Name: [DIAGNOSTIC] Sprint 8.8.5a Phase 2 — get_practice_cards completeness vs get_browsable_decks
--
-- Description: D-41 Area E requires proof, before PracticeMode.jsx is changed to filter to
-- is_enrolled=false client-side, that get_practice_cards already returns the COMPLETE Practice
-- candidate set for a deck (enrolled + unenrolled, no hidden pagination/limit, no hidden
-- enrollment filter) — i.e. that the "N" get_browsable_decks shows on a deck tile and the "N"
-- get_practice_cards actually returns for that same deck are the same universe.
--
-- Why this runs raw predicates instead of calling the RPCs directly: both get_browsable_decks
-- and get_practice_cards are SECURITY DEFINER functions gated on auth.uid() (get_practice_cards
-- additionally raises 'Access denied' when p_user_id IS DISTINCT FROM auth.uid() AND NOT
-- is_admin()). The Supabase SQL Editor has no authenticated session — auth.uid() is NULL there —
-- so calling either RPC as-is from this editor would fail before testing anything, not prove
-- anything about them. Per this project's established pattern for this class of check (D-30's
-- "independently re-written predicate, not a call to the function itself," Sprint 8.7.8e), this
-- diagnostic reproduces both functions' predicates VERBATIM from their live source:
--   get_browsable_decks v8 vc lateral  — docs/database/sprint8.7.7/11_FUNCTIONS_get_browsable_decks_v8_matching_card_count.sql:92-125
--   get_practice_cards card-level gate — docs/database/sprint8.7.10/12_FUNCTIONS_get_practice_cards_multi_deck.sql:192-232
-- against an explicit v_user_id, so it proves what those real functions would return for a real
-- user without needing a simulated session.
--
-- Modifies no data. Read-only.
--
-- HOW TO RUN (pre-filled for this run):
--   v_user_id (viewer/practicer, "Student Id")  = 26507dc7-5ceb-4940-878e-f4cdd2f6eab3
--   v_author_id (deck owner, "Author id")       = 075ad481-13e8-45e4-9deb-3c38907eb3e6
-- Unlike the generic version of this file, deck selection is scoped to decks AUTHORED BY
-- v_author_id and visible to v_user_id — every such deck is tested (not just the single largest),
-- since a known author/student pair with real content is stronger evidence than one auto-picked
-- deck. Just run the whole script as-is.
--
-- Report back EVERY result row, specifically per deck:
--      counts_match_expect_true            — must be TRUE for every row
--      practice_candidate_enrolled_true    — should be > 0 for at least one deck if this student
--                                             has enrolled cards from this author (0 across every
--                                             row would itself be worth flagging — check against
--                                             what you know about this account's enrollment state)
--      practice_candidate_total = practice_candidate_enrolled_true + practice_candidate_enrolled_false
--                                           — always true by construction; included as a visible
--                                             sanity check, not a real pass/fail condition
--
-- PASS condition for Phase 2: counts_match_expect_true = true on every row. If FALSE on any row,
-- STOP — do not build PracticeMode.jsx's remaining-only filter on get_practice_cards.is_enrolled
-- until that mismatch is understood; report it instead.

WITH params AS (
  SELECT
    '26507dc7-5ceb-4940-878e-f4cdd2f6eab3'::uuid AS v_user_id,
    '075ad481-13e8-45e4-9deb-3c38907eb3e6'::uuid AS v_author_id
),
user_ctx AS (
  SELECT pr.v_user_id, pr.v_author_id, p.role AS v_user_role, p.course_level AS v_user_course
  FROM params pr
  JOIN profiles p ON p.id = pr.v_user_id
),
-- Step 1 — every deck authored by v_author_id that is visible to v_user_id (get_browsable_decks
-- v8's vc.visible_card_count logic, p_question_type NULL, reproduced verbatim), not just the
-- single largest — a known author/student pair is worth testing exhaustively.
deck_candidates AS (
  SELECT
    fd.id AS deck_id, fd.user_id AS deck_owner, fd.subject_id, fd.topic_id,
    fd.custom_subject, fd.custom_topic, vc.visible_card_count
  FROM flashcard_decks fd
  CROSS JOIN user_ctx uc
  CROSS JOIN LATERAL (
    SELECT count(*)::int AS visible_card_count
    FROM flashcards fc
    WHERE fc.user_id = fd.user_id
      AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
      AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
      AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
      AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
      AND fc.question_type <> 'concept_card'
      AND (
        fc.visibility = 'public'
        OR fc.user_id = uc.v_user_id
        OR (fc.visibility = 'friends' AND EXISTS (
             SELECT 1 FROM friendships f WHERE f.status = 'accepted'
               AND ((f.user_id = uc.v_user_id AND f.friend_id = fc.user_id)
                 OR (f.friend_id = uc.v_user_id AND f.user_id = fc.user_id))))
        OR uc.v_user_role IN ('admin', 'super_admin')
        OR EXISTS (
             SELECT 1 FROM content_group_shares cgs
             JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
             WHERE cgs.content_type = 'flashcard_deck' AND cgs.content_id = fd.id
               AND sgm.user_id = uc.v_user_id AND sgm.status = 'active')
      )
  ) vc
  WHERE vc.visible_card_count > 0
    AND fd.user_id = uc.v_author_id               -- scoped to the given Author id only
    AND (
      fd.user_id = uc.v_user_id
      OR fd.visibility = 'public'
      OR (fd.visibility = 'friends' AND EXISTS (
           SELECT 1 FROM friendships f WHERE f.status = 'accepted'
             AND ((f.user_id = uc.v_user_id AND f.friend_id = fd.user_id)
               OR (f.friend_id = uc.v_user_id AND f.user_id = fd.user_id))))
      OR EXISTS (
           SELECT 1 FROM content_group_shares cgs
           JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
           WHERE cgs.content_type = 'flashcard_deck' AND cgs.content_id = fd.id
             AND sgm.user_id = uc.v_user_id AND sgm.status = 'active')
    )
    AND (
      uc.v_user_role IN ('professor', 'admin', 'super_admin')
      OR fd.user_id = uc.v_user_id
      OR fd.target_course = uc.v_user_course
    )
  ORDER BY vc.visible_card_count DESC
  -- no LIMIT — every visible deck by this author is tested, not just the largest
),
-- Step 2 — reproduce get_practice_cards' exact card set for EACH of those decks: same 5-column
-- deck match, then its card-level Practice-visibility gate, verbatim.
practice_candidate_set AS (
  SELECT
    dc.deck_id,
    fc.id AS flashcard_id,
    EXISTS (
      SELECT 1 FROM my_cards_enrollment e
      WHERE e.user_id = pr.v_user_id AND e.flashcard_id = fc.id AND e.status = 'active'
    ) AS is_enrolled
  FROM flashcards fc
  JOIN deck_candidates dc
    ON fc.user_id = dc.deck_owner
   AND (fc.subject_id     IS NOT DISTINCT FROM dc.subject_id)
   AND (fc.topic_id       IS NOT DISTINCT FROM dc.topic_id)
   AND (fc.custom_subject IS NOT DISTINCT FROM dc.custom_subject)
   AND (fc.custom_topic   IS NOT DISTINCT FROM dc.custom_topic)
  CROSS JOIN params pr
  CROSS JOIN user_ctx uc
  WHERE fc.question_type <> 'concept_card'
    AND (
      fc.user_id = pr.v_user_id
      OR fc.visibility = 'public'
      OR (fc.visibility = 'friends' AND EXISTS (
           SELECT 1 FROM friendships fr WHERE fr.status = 'accepted'
             AND ((fr.user_id = pr.v_user_id AND fr.friend_id = fc.user_id)
               OR (fr.friend_id = pr.v_user_id AND fr.user_id = fc.user_id))))
      OR uc.v_user_role IN ('admin', 'super_admin')
      OR EXISTS (
           SELECT 1
           FROM content_group_shares cgs
           JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
           JOIN flashcard_decks fd2 ON fd2.id = cgs.content_id
           WHERE cgs.content_type = 'flashcard_deck'
             AND sgm.user_id = pr.v_user_id AND sgm.status = 'active'
             AND fd2.user_id = fc.user_id
             AND (fd2.subject_id     IS NOT DISTINCT FROM fc.subject_id)
             AND (fd2.topic_id       IS NOT DISTINCT FROM fc.topic_id)
             AND (fd2.custom_subject IS NOT DISTINCT FROM fc.custom_subject)
             AND (fd2.custom_topic   IS NOT DISTINCT FROM fc.custom_topic))
    )
)
SELECT
  dc.deck_id,
  dc.visible_card_count                          AS browsable_visible_card_count,
  count(pcs.flashcard_id)                        AS practice_candidate_total,
  count(*) FILTER (WHERE pcs.is_enrolled)        AS practice_candidate_enrolled_true,
  count(*) FILTER (WHERE NOT pcs.is_enrolled)    AS practice_candidate_enrolled_false,
  (count(pcs.flashcard_id) = dc.visible_card_count) AS counts_match_expect_true
FROM deck_candidates dc
LEFT JOIN practice_candidate_set pcs ON pcs.deck_id = dc.deck_id
GROUP BY dc.deck_id, dc.visible_card_count
ORDER BY dc.visible_card_count DESC;
