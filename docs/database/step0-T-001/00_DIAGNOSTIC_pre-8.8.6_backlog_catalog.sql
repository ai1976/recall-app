-- Name: [DIAGNOSTIC] T-001 Step 0 (v2) - live catalog + data facts for the pre-8.8.6 backlog
--
-- Description: READ-ONLY. Confirms against the LIVE database the database-side claims in
-- docs/discussions/T-001 that could only be inferred from repo files (CLAUDE.md rule: the
-- existence, absence or behaviour of a DB object is never concluded from code or docs alone).
-- v2 (Round 4) answers QA's Round 3 blocking findings:
--   * No free-text user values are ever selected: only counts, schema metadata and function
--     source. (Finding 1)
--   * RUN 8 is an exact row-level comparison of the forecast predicate against the Review page's
--     enrollment boundary, using each student's own timezone date. (Finding 2)
--   * RUN 1B includes get_due_forecast_buckets (the Dashboard Forward Load). (Finding 3)
--   * RUN 5B is a bounded catalog inventory (all public table names, course-related columns,
--     keys, constraints) so "no registry / no custom-course entity" can be tested, and RUN 6
--     covers the live study_group_members model. (Finding 4)
--
-- HOW TO RUN (10 runs). Each RUN is ONE statement that returns ONE row with ONE column named
-- `result` (json). In the Supabase SQL Editor: select the text of a single RUN (from its SELECT/WITH
-- to its closing semicolon), click Run, then copy the single result cell. Paste each result into the
-- Claude chat, saying which RUN it is; Claude saves it under docs/discussions/evidence/.
-- If a RUN returns an error, paste the error text instead; do not modify the query.
-- Environment: production. Record the execution date.
-- Nothing here writes data, changes schema, or calls an application function.

-- ============================================================================
-- RUN 1A. Live function bodies: batch, join, removal, access-request functions
-- ============================================================================
SELECT jsonb_agg(jsonb_build_object(
         'name', p.proname,
         'args', pg_get_function_identity_arguments(p.oid),
         'security_definer', p.prosecdef,
         'definition', pg_get_functiondef(p.oid)
       ) ORDER BY p.proname) AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'remove_group_member', 'leave_group', 'get_group_detail',
    'join_group_by_token', 'get_group_preview',
    'get_admin_pending_batch_requests', 'approve_batch_join_request', 'reject_batch_join_request',
    'enroll_user_in_batch_group', 'admin_bulk_resolve_batch_requests', 'get_admin_batch_groups',
    'admin_grant_access', 'submit_access_request', 'link_access_request', 'admin_read_profiles'
  );

-- ============================================================================
-- RUN 1B. Live function bodies: due / queue / forecast / heatmap / My Cards
-- ============================================================================
SELECT jsonb_agg(jsonb_build_object(
         'name', p.proname,
         'args', pg_get_function_identity_arguments(p.oid),
         'security_definer', p.prosecdef,
         'definition', pg_get_functiondef(p.oid)
       ) ORDER BY p.proname) AS result
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'get_due_forecast', 'get_due_forecast_buckets', 'get_study_queue',
    'get_my_cards', 'add_to_my_cards', 'remove_from_my_cards',
    'get_study_heatmap'
  );

-- ============================================================================
-- RUN 2. EXECUTE grants on every function inspected in RUN 1A and 1B
-- ============================================================================
SELECT jsonb_agg(jsonb_build_object(
         'function', routine_name, 'grantee', grantee, 'privilege', privilege_type
       ) ORDER BY routine_name, grantee) AS result
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name IN (
    'remove_group_member', 'leave_group', 'get_group_detail',
    'join_group_by_token', 'get_group_preview',
    'get_admin_pending_batch_requests', 'approve_batch_join_request', 'reject_batch_join_request',
    'enroll_user_in_batch_group', 'admin_bulk_resolve_batch_requests', 'get_admin_batch_groups',
    'admin_grant_access', 'submit_access_request', 'link_access_request', 'admin_read_profiles',
    'get_due_forecast', 'get_due_forecast_buckets', 'get_study_queue',
    'get_my_cards', 'add_to_my_cards', 'remove_from_my_cards', 'get_study_heatmap'
  );

