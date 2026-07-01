-- Name: [TEST] Verify Featured Nomination & Approval RPCs
-- Description: Verifies the Sprint 3 curation gate: role gates on nominate/approve (student
-- blocked, professor cannot approve), the public-only nomination guard, the approve→live
-- transition via the RPC's own return value, that approving a nomination whose content went
-- non-public mid-flight never sets the flag, and that unpublishing a live-featured row resets
-- all four nomination/approval fields via the updated fn_autoclear_featured_on_visibility_change
-- (10_SCHEMA). Caller identity is simulated via Supabase's standard `request.jwt.claim.sub`
-- local setting, which auth.uid() reads — this only works in a session without a real JWT
-- already set (e.g. the Supabase SQL Editor running as postgres). Every block wraps its writes
-- in BEGIN/ROLLBACK; no test data is left committed. Run each block separately and read its
-- NOTICE output. Blocks marked SKIP mean the picked professor/admin fixture didn't have the
-- right shape of data (e.g. no public deck) — re-run against a different course/professor if
-- you want to exercise that block.

-- ============================================
-- 1. Student cannot nominate (role gate)
-- Expected: PASS (expected error): Access denied
-- ============================================
BEGIN;
DO $$
DECLARE
  v_student_id uuid;
  v_deck_id    uuid;
BEGIN
  SELECT id INTO v_student_id FROM profiles WHERE role = 'student' LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE visibility = 'public' LIMIT 1;

  PERFORM set_config('request.jwt.claim.sub', v_student_id::text, true);
  PERFORM nominate_featured_content('deck', v_deck_id);
  RAISE NOTICE 'FAIL: student nomination should have raised Access denied';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'PASS (expected error): %', SQLERRM;
END $$;
ROLLBACK;

-- ============================================
-- 2. Professor CAN nominate own public deck; nomination fields are set
-- Expected: PASS: nomination fields set correctly
-- ============================================
BEGIN;
DO $$
DECLARE
  v_prof_id uuid;
  v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;

  IF v_deck_id IS NULL THEN
    RAISE NOTICE 'SKIP: selected professor owns no public deck';
  ELSE
    PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
    PERFORM nominate_featured_content('deck', v_deck_id);

    PERFORM 1 FROM flashcard_decks
    WHERE id = v_deck_id AND featured_nominated_by = v_prof_id AND featured_nominated_at IS NOT NULL;

    IF FOUND THEN
      RAISE NOTICE 'PASS: nomination fields set correctly';
    ELSE
      RAISE NOTICE 'FAIL: nomination fields not set';
    END IF;
  END IF;
END $$;
ROLLBACK;

-- ============================================
-- 3. Professor CANNOT approve (role gate on approve — nominate != approve permission)
-- Expected: PASS (expected error): Access denied
-- ============================================
BEGIN;
DO $$
DECLARE
  v_prof_id uuid;
  v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE visibility = 'public' LIMIT 1;

  PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
  PERFORM approve_featured_nomination('deck', v_deck_id);
  RAISE NOTICE 'FAIL: professor approval should have raised Access denied';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'PASS (expected error): %', SQLERRM;
END $$;
ROLLBACK;

-- ============================================
-- 4. Nominating a non-public deck is rejected (public-only guard)
-- Expected: PASS (expected error): Content must be public to nominate for featuring
-- ============================================
BEGIN;
DO $$
DECLARE
  v_prof_id uuid;
  v_deck_id uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE user_id = v_prof_id AND visibility <> 'public' LIMIT 1;

  IF v_deck_id IS NULL THEN
    RAISE NOTICE 'SKIP: selected professor owns no non-public deck to test against';
  ELSE
    PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
    PERFORM nominate_featured_content('deck', v_deck_id);
    RAISE NOTICE 'FAIL: non-public nomination should have raised an error';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'PASS (expected error): %', SQLERRM;
END $$;
ROLLBACK;

