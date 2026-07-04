-- Name: [DIAGNOSTIC] Public deck preview leaks non-public cards
-- Description: Confirms the visibility leak in get_public_deck_preview before fixing it.
-- The DeckPreview public page (/deck/:id -> src/pages/public/DeckPreview.jsx) calls this
-- SECURITY DEFINER RPC, which bypasses RLS. It gates the DECK on visibility='public' but its
-- inner preview_items subquery selects the first 5 cards by created_at with NO per-card
-- visibility filter -> a private or friends-only card inside a public deck leaks its front_text
-- to anyone, including anonymous visitors. Reported 04/07/2026 (founder saw a card still visible
-- to a professor after the creator set it to private).
--
-- Read-only. Run all three blocks; paste the output back before deploying 02_FUNCTIONS.

-- ============================================
-- 1. Dump the LIVE function body — confirm it matches the repo copy
--    (docs/database/phase5/07_FUNCTIONS_cap_public_deck_preview_at_5.sql) and that the
--    preview_items subquery has no `fc.visibility` predicate.
-- ============================================
SELECT pg_get_functiondef(oid)
FROM pg_proc
WHERE proname = 'get_public_deck_preview'
  AND pronamespace = 'public'::regnamespace;

-- ============================================
-- 2. Prove the leak with live data: for every PUBLIC deck, count how many of its grouped cards
--    are NOT public. Any row with non_public_cards > 0 is a deck whose preview can leak.
--    (Grouped by the same 5 columns the RPC + trigger use — never fc.deck_id, which is unpopulated.)
-- ============================================
SELECT
  fd.id                         AS deck_id,
  fd.name                       AS deck_name,
  fd.card_count                 AS stored_card_count,
  count(fc.*)                   AS grouped_cards_total,
  count(fc.*) FILTER (WHERE fc.visibility = 'public')  AS public_cards,
  count(fc.*) FILTER (WHERE fc.visibility <> 'public') AS non_public_cards
FROM flashcard_decks fd
JOIN flashcards fc ON
      fc.user_id = fd.user_id
  AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
  AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
  AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
  AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
WHERE fd.visibility = 'public'
GROUP BY fd.id, fd.name, fd.card_count
HAVING count(fc.*) FILTER (WHERE fc.visibility <> 'public') > 0
ORDER BY non_public_cards DESC;

-- ============================================
-- 3. Confirm no OTHER function returns individual card content for a deck without a visibility
--    filter (defensive — we expect only get_public_deck_preview). get_browsable_decks returns
--    DECK-level rows (card_count only, no card text), so it does not leak content — but list it
--    to confirm its shape.
-- ============================================
SELECT proname, pg_get_function_result(oid) AS returns
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname IN ('get_public_deck_preview', 'get_browsable_decks')
ORDER BY proname;