-- ============================================================================
-- RUN 3. study_sessions: columns, ALL constraints, indexes, RLS, grants, source mix
-- ============================================================================
SELECT jsonb_build_object(
  'columns', (SELECT jsonb_agg(jsonb_build_object(
                'column', column_name, 'type', data_type, 'nullable', is_nullable, 'default', column_default
              ) ORDER BY ordinal_position)
              FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name = 'study_sessions'),
  'constraints', (SELECT jsonb_agg(jsonb_build_object(
                'name', conname, 'type', contype::text,
                'definition', pg_get_constraintdef(oid), 'validated', convalidated
              ) ORDER BY conname)
              FROM pg_constraint WHERE conrelid = 'public.study_sessions'::regclass),
  'indexes', (SELECT jsonb_agg(jsonb_build_object('name', indexname, 'definition', indexdef) ORDER BY indexname)
              FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'study_sessions'),
  'policies', (SELECT jsonb_agg(jsonb_build_object(
                'name', policyname, 'cmd', cmd, 'roles', roles, 'using', qual, 'check', with_check))
              FROM pg_policies WHERE schemaname = 'public' AND tablename = 'study_sessions'),
  'grants', (SELECT jsonb_agg(jsonb_build_object('grantee', grantee, 'privilege', privilege_type)
                ORDER BY grantee, privilege_type)
              FROM information_schema.role_table_grants
              WHERE table_schema = 'public' AND table_name = 'study_sessions'),
  'source_category_mix', (SELECT jsonb_agg(jsonb_build_object(
                'source', source, 'has_category', has_cat, 'rows', n, 'hours', hrs
              ) ORDER BY source, has_cat)
              FROM (SELECT CASE WHEN source IN ('manual', 'study_mode', 'practice_mode')
                                THEN source ELSE 'unexpected_other' END AS source,
                           (category IS NOT NULL) AS has_cat, count(*) AS n,
                           round(sum(duration_seconds) / 3600.0, 1) AS hrs
                    FROM public.study_sessions GROUP BY 1, 2) s)
) AS result;

-- ============================================================================
-- RUN 4. Triggers in the public schema: broad scan, two independent methods
-- ============================================================================
SELECT jsonb_build_object(
  'information_schema_triggers',
    (SELECT jsonb_agg(jsonb_build_object(
        'trigger', trigger_name, 'table', event_object_table,
        'event', event_manipulation, 'timing', action_timing
      ) ORDER BY event_object_table, trigger_name)
     FROM information_schema.triggers WHERE trigger_schema = 'public'),
  'pg_trigger_non_internal',
    (SELECT jsonb_agg(jsonb_build_object(
        'table', c.relname, 'trigger', t.tgname, 'enabled', t.tgenabled::text, 'function', p.proname
      ) ORDER BY c.relname, t.tgname)
     FROM pg_trigger t
     JOIN pg_class c ON c.oid = t.tgrelid
     JOIN pg_namespace n ON n.oid = c.relnamespace
     JOIN pg_proc p ON p.oid = t.tgfoid
     WHERE n.nspname = 'public' AND NOT t.tgisinternal)
) AS result;

