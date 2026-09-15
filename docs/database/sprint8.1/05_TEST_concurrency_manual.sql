-- Name: [TEST] Sprint 8.1 concurrent archive-vs-enrollment race (manual, two tabs)
-- Description: Verifies the row-lock convention actually serializes a
-- concurrent archive_batch_group against an enrollment action, in both
-- orderings, with no partial outcome. This cannot run inside a single
-- BEGIN...ROLLBACK transaction (04_TEST) because it needs two sessions
-- holding locks against each other at the same time — run this manually
-- across two Supabase SQL Editor tabs. Each tab keeps its own transaction
-- open (do not let the editor auto-commit between steps — run each
-- numbered block as its own statement, in order, waiting for the note
-- before moving to the next).
--
-- No IDs need to be copied between blocks — every statement below resolves
-- the fixture group/admin/student itself by name/role via subquery, so you
-- can paste each block as-is into whichever tab it's marked for.

-- ============================================================================
-- Setup — run this at the START of every attempt (not just the first), and
-- again any time a run gets interrupted or aborted partway. It unconditionally
-- deletes and recreates the fixture group, so it always starts unarchived
-- with zero members, regardless of what state an earlier attempt left it in.
-- (An earlier version of this file only created the fixture if it didn't
-- already exist — so a prior run that got as far as archiving it left every
-- later run starting from an already-archived group, making the very first
-- enroll_user_in_batch_group call fail immediately with "This batch has been
-- archived" before any real concurrency was exercised. That's not a bug in
-- the function — it's exactly the correct refusal — it just wasn't testing
-- what this file intends to test.)
-- ============================================================================
DO $$
DECLARE
  v_admin uuid;
BEGIN
  DELETE FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test';

  SELECT id INTO v_admin FROM profiles WHERE role IN ('admin','super_admin') LIMIT 1;
  IF v_admin IS NULL THEN
    RAISE EXCEPTION 'No admin/super_admin profile found — cannot create fixture.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE role = 'student') THEN
    RAISE EXCEPTION 'No student profile found — cannot create fixture.';
  END IF;

  INSERT INTO study_groups (name, description, is_batch_group, group_type, batch_course, batch_institution, created_by, invite_token)
  VALUES ('Sprint8.1 Concurrency Test', 'temp - safe to delete', true, 'batch', 'ZZ Test Course', 'ZZ Test Institution', v_admin, gen_random_uuid());

  RAISE NOTICE 'Fixture group reset: unarchived, zero members.';
END $$;

-- Cleanup when fully done with both scenarios below:
-- DELETE FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test';

-- If this setup block hangs instead of completing: a previous attempt left a
-- `BEGIN; ... FOR UPDATE;` open in another tab without COMMIT/ROLLBACK, and
-- this DELETE is waiting on that lock. Find and end it:
--   SELECT pid, state, query, now() - xact_start AS age FROM pg_stat_activity
--   WHERE state = 'idle in transaction' ORDER BY xact_start;
-- then either go to that tab and run ROLLBACK, or (if the tab is gone):
--   SELECT pg_terminate_backend(<pid>);


-- ============================================================================
-- SCENARIO 1 — archive wins the lock first: the concurrent enroll must be
-- refused once archive commits.
-- ============================================================================

-- --- TAB 1 --- run this first, then WAIT (do not run the COMMIT yet):
BEGIN;
SELECT is_batch_group, archived_at
FROM study_groups
WHERE name = 'Sprint8.1 Concurrency Test'
FOR UPDATE;
-- Tab 1 now holds the row lock. Leave this transaction open.

-- --- TAB 2 --- run this next, while Tab 1's transaction is still open:
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM profiles WHERE role IN ('admin','super_admin') LIMIT 1), 'role','authenticated')::text,
  true);
SELECT public.enroll_user_in_batch_group(
  (SELECT id FROM profiles WHERE role = 'student' LIMIT 1),
  (SELECT id FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test')
);
-- This BLOCKS (waiting on Tab 1's lock) — expected. Do not cancel it.

-- --- TAB 1 --- now run the actual archive + commit:
SELECT public.archive_batch_group((SELECT id FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test'));
COMMIT;
-- Tab 2's blocked enroll_user_in_batch_group call should now return —
-- EXPECTED: it raises 'This batch has been archived' (Tab 1's archive won
-- the lock and committed first, so Tab 2 must see archived_at set).

-- --- Verify no partial outcome ---
SELECT archived_at FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test';  -- expect: not null
SELECT COUNT(*) FROM study_group_members sgm
  JOIN study_groups sg ON sg.id = sgm.group_id
  JOIN profiles p ON p.id = sgm.user_id
  WHERE sg.name = 'Sprint8.1 Concurrency Test' AND p.role = 'student';  -- expect: 0 (enroll never committed)


-- ============================================================================
-- SCENARIO 2 — enrollment wins the lock first: it must succeed, and the
-- member added just before archiving must still be preserved as an approved
-- member after archive commits (matches "an action that completes before
-- archiving may succeed").
-- ============================================================================

-- Reset: restore the group and remove the student added in Scenario 1.
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM profiles WHERE role IN ('admin','super_admin') LIMIT 1), 'role','authenticated')::text,
  true);
SELECT public.restore_batch_group((SELECT id FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test'));
DELETE FROM study_group_members
  WHERE group_id = (SELECT id FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test')
    AND user_id = (SELECT id FROM profiles WHERE role = 'student' LIMIT 1);

-- --- TAB 1 --- run this first, then WAIT (do not run the COMMIT yet):
BEGIN;
SELECT is_batch_group, archived_at
FROM study_groups
WHERE name = 'Sprint8.1 Concurrency Test'
FOR UPDATE;
-- Tab 1 now holds the row lock. Leave this transaction open.

-- --- TAB 2 --- run this next, while Tab 1's transaction is still open:
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM profiles WHERE role IN ('admin','super_admin') LIMIT 1), 'role','authenticated')::text,
  true);
SELECT public.archive_batch_group((SELECT id FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test'));
-- This BLOCKS (waiting on Tab 1's lock) — expected. Do not cancel it.

-- --- TAB 1 --- now run the enrollment + commit (releases the lock Tab 2 is waiting on):
SELECT set_config('request.jwt.claims',
  json_build_object('sub', (SELECT id FROM profiles WHERE role IN ('admin','super_admin') LIMIT 1), 'role','authenticated')::text,
  true);
SELECT public.enroll_user_in_batch_group(
  (SELECT id FROM profiles WHERE role = 'student' LIMIT 1),
  (SELECT id FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test')
);
COMMIT;
-- Tab 2's blocked archive_batch_group call should now return successfully —
-- EXPECTED: no error, already_archived=false.

-- --- Verify: the member enrolled just before archiving is preserved active,
-- and the snapshot captured by Tab 2's archive call includes them ---
SELECT sgm.status FROM study_group_members sgm
  JOIN study_groups sg ON sg.id = sgm.group_id
  JOIN profiles p ON p.id = sgm.user_id
  WHERE sg.name = 'Sprint8.1 Concurrency Test' AND p.role = 'student';  -- expect: active
SELECT report->'member_count'
FROM batch_group_archives
WHERE group_id = (SELECT id FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test')
ORDER BY archived_at DESC LIMIT 1;
  -- expect: reflects the enrolled student (member_count includes them, since
  -- Tab 1's enroll committed before Tab 2's archive_batch_group captured its snapshot)

-- Cleanup:
-- DELETE FROM study_groups WHERE name = 'Sprint8.1 Concurrency Test';
