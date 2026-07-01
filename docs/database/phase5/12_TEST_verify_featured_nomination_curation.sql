-- Name: [TEST] Verify Featured Nomination & Approval RPCs
-- Description: Verifies the Sprint 3 curation gate: role gates on nominate/approve (student
-- blocked, professor cannot approve), the public-only nomination guard, the approve→live
-- transition, that approving content that went non-public mid-flight never sets the flag, that
-- unpublishing a live-featured row resets all four nomination/approval fields (10_SCHEMA), and
-- that unfeature_content is a FULL removal (nulls all four fields, leaving both landing + queue).
--
-- OUTPUT: each block returns its verdict as a RESULT ROW in the grid (a single `verdict` column),
-- because the Supabase SQL Editor does not surface RAISE NOTICE output. Read the returned row:
--   'PASS ...'  = block passed
--   'FAIL: ...' = real problem — stop and report it
--   'SKIP: ...' = the picked professor/admin fixture lacked the right data shape (e.g. no public
--                 deck); not a failure — re-run against a different course/professor to exercise it.
--
-- Caller identity is simulated via set_config('request.jwt.claim.sub', ...), which auth.uid()
-- reads. Each block is its own BEGIN/ROLLBACK — writes AND the temp verdict table are rolled back;
-- the SELECT returns the verdict to the grid before ROLLBACK discards the data. Run each block
-- separately.

-- ============================================
-- 1. Student cannot nominate (role gate) — Expected: PASS (expected error): Access denied
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_student_id uuid; v_deck_id uuid;
BEGIN
  SELECT id INTO v_student_id FROM profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_deck_id   FROM flashcard_decks WHERE visibility = 'public' LIMIT 1;
  IF v_student_id IS NULL OR v_deck_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no student or public-deck fixture'); RETURN;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_student_id::text, true);
  BEGIN
    PERFORM nominate_featured_content('deck', v_deck_id);
    INSERT INTO _r VALUES ('FAIL: student nomination should have been denied');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('PASS (expected error): ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 2. Professor CAN nominate own public deck; nomination fields set — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_prof_id uuid; v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;
  IF v_deck_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: selected professor owns no public deck'); RETURN;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
  PERFORM nominate_featured_content('deck', v_deck_id);
  PERFORM 1 FROM flashcard_decks
  WHERE id = v_deck_id AND featured_nominated_by = v_prof_id AND featured_nominated_at IS NOT NULL;
  IF FOUND THEN INSERT INTO _r VALUES ('PASS: nomination fields set correctly');
  ELSE           INSERT INTO _r VALUES ('FAIL: nomination fields not set'); END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 3. Professor CANNOT approve (role gate on approve) — Expected: PASS (expected error): Access denied
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_prof_id uuid; v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE visibility = 'public' LIMIT 1;
  IF v_prof_id IS NULL OR v_deck_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: no professor or public-deck fixture'); RETURN;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
  BEGIN
    PERFORM approve_featured_nomination('deck', v_deck_id);
    INSERT INTO _r VALUES ('FAIL: professor approval should have been denied');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('PASS (expected error): ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 4. Nominating a non-public deck is rejected (public-only guard)
-- Expected: PASS (expected error): Content must be public to nominate for featuring
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_prof_id uuid; v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE user_id = v_prof_id AND visibility <> 'public' LIMIT 1;
  IF v_deck_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: selected professor owns no non-public deck'); RETURN;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
  BEGIN
    PERFORM nominate_featured_content('deck', v_deck_id);
    INSERT INTO _r VALUES ('FAIL: non-public nomination should have been rejected');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('PASS (expected error): ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 5. Full approve → live transition, via the RPC's return value — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_prof_id uuid; v_admin_id uuid; v_deck_id uuid; v_result boolean;
BEGIN
  SELECT id INTO v_prof_id  FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_deck_id  FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;
  IF v_deck_id IS NULL OR v_admin_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: missing professor public deck or admin fixture'); RETURN;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
  PERFORM nominate_featured_content('deck', v_deck_id);
  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  SELECT approve_featured_nomination('deck', v_deck_id) INTO v_result;
  IF v_result THEN INSERT INTO _r VALUES ('PASS: approve returned true, deck is live');
  ELSE            INSERT INTO _r VALUES ('FAIL: approve returned false/null'); END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 6. Approving content that went non-public mid-flight does NOT set the flag
-- Expected: PASS (expected error) — 'No pending nomination found' (trigger already cleared it)
-- or 'Content is no longer public'; both prove the flag was never set.
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_prof_id uuid; v_admin_id uuid; v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id  FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_deck_id  FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;
  IF v_deck_id IS NULL OR v_admin_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: missing professor public deck or admin fixture'); RETURN;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
  PERFORM nominate_featured_content('deck', v_deck_id);
  UPDATE flashcard_decks SET visibility = 'private' WHERE id = v_deck_id;
  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  BEGIN
    PERFORM approve_featured_nomination('deck', v_deck_id);
    INSERT INTO _r VALUES ('FAIL: approval on non-public content should have errored');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO _r VALUES ('PASS (expected error): ' || SQLERRM);
  END;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 7. Unpublishing a LIVE featured deck resets all four fields (10_SCHEMA trigger) — Expected: PASS
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_prof_id uuid; v_admin_id uuid; v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id  FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_deck_id  FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;
  IF v_deck_id IS NULL OR v_admin_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: missing professor public deck or admin fixture'); RETURN;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
  PERFORM nominate_featured_content('deck', v_deck_id);
  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  PERFORM approve_featured_nomination('deck', v_deck_id);
  UPDATE flashcard_decks SET visibility = 'private' WHERE id = v_deck_id;
  PERFORM 1 FROM flashcard_decks
  WHERE id = v_deck_id
    AND is_featured_on_landing = false
    AND featured_nominated_by IS NULL AND featured_nominated_at IS NULL
    AND featured_approved_by IS NULL AND featured_approved_at IS NULL;
  IF FOUND THEN INSERT INTO _r VALUES ('PASS: all four fields reset on unpublish');
  ELSE           INSERT INTO _r VALUES ('FAIL: fields not fully reset'); END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;

-- ============================================
-- 8. unfeature_content is a full removal — nulls all four fields (leaves BOTH landing + queue)
-- Expected: PASS: is_featured_on_landing false and all four nomination/approval fields null
-- ============================================
BEGIN;
CREATE TEMP TABLE _r(verdict text);
DO $$
DECLARE v_prof_id uuid; v_admin_id uuid; v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id  FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_deck_id  FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;
  IF v_deck_id IS NULL OR v_admin_id IS NULL THEN
    INSERT INTO _r VALUES ('SKIP: missing professor public deck or admin fixture'); RETURN;
  END IF;
  PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
  PERFORM nominate_featured_content('deck', v_deck_id);
  PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
  PERFORM approve_featured_nomination('deck', v_deck_id);
  PERFORM unfeature_content('deck', v_deck_id);
  PERFORM 1 FROM flashcard_decks
  WHERE id = v_deck_id
    AND is_featured_on_landing = false
    AND featured_nominated_by IS NULL AND featured_nominated_at IS NULL
    AND featured_approved_by IS NULL AND featured_approved_at IS NULL;
  IF FOUND THEN INSERT INTO _r VALUES ('PASS: all four fields cleared after unfeature (full removal)');
  ELSE           INSERT INTO _r VALUES ('FAIL: unexpected field state after unfeature'); END IF;
END $$;
SELECT * FROM _r;
ROLLBACK;