-- ============================================================================
-- RUN 5A. Course identity: privacy-safe aggregates ONLY (no free-text value is selected)
-- ============================================================================
WITH d AS (SELECT array_agg(name) AS names FROM public.disciplines)
SELECT jsonb_build_object(
  'platform_courses', (SELECT jsonb_agg(jsonb_build_object(
                'name', x.name, 'code', x.code, 'is_active', x.is_active,
                'subjects', (SELECT count(*) FROM public.subjects s WHERE s.discipline_id = x.id)
              ) ORDER BY x.order_num, x.name) FROM public.disciplines x),
  'profiles_course_level', (SELECT jsonb_build_object(
                'total_profiles', count(*),
                'null_or_blank', count(*) FILTER (WHERE p.course_level IS NULL OR btrim(p.course_level) = ''),
                'equals_a_platform_course_name', count(*) FILTER (WHERE p.course_level = ANY (d.names)),
                'other_nonblank', count(*) FILTER (WHERE btrim(coalesce(p.course_level, '')) <> ''
                                                   AND NOT (p.course_level = ANY (d.names))),
                'distinct_other_values', count(DISTINCT p.course_level) FILTER (WHERE btrim(coalesce(p.course_level, '')) <> ''
                                                   AND NOT (p.course_level = ANY (d.names)))
              ) FROM public.profiles p CROSS JOIN d),
  'flashcards_course_columns', (SELECT jsonb_build_object(
                'total_cards', count(*),
                'target_course_null', count(*) FILTER (WHERE f.target_course IS NULL),
                'target_course_equals_platform_name', count(*) FILTER (WHERE f.target_course = ANY (d.names)),
                'target_course_other', count(*) FILTER (WHERE f.target_course IS NOT NULL AND NOT (f.target_course = ANY (d.names))),
                'with_subject_id', count(*) FILTER (WHERE f.subject_id IS NOT NULL),
                'with_custom_subject_text', count(*) FILTER (WHERE btrim(coalesce(to_jsonb(f)->>'custom_subject', '')) <> ''),
                'with_custom_course_text', count(*) FILTER (WHERE btrim(coalesce(to_jsonb(f)->>'custom_course', '')) <> ''),
                'distinct_custom_subject_normalised', count(DISTINCT lower(btrim(to_jsonb(f)->>'custom_subject')))
                                                      FILTER (WHERE btrim(coalesce(to_jsonb(f)->>'custom_subject', '')) <> '')
              ) FROM public.flashcards f CROSS JOIN d),
  'notes_course_columns', (SELECT jsonb_build_object(
                'total_notes', count(*),
                'target_course_null', count(*) FILTER (WHERE n.target_course IS NULL),
                'target_course_equals_platform_name', count(*) FILTER (WHERE n.target_course = ANY (d.names)),
                'target_course_other', count(*) FILTER (WHERE n.target_course IS NOT NULL AND NOT (n.target_course = ANY (d.names))),
                'with_subject_id', count(*) FILTER (WHERE n.subject_id IS NOT NULL),
                'with_custom_subject_text', count(*) FILTER (WHERE btrim(coalesce(to_jsonb(n)->>'custom_subject', '')) <> ''),
                'with_custom_course_text', count(*) FILTER (WHERE btrim(coalesce(to_jsonb(n)->>'custom_course', '')) <> ''),
                'distinct_custom_course_normalised', count(DISTINCT lower(btrim(to_jsonb(n)->>'custom_course')))
                                                     FILTER (WHERE btrim(coalesce(to_jsonb(n)->>'custom_course', '')) <> '')
              ) FROM public.notes n CROSS JOIN d),
  'profile_courses', jsonb_build_object(
      'columns', (SELECT jsonb_agg(jsonb_build_object('column', column_name, 'type', data_type, 'nullable', is_nullable)
                    ORDER BY ordinal_position)
                  FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'profile_courses'),
      'users_and_rows_by_role', (SELECT jsonb_agg(jsonb_build_object('role', role, 'users', users, 'rows', n))
                  FROM (SELECT CASE WHEN p.role IN ('student', 'professor', 'admin', 'super_admin')
                                THEN p.role ELSE 'unexpected_other' END AS role,
                           count(DISTINCT pc.user_id) AS users, count(*) AS n
                        FROM public.profile_courses pc JOIN public.profiles p ON p.id = pc.user_id
                        GROUP BY 1) s)
  )
) AS result;

