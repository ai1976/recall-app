-- Name: [FIX] One-time backfill — set target_course on the 2 NULL flashcard_decks rows
--
-- Description: Run AFTER 07_FUNCTIONS is deployed (so no new NULL rows form while this runs).
-- Recovers target_course for each affected deck from its own member flashcards (5-column grouping
-- join, same association used everywhere else in this project) — flashcards.target_course is
-- NOT NULL, so every deck's cards carry the correct value. Uses the most common target_course
-- among matching cards (defensive against the rare case where a subject's course mapping changed
-- over time and member cards disagree) rather than assuming a single value.
--
-- Safe to re-run: the WHERE clause only matches rows still NULL; a second run affects 0 rows.

WITH inferred AS (
  SELECT
    fd.id AS deck_id,
    (
      SELECT fc.target_course
      FROM flashcards fc
      WHERE fc.user_id = fd.user_id
        AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
        AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
        AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
        AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
      GROUP BY fc.target_course
      ORDER BY count(*) DESC
      LIMIT 1
    ) AS target_course
  FROM flashcard_decks fd
  WHERE fd.target_course IS NULL
)
UPDATE flashcard_decks fd
SET target_course = i.target_course
FROM inferred i
WHERE fd.id = i.deck_id
  AND i.target_course IS NOT NULL;

-- Verify: should return 0.
SELECT count(*) AS still_null_target_course FROM flashcard_decks WHERE target_course IS NULL;
