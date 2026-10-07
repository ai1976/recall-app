-- Name: [DIAGNOSTIC] T-001 brief C file C-03 pre-check (v3) - which public routines can write the tables that define "due", read from the live function bodies
--
-- Description: READ-ONLY. Brief C v6 (20647dbce877, Gate 1) C-6.4 requires a reviewed manifest that classifies EVERY database call in the frontend as
-- due-changing or not-due-changing, with a reason; QA Round 78 made it a condition that the initial classification of each RPC use the reviewed function
-- BODIES and the live catalogue, because the name of an RPC does not show which tables it changes. The saved evidence holds full bodies for only about 57
-- group-related routines and seven forecast and queue functions, not for the roughly 136 RPCs the frontend calls. This file reads the live bodies of every
-- routine in schema public, analyses them LEXICALLY (INSERT INTO, UPDATE ... SET in its three forms, DELETE FROM, MERGE INTO and TRUNCATE with a table list),
-- follows calls transitively, and reports which routines can write the six tables that define a student's due set: reviews, my_cards_enrollment,
-- friendships, flashcards, notes and profiles (the course_level and timezone columns). It returns analysis only: NO function body, no definition text and
-- no identity is returned.
-- v2 (after QA Round 116): (1) the strict write matcher now also reads UPDATE t alias SET and every table of TRUNCATE a, b; (2) a LOOSE matcher reports, per
-- routine, any write keyword followed in the same statement by a due-input table name that the strict matcher did not report (over-reports on purpose), so a
-- form the matcher misses is a visible lead and not a silent gap; (3) the closure now also reports calls qualified with a non-public schema, calls of public
-- routines whose language is not readable, writes that reach a due-input table through a trigger, a cascading foreign key or a view, and tables whose trigger
-- cannot be resolved; (4) the profile flag is transitive; (5) the recursive WITH was missing its RECURSIVE keyword (v1 would have failed to parse); (6) the
-- list now includes get_study_heatmap_split (C-02, applied), so the C-03 manifest ties that call to evidence.
-- v3 (after QA Round 118): (7) every frontend name with no readable routine now gets its own row (readable_routine_found false, needs_manual_review true) and is
-- counted, and a manifest_preconditions object lists the missing names, every non-view rule and every row-level-security policy that calls a public routine;
-- all must be empty or cleared by hand before ANY routine is classified not-due-changing; (8) markers that make a routine need manual review: an unqualified
-- call whose name is also the name of a routine in a non-public non-system schema (search_path), built-in or extension functions that run SQL given as text
-- or reach other databases (query_to_xml, cursor_to_xml, dblink, large-object import and export), and TRUNCATE ... CASCADE.
-- How it moves the finish line (the standing rule for new diagnostics): without it the C-03 manifest could classify the RPCs only by name, which QA has
-- already ruled insufficient; with it the manifest is built from evidence and the C-03 exact-diff audit does not stop on that point.
-- What it returns (one row, one jsonb column named `result`):
--   * routine_count, unreadable_routine_count, language_counts, frontend_names_expected, frontend_names_missing;
--   * summary counts, tables_with_unresolved_trigger, and table_effect_edges_reaching_a_due_input_table (trigger, fk_cascade and view edges);
--   * routines: for every public routine that is called from the frontend, OR can write a due-input table (directly, transitively or indirectly), OR needs
--     manual review: its name and arguments, SECURITY DEFINER flag, language, whether it is called from the frontend, own_writes, due_input_writes_transitive,
--     due_input_writes_indirect (table.op>due_table through a trigger, cascade or view), loose_write_leads_transitive, non_public_calls_transitive,
--     unreadable_callees_transitive, writes_table_with_unresolved_trigger, uses_execute, reaches_execute, the transitive profiles flag, needs_manual_review.
-- Rule for the C-03 manifest: a routine may be classified not-due-changing from this evidence ONLY if every manifest_preconditions list is empty or cleared by
-- hand, AND the routine has readable_routine_found true, due_input_writes_transitive and due_input_writes_indirect empty, AND needs_manual_review false; every other routine called from the frontend is read by hand (body in the live
-- database, not in the evidence) before it is classified, and the manual review is recorded in the manifest reason.
-- Safety: one SELECT ... WITH RECURSIVE, no DML, DDL, dynamic SQL, transaction control or application-function call. Only pg_proc, pg_namespace, pg_language,
-- pg_class, pg_constraint, pg_trigger, pg_rewrite, pg_policy, pg_get_expr, pg_get_functiondef (public routines of languages plpgsql and sql), pg_get_viewdef (public views),
-- pg_get_function_identity_arguments and regular-expression functions are used. Definition text is read into an internal string for analysis only.
-- Blind spots, stated: the analysis is lexical (a table named in a comment or a string is reported; a statement built by string concatenation inside EXECUTE
-- is NOT seen and the routine is flagged dynamic); calls are matched by routine name followed by an opening parenthesis, read once per routine as a token (every overload, an
-- over-approximation); trigger events are not matched (every trigger on a table is assumed to fire); effects of extensions and non-public routines are only
-- flagged, not followed; rules other than views and policies that call public routines are listed as preconditions, not analysed; an unqualified call that resolves to a built-in function or to no routine at all cannot be flagged (built-ins other than those marked cannot write user tables); a write to a due-input table by a
-- role other than through these routines is out of scope. Anything flagged needs_manual_review must be read by hand before it is classified.
--
-- HOW TO RUN (one run): select the whole file (Ctrl+A in the file, Ctrl+C), paste it into the SQL Editor, click Run, copy the single result cell and paste it into a
-- Notepad file under the label W1; save it as docs/discussions/evidence/T-001_C03-W-raw_<dd-mm-yyyy>.raw.txt (check that Notepad did not drop the .txt) and keep it
-- untouched. An error is evidence: save the error text under the label, do not edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN W1 =====
WITH RECURSIVE fe(name) AS (
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
         ('get_study_heatmap_split'),
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
pt AS (
  -- public relations (tables, partitioned tables, views, materialised views, foreign tables)
  SELECT c.oid, c.relname::text AS relname, c.relkind
  FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
),
r AS (
  SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) AS args, p.prosecdef, l.lanname,
         lower(replace(pg_get_functiondef(p.oid), '"', '')) AS body
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname = 'public' AND p.prokind IN ('f', 'p') AND l.lanname IN ('plpgsql', 'sql')
),
ur AS (
  -- public routines whose body cannot be read as text (any other language): matched by name as callees
  SELECT DISTINCT p.proname
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname = 'public' AND p.prokind IN ('f', 'p') AND l.lanname NOT IN ('plpgsql', 'sql')
),
tok AS (
  -- every name followed by an opening parenthesis in a body, once per routine; "public." is stripped, any other qualifier is kept
  SELECT DISTINCT r.oid, regexp_replace(m[1], '^public\.', '') AS nm
  FROM r, regexp_matches(r.body, '([a-z0-9_.]+)\s*\(', 'g') m
),
w AS (
  SELECT r.oid, m[1] AS tbl, 'insert' AS op
  FROM r, regexp_matches(r.body, 'insert\s+into\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)', 'g') m
  UNION ALL
  -- UPDATE t SET, UPDATE t AS a SET and UPDATE t a SET
  SELECT r.oid, m[1], 'update'
  FROM r, regexp_matches(r.body, 'update\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)(?:\s+(?:as\s+)?[a-z_][a-z0-9_]*)?\s+set\s', 'g') m
  UNION ALL
  SELECT r.oid, m[1], 'delete'
  FROM r, regexp_matches(r.body, 'delete\s+from\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)', 'g') m
  UNION ALL
  SELECT r.oid, m[1], 'merge'
  FROM r, regexp_matches(r.body, 'merge\s+into\s+(?:only\s+)?(?:public\.)?([a-z_][a-z0-9_]*)', 'g') m
  UNION ALL
  -- TRUNCATE a, b, c: every public relation named in the statement (up to the next semicolon)
  SELECT r.oid, t.tok, 'truncate'
  FROM r,
       regexp_matches(r.body, 'truncate\s+(?:table\s+)?([^;]*)', 'g') m,
       regexp_split_to_table(replace(m[1], 'public.', ''), '[\s,]+') t(tok)
  WHERE t.tok IN (SELECT relname FROM pt)
),
own AS (
  SELECT oid, tbl, op FROM w GROUP BY oid, tbl, op
),
lead AS (
  -- LOOSE leads: a write keyword followed, inside the same statement (up to the next semicolon), by the name of a due-input table, where the strict
  -- pattern above found no such write. Over-reports on purpose (INSERT ... SELECT FROM reviews); it exists so a form the strict pattern misses is a
  -- lead the manifest must clear, not a silent gap.
  SELECT r.oid, d.tbl, k.op
  FROM r
  CROSS JOIN due d
  CROSS JOIN (VALUES ('insert'), ('update'), ('delete'), ('merge'), ('truncate')) k(op)
  WHERE r.body ~ ('(^|[^a-z0-9_])' || k.op || '[^a-z0-9_]([^;]*[^a-z0-9_])?' || d.tbl || '([^a-z0-9_]|$)')
    AND NOT EXISTS (SELECT 1 FROM own x WHERE x.oid = r.oid AND x.tbl = d.tbl AND x.op = k.op)
),
npc AS (
  -- calls qualified with a schema other than public / pg_catalog / information_schema (auth.uid, auth.jwt and auth.role excluded: they read the session)
  SELECT DISTINCT r.oid, m[1] || '.' || m[2] AS callee
  FROM r, regexp_matches(r.body, '([a-z_][a-z0-9_]*)\.([a-z_][a-z0-9_]*)\s*\(', 'g') m
  WHERE m[1] IN (SELECT nspname FROM pg_namespace WHERE nspname NOT IN ('public', 'pg_catalog', 'information_schema', 'pg_toast') AND nspname NOT LIKE 'pg_temp%')
    AND (m[1] || '.' || m[2]) NOT IN ('auth.uid', 'auth.jwt', 'auth.role')
),
ucall AS (
  SELECT DISTINCT t.oid, t.nm AS callee
  FROM tok t JOIN ur u ON u.proname = t.nm
),
edges AS (
  SELECT DISTINCT t.oid AS caller, b.oid AS callee
  FROM tok t JOIN r b ON b.proname = t.nm AND b.oid <> t.oid
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
tlead AS (
  SELECT reach.root AS oid, l.tbl, l.op
  FROM reach JOIN lead l ON l.oid = reach.node
  GROUP BY reach.root, l.tbl, l.op
),
tnpc AS (
  SELECT reach.root AS oid, n.callee
  FROM reach JOIN npc n ON n.oid = reach.node
  GROUP BY reach.root, n.callee
),
tucall AS (
  SELECT reach.root AS oid, u.callee
  FROM reach JOIN ucall u ON u.oid = reach.node
  GROUP BY reach.root, u.callee
),
uns AS (
  -- markers the table and call analysis cannot resolve; each makes the routine need manual review
  -- (1) an UNQUALIFIED call whose name is also the name of a routine in a non-public, non-system schema (resolved through search_path)
  SELECT DISTINCT t.oid, 'bare_call_matching_non_public_routine'::text AS kind, t.nm::text AS what
  FROM tok t
  WHERE t.nm IN (SELECT p.proname::text
                 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
                 WHERE n.nspname NOT IN ('public', 'pg_catalog', 'information_schema', 'pg_toast') AND n.nspname NOT LIKE 'pg_temp%')
  UNION
  -- (2) built-in or extension functions that run SQL given as text, or reach other databases or large objects
  SELECT DISTINCT t.oid, 'builtin_dynamic_sql_or_remote'::text, regexp_replace(t.nm, '^pg_catalog\.', '')
  FROM tok t
  WHERE regexp_replace(t.nm, '^pg_catalog\.', '') IN ('query_to_xml', 'query_to_xml_and_xmlschema', 'query_to_xmlschema', 'cursor_to_xml', 'dblink', 'dblink_exec',
                                                        'lo_import', 'lo_export')
  -- (3) TRUNCATE ... CASCADE also empties every table that references the truncated one, whatever the foreign key action
  SELECT r.oid, 'truncate_cascade'::text, 'truncate'::text
  FROM r
  WHERE r.body ~ 'truncate[^;]*[^a-z0-9_]cascade([^a-z0-9_]|$)'
),
dyn AS (
  SELECT oid, (body ~ '(^|[^a-z0-9_])execute\s') AS has_exec FROM r
),
tuns AS (
  SELECT reach.root AS oid, u.kind, u.what
  FROM reach JOIN uns u ON u.oid = reach.node
  GROUP BY reach.root, u.kind, u.what
),
tdyn AS (
  SELECT reach.root AS oid, bool_or(d.has_exec) AS reaches_exec
  FROM reach JOIN dyn d ON d.oid = reach.node
  GROUP BY reach.root
),
flag AS (
  -- a routine (with everything it can call) that the strict analysis cannot fully resolve
  SELECT r.oid,
         (COALESCE(td.reaches_exec, false)
          OR EXISTS (SELECT 1 FROM tlead x WHERE x.oid = r.oid)
          OR EXISTS (SELECT 1 FROM tnpc x WHERE x.oid = r.oid)
          OR EXISTS (SELECT 1 FROM tucall x WHERE x.oid = r.oid)
          OR EXISTS (SELECT 1 FROM tuns x WHERE x.oid = r.oid)) AS unresolved
  FROM r LEFT JOIN tdyn td ON td.oid = r.oid
),
vd AS (
  SELECT v.oid, v.relname, lower(pg_get_viewdef(v.oid)) AS def FROM pt v WHERE v.relkind = 'v'
),
tedge(src, dst, via) AS (
  -- table-to-table effects that a write can have without the routine naming the target
  -- (1) a trigger function on src (and everything it calls) writes dst; trigger events are not matched, every trigger on src is assumed to fire
  SELECT pc.relname, o.tbl, 'trigger'
  FROM pg_trigger tg
  JOIN pt pc ON pc.oid = tg.tgrelid
  JOIN reach rr ON rr.root = tg.tgfoid
  JOIN own o ON o.oid = rr.node
  WHERE NOT tg.tgisinternal
  UNION
  -- (2) a foreign key with a cascading or nulling action on delete or update: a write to the parent writes the child
  SELECT pp.relname, cc.relname, 'fk_cascade'
  FROM pg_constraint k
  JOIN pt pp ON pp.oid = k.confrelid
  JOIN pt cc ON cc.oid = k.conrelid
  WHERE k.contype = 'f' AND (k.confdeltype IN ('c', 'n', 'd') OR k.confupdtype IN ('c', 'n', 'd'))
  UNION
  -- (3) a view whose definition names another relation: a write to the view can write that relation
  SELECT v.relname, b.relname, 'view'
  FROM vd v JOIN pt b ON b.oid <> v.oid
  WHERE v.def ~ ('(^|[^a-z0-9_])' || b.relname || '([^a-z0-9_]|$)')
),
tclose(src, dst) AS (
  SELECT relname, relname FROM pt
  UNION
  SELECT c.src, e.dst FROM tclose c JOIN tedge e ON e.src = c.dst
),
utr AS (
  -- tables that have a trigger the analysis cannot resolve (function not readable, or it reaches dynamic SQL, a loose lead, a non-public or unreadable call)
  SELECT DISTINCT pc.relname AS tbl
  FROM pg_trigger tg
  JOIN pt pc ON pc.oid = tg.tgrelid
  WHERE NOT tg.tgisinternal
    AND (tg.tgfoid NOT IN (SELECT oid FROM r) OR COALESCE((SELECT f.unresolved FROM flag f WHERE f.oid = tg.tgfoid), false))
),
indirect AS (
  SELECT t.oid, t.tbl || '.' || t.op || '>' || c.dst AS item
  FROM trans t JOIN tclose c ON c.src = t.tbl
  WHERE c.dst <> t.tbl AND c.dst IN (SELECT tbl FROM due)
  GROUP BY t.oid, t.tbl, t.op, c.dst
),
prof_own AS (
  -- writes profiles and names course_level or timezone anywhere in its body (a mention, not only an assignment: over-reports on purpose)
  SELECT r.oid
  FROM r
  WHERE EXISTS (SELECT 1 FROM own o WHERE o.oid = r.oid AND o.tbl = 'profiles')
    AND r.body ~ '(^|[^a-z0-9_])(course_level|timezone)([^a-z0-9_]|$)'
),
tprof AS (
  SELECT reach.root AS oid
  FROM reach JOIN prof_own p ON p.oid = reach.node
  GROUP BY reach.root
),
urules AS (
  -- rules other than the view rule (_RETURN) on public relations: not analysed, so each is a precondition to clear by hand
  SELECT pc.relname || '.' || rw.rulename::text AS item
  FROM pg_rewrite rw JOIN pt pc ON pc.oid = rw.ev_class
  WHERE rw.rulename <> '_RETURN'
),
prp AS (
  -- row-level-security policies on public relations whose USING or WITH CHECK expression calls a public routine by name
  SELECT pc.relname || '.' || pol.polname::text AS item
  FROM pg_policy pol JOIN pt pc ON pc.oid = pol.polrelid
  WHERE EXISTS (SELECT 1 FROM r
                WHERE (COALESCE(lower(pg_get_expr(pol.polqual, pol.polrelid)), '') || ' ' || COALESCE(lower(pg_get_expr(pol.polwithcheck, pol.polrelid)), ''))
                      ~ ('(^|[^a-z0-9_.])(public\.)?' || r.proname || '\s*\('))
),
rep AS (
  SELECT r.oid, r.proname, r.args, r.prosecdef, r.lanname,
         EXISTS (SELECT 1 FROM fe WHERE fe.name = r.proname) AS called_from_frontend,
         COALESCE((SELECT jsonb_agg(o.tbl || '.' || o.op ORDER BY o.tbl, o.op) FROM own o WHERE o.oid = r.oid), '[]'::jsonb) AS own_writes,
         COALESCE((SELECT jsonb_agg(t.tbl || '.' || t.op ORDER BY t.tbl, t.op) FROM trans t WHERE t.oid = r.oid AND t.tbl IN (SELECT tbl FROM due)), '[]'::jsonb) AS due_input_writes_transitive,
         COALESCE((SELECT jsonb_agg(i.item ORDER BY i.item) FROM indirect i WHERE i.oid = r.oid), '[]'::jsonb) AS due_input_writes_indirect,
         COALESCE((SELECT jsonb_agg(l.tbl || '.' || l.op ORDER BY l.tbl, l.op) FROM tlead l WHERE l.oid = r.oid), '[]'::jsonb) AS loose_write_leads_transitive,
         COALESCE((SELECT jsonb_agg(n.callee ORDER BY n.callee) FROM tnpc n WHERE n.oid = r.oid), '[]'::jsonb) AS non_public_calls_transitive,
         COALESCE((SELECT jsonb_agg(u.callee ORDER BY u.callee) FROM tucall u WHERE u.oid = r.oid), '[]'::jsonb) AS unreadable_callees_transitive,
         COALESCE((SELECT jsonb_agg(DISTINCT t.tbl ORDER BY t.tbl) FROM trans t WHERE t.oid = r.oid AND t.tbl IN (SELECT tbl FROM utr)), '[]'::jsonb) AS writes_table_with_unresolved_trigger,
         COALESCE((SELECT jsonb_agg(u.kind || ':' || u.what ORDER BY u.kind, u.what) FROM tuns u WHERE u.oid = r.oid), '[]'::jsonb) AS unresolved_effect_markers_transitive,
         d.has_exec AS uses_execute, COALESCE(td.reaches_exec, false) AS reaches_execute,
         EXISTS (SELECT 1 FROM tprof tp WHERE tp.oid = r.oid) AS reaches_profiles_write_naming_course_level_or_timezone
  FROM r
  JOIN dyn d ON d.oid = r.oid
  LEFT JOIN tdyn td ON td.oid = r.oid
),
rep2 AS (
  SELECT rep.*,
         (jsonb_array_length(loose_write_leads_transitive) > 0 OR jsonb_array_length(non_public_calls_transitive) > 0
          OR jsonb_array_length(unreadable_callees_transitive) > 0 OR jsonb_array_length(writes_table_with_unresolved_trigger) > 0
          OR jsonb_array_length(unresolved_effect_markers_transitive) > 0
          OR uses_execute OR reaches_execute) AS needs_manual_review,
         (jsonb_array_length(due_input_writes_transitive) > 0 OR jsonb_array_length(due_input_writes_indirect) > 0) AS can_write_due_input
  FROM rep
)
SELECT jsonb_build_object(
  'run', 'W1',
  'routine_count', (SELECT count(*) FROM r),
  'unreadable_routine_count', (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace JOIN pg_language l ON l.oid = p.prolang
                               WHERE n.nspname = 'public' AND p.prokind IN ('f', 'p') AND l.lanname NOT IN ('plpgsql', 'sql')),
  'language_counts', (SELECT COALESCE(jsonb_object_agg(lanname, c), '{}'::jsonb) FROM (SELECT lanname, count(*) AS c FROM r GROUP BY lanname) x),
  'frontend_names_expected', (SELECT count(*) FROM fe),
  'frontend_names_missing', (SELECT COALESCE(jsonb_agg(fe.name ORDER BY fe.name), '[]'::jsonb) FROM fe WHERE NOT EXISTS (SELECT 1 FROM r WHERE r.proname = fe.name)),
  'routines_that_can_write_a_due_input_table', (SELECT count(*) FROM rep2 WHERE can_write_due_input),
  'frontend_routines_needing_manual_review', (SELECT count(*) FROM rep2 WHERE called_from_frontend AND needs_manual_review)
                                            + (SELECT count(*) FROM fe WHERE NOT EXISTS (SELECT 1 FROM r WHERE r.proname = fe.name)),
  'manifest_preconditions', jsonb_build_object(
      'frontend_names_missing', (SELECT COALESCE(jsonb_agg(fe.name ORDER BY fe.name), '[]'::jsonb) FROM fe WHERE NOT EXISTS (SELECT 1 FROM r WHERE r.proname = fe.name)),
      'rules_on_public_relations_other_than_views', (SELECT COALESCE(jsonb_agg(item ORDER BY item), '[]'::jsonb) FROM urules),
      'policies_calling_public_routines', (SELECT COALESCE(jsonb_agg(item ORDER BY item), '[]'::jsonb) FROM prp),
      'rule', 'every list must be empty, or each entry cleared by hand and recorded, before ANY frontend routine is classified not-due-changing'),
  'routines_using_execute', (SELECT count(*) FROM rep2 WHERE uses_execute),
  'tables_with_unresolved_trigger', (SELECT COALESCE(jsonb_agg(tbl ORDER BY tbl), '[]'::jsonb) FROM utr),
  'table_effect_edges_reaching_a_due_input_table', (SELECT COALESCE(jsonb_agg(jsonb_build_object('src', e.src, 'dst', e.dst, 'via', e.via) ORDER BY e.src, e.dst, e.via), '[]'::jsonb)
                                                    FROM tedge e WHERE EXISTS (SELECT 1 FROM tclose c WHERE c.src = e.dst AND c.dst IN (SELECT tbl FROM due))),
  'routines', (SELECT COALESCE(jsonb_agg(x ORDER BY x->>'name', x->>'args'), '[]'::jsonb)
               FROM (
                 SELECT jsonb_build_object(
                  'name', proname, 'args', args, 'readable_routine_found', true, 'security_definer', prosecdef, 'language', lanname,
                  'called_from_frontend', called_from_frontend, 'own_writes', own_writes,
                  'due_input_writes_transitive', due_input_writes_transitive,
                  'due_input_writes_indirect', due_input_writes_indirect,
                  'loose_write_leads_transitive', loose_write_leads_transitive,
                  'non_public_calls_transitive', non_public_calls_transitive,
                  'unreadable_callees_transitive', unreadable_callees_transitive,
                  'unresolved_effect_markers_transitive', unresolved_effect_markers_transitive,
                  'writes_table_with_unresolved_trigger', writes_table_with_unresolved_trigger,
                  'uses_execute', uses_execute, 'reaches_execute', reaches_execute,
                  'reaches_profiles_write_naming_course_level_or_timezone', reaches_profiles_write_naming_course_level_or_timezone,
                  'needs_manual_review', needs_manual_review) AS x
                 FROM rep2
                 WHERE called_from_frontend OR can_write_due_input OR needs_manual_review
                 UNION ALL
                 SELECT jsonb_build_object('name', fe.name, 'args', '', 'readable_routine_found', false, 'called_from_frontend', true, 'needs_manual_review', true)
                 FROM fe WHERE NOT EXISTS (SELECT 1 FROM r WHERE r.proname = fe.name)
               ) q)
) AS result;
