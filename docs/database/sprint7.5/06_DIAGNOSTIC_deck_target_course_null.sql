-- Name: [DIAGNOSTIC] flashcard_decks.target_course NULL — blast radius + confirm the omission
--
-- Description: Follow-up to the visibility-desync fix (04/05). Reading update_deck_card_count()'s
-- live body (00_DIAGNOSTIC query 1 from this same sprint) showed its auto-create-deck branch
-- (fires when a flashcard's INSERT finds no matching existing deck row) inserts
-- (user_id, subject_id, topic_id, custom_subject, custom_topic, visibility, card_count) —
-- target_course is NOT in that column list. bugs.md's "[Mar 2, 2026] CA Foundation Flashcards
-- Invisible" entry describes the historical fix as setting target_course too, which does not match
-- what's actually live. This checks whether that gap has ever produced a NULL-target_course deck,
-- and whether get_recent_activity_feed / get_browsable_decks (both filter on fd.target_course)
-- would silently exclude it regardless of visibility. Read-only throughout.

-- 1. Blast radius: any flashcard_decks rows with target_course IS NULL at all?
SELECT count(*) AS null_target_course_decks FROM flashcard_decks WHERE target_course IS NULL;

-- 2. If any exist: how many actually contain content, and what visibility (matters for OTHER
--    users, not just the owner's own view — a private deck being invisible to others is normal).
SELECT
  visibility,
  count(*) AS deck_count,
  count(*) FILTER (WHERE card_count > 0) AS decks_with_cards,
  sum(card_count) AS total_cards_affected
FROM flashcard_decks
WHERE target_course IS NULL
GROUP BY visibility
ORDER BY total_cards_affected DESC NULLS LAST;

-- 3. Sample rows (id, owner, subject/topic, card_count) for sanity-checking before any fix.
SELECT id, user_id, subject_id, topic_id, custom_subject, custom_topic, visibility, card_count, created_at
FROM flashcard_decks
WHERE target_course IS NULL
ORDER BY card_count DESC
LIMIT 20;

-- 4. Confirm get_browsable_decks also filters on fd.target_course (same failure mode as
--    get_recent_activity_feed, already confirmed filtering `fd.target_course = p_course_level`
--    during the visibility-desync investigation).
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'get_browsable_decks' AND pronamespace = 'public'::regnamespace;

-- 5. Re-confirm the live trigger body (in case it's changed since 04_FUNCTIONS was deployed) —
--    should show the visibility-widen fix from 04 already in place, and target_course still
--    absent from the auto-create INSERT's column list.
SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'update_deck_card_count' AND pronamespace = 'public'::regnamespace;
