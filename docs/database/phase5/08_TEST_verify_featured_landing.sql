-- Name: [TEST] Verify Featured Landing Schema + RPC
-- Description: Verification for Sprint 2 featured-flag work. Confirms (1) the CHECK
-- constraint rejects is_featured_on_landing=true on a non-public row, (2) the auto-clear
-- trigger clears the flag when a featured row's visibility changes away from 'public', and
-- (3) get_featured_landing_content() returns the correct shape and caps at 5 cards per deck.
-- Run each numbered block separately and read its output before moving to the next. Blocks 2
-- and 4 wrap their writes in BEGIN/ROLLBACK — no test data is left committed. Block 1 is a
-- single statement that is expected to error (Postgres auto-rolls back a failed statement),
-- so nothing persists there either.

-- ============================================
-- 1. CHECK constraint rejects featured + non-public (backstop)
-- The BEFORE UPDATE auto-clear trigger (04) would otherwise coerce is_featured_on_landing
-- to false before the CHECK is ever evaluated, so we temporarily disable it to prove the
-- CHECK itself still guards the invariant (the scenario the CHECK exists for: trigger dropped
-- or a direct INSERT). Expected: ERROR — violates check constraint on flashcard_decks.
-- The failed statement aborts the transaction; ROLLBACK also restores the trigger.
-- ============================================
BEGIN;
ALTER TABLE flashcard_decks DISABLE TRIGGER trg_autoclear_featured_flashcard_decks;
UPDATE flashcard_decks
SET is_featured_on_landing = true
WHERE id = (SELECT id FROM flashcard_decks WHERE visibility <> 'public' LIMIT 1);
ROLLBACK;

-- ============================================
-- 2. Auto-clear trigger fires on visibility downgrade
-- Expected: final SELECT shows is_featured_on_landing = false
-- ============================================
BEGIN;

UPDATE flashcard_decks
SET is_featured_on_landing = true
WHERE id = (SELECT id FROM flashcard_decks WHERE visibility = 'public' LIMIT 1);

UPDATE flashcard_decks
SET visibility = 'private'
WHERE id = (SELECT id FROM flashcard_decks WHERE is_featured_on_landing = true LIMIT 1);

SELECT id, visibility, is_featured_on_landing
FROM flashcard_decks
WHERE is_featured_on_landing = true; -- Expected: 0 rows (trigger cleared the flag)

ROLLBACK;

-- ============================================
-- 3. Baseline RPC call (no featured content yet)
-- Expected: {"decks": [], "notes": []}
-- ============================================
SELECT get_featured_landing_content();

-- ============================================
-- 4. Feature one public deck (with >= 5 cards, to actually exercise the cap) + one
--    public note, then confirm shape and the 5-card cap
-- Expected: decks[0].cards has exactly 5 items (front_text/back_text/question_type only);
-- notes[0] has metadata + description only, no note body
-- ============================================
BEGIN;

UPDATE flashcard_decks
SET is_featured_on_landing = true
WHERE id = (
  SELECT id FROM flashcard_decks
  WHERE visibility = 'public' AND card_count >= 5
  ORDER BY card_count DESC
  LIMIT 1
);

UPDATE notes
SET is_featured_on_landing = true
WHERE id = (SELECT id FROM notes WHERE visibility = 'public' LIMIT 1);

SELECT get_featured_landing_content();

ROLLBACK;
