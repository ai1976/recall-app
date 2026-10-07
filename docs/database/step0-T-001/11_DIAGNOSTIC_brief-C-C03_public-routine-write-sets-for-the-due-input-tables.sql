-- Name: [DIAGNOSTIC] T-001 brief C file C-03 pre-check (v1) - which public routines can write the tables that define "due", read from the live function bodies
--
-- Description: READ-ONLY. Brief C v6 (20647dbce877, Gate 1) C-6.4 requires a reviewed manifest that classifies EVERY database call in the frontend as
-- due-changing or not-due-changing, with a reason; QA Round 78 made it a condition that the initial classification of each RPC use the reviewed function
-- BODIES and the live catalogue, because the name of an RPC does not show which tables it changes. The saved evidence holds full bodies for only about 57
-- group-related routines and seven forecast and queue functions, not for the roughly 135 RPCs the frontend calls. This file reads the live bodies of every
-- routine in schema public, analyses them LEXICALLY (the statement forms INSERT INTO, UPDATE ... SET, DELETE FROM, MERGE INTO and TRUNCATE; the tables they
-- name; whether the body uses EXECUTE; which other public routines it calls), follows calls transitively, and reports which routines can write the six tables
-- that define a student's due set: reviews, my_cards_enrollment, friendships, flashcards, notes and profiles (the course_level and timezone columns).
-- It returns analysis only: NO function body, no definition text and no identity is returned.
-- How it moves the finish line (the standing rule for new diagnostics): without it the C-03 manifest could classify the RPCs only by name, which QA has
-- already ruled insufficient; with it the manifest is built from evidence and the C-03 exact-diff audit does not stop on that point.
-- What it returns (one row, one jsonb column named `result`):
--   * routine_count (public routines readable as plpgsql or sql), unreadable_routine_count (any other language), language_counts;
--   * frontend_names_expected and frontend_names_missing (names in the list below that match no public routine);
--   * routines: for every public routine that is called from the frontend, OR can (transitively) write a due-input table, OR uses EXECUTE: its name and
--     arguments, SECURITY DEFINER flag, language, whether it is called from the frontend (the list below), its own written tables by statement form, the
--     due-input tables it can write transitively (and through which statement form), whether it uses EXECUTE (dynamic SQL, not analysable), and whether it
--     writes profiles and assigns course_level or timezone;
--   * summary counts.
-- Safety: one SELECT ... WITH, no DML, DDL, dynamic SQL, transaction control or application-function call. Only pg_proc, pg_namespace, pg_language,
-- pg_get_functiondef (on public routines of languages plpgsql and sql), pg_get_function_identity_arguments and regular-expression functions are used.
-- Blind spots, stated: the analysis is lexical (a table named in a comment or in a string is reported; a statement built by string concatenation inside EXECUTE
-- is NOT seen and the routine is flagged dynamic instead; a table written only by a trigger is not attributed to the routine); calls are matched by routine name
-- followed by an opening parenthesis (every overload, an over-approximation); routines of other schemas are not analysed. A routine that is flagged dynamic or
-- that calls a flagged routine must be read by hand before it is classified.
--
-- HOW TO RUN (one run): select the whole file (Ctrl+A in the file, Ctrl+C), paste it into the SQL Editor, click Run, copy the single result cell and paste it into a
-- Notepad file under the label W1; save it as docs/discussions/evidence/T-001_C03-W-raw_<dd-mm-yyyy>.raw.txt (check that Notepad did not drop the .txt) and keep it
-- untouched. An error is evidence: save the error text under the label, do not edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN W1 =====
WITH fe(name) AS (
  VALUES
         ('accept_group_invite'),
         ('add_batch_to_my_cards'),
         ('add_to_my_cards'),
         ('admin_bulk_add_to_batch'),
         ('admin_bulk_resolve_batch_requests'),
         ('admin_change_role'),
         ('admin_delete_note'),
         ('admin_delete_user_data'),
         ('admin_grant_access'),
         ('admin_reactivate_user'),
         ('admin_read_profiles'),
         ('admin_suspend_user'),
         ('apply_review'),
         ('approve_batch_join_request'),
         ('approve_educator_application'),
         ('approve_featured_nomination'),
         ('archive_batch_group'),
         ('assign_professor_to_batch'),
         ('bulk_pause_my_cards'),
         ('bulk_remove_from_my_cards'),
         ('bulk_resume_my_cards'),
         ('create_batch_group'),
         ('create_flashcard_batches'),
         ('create_study_group'),
         ('decline_group_invite'),
         ('delete_notification'),
         ('enroll_user_in_batch_group'),
         ('follow_user'),
         ('get_admin_batch_groups'),
         ('get_admin_flags'),
         ('get_admin_pending_batch_requests'),
         ('get_admin_platform_overview'),
         ('get_assignable_professors'),
         ('get_author_content_summary'),
         ('get_author_profile'),
         ('get_batch_group_archive'),
         ('get_batch_group_member_stats'),
         ('get_batch_group_professors'),
         ('get_browsable_decks'),
         ('get_browsable_notes'),
         ('get_content_creation_stats'),
         ('get_content_health_stats'),
         ('get_course_archived_my_cards'),
         ('get_creator_leaderboard'),
         ('get_discoverable_users'),
         ('get_due_forecast'),
         ('get_due_forecast_buckets'),
         ('get_educator_accuracy_by_qtype'),
         ('get_educator_cohort_forecast_buckets'),
         ('get_featured_landing_content'),
         ('get_filtered_authors_for_flashcards'),
         ('get_filtered_authors_for_notes'),
         ('get_follow_status'),
         ('get_following_leaderboard'),
         ('get_following_with_stats'),
         ('get_friends_leaderboard'),
         ('get_group_detail'),
         ('get_group_preview'),
         ('get_live_featured_content_admin'),
         ('get_mastered_cards'),
         ('get_my_batch_groups'),
         ('get_my_cards'),
         ('get_my_content_flags'),
         ('get_my_enrollment_count'),
         ('get_my_friends_with_stats'),
         ('get_pending_featured_nominations'),
         ('get_pending_group_invites'),
         ('get_platform_heatmap'),
         ('get_platform_stats'),
         ('get_practice_cards'),
         ('get_professor_overview'),
         ('get_professor_subject_engagement'),
         ('get_professor_top_cards'),
         ('get_professor_weak_cards'),
         ('get_professor_weekly_reach'),
         ('get_public_deck_preview'),
         ('get_public_educators'),
         ('get_public_note_preview'),
         ('get_question_type_performance'),
         ('get_recent_activity_feed'),
         ('get_recent_notifications'),
         ('get_removed_my_cards'),
         ('get_srs_ladder_config'),
         ('get_study_engagement_stats'),
         ('get_study_heatmap'),
         ('get_study_queue'),
         ('get_study_time_stats'),
         ('get_subject_mastery_v1'),
         ('get_super_admin_cohort_comparison'),
         ('get_super_admin_header_stats'),
         ('get_suspended_cards'),
         ('get_unnotified_badges'),
         ('get_unread_notification_count'),
         ('get_user_activity_stats'),
         ('get_user_badges'),
         ('get_user_groups'),
         ('get_user_onboarding_stats'),
         ('get_user_retention_stats'),
         ('get_user_streak'),
         ('get_weekly_platform_reviews'),
         ('invite_to_group'),
         ('join_group_by_token'),
         ('leave_group'),
         ('link_access_request'),
         ('log_admin_event'),
         ('log_practice_attempt'),
         ('mark_notifications_read'),
         ('mark_single_notification_read'),
         ('nominate_featured_content'),
         ('preview_course_change'),
         ('reject_batch_join_request'),
         ('reject_educator_application'),
         ('reject_featured_nomination'),
         ('remove_from_my_cards'),
         ('remove_group_member'),
         ('rename_batch_group'),
         ('reset_card'),
         ('resolve_content_flag'),
         ('restore_batch_group'),
         ('search_users_for_group_invite'),
         ('share_content_with_groups'),
         ('skip_card'),
         ('skip_topic_cards'),
         ('submit_access_request'),
         ('submit_content_flag'),
         ('submit_educator_application'),
         ('submit_institute_inquiry'),
         ('suspend_card'),
         ('suspend_topic_cards'),
         ('toggle_upvote'),
         ('unassign_professor_from_batch'),
         ('unfeature_content'),
         ('unfollow_user'),
         ('unsuspend_card'),
         ('update_daily_goal')
),
due(tbl) AS (
  VALUES ('reviews'), ('my_cards_enrollment'), ('friendships'), ('flashcards'), ('notes'), ('profiles')
),
r AS (
  SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef, l.lanname,
         lower(replace(pg_get_functiondef(p.oid), '"', '')) AS body
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname = 'public' AND p.prokind IN ('f', 'p') AND l.lanname IN ('plpgsql', 'sql')
),
w AS (
  SELECT r.oid, m[1] AS tbl, 'insert' AS op
  FROM r, regexp_matches(r.body, 'insert\s+into\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)', 'g') m
  UNION ALL
  SELECT r.oid, m[1], 'update'
  FROM r, regexp_matches(r.body, 'update\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)\s+(?:as\s+[a-z_][a-z0-9_]*\s+)?set\s', 'g') m
  UNION ALL
  SELECT r.oid, m[1], 'delete'
  FROM r, regexp_matches(r.body, 'delete\s+from\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)', 'g') m
  UNION ALL
  SELECT r.oid, m[1], 'merge'
  FROM r, regexp_matches(r.body, 'merge\s+into\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)', 'g') m
  UNION ALL
  SELECT r.oid, m[1], 'truncate'
  FROM r, regexp_matches(r.body, 'truncate\s+(?:table\s+)?(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)', 'g') m
),
own AS (
  SELECT oid, tbl, op FROM w GROUP BY oid, tbl, op
),
edges AS (
  SELECT a.oid AS caller, b.oid AS callee
  FROM r a
  JOIN r b ON a.oid <> b.oid
          AND a.body ~ ('(^|[^a-z0-9_.])(public\.)?' || b.proname || '\s*\(')
),
reach(root, node) AS (
  SELECT oid, oid FROM r
  UNION
  SELECT reach.root, e.callee FROM reach JOIN edges e ON e.caller = reach.node
),
trans AS (
  SELECT reach.root AS oid, o.tbl, o.op
  FROM reach JOIN own o ON o.oid = reach.node
  GROUP BY reach.root, o.tbl, o.op
),
dyn AS (
  SELECT oid, (body ~ '(^|[^a-z0-9_])execute\s') AS has_exec FROM r
),
tdyn AS (
  SELECT reach.root AS oid, bool_or(d.has_exec) AS reaches_exec
  FROM reach JOIN dyn d ON d.oid = reach.node
  GROUP BY reach.root
),
prof AS (
  SELECT r.oid,
         EXISTS (SELECT 1 FROM own o WHERE o.oid = r.oid AND o.tbl = 'profiles')
         AND r.body ~ '(course_level|timezone)\s*=' AS assigns_course_or_timezone
  FROM r
),
rep AS (
  SELECT r.oid, r.proname, r.args, r.prosecdef, r.lanname,
         EXISTS (SELECT 1 FROM fe WHERE fe.name = r.proname) AS called_from_frontend,
         COALESCE((SELECT jsonb_agg(o.tbl || '.' || o.op ORDER BY o.tbl, o.op) FROM own o WHERE o.oid = r.oid), '[]'::jsonb) AS own_writes,
         COALESCE((SELECT jsonb_agg(t.tbl || '.' || t.op ORDER BY t.tbl, t.op) FROM trans t WHERE t.oid = r.oid AND t.tbl IN (SELECT tbl FROM due)), '[]'::jsonb) AS due_input_writes_transitive,
         d.has_exec AS uses_execute, COALESCE(td.reaches_exec, false) AS reaches_execute,
         COALESCE(pf.assigns_course_or_timezone, false) AS writes_profiles_and_assigns_course_or_timezone
  FROM r
  JOIN dyn d ON d.oid = r.oid
  LEFT JOIN tdyn td ON td.oid = r.oid
  LEFT JOIN prof pf ON pf.oid = r.oid
)
SELECT jsonb_build_object(
  'run', 'W1',
  'routine_count', (SELECT count(*) FROM r),
  'unreadable_routine_count', (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_language l ON l.oid = p.prolang
                               WHERE n.nspname = 'public' AND p.prokind IN ('f', 'p') AND l.lanname NOT IN ('plpgsql', 'sql')),
  'language_counts', (SELECT COALESCE(jsonb_object_agg(lanname, c), '{}'::jsonb) FROM (SELECT lanname, count(*) AS c FROM r GROUP BY lanname) x),
  'frontend_names_expected', (SELECT count(*) FROM fe),
  'frontend_names_missing', (SELECT COALESCE(jsonb_agg(fe.name ORDER BY fe.name), '[]'::jsonb) FROM fe WHERE NOT EXISTS (SELECT 1 FROM r WHERE r.proname = fe.name)),
  'routines_that_can_write_a_due_input_table_transitively', (SELECT count(*) FROM rep WHERE jsonb_array_length(due_input_writes_transitive) > 0),
  'routines_using_execute', (SELECT count(*) FROM rep WHERE uses_execute),
  'routines', (SELECT COALESCE(jsonb_agg(jsonb_build_object(
                  'name', proname, 'args', args, 'security_definer', prosecdef, 'language', lanname,
                  'called_from_frontend', called_from_frontend, 'own_writes', own_writes,
                  'due_input_writes_transitive', due_input_writes_transitive,
                  'uses_execute', uses_execute, 'reaches_execute', reaches_execute,
                  'writes_profiles_and_assigns_course_or_timezone', writes_profiles_and_assigns_course_or_timezone)
                  ORDER BY proname, args), '[]'::jsonb)
               FROM rep
               WHERE called_from_frontend OR jsonb_array_length(due_input_writes_transitive) > 0 OR uses_execute OR reaches_execute)
) AS result;
