-- Name: [FIX] Sprint 8.1 — archive_batch_group timestamp precision (NOW() -> clock_timestamp())
-- Description: archive_batch_group used NOW() to stamp the archive event.
-- NOW() returns the enclosing TRANSACTION's start time, not the actual
-- wall-clock moment of the statement — constant for the whole transaction.
-- A restore-then-re-archive of the same batch group done inside one
-- transaction (e.g. 04_TEST_verify_archiving.sql's BEGIN...ROLLBACK, which
-- archives, restores, and re-archives the same fixture group in one go)
-- computes the identical timestamp twice, violating
-- batch_group_archives' UNIQUE(group_id, archived_at):
--   ERROR: 23505 duplicate key value violates unique constraint
--   "batch_group_archives_group_id_archived_at_key"
-- Fix: clock_timestamp() instead of NOW() — advances on every statement
-- regardless of transaction boundaries, and is the more correct choice
-- anyway for an audit marker of the actual moment captured. Only this one
-- function needs re-deploying; 01_SCHEMA and the rest of 02/03 are
-- unaffected. Superseded 02_FUNCTIONS_archive_restore.sql has been updated
-- in place to match, for anyone reading the migration history later.

CREATE OR REPLACE FUNCTION public.archive_batch_group(p_group_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_is_batch    boolean;
  v_archived_at timestamptz;
  v_new_archived_at timestamptz;
  v_report      jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: admin only';
  END IF;

  SELECT is_batch_group, archived_at INTO v_is_batch, v_archived_at
  FROM study_groups WHERE id = p_group_id FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Group not found';
  END IF;
  IF NOT v_is_batch THEN
    RAISE EXCEPTION 'Not a batch group';
  END IF;

  IF v_archived_at IS NOT NULL THEN
    RETURN jsonb_build_object('group_id', p_group_id, 'archived_at', v_archived_at, 'already_archived', true);
  END IF;

  v_new_archived_at := clock_timestamp();

  SELECT jsonb_build_object(
    'group', jsonb_build_object(
      'name', sg.name,
      'description', sg.description,
      'batch_course', sg.batch_course,
      'batch_institution', sg.batch_institution
    ),
    'member_count', (
      SELECT COUNT(*) FROM study_group_members WHERE group_id = p_group_id AND status = 'active'
    ),
    'members', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', s.user_id,
        'full_name', s.full_name,
        'reviews_this_week', s.reviews_this_week,
        'streak_days', s.streak_days,
        'study_time_this_week_seconds', s.study_time_this_week_seconds,
        'last_active_date', s.last_active_date
      ))
      FROM get_batch_group_member_stats(p_group_id) s
    ), '[]'::jsonb)
  ) INTO v_report
  FROM study_groups sg WHERE sg.id = p_group_id;

  INSERT INTO batch_group_archives (group_id, archived_at, archived_by, report)
  VALUES (p_group_id, v_new_archived_at, auth.uid(), v_report);

  UPDATE study_groups
  SET archived_at = v_new_archived_at, archived_by = auth.uid()
  WHERE id = p_group_id;

  UPDATE study_group_members
  SET status = 'closed', closed_at = v_new_archived_at, closed_reason = 'batch_archived'
  WHERE group_id = p_group_id AND status IN ('requested', 'invited');

  RETURN jsonb_build_object('group_id', p_group_id, 'archived_at', v_new_archived_at, 'already_archived', false);
END;
$function$;
