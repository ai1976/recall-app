-- Name: [TEST] Verify Landmine L1 Drops
-- Description: Post-drop sanity checks for 02/03/04/05_*.sql in this folder. Run each block
-- separately, in order, AFTER the corresponding drop has been deployed (skip blocks for drops
-- not yet deployed).
--
-- OUTPUT: each block returns its verdict as a RESULT ROW (a single `verdict` column), same
-- pattern as docs/database/phase5/12_TEST_verify_featured_nomination_curation.sql — the
-- Supabase SQL Editor does not surface RAISE NOTICE output.
--   'PASS ...'  = block passed
--   'FAIL: ...' = real problem — stop and report it
-- Blocks that exercise writes use BEGIN/ROLLBACK so nothing is left behind.

-- ============================================
-- 1. Dropped objects are gone (run after 02_CLEANUP + 03_CLEANUP) — Expected: PASS
-- ============================================
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM pg_proc
  WHERE pronamespace = 'public'::regnamespace
    AND proname = ANY (ARRAY[
      'trg_check_badge_flashcard_create', 'trg_check_badge_note_upload',
      'trg_check_badge_review', 'trg_check_badge_upvote',
      'notify_friend_request', 'notify_friend_accepted', 'notify_content_upvoted'
    ]);
  CREATE TEMP TABLE IF NOT EXISTS _r(verdict text);
  IF v_count = 0 THEN
    INSERT INTO _r VALUES ('PASS: all 7 dead trigger-functions are gone');
  ELSE
    INSERT INTO _r VALUES ('FAIL: ' || v_count || ' of the 7 target functions still exist');
  END IF;
END $$;
SELECT * FROM _r;
DROP TABLE IF EXISTS _r;

-- ============================================
-- 2. comments table is gone — Expected: PASS
-- ============================================
DO $$
BEGIN
  CREATE TEMP TABLE IF NOT EXISTS _r(verdict text);
  IF to_regclass('public.comments') IS NULL THEN
    INSERT INTO _r VALUES ('PASS: comments table no longer exists');
  ELSE
    INSERT INTO _r VALUES ('FAIL: comments table still exists');
  END IF;
END $$;
SELECT * FROM _r;
DROP TABLE IF EXISTS _r;

-- ============================================
-- 3. Legacy columns are gone (notes.course/subject/topic, upvotes.note_id) — Expected: PASS
-- ============================================
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema = 'public'
    AND (
      (table_name = 'notes' AND column_name IN ('course', 'subject', 'topic'))
      OR (table_name = 'upvotes' AND column_name = 'note_id')
    );
  CREATE TEMP TABLE IF NOT EXISTS _r(verdict text);
  IF v_count = 0 THEN
    INSERT INTO _r VALUES ('PASS: notes.course/subject/topic and upvotes.note_id are gone');
  ELSE
    INSERT INTO _r VALUES ('FAIL: ' || v_count || ' of the 4 target columns still exist');
  END IF;
END $$;
SELECT * FROM _r;
DROP TABLE IF EXISTS _r;

-- ============================================
-- 4. flashcards SRS columns are gone (only after frontend deployed+verified, then 05_SCHEMA
--    run) — Expected: PASS
-- ============================================
DO $$
DECLARE v_count int;
BEGIN
  SELECT count(*) INTO v_count FROM information_schema.columns
  WHERE table_schema = 'public' AND table_name = 'flashcards'
    AND column_name IN ('next_review', 'interval', 'ease_factor', 'repetitions');
  CREATE TEMP TABLE IF NOT EXISTS _r(verdict text);
  IF v_count = 0 THEN
    INSERT INTO _r VALUES ('PASS: flashcards SRS columns are gone');
  ELSE
    INSERT INTO _r VALUES ('FAIL: ' || v_count || ' of the 4 SRS columns still exist');
  END IF;
END $$;
SELECT * FROM _r;
DROP TABLE IF EXISTS _r;

-- ============================================
-- 5. A flashcard insert still succeeds after the SRS-column drop (exercises the exact shape
--    the post-change FlashcardCreate.jsx sends) — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_user_id uuid; v_id uuid;
BEGIN
  SELECT id INTO v_user_id FROM profiles LIMIT 1;
  IF v_user_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no profile fixture available'); RETURN;
  END IF;
  BEGIN
    INSERT INTO flashcards (
      user_id, contributed_by, creator_id, target_course, front_text, back_text,
      visibility, is_public, is_verified, difficulty, batch_id
    ) VALUES (
      v_user_id, v_user_id, v_user_id, 'test_course', 'test front', 'test back',
      'private', false, false, 'medium', gen_random_uuid()
    ) RETURNING id INTO v_id;
    INSERT INTO _r VALUES ('PASS: flashcard insert succeeded without SRS columns, id=' || v_id);
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('FAIL: insert errored — ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 6. Badge triggers still fire on flashcard insert (trg_badge_flashcard_create /
--    fn_badge_check_* family — NOT the dropped trg_check_badge_* dead code) — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_user_id uuid; v_before int; v_after int;
BEGIN
  SELECT id INTO v_user_id FROM profiles LIMIT 1;
  IF v_user_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no profile fixture available'); RETURN;
  END IF;
  SELECT total_flashcards INTO v_before FROM user_stats WHERE user_id = v_user_id;
  INSERT INTO flashcards (
    user_id, contributed_by, creator_id, target_course, front_text, back_text,
    visibility, is_public, is_verified, difficulty, batch_id
  ) VALUES (
    v_user_id, v_user_id, v_user_id, 'test_course', 'test front 2', 'test back 2',
    'private', false, false, 'medium', gen_random_uuid()
  );
  SELECT total_flashcards INTO v_after FROM user_stats WHERE user_id = v_user_id;
  IF v_after = coalesce(v_before, 0) + 1 THEN
    INSERT INTO _r VALUES ('PASS: user_stats.total_flashcards incremented — badge/counter triggers still fire');
  ELSE
    INSERT INTO _r VALUES ('FAIL: counter did not increment (before=' || v_before || ', after=' || v_after || ')');
  END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 7. notes and upvotes are still readable (no drop broke a SELECT *) — Expected: PASS
-- ============================================
DO $$
DECLARE v_notes int; v_upvotes int;
BEGIN
  SELECT count(*) INTO v_notes FROM notes;
  SELECT count(*) INTO v_upvotes FROM upvotes;
  CREATE TEMP TABLE IF NOT EXISTS _r(verdict text);
  INSERT INTO _r VALUES ('PASS: notes (' || v_notes || ' rows) and upvotes (' || v_upvotes || ' rows) still readable');
END $$;
SELECT * FROM _r;
DROP TABLE IF EXISTS _r;
