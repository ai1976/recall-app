-- Name: [DIAGNOSTIC] Deck visibility desync — live trigger body + blast-radius measurement
--
-- Description: Investigating a bug found during Sprint 7.5 live testing (not an MCQ bug —
-- pre-existing, platform-wide): flashcard_decks.visibility is set once, at deck-creation time,
-- and never re-widened when a later card with a more permissive visibility is added to the same
-- (user, subject, topic) group. Symptom: a deck created 'private' that later gains public cards
-- stays invisible in get_recent_activity_feed and get_browsable_decks, even though the public
-- cards' own flashcards.visibility is correct. Run before writing any fix DDL.

-- 1. Live body of the trigger function that maintains flashcard_decks (confirm exact current
--    UPDATE-then-INSERT shape described in bugs.md "[Mar 2, 2026] CA Foundation Flashcards
--    Invisible" before touching it).
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'update_deck_card_count' AND pronamespace = 'public'::regnamespace;

-- 2. Confirm the trigger definition itself (fires on flashcards, which events, what function).
SELECT tgname, pg_get_triggerdef(oid) FROM pg_trigger WHERE tgrelid = 'public.flashcards'::regclass AND NOT tgisinternal;

-- 3. Blast radius: how many existing flashcard_decks rows are currently desynced — i.e. the
--    deck's stored visibility is LESS permissive than the most-permissive card actually in it.
--    (private=0, friends=1, public=2; a desync is deck_rank < max_card_rank)
WITH rank AS (
  SELECT 'private'::text AS v, 0 AS r UNION ALL SELECT 'friends', 1 UNION ALL SELECT 'public', 2
),
deck_actual AS (
  SELECT
    fd.id AS deck_id,
    fd.visibility AS deck_visibility,
    dr.r AS deck_rank,
    MAX(cr.r) AS max_card_rank
  FROM flashcard_decks fd
  JOIN rank dr ON dr.v = fd.visibility
  JOIN flashcards fc
    ON fc.user_id = fd.user_id
   AND (fc.subject_id IS NOT DISTINCT FROM fd.subject_id)
   AND (fc.topic_id IS NOT DISTINCT FROM fd.topic_id)
   AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
   AND (fc.custom_topic IS NOT DISTINCT FROM fd.custom_topic)
  JOIN rank cr ON cr.v = fc.visibility
  GROUP BY fd.id, fd.visibility, dr.r
)
SELECT count(*) AS desynced_deck_count
FROM deck_actual
WHERE max_card_rank > deck_rank;

-- 4. Sample of the desynced decks (for sanity-checking before backfilling)
WITH rank AS (
  SELECT 'private'::text AS v, 0 AS r UNION ALL SELECT 'friends', 1 UNION ALL SELECT 'public', 2
),
deck_actual AS (
  SELECT
    fd.id AS deck_id,
    fd.user_id,
    fd.visibility AS deck_visibility,
    dr.r AS deck_rank,
    MAX(cr.r) AS max_card_rank,
    COUNT(*) AS card_count_matched
  FROM flashcard_decks fd
  JOIN rank dr ON dr.v = fd.visibility
  JOIN flashcards fc
    ON fc.user_id = fd.user_id
   AND (fc.subject_id IS NOT DISTINCT FROM fd.subject_id)
   AND (fc.topic_id IS NOT DISTINCT FROM fd.topic_id)
   AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
   AND (fc.custom_topic IS NOT DISTINCT FROM fd.custom_topic)
  JOIN rank cr ON cr.v = fc.visibility
  GROUP BY fd.id, fd.user_id, fd.visibility, dr.r
)
SELECT deck_id, user_id, deck_visibility, max_card_rank, card_count_matched
FROM deck_actual
WHERE max_card_rank > deck_rank
ORDER BY card_count_matched DESC
LIMIT 20;
