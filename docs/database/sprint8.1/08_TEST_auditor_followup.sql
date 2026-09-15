-- Name: [TEST] Sprint 8.1 quality-auditor follow-up — snapshot atomicity + frozen report
-- Description: Closes two verification gaps flagged by quality-auditor review of the
-- Sprint 8.1 completion report:
--   1. If snapshot capture fails mid-archive, the batch must stay active and no
--      requests/invitations get closed — no partial state.
--   2. Real student review activity recorded AFTER archiving must not change the
--      already-saved report, while the live (non-archived) reporting path is
--      unaffected by archiving at all.
-- Runs inside BEGIN...ROLLBACK (same idiom as 04_TEST). Part 1 creates a
-- transaction-scoped fault-injection trigger (a pg_temp function + a trigger on
-- batch_group_archives) purely to force the failure — invisible to any other
-- session (DDL isn't visible outside its own transaction until commit) and fully
-- undone by ROLLBACK regardless, though it's also explicitly dropped mid-script
-- since Part 2 needs a real, working archive call. Part 2 inserts real rows into
-- reviews (not a proxy) — flashcards the target student has never reviewed, so
-- there's no risk of colliding with the UNIQUE(user_id, flashcard_id) constraint
-- on real data. Not covered here: genuine concurrent-session locking (needs two
-- independent database connections; see 05_TEST_concurrency_manual.sql and its
-- status notes — not completed, tooling constraints, not a code gap). Run in
-- Supabase SQL Editor and report the _r table back.

BEGIN;
CREATE TEMP TABLE _r(check_name text, expected text, actual text, verdict text);

DO $$
DECLARE
  v_admin      uuid;
  v_student    uuid;
  v_group      uuid;
  v_flashcard1 uuid;
  v_flashcard2 uuid;
  v_err        text;
  v_archived_at timestamptz;
  v_status     text;
  v_count      int;
  v_reviews_frozen int;
  v_reviews_live   int;
BEGIN
  SELECT id INTO v_admin FROM profiles WHERE role IN ('admin','super_admin') LIMIT 1;
  SELECT id INTO v_student FROM profiles WHERE role = 'student' LIMIT 1;

  IF v_admin IS NULL OR v_student IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', 'admin + student', 'missing', 'SKIP: insufficient profile fixtures');
    RETURN;
  END IF;

  -- Two flashcards this specific student has never reviewed, so the inserts
  -- below can never collide with reviews_user_flashcard_unique on real data.
  SELECT f.id INTO v_flashcard1 FROM flashcards f
    WHERE NOT EXISTS (SELECT 1 FROM reviews r WHERE r.user_id = v_student AND r.flashcard_id = f.id)
    LIMIT 1;
  SELECT f.id INTO v_flashcard2 FROM flashcards f
    WHERE f.id <> v_flashcard1
      AND NOT EXISTS (SELECT 1 FROM reviews r WHERE r.user_id = v_student AND r.flashcard_id = f.id)
    LIMIT 1;

  IF v_flashcard1 IS NULL OR v_flashcard2 IS NULL THEN
    INSERT INTO _r VALUES ('fixtures', '2 unreviewed flashcards for the test student', 'missing', 'SKIP: student has reviewed every card, or <2 flashcards exist');
    RETURN;
  END IF;

  INSERT INTO study_groups (name, description, is_batch_group, group_type, batch_course, batch_institution, created_by, invite_token)
  VALUES ('Sprint8.1 Auditor Followup Test', 'temp', true, 'batch', 'ZZ Test Course', 'ZZ Test Institution', v_admin, gen_random_uuid())
  RETURNING id INTO v_group;

  INSERT INTO study_group_members (group_id, user_id, role, status) VALUES (v_group, v_student, 'member', 'active');

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);

  -- ============================================================
  -- Part 1: snapshot-capture failure leaves no partial state
  -- ============================================================
  CREATE FUNCTION pg_temp._force_snapshot_failure() RETURNS trigger AS $trig$
  BEGIN
    RAISE EXCEPTION 'INTENTIONAL TEST FAILURE - snapshot insert blocked';
  END;
  $trig$ LANGUAGE plpgsql;

  CREATE TRIGGER _trg_force_snapshot_failure
    BEFORE INSERT ON batch_group_archives
    FOR EACH ROW EXECUTE FUNCTION pg_temp._force_snapshot_failure();

  BEGIN
    PERFORM public.archive_batch_group(v_group);
    INSERT INTO _r VALUES ('snapshot failure: archive_batch_group raises [CRITICAL]', 'INTENTIONAL TEST FAILURE', 'no error', 'FAIL');
  EXCEPTION WHEN OTHERS THEN
    v_err := SQLERRM;
    INSERT INTO _r VALUES ('snapshot failure: archive_batch_group raises [CRITICAL]', 'INTENTIONAL TEST FAILURE', left(v_err,50),
      CASE WHEN v_err ILIKE '%INTENTIONAL TEST FAILURE%' THEN 'PASS' ELSE 'FAIL: '||v_err END);
  END;

  -- Drop the fault-injection trigger now — Part 2 needs a real, successful archive.
  DROP TRIGGER _trg_force_snapshot_failure ON batch_group_archives;

  SELECT archived_at INTO v_archived_at FROM study_groups WHERE id = v_group;
  INSERT INTO _r VALUES ('snapshot failure: batch stays active (archived_at still null) [CRITICAL]', 'null', COALESCE(v_archived_at::text,'null'),
    CASE WHEN v_archived_at IS NULL THEN 'PASS' ELSE 'FAIL' END);

  SELECT status INTO v_status FROM study_group_members WHERE group_id = v_group AND user_id = v_student;
  INSERT INTO _r VALUES ('snapshot failure: existing membership untouched [CRITICAL]', 'active', v_status,
    CASE WHEN v_status = 'active' THEN 'PASS' ELSE 'FAIL' END);

  SELECT COUNT(*) INTO v_count FROM batch_group_archives WHERE group_id = v_group;
  INSERT INTO _r VALUES ('snapshot failure: no orphaned snapshot row [CRITICAL]', '0', v_count::text,
    CASE WHEN v_count = 0 THEN 'PASS' ELSE 'FAIL' END);

  -- ============================================================
  -- Part 2: real student activity after archiving leaves the frozen report unchanged
  -- ============================================================
  INSERT INTO reviews (user_id, flashcard_id, quality, created_at) VALUES (v_student, v_flashcard1, 5, NOW());

  PERFORM public.archive_batch_group(v_group);

  SELECT (report->'members'->0->>'reviews_this_week')::int INTO v_reviews_frozen
  FROM batch_group_archives WHERE group_id = v_group;
  INSERT INTO _r VALUES ('frozen report captures the pre-archive review [CRITICAL]', '1', COALESCE(v_reviews_frozen::text,'null'),
    CASE WHEN v_reviews_frozen = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- Real NEW activity, recorded strictly AFTER archiving.
  INSERT INTO reviews (user_id, flashcard_id, quality, created_at) VALUES (v_student, v_flashcard2, 5, NOW());

  SELECT (public.get_batch_group_archive(v_group)->'report'->'members'->0->>'reviews_this_week')::int INTO v_reviews_frozen;
  INSERT INTO _r VALUES ('frozen report UNCHANGED by post-archive review [CRITICAL]', '1 (still)', v_reviews_frozen::text,
    CASE WHEN v_reviews_frozen = 1 THEN 'PASS' ELSE 'FAIL' END);

  -- Proves this was a real before/after difference, not a trivial always-zero
  -- scenario: the live report path (which archiving does not gate) DOES see
  -- both reviews.
  SELECT reviews_this_week INTO v_reviews_live
  FROM public.get_batch_group_member_stats(v_group) WHERE user_id = v_student;
  INSERT INTO _r VALUES ('live report reflects both reviews (proves the test is non-trivial)', '2', v_reviews_live::text,
    CASE WHEN v_reviews_live = 2 THEN 'PASS' ELSE 'FAIL' END);

  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT * FROM _r ORDER BY verdict LIKE 'FAIL%' DESC, verdict LIKE 'SKIP%' DESC, check_name;
ROLLBACK;