-- ============================================================================
-- RUN 5B. Bounded catalog inventory for course identity (schema metadata only)
-- ============================================================================
SELECT jsonb_build_object(
  'all_public_tables', (SELECT jsonb_agg(table_name ORDER BY table_name)
                        FROM information_schema.tables
                        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'),
  'course_related_columns', (SELECT jsonb_agg(jsonb_build_object(
                'table', table_name, 'column', column_name, 'type', data_type
              ) ORDER BY table_name, column_name)
              FROM information_schema.columns
              WHERE table_schema = 'public'
                AND column_name ~* '(course|discipline|subject|curriculum|exam|level)'),
  'foreign_keys_to_disciplines_or_subjects', (SELECT jsonb_agg(jsonb_build_object(
                'table', conrelid::regclass::text, 'name', conname, 'definition', pg_get_constraintdef(oid)
              ) ORDER BY conrelid::regclass::text, conname)
              FROM pg_constraint
              WHERE contype = 'f'
                AND confrelid IN ('public.disciplines'::regclass, 'public.subjects'::regclass)),
  'check_constraints_mentioning_course_or_subject', (SELECT jsonb_agg(jsonb_build_object(
                'table', c.conrelid::regclass::text, 'name', c.conname, 'definition', pg_get_constraintdef(c.oid)
              ) ORDER BY c.conrelid::regclass::text, c.conname)
              FROM pg_constraint c
              JOIN pg_namespace n ON n.oid = c.connamespace
              WHERE n.nspname = 'public' AND c.contype = 'c'
                AND pg_get_constraintdef(c.oid) ~* '(course|subject|discipline)'),
  -- Full structure of every table whose NAME looks course-related (so a registry table with generic
  -- columns such as id / name / user_id is still found), including PK, UNIQUE, FK and CHECK constraints.
  'course_named_tables', (SELECT jsonb_agg(jsonb_build_object(
                'table', t.relname,
                'columns', (SELECT jsonb_agg(jsonb_build_object(
                              'column', a.attname, 'type', format_type(a.atttypid, a.atttypmod),
                              'not_null', a.attnotnull) ORDER BY a.attnum)
                            FROM pg_attribute a
                            WHERE a.attrelid = t.oid AND a.attnum > 0 AND NOT a.attisdropped),
                'constraints', (SELECT jsonb_agg(jsonb_build_object(
                              'name', k.conname, 'type', k.contype::text,
                              'definition', pg_get_constraintdef(k.oid)) ORDER BY k.conname)
                            FROM pg_constraint k WHERE k.conrelid = t.oid),
                'indexes', (SELECT jsonb_agg(jsonb_build_object(
                              'name', i.indexname, 'definition', i.indexdef) ORDER BY i.indexname)
                            FROM pg_indexes i
                            WHERE i.schemaname = 'public' AND i.tablename = t.relname)
              ) ORDER BY t.relname)
              FROM pg_class t
              JOIN pg_namespace tn ON tn.oid = t.relnamespace
              WHERE tn.nspname = 'public' AND t.relkind = 'r'
                AND (t.relname ~* '(course|discipline|subject|curriculum|exam|level|program|qualification)'
                     OR t.relname IN ('profile_courses', 'disciplines', 'subjects'))),
  'foreign_keys_referencing_course_named_tables', (SELECT jsonb_agg(jsonb_build_object(
                'table', k.conrelid::regclass::text, 'name', k.conname,
                'definition', pg_get_constraintdef(k.oid)
              ) ORDER BY k.conrelid::regclass::text, k.conname)
              FROM pg_constraint k
              WHERE k.contype = 'f'
                AND k.confrelid IN (
                  SELECT t.oid FROM pg_class t JOIN pg_namespace tn ON tn.oid = t.relnamespace
                  WHERE tn.nspname = 'public' AND t.relkind = 'r'
                    AND (t.relname ~* '(course|discipline|subject|curriculum|exam|level|program|qualification)'
                         OR t.relname IN ('profile_courses', 'disciplines', 'subjects'))))
) AS result;

-- ============================================================================
-- RUN 6. Batch membership live model: structure, constraints, RLS, state counts (no names)
-- ============================================================================
SELECT jsonb_build_object(
  'columns', (SELECT jsonb_agg(jsonb_build_object(
                'table', table_name, 'column', column_name, 'type', data_type, 'nullable', is_nullable, 'default', column_default
              ) ORDER BY table_name, ordinal_position)
              FROM information_schema.columns
              WHERE table_schema = 'public' AND table_name IN ('study_group_members', 'study_groups')),
  'constraints', (SELECT jsonb_agg(jsonb_build_object(
                'table', conrelid::regclass::text, 'name', conname, 'type', contype::text,
                'definition', pg_get_constraintdef(oid)
              ) ORDER BY conrelid::regclass::text, conname)
              FROM pg_constraint
              WHERE conrelid IN ('public.study_group_members'::regclass, 'public.study_groups'::regclass)),
  'indexes', (SELECT jsonb_agg(jsonb_build_object('table', tablename, 'name', indexname, 'definition', indexdef)
                ORDER BY tablename, indexname)
              FROM pg_indexes
              WHERE schemaname = 'public' AND tablename IN ('study_group_members', 'study_groups')),
  'policies', (SELECT jsonb_agg(jsonb_build_object(
                'table', tablename, 'name', policyname, 'cmd', cmd, 'roles', roles, 'using', qual, 'check', with_check
              ) ORDER BY tablename, policyname)
              FROM pg_policies
              WHERE schemaname = 'public'
                AND tablename IN ('study_group_members', 'study_groups', 'admin_audit_log')),
  'status_role_counts_by_group_kind', (SELECT jsonb_agg(jsonb_build_object(
                'is_batch_group', is_batch_group, 'status', status, 'role', role, 'rows', n
              ) ORDER BY is_batch_group, status, role)
              FROM (SELECT sg.is_batch_group,
                           CASE WHEN sgm.status IN ('invited', 'active', 'requested', 'closed')
                                THEN sgm.status ELSE 'unexpected_other' END AS status,
                           CASE WHEN sgm.role IN ('admin', 'member')
                                THEN sgm.role ELSE 'unexpected_other' END AS role,
                           count(*) AS n
                    FROM public.study_group_members sgm
                    JOIN public.study_groups sg ON sg.id = sgm.group_id
                    GROUP BY 1, 2, 3) s),
  'batch_group_admin_members_by_platform_role', (SELECT jsonb_agg(jsonb_build_object(
                'platform_role', platform_role, 'status', status, 'rows', n
              ) ORDER BY platform_role, status)
              FROM (SELECT CASE WHEN p.role IN ('student', 'professor', 'admin', 'super_admin')
                                THEN p.role ELSE 'unexpected_other' END AS platform_role,
                           CASE WHEN sgm.status IN ('invited', 'active', 'requested', 'closed')
                                THEN sgm.status ELSE 'unexpected_other' END AS status,
                           count(*) AS n
                    FROM public.study_group_members sgm
                    JOIN public.study_groups sg ON sg.id = sgm.group_id AND sg.is_batch_group
                    JOIN public.profiles p ON p.id = sgm.user_id
                    WHERE sgm.role = 'admin'
                    GROUP BY 1, 2) s),
  -- admin_audit_log.action is unbounded stored text: only the action names already known from the repo
  -- are returned literally; anything else is reported as a COUNT, never as a value.
  'audit_actions_related_to_batches_or_members', jsonb_build_object(
      'known_actions', (SELECT jsonb_object_agg(a, n)
                FROM (SELECT action AS a, count(*) AS n FROM public.admin_audit_log
                      WHERE action IN ('add_to_batch', 'admin_bulk_add_to_batch', 'bulk_add_to_batch',
                                       'approve_batch_join_request', 'reject_batch_join_request',
                                       'bulk_approve_batch_requests', 'bulk_reject_batch_requests',
                                       'create_batch_group', 'archive_batch_group', 'restore_batch_group',
                                       'assign_professor_to_batch', 'unassign_professor_from_batch',
                                       'remove_group_member')
                      GROUP BY action) k),
      'unexpected_other_batch_or_member_actions', (SELECT count(*) FROM public.admin_audit_log
                WHERE (action ILIKE '%batch%' OR action ILIKE '%member%')
                  AND action NOT IN ('add_to_batch', 'admin_bulk_add_to_batch', 'bulk_add_to_batch',
                                     'approve_batch_join_request', 'reject_batch_join_request',
                                     'bulk_approve_batch_requests', 'bulk_reject_batch_requests',
                                     'create_batch_group', 'archive_batch_group', 'restore_batch_group',
                                     'assign_professor_to_batch', 'unassign_professor_from_batch',
                                     'remove_group_member')),
      'unexpected_other_removal_like_actions', (SELECT count(*) FROM public.admin_audit_log
                WHERE action ILIKE '%remov%' AND action <> 'remove_group_member')
  )
) AS result;

-- ============================================================================
-- RUN 7. Access requests and account_type (structure and counts only; no names or emails)
-- ============================================================================
SELECT jsonb_build_object(
  'access_requests_columns', (SELECT jsonb_agg(jsonb_build_object('column', column_name, 'type', data_type, 'nullable', is_nullable)
                ORDER BY ordinal_position)
              FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'access_requests'),
  'access_requests_constraints', (SELECT jsonb_agg(jsonb_build_object('name', conname, 'type', contype::text,
                'definition', pg_get_constraintdef(oid)) ORDER BY conname)
              FROM pg_constraint WHERE conrelid = 'public.access_requests'::regclass),
  'access_requests_policies', (SELECT jsonb_agg(jsonb_build_object('name', policyname, 'cmd', cmd, 'roles', roles,
                'using', qual, 'check', with_check) ORDER BY policyname)
              FROM pg_policies WHERE schemaname = 'public' AND tablename = 'access_requests'),
  -- Stored text columns are bucketed to the values the repo says are allowed; anything else is
  -- reported as 'unexpected_other' (a count), never as a literal. The CHECK definitions above show
  -- the real allowed lists.
  'access_requests_by_status', (SELECT jsonb_agg(jsonb_build_object('status', st, 'rows', n) ORDER BY n DESC)
              FROM (SELECT CASE WHEN to_jsonb(a)->>'status' IN ('pending', 'contacted', 'enrolled',
                                                                'approved', 'rejected', 'dismissed')
                                THEN to_jsonb(a)->>'status' ELSE 'unexpected_other' END AS st,
                           count(*) AS n
                    FROM public.access_requests a GROUP BY 1) s),
  'access_requests_by_request_type', (SELECT jsonb_agg(jsonb_build_object('request_type', rt, 'rows', n) ORDER BY n DESC)
              FROM (SELECT CASE WHEN to_jsonb(a)->>'request_type' IN ('student_access', 'institute_inquiry',
                                                                      'educator_application')
                                THEN to_jsonb(a)->>'request_type' ELSE 'unexpected_other' END AS rt,
                           count(*) AS n
                    FROM public.access_requests a GROUP BY 1) s),
  'profiles_by_account_type_and_role', (SELECT jsonb_agg(jsonb_build_object(
                'account_type', account_type, 'role', role, 'profiles', n
              ) ORDER BY n DESC)
              FROM (SELECT CASE WHEN account_type IN ('self_registered', 'enrolled')
                                THEN account_type ELSE 'unexpected_other' END AS account_type,
                           CASE WHEN role IN ('student', 'professor', 'admin', 'super_admin')
                                THEN role ELSE 'unexpected_other' END AS role,
                           count(*) AS n
                    FROM public.profiles GROUP BY 1, 2) s)
) AS result;

-- ============================================================================
-- RUN 8. Point 6, exact comparison (counts only). Row-level, per-student timezone date.
--   "Badge set"  = rows satisfying the get_due_forecast.due_today predicate (repo copy
--                  srs-ladder/02:410-476), reproduced here. RUN 1B shows the live bodies; if the
--                  live get_due_forecast or get_my_cards differs from the repo copies this result
--                  must be re-derived, so compare before relying on it.
--   "Review set" = badge rows that also have an ACTIVE My Cards enrollment (get_my_cards v2,
--                  sprint8.7.10/02: own cards need an active enrollment too; visibility rule is
--                  the same as the forecast's).
-- ============================================================================
WITH p AS (
  SELECT pr.id AS user_id, pr.course_level,
         (now() AT TIME ZONE COALESCE(pr.timezone, 'Asia/Kolkata'))::date AS today
  FROM public.profiles pr
),
due AS (
  SELECT r.user_id, r.flashcard_id
  FROM public.reviews r
  JOIN p ON p.user_id = r.user_id
  JOIN public.flashcards f ON f.id = r.flashcard_id
  WHERE r.status = 'active'
    AND r.next_review_date <= p.today
    AND (r.skip_until IS NULL OR r.skip_until <= p.today)
    AND f.question_type <> 'concept_card'
    AND (p.course_level IS NULL OR f.target_course IS NULL OR f.target_course = p.course_level)
    AND (
      f.user_id = r.user_id
      OR f.visibility = 'public'
      OR (f.visibility = 'friends' AND EXISTS (
            SELECT 1 FROM public.friendships fr
            WHERE fr.status = 'accepted'
              AND ((fr.user_id = r.user_id AND fr.friend_id = f.user_id)
                OR (fr.friend_id = r.user_id AND fr.user_id = f.user_id))))
    )
),
classified AS (
  SELECT d.user_id, d.flashcard_id, f.user_id = d.user_id AS is_own_card,
         CASE WHEN e.status IS NULL THEN 'no_enrollment_row'
              WHEN e.status IN ('active', 'removed', 'course_archived') THEN e.status
              ELSE 'unexpected_other' END AS enrollment_state
  FROM due d
  JOIN public.flashcards f ON f.id = d.flashcard_id
  LEFT JOIN public.my_cards_enrollment e ON e.user_id = d.user_id AND e.flashcard_id = d.flashcard_id
)
SELECT jsonb_build_object(
  'students_with_badge_rows', (SELECT count(DISTINCT user_id) FROM classified),
  'badge_rows', (SELECT count(*) FROM classified),
  'review_page_rows', (SELECT count(*) FROM classified WHERE enrollment_state = 'active'),
  'mismatch_rows', (SELECT count(*) FROM classified WHERE enrollment_state <> 'active'),
  'students_with_mismatch', (SELECT count(DISTINCT user_id) FROM classified WHERE enrollment_state <> 'active'),
  'mismatch_rows_by_enrollment_state', (SELECT jsonb_object_agg(enrollment_state, n)
        FROM (SELECT enrollment_state, count(*) AS n FROM classified
              WHERE enrollment_state <> 'active' GROUP BY 1) s),
  'mismatch_rows_that_are_own_cards', (SELECT count(*) FROM classified
        WHERE enrollment_state <> 'active' AND is_own_card)
) AS result;
