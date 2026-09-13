-- Name: [FIX] One-time backfill — widen already-desynced flashcard_decks.visibility
--
-- Description: Run AFTER 04_FUNCTIONS is deployed (so no new desyncs form while this runs).
-- Fixes the decks 00_DIAGNOSTIC query 3/4 already found live (4 decks, 3 belonging to other
-- users — this bug predates and is unrelated to Sprint 7.5's testing). For each deck, recomputes
-- the widest visibility among its member flashcards (5-column grouping join, same as every other
-- deck↔flashcards association in this project) and upgrades the deck row only when that's more
-- permissive than what's currently stored — mirrors the trigger's own "only ever widen" rule, so
-- this is a one-time catch-up for existing data, not a general visibility recompute.
--
-- Safe to re-run: the WHERE clause only matches rows that still need widening; a second run
-- affects 0 rows.

WITH rank AS (
  SELECT 'private'::text AS v, 0 AS r UNION ALL SELECT 'friends', 1 UNION ALL SELECT 'public', 2
),
correct_visibility AS (
  SELECT
    fd.id AS deck_id,
    MAX(cr.r) AS max_card_rank
  FROM flashcard_decks fd
  JOIN flashcards fc
    ON fc.user_id = fd.user_id
   AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
   AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
   AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
   AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
  JOIN rank cr ON cr.v = fc.visibility
  GROUP BY fd.id
)
UPDATE flashcard_decks fd
SET visibility = (SELECT v FROM rank WHERE r = cv.max_card_rank)
FROM correct_visibility cv
WHERE fd.id = cv.deck_id
  AND cv.max_card_rank > (SELECT r FROM rank WHERE v = fd.visibility);

-- Verify: should return 0 rows now.
WITH rank AS (
  SELECT 'private'::text AS v, 0 AS r UNION ALL SELECT 'friends', 1 UNION ALL SELECT 'public', 2
)
SELECT count(*) AS still_desynced
FROM flashcard_decks fd
JOIN rank dr ON dr.v = fd.visibility
JOIN flashcards fc
  ON fc.user_id = fd.user_id
 AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
 AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
 AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
 AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
JOIN rank cr ON cr.v = fc.visibility
GROUP BY fd.id, dr.r
HAVING MAX(cr.r) > dr.r;
