-- Name: [DIAGNOSTIC] Deck-listing + activity-feed per-viewer visibility (bugfix follow-up)
-- Description: The get_public_deck_preview fix (02_FUNCTIONS) closed the PUBLIC teaser leak, but the
-- founder's actual surface is the authenticated dashboard: (1) Review Flashcards deck grid
-- (get_browsable_decks) still lists a public deck whose only card is now private, with an inflated
-- card_count; (2) dashboard Recent Activity (get_recent_activity_feed) still shows the creation
-- event. Both leak metadata (existence/name/author/count) though the card CONTENT is correctly
-- hidden. This dumps the function bodies we need and quantifies the specific deck. Read-only.

-- ============================================
-- 1. get_recent_activity_feed body — not in the repo. Need to see what table it reads and whether
--    it re-checks current content visibility per viewer.
-- ============================================
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'get_recent_activity_feed' AND pronamespace = 'public'::regnamespace;

-- ============================================
-- 2. get_browsable_notes body — the notes twin of get_browsable_decks; check it has the same
--    deck-level-only gate so we fix both consistently.
-- ============================================
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'get_browsable_notes' AND pronamespace = 'public'::regnamespace;

-- ============================================
-- 3. The specific deck from the report (1e521de5…): its deck-level visibility + stored card_count
--    vs the actual per-visibility card breakdown (grouping-column join). Confirms "public deck,
--    stored count 1, 0 public cards".
-- ============================================
SELECT
  fd.id, fd.name, fd.visibility AS deck_visibility, fd.card_count AS stored_count,
  count(fc.*)                                          AS grouped_total,
  count(fc.*) FILTER (WHERE fc.visibility = 'public')  AS public_cards,
  count(fc.*) FILTER (WHERE fc.visibility = 'friends') AS friends_cards,
  count(fc.*) FILTER (WHERE fc.visibility = 'private') AS private_cards
FROM flashcard_decks fd
LEFT JOIN flashcards fc ON
      fc.user_id = fd.user_id
  AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
  AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
  AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
  AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
WHERE fd.id = '1e521de5-473b-4bec-9f9e-c0d40834e7f2'
GROUP BY fd.id, fd.name, fd.visibility, fd.card_count;

-- ============================================
-- 4. What does the activity feed read from? List candidate source tables/columns so we know where
--    the per-viewer visibility filter must go.
-- ============================================
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('user_activity_log', 'activity_log', 'user_activity');
