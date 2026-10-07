-- Name: [DIAGNOSTIC] T-001 brief C slice 1 pre-check (v1) - live baseline of the forecast, queue and heatmap functions and the tables C-01 and C-02 rely on
--
-- Description: READ-ONLY. The pre-check required before the slice 1 SQL files C-01 and C-02 (brief C v6, 20647dbce877, Gate 1 given by the Founder on
-- 07/10/2026) are executed. Two jobs: (1) capture, from the live catalog, the exact current definitions and ACLs of get_due_forecast and
-- get_due_forecast_buckets, so that the ROLLBACK file of C-01 can be compared with them byte for byte (the saved RUN 1B text is a transcription,
-- not byte-identical to the live cell, so it is not a safe rollback source by itself), and confirm that the new routine names do not already exist;
-- (2) confirm the facts the new SQL assumes, from the catalog and not from repository documents (CLAUDE.md database rules): the columns, unique
-- constraints and check constraints it reads, and a few aggregate counts that decide what the TEST files can and cannot cover.
-- What it returns (one row, one jsonb column named `result`, per run):
--   * P1 (catalog): for get_due_forecast, get_due_forecast_buckets, get_study_queue, get_my_cards, get_study_heatmap, is_admin and for any routine named
--     fn_due_eligible_dates or get_study_heatmap_split in schema public: identity, owner, language, SECURITY DEFINER flag, volatility, function
--     configuration, the list of every role holding EXECUTE (PUBLIC shown as PUBLIC), the md5 of the definition, and the FULL definition of
--     get_due_forecast and get_due_forecast_buckets only. For the tables my_cards_enrollment, reviews, flashcards, friendships, profiles,
--     study_sessions and user_activity_log: the columns the new SQL reads (type, NOT NULL), the primary key, unique constraints and unique indexes,
--     and every CHECK constraint on study_sessions and my_cards_enrollment. Expected-versus-found counts and named missing columns are returned.
--   * P2 (counts only, no identities): study_sessions rows by source (every distinct value, no per-user data); rows whose session_date is later than the
--     profile's local today (the new heatmap window has no days after today, brief C C-7.3); rows older than 400 days; the number of profiles, of
--     profiles with role admin or super_admin (the TEST files need at least one), of users with at least one review; the number of distinct profile
--     time zones and the smallest and largest current UTC offset in hours among them; the number of profiles with a null or unlisted time zone;
--     reviews by status; my_cards_enrollment by status; reviews rows with an enrollment row of each status and with none; active reviews with a skip_until
--     in the past, today and the future (by the profile's local today); flashcards by visibility and by whether question_type is concept_card or null.
--     No user id, card id, text or per-user figure is returned.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control, dynamic SQL or application-function call.
-- Only catalog views and functions and plain reads of the application tables are used.
-- Blind spots, stated: counts are one statement's view at its run time (P1 and P2 are separate statements); the SQL Editor role bypasses student RLS,
-- which is intended; the md5 of a definition covers the text pg_get_functiondef returns, which is the text the ROLLBACK file must reproduce.
--
-- HOW TO RUN (two runs): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and paste
-- it into one Notepad file under its label (P1, P2), unchanged. Save the file as docs/discussions/evidence/T-001_C-slice1-precheck-raw_<dd-mm-yyyy>.raw.txt
-- and keep it untouched; the derived .json files are made from it by script. An error is evidence: save the error text under its label, do not
-- edit and re-run (stop and report instead).
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ===== RUN P1: catalog baseline =====
WITH fns AS (
  SELECT p.oid, n.nspname, p.proname, pg_get_function_identity_arguments(p.oid) AS args,
         p.proowner AS ownerid, pg_get_userbyid(p.proowner) AS owner, l.lanname AS language, p.prosecdef, p.provolatile, p.proconfig, p.proacl
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  JOIN pg_language l ON l.oid = p.prolang
  WHERE n.nspname = 'public'
    AND p.proname IN ('get_due_forecast', 'get_due_forecast_buckets', 'get_study_queue', 'get_my_cards', 'get_study_heatmap',
                      'is_admin', 'fn_due_eligible_dates', 'get_study_heatmap_split')
    AND p.prokind = 'f'
),
cols(tbl, col) AS (
  VALUES ('my_cards_enrollment', 'user_id'), ('my_cards_enrollment', 'flashcard_id'), ('my_cards_enrollment', 'status'),
         ('reviews', 'user_id'), ('reviews', 'flashcard_id'), ('reviews', 'status'), ('reviews', 'next_review_date'),
         ('reviews', 'skip_until'), ('reviews', 'created_at'),
         ('flashcards', 'id'), ('flashcards', 'user_id'), ('flashcards', 'visibility'), ('flashcards', 'question_type'),
         ('flashcards', 'target_course'),
         ('friendships', 'user_id'), ('friendships', 'friend_id'), ('friendships', 'status'),
         ('profiles', 'id'), ('profiles', 'timezone'), ('profiles', 'course_level'), ('profiles', 'role'),
         ('study_sessions', 'user_id'), ('study_sessions', 'session_date'), ('study_sessions', 'duration_seconds'), ('study_sessions', 'source'),
         ('user_activity_log', 'user_id'), ('user_activity_log', 'activity_type'), ('user_activity_log', 'activity_date')
),
fnd AS (
  SELECT c.tbl, c.col, a.atttypid IS NOT NULL AS exists_, format_type(a.atttypid, a.atttypmod) AS type, a.attnotnull
  FROM cols c
  LEFT JOIN pg_class k ON k.relname = c.tbl AND k.relnamespace = 'public'::regnamespace AND k.relkind = 'r'
  LEFT JOIN pg_attribute a ON a.attrelid = k.oid AND a.attname = c.col AND a.attnum > 0 AND NOT a.attisdropped
),
tbls AS (
  SELECT k.oid, k.relname FROM pg_class k
  WHERE k.relnamespace = 'public'::regnamespace AND k.relkind = 'r'
    AND k.relname IN ('my_cards_enrollment', 'reviews', 'flashcards', 'friendships', 'profiles', 'study_sessions', 'user_activity_log')
)
SELECT jsonb_build_object(
  'run', 'P1',
  'functions', (SELECT jsonb_agg(jsonb_build_object(
                  'identity', f.nspname || '.' || f.proname || '(' || f.args || ')',
                  'owner', f.owner, 'language', f.language, 'security_definer', f.prosecdef, 'volatility', f.provolatile,
                  'config', f.proconfig,
                  'execute_roles', (SELECT COALESCE(jsonb_agg(DISTINCT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee) END), '[]'::jsonb)
                                    FROM aclexplode(COALESCE(f.proacl, acldefault('f', f.ownerid))) x
                                    WHERE x.privilege_type = 'EXECUTE'),
                  'definition_md5', md5(pg_get_functiondef(f.oid)),
                  'definition', CASE WHEN f.proname IN ('get_due_forecast', 'get_due_forecast_buckets') THEN pg_get_functiondef(f.oid) END)
                  ORDER BY f.proname, f.args)
                FROM fns f),
  'new_routine_names_already_present', (SELECT COALESCE(jsonb_agg(f.proname || '(' || f.args || ')'), '[]'::jsonb)
                                        FROM fns f WHERE f.proname IN ('fn_due_eligible_dates', 'get_study_heatmap_split')),
  'columns_expected_count', (SELECT count(*) FROM cols),
  'columns_found_count', (SELECT count(*) FROM fnd WHERE exists_),
  'columns_missing', (SELECT COALESCE(jsonb_agg(tbl || '.' || col ORDER BY tbl, col), '[]'::jsonb) FROM fnd WHERE NOT exists_),
  'columns', (SELECT jsonb_agg(jsonb_build_object('table', tbl, 'column', col, 'type', type, 'not_null', attnotnull) ORDER BY tbl, col)
              FROM fnd WHERE exists_),
  'primary_and_unique_constraints', (SELECT jsonb_agg(jsonb_build_object('table', t.relname, 'name', k.conname, 'type', k.contype,
                                       'definition', pg_get_constraintdef(k.oid)) ORDER BY t.relname, k.conname)
                                     FROM pg_constraint k JOIN tbls t ON t.oid = k.conrelid WHERE k.contype IN ('p', 'u')),
  'unique_indexes', (SELECT jsonb_agg(jsonb_build_object('table', t.relname, 'definition', pg_get_indexdef(i.indexrelid))
                                      ORDER BY t.relname, pg_get_indexdef(i.indexrelid))
                     FROM pg_index i JOIN tbls t ON t.oid = i.indrelid WHERE i.indisunique),
  'check_constraints_study_sessions_and_enrollment', (SELECT jsonb_agg(jsonb_build_object('table', t.relname, 'name', k.conname,
                                       'validated', k.convalidated, 'definition', pg_get_constraintdef(k.oid)) ORDER BY t.relname, k.conname)
                                     FROM pg_constraint k JOIN tbls t ON t.oid = k.conrelid
                                     WHERE k.contype = 'c' AND t.relname IN ('study_sessions', 'my_cards_enrollment'))
) AS result;

