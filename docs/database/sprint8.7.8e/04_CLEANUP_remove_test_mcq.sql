-- Name: [CLEANUP] Remove 8.7.8e disposable live-verification MCQ card
--
-- Description: Removes the one real (not rolled-back) test card created
-- through the app UI to visually confirm 8.7.8e's fix in the actual Review
-- flow, plus its reviews row and provenance row. Run after confirming the
-- card is no longer needed.
--
-- Order matters: reviews and flashcard_batch_provenance both reference
-- flashcards (batch_id / flashcard_id), so delete them before the flashcards
-- row itself. Identifies everything by the same unique front_text prefix
-- used to create/find it — no hardcoded ids.
--
-- No flashcard_decks cleanup needed: this test card was added to the
-- professor's REAL, pre-existing Quality Control deck (16 real cards before
-- this test, confirmed live via Browse Study Sets before creating it), not a
-- newly auto-created deck — trigger_update_deck_card_count will correctly
-- decrement it back to 16 on the flashcards delete below. Deliberately not
-- running any broad "delete empty decks" cleanup here — that could touch
-- unrelated real empty decks elsewhere in the database with no connection to
-- this test, an unbounded blast radius this sprint has no business taking.

DELETE FROM public.reviews
WHERE flashcard_id IN (
  SELECT id FROM public.flashcards WHERE front_text LIKE '[8.7.8e TEST]%'
);

DELETE FROM public.flashcard_batch_provenance
WHERE batch_id IN (
  SELECT batch_id FROM public.flashcards WHERE front_text LIKE '[8.7.8e TEST]%'
);

DELETE FROM public.flashcards
WHERE front_text LIKE '[8.7.8e TEST]%';

-- Verify: all should return 0 rows / 0 count.
SELECT count(*) AS remaining_flashcards FROM public.flashcards WHERE front_text LIKE '[8.7.8e TEST]%';
SELECT count(*) AS remaining_reviews FROM public.reviews r
  WHERE NOT EXISTS (SELECT 1 FROM public.flashcards f WHERE f.id = r.flashcard_id);