-- ============================================
-- 5. Full approve → live transition, verified via the RPC's own return value
-- Expected: PASS: approve returned true, deck is live
-- ============================================
BEGIN;
DO $$
DECLARE
  v_prof_id  uuid;
  v_admin_id uuid;
  v_deck_id  uuid;
  v_result   boolean;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;

  IF v_deck_id IS NULL THEN
    RAISE NOTICE 'SKIP: selected professor owns no public deck';
  ELSE
    PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
    PERFORM nominate_featured_content('deck', v_deck_id);

    PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
    SELECT approve_featured_nomination('deck', v_deck_id) INTO v_result;

    IF v_result THEN
      RAISE NOTICE 'PASS: approve returned true, deck is live';
    ELSE
      RAISE NOTICE 'FAIL: approve returned false/null';
    END IF;
  END IF;
END $$;
ROLLBACK;

-- ============================================
-- 6. Approving a nomination whose content went non-public mid-flight does NOT set the flag
-- Expected: PASS (expected error) — either "No pending nomination found" (nomination fields
-- were already auto-cleared by the trigger the instant visibility changed) or "Content is no
-- longer public" is an acceptable pass; both prove the flag was never set.
-- ============================================
BEGIN;
DO $$
DECLARE
  v_prof_id  uuid;
  v_admin_id uuid;
  v_deck_id  uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;

  IF v_deck_id IS NULL THEN
    RAISE NOTICE 'SKIP: selected professor owns no public deck';
  ELSE
    PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
    PERFORM nominate_featured_content('deck', v_deck_id);

    UPDATE flashcard_decks SET visibility = 'private' WHERE id = v_deck_id;

    PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
    PERFORM approve_featured_nomination('deck', v_deck_id);
    RAISE NOTICE 'FAIL: approval on non-public content should have raised an error';
  END IF;
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'PASS (expected error): %', SQLERRM;
END $$;
ROLLBACK;

-- ============================================
-- 7. Unpublishing a LIVE featured deck resets all four nomination/approval fields (10_SCHEMA)
-- Expected: PASS: all four fields reset on unpublish
-- ============================================
BEGIN;
DO $$
DECLARE
  v_prof_id  uuid;
  v_admin_id uuid;
  v_deck_id  uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;

  IF v_deck_id IS NULL THEN
    RAISE NOTICE 'SKIP: selected professor owns no public deck';
  ELSE
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

    IF FOUND THEN
      RAISE NOTICE 'PASS: all four fields reset on unpublish';
    ELSE
      RAISE NOTICE 'FAIL: fields not fully reset';
    END IF;
  END IF;
END $$;
ROLLBACK;

-- ============================================
-- 8. unfeature_content leaves nomination fields intact (re-enters Pending queue by design)
-- Expected: PASS: nomination fields intact, is_featured_on_landing false, approval fields null
-- ============================================
BEGIN;
DO $$
DECLARE
  v_prof_id  uuid;
  v_admin_id uuid;
  v_deck_id  uuid;
BEGIN
  SELECT id INTO v_prof_id FROM profiles WHERE role = 'professor' LIMIT 1;
  SELECT id INTO v_admin_id FROM profiles WHERE role IN ('admin', 'super_admin') LIMIT 1;
  SELECT id INTO v_deck_id FROM flashcard_decks WHERE user_id = v_prof_id AND visibility = 'public' LIMIT 1;

  IF v_deck_id IS NULL THEN
    RAISE NOTICE 'SKIP: selected professor owns no public deck';
  ELSE
    PERFORM set_config('request.jwt.claim.sub', v_prof_id::text, true);
    PERFORM nominate_featured_content('deck', v_deck_id);

    PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);
    PERFORM approve_featured_nomination('deck', v_deck_id);
    PERFORM unfeature_content('deck', v_deck_id);

    PERFORM 1 FROM flashcard_decks
    WHERE id = v_deck_id
      AND is_featured_on_landing = false
      AND featured_nominated_by IS NOT NULL AND featured_nominated_at IS NOT NULL
      AND featured_approved_by IS NULL AND featured_approved_at IS NULL;

    IF FOUND THEN
      RAISE NOTICE 'PASS: nomination fields intact after unfeature, approval fields cleared';
    ELSE
      RAISE NOTICE 'FAIL: unexpected field state after unfeature';
    END IF;
  END IF;
END $$;
ROLLBACK;