-- ===== RUN P2: counts only =====
WITH tzl AS MATERIALIZED (
  SELECT lower(z.name) AS nm, z.utc_offset FROM pg_timezone_names z
),
pr AS (
  SELECT p.id, p.role, p.timezone,
         (p.timezone IS NOT NULL AND lower(p.timezone) IN (SELECT nm FROM tzl)) AS tz_listed,
         CASE WHEN p.timezone IS NOT NULL AND lower(p.timezone) IN (SELECT nm FROM tzl) THEN p.timezone ELSE 'Asia/Kolkata' END AS tz_used
  FROM public.profiles p
),
ss AS (
  SELECT s.user_id, s.session_date, s.source, pr.tz_used,
         (now() AT TIME ZONE pr.tz_used)::date AS local_today
  FROM public.study_sessions s
  LEFT JOIN pr ON pr.id = s.user_id
),
rv AS (
  SELECT r.status, r.skip_until, r.next_review_date, e.status AS enrollment_status,
         (now() AT TIME ZONE COALESCE(pr.tz_used, 'Asia/Kolkata'))::date AS local_today
  FROM public.reviews r
  LEFT JOIN public.my_cards_enrollment e ON e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
  LEFT JOIN pr ON pr.id = r.user_id
)
SELECT jsonb_build_object(
  'run', 'P2',
  'study_sessions_total', (SELECT count(*) FROM ss),
  'study_sessions_by_source', (SELECT COALESCE(jsonb_object_agg(x.source, x.c), '{}'::jsonb)
                               FROM (SELECT source, count(*) AS c FROM ss WHERE source IS NOT NULL GROUP BY source) x),
  'study_sessions_with_null_source', (SELECT count(*) FROM ss WHERE source IS NULL),
  'study_sessions_dated_after_profile_local_today', (SELECT count(*) FROM ss WHERE session_date > local_today),
  'study_sessions_without_profile', (SELECT count(*) FROM ss WHERE tz_used IS NULL),
  'study_sessions_older_than_400_days', (SELECT count(*) FROM ss WHERE session_date < local_today - 400),
  'profiles_total', (SELECT count(*) FROM pr),
  'profiles_admin_or_super_admin', (SELECT count(*) FROM pr WHERE role IN ('admin', 'super_admin')),
  'users_with_a_review', (SELECT count(DISTINCT user_id) FROM public.reviews),
  'profiles_with_null_timezone', (SELECT count(*) FROM pr WHERE timezone IS NULL),
  'profiles_with_unlisted_timezone', (SELECT count(*) FROM pr WHERE timezone IS NOT NULL AND NOT tz_listed),
  'distinct_profile_timezones', (SELECT count(DISTINCT tz_used) FROM pr),
  'utc_offset_hours_min', (SELECT min(extract(epoch FROM t.utc_offset) / 3600) FROM tzl t WHERE t.nm IN (SELECT lower(tz_used) FROM pr)),
  'utc_offset_hours_max', (SELECT max(extract(epoch FROM t.utc_offset) / 3600) FROM tzl t WHERE t.nm IN (SELECT lower(tz_used) FROM pr)),
  'reviews_by_status', (SELECT COALESCE(jsonb_object_agg(x.status, x.c), '{}'::jsonb)
                        FROM (SELECT status, count(*) AS c FROM rv WHERE status IS NOT NULL GROUP BY status) x),
  'enrollment_by_status', (SELECT COALESCE(jsonb_object_agg(x.status, x.c), '{}'::jsonb)
                           FROM (SELECT status, count(*) AS c FROM public.my_cards_enrollment WHERE status IS NOT NULL GROUP BY status) x),
  'reviews_by_enrollment_state', (SELECT COALESCE(jsonb_object_agg(x.st, x.c), '{}'::jsonb)
                                  FROM (SELECT COALESCE(enrollment_status, 'no_enrollment_row') AS st, count(*) AS c FROM rv GROUP BY 1) x),
  'active_reviews_skip_until', jsonb_build_object(
      'null', (SELECT count(*) FROM rv WHERE status = 'active' AND skip_until IS NULL),
      'in_the_past', (SELECT count(*) FROM rv WHERE status = 'active' AND skip_until < local_today),
      'today', (SELECT count(*) FROM rv WHERE status = 'active' AND skip_until = local_today),
      'in_the_future', (SELECT count(*) FROM rv WHERE status = 'active' AND skip_until > local_today)),
  'flashcards_by_visibility', (SELECT COALESCE(jsonb_object_agg(x.v, x.c), '{}'::jsonb)
                               FROM (SELECT COALESCE(visibility, '(null)') AS v, count(*) AS c FROM public.flashcards GROUP BY 1) x),
  'flashcards_concept_card', (SELECT count(*) FROM public.flashcards WHERE question_type = 'concept_card'),
  'flashcards_null_question_type', (SELECT count(*) FROM public.flashcards WHERE question_type IS NULL),
  'friendships_by_status', (SELECT COALESCE(jsonb_object_agg(x.v, x.c), '{}'::jsonb)
                            FROM (SELECT COALESCE(status, '(null)') AS v, count(*) AS c FROM public.friendships GROUP BY 1) x)
) AS result;
