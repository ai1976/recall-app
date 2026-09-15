-- Name: [DIAGNOSTIC] Sprint 8.1 — why did sg_delete_creator not block a batch-group DELETE under 'authenticated'
-- Description: 04_TEST_verify_archiving.sql's RLS check shows a batch
-- group's row count going from 1 to 0 after `SET LOCAL ROLE authenticated;
-- DELETE FROM study_groups WHERE id = v_group_a;` — meaning the DELETE
-- actually removed the row, even though sg_delete_creator was narrowed to
-- `is_batch_group = false` in 01_SCHEMA. Every value below is captured into
-- a plain variable WHILE role-switched, then RESET ROLE runs, and only
-- afterward is anything written to the _diag temp table — no INSERT touches
-- it while current_user is 'authenticated' (that was the bug in the
-- previous version of this file: the temp table is owned by the session's
-- original role, so 'authenticated' has no grant on it — same class of
-- mistake already fixed once in 04_TEST and reintroduced here by not
-- applying the same care). Creates a disposable fixture row, exercises the
-- exact same statements the test used, and rolls everything back. Run in
-- Supabase SQL Editor and paste back the full result table.

BEGIN;
CREATE TEMP TABLE _diag(step text, value text);

DO $$
DECLARE
  v_admin    uuid;
  v_group    uuid;
  v_is_batch boolean;
  v_rows_affected int;
  v_cur_user_before   text;
  v_auth_uid_before    text;
  v_cur_user_after     text;
  v_auth_uid_after      text;
  v_is_batch_under_auth text;
  v_delete_rows         text;
  v_cur_user_reset      text;
  v_row_exists_after    text;
BEGIN
  SELECT id INTO v_admin FROM profiles WHERE role IN ('admin','super_admin') LIMIT 1;
  IF v_admin IS NULL THEN
    INSERT INTO _diag VALUES ('ERROR', 'no admin/super_admin profile found');
    RETURN;
  END IF;

  INSERT INTO study_groups (name, description, is_batch_group, group_type, batch_course, batch_institution, created_by, invite_token)
  VALUES ('RLS Diagnostic Batch', 'temp', true, 'batch', 'ZZ', 'ZZ', v_admin, gen_random_uuid())
  RETURNING id INTO v_group;

  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role','authenticated')::text, true);
  v_auth_uid_before := auth.uid()::text;
  v_cur_user_before := current_user;

  SET LOCAL ROLE authenticated;

  v_cur_user_after := current_user;
  v_auth_uid_after := auth.uid()::text;

  SELECT is_batch_group INTO v_is_batch FROM study_groups WHERE id = v_group;
  v_is_batch_under_auth := v_is_batch::text;

  DELETE FROM study_groups WHERE id = v_group;
  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
  v_delete_rows := v_rows_affected::text;

  RESET ROLE;
  v_cur_user_reset := current_user;

  SELECT is_batch_group INTO v_is_batch FROM study_groups WHERE id = v_group;
  v_row_exists_after := COALESCE(v_is_batch::text, 'ROW IS GONE');

  -- Only now, back under the original (postgres) role, write everything at once.
  INSERT INTO _diag VALUES
    ('01_fixture_group_id', v_group::text),
    ('02_fixture_created_by_admin', v_admin::text),
    ('03_auth.uid()_before_switch', v_auth_uid_before),
    ('04_current_user_before_switch', v_cur_user_before),
    ('05_current_user_AFTER_switch', v_cur_user_after),
    ('06_auth.uid()_after_switch', v_auth_uid_after),
    ('07_is_batch_group_seen_under_authenticated', v_is_batch_under_auth),
    ('08_delete_rows_affected', v_delete_rows),
    ('09_current_user_after_reset', v_cur_user_reset),
    ('10_row_still_exists_is_batch_group', v_row_exists_after);
END $$;

INSERT INTO _diag
SELECT '11_policy_' || policyname,
       cmd || ' | USING: ' || COALESCE(qual,'(none)') || ' | WITH CHECK: ' || COALESCE(with_check,'(none)')
FROM pg_policies WHERE tablename = 'study_groups';

INSERT INTO _diag SELECT '12_rls_enabled (relrowsecurity)', relrowsecurity::text FROM pg_class WHERE relname = 'study_groups';
INSERT INTO _diag SELECT '13_rls_forced (relforcerowsecurity)', relforcerowsecurity::text FROM pg_class WHERE relname = 'study_groups';
INSERT INTO _diag SELECT '14_table_owner', pg_get_userbyid(relowner) FROM pg_class WHERE relname = 'study_groups';

SELECT * FROM _diag ORDER BY step;
ROLLBACK;
