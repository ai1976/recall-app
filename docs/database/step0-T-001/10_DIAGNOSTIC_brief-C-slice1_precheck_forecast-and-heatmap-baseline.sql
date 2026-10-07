-- Name: [DIAGNOSTIC] T-001 brief C slice 1 pre-check (v2) - live baseline of the forecast, queue and heatmap functions and the tables C-01 and C-02 rely on
--
-- Description: READ-ONLY. The pre-check required before the slice 1 SQL files C-01 and C-02 (brief C v6, 20647dbce877, Gate 1 given by the Founder on
-- 07/10/2026) are executed. Two jobs: (1) capture, from the live catalog, the exact current definitions and ACLs of get_due_forecast and
-- get_due_forecast_buckets, so that the ROLLBACK file of C-01 can be compared with them byte for byte (the saved RUN 1B text is a transcription,
-- not byte-identical to the live cell, so it is not a safe rollback source by itself), and confirm that the new routine names do not already exist;
-- (2) confirm the facts the new SQL assumes, from the catalog and not from repository documents (CLAUDE.md database rules): the columns, unique
-- constraints and check constraints it reads, and a few aggregate counts that decide what the TEST files can and cannot cover.
-- v2 (supersedes v1 e0d3cb3fef94, which QA recommended in Round 94 but which was never authorized or run): the pre-check now also settles, BEFORE Gate 2,
-- what QA Round 94 said v1 could not: P1 also returns the default ACLs for functions (so the exact post-C-01 ACLs can be predicted), a deterministically
-- ordered execute-role list per function and a flag whether each of the five application functions has exactly the approved ceiling (authenticated, postgres,
-- service_role); and two new runs measure EXACT coverage: P3 for the C-01 boundary cases (status, enrollment, visibility including pending friendships,
-- concept_card, course, skip_until yesterday, today and tomorrow, a card dated today and one dated in 3 days, the null date, users at exactly +14 h and -12 h)
-- and P4 for the C-02 boundary cases restricted to the days the 90-day window exercises, with the complete upper-end count over ALL THREE sources (study
-- sessions, review activity-log days and active reviews dated after the profile's local today). If P1 does not show the expected columns, a unique
-- (user_id, flashcard_id) enrollment key, the expected CHECK constraints, the expected ACLs, the two new names absent, or if P2 shows no administrator
-- profile, C-01 and C-02 do not go to Gate 2; this file reports those inputs and does not turn an unexpected result into a pass.
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
-- HOW TO RUN (four runs: P1, P2, P3, P4): select the text of ONE run (from its banner line to its closing semicolon), click Run, copy the single result cell, and paste
-- it into one Notepad file under its label (P1, P2, P3, P4), unchanged. Save the file as docs/discussions/evidence/T-001_C-slice1-precheck-raw_<dd-mm-yyyy>.raw.txt
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
                  'execute_roles', (SELECT COALESCE(to_jsonb(array_agg(DISTINCT s.g ORDER BY s.g)), '[]'::jsonb)
                                    FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g
                                          FROM aclexplode(COALESCE(f.proacl, acldefault('f', f.ownerid))) x
                                          WHERE x.privilege_type = 'EXECUTE') s),
                  'execute_roles_exactly_authenticated_postgres_service_role',
                    COALESCE((SELECT array_agg(DISTINCT s.g ORDER BY s.g)
                              FROM (SELECT CASE WHEN x.grantee = 0 THEN 'PUBLIC' ELSE pg_get_userbyid(x.grantee)::text END AS g
                                    FROM aclexplode(COALESCE(f.proacl, acldefault('f', f.ownerid))) x
                                    WHERE x.privilege_type = 'EXECUTE') s) = ARRAY['authenticated', 'postgres', 'service_role'], false),
                  'definition_md5', md5(pg_get_functiondef(f.oid)),
                  'definition', CASE WHEN f.proname IN ('get_due_forecast', 'get_due_forecast_buckets') THEN pg_get_functiondef(f.oid) END)
                  ORDER BY f.proname, f.args)
                FROM fns f),
  'default_acls_for_functions', (SELECT COALESCE(jsonb_agg(jsonb_build_object('owner_role', pg_get_userbyid(d.defaclrole),
                                       'schema', COALESCE(ns.nspname, '(all schemas)'), 'acl', d.defaclacl::text[])
                                       ORDER BY pg_get_userbyid(d.defaclrole), COALESCE(ns.nspname, '')), '[]'::jsonb)
                                 FROM pg_default_acl d LEFT JOIN pg_namespace ns ON ns.oid = d.defaclnamespace WHERE d.defaclobjtype = 'f'),
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

-- ===== RUN P3: exact coverage of the brief C v6 C-6.5 item 3 boundary cases by live data (counts only; used to judge C-01_TEST T3) =====
-- Each count is of review rows that satisfy EVERY other condition of the due rule and fall in the named category, so a count above 0 means the category is
-- decisive for at least one live row and C-01_TEST T3 (which compares all profiles) exercises it. A count of 0 is reported under NOT_COVERED_by_live_data.
WITH tzl AS MATERIALIZED (
  SELECT lower(z.name) AS nm, z.utc_offset FROM pg_timezone_names z
),
pr AS (
  SELECT p.id, p.course_level AS cl,
         CASE WHEN p.timezone IS NOT NULL AND lower(p.timezone) IN (SELECT nm FROM tzl) THEN p.timezone ELSE 'Asia/Kolkata' END AS tz
  FROM public.profiles p
),
x AS (
  SELECT r.status AS rstatus, e.status AS enr, f.question_type AS qt, f.visibility AS vis, (f.user_id = r.user_id) AS own,
         r.next_review_date AS nrd, r.skip_until AS su, (now() AT TIME ZONE pr.tz)::date AS today,
         (pr.cl IS NULL) AS cl_null, (f.target_course IS NULL) AS tc_null,
         (pr.cl IS NOT NULL AND f.target_course = pr.cl) AS course_equal,
         (pr.cl IS NOT NULL AND f.target_course IS NOT NULL AND f.target_course <> pr.cl) AS course_diff,
         EXISTS (SELECT 1 FROM public.friendships fr WHERE fr.status = 'accepted' AND fr.user_id <> fr.friend_id
                 AND r.user_id IN (fr.user_id, fr.friend_id) AND f.user_id IN (fr.user_id, fr.friend_id)) AS fr_acc,
         EXISTS (SELECT 1 FROM public.friendships fr WHERE fr.status = 'pending' AND fr.user_id <> fr.friend_id
                 AND r.user_id IN (fr.user_id, fr.friend_id) AND f.user_id IN (fr.user_id, fr.friend_id)) AS fr_pend,
         EXISTS (SELECT 1 FROM public.friendships fr WHERE fr.user_id <> fr.friend_id
                 AND r.user_id IN (fr.user_id, fr.friend_id) AND f.user_id IN (fr.user_id, fr.friend_id)) AS fr_any
  FROM public.reviews r
  JOIN public.flashcards f ON f.id = r.flashcard_id
  LEFT JOIN pr ON pr.id = r.user_id
  LEFT JOIN public.my_cards_enrollment e ON e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id
),
y AS (
  SELECT x.*,
         COALESCE(x.rstatus = 'active', false) AS a_ok,
         COALESCE(x.su IS NULL OR x.su <= x.today, false) AS b_ok,
         COALESCE(x.qt IS NOT NULL AND x.qt <> 'concept_card', false) AS c_ok,
         COALESCE(x.cl_null OR x.tc_null OR x.course_equal, false) AS d_ok,
         COALESCE(x.own OR x.vis = 'public' OR (x.vis = 'friends' AND x.fr_acc), false) AS e_ok,
         COALESCE(x.enr = 'active', false) AS f_ok,
         (x.nrd IS NOT NULL) AS g_ok
  FROM x
),
z AS (
  SELECT y.*, ((NOT y.a_ok)::int + (NOT y.b_ok)::int + (NOT y.c_ok)::int + (NOT y.d_ok)::int + (NOT y.e_ok)::int + (NOT y.f_ok)::int + (NOT y.g_ok)::int) AS fails
  FROM y
),
cov AS (
  SELECT 'review_status_active' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.a_ok)::int) = 0 AND (z.rstatus = 'active')) AS n FROM z
UNION ALL
  SELECT 'review_status_suspended_the_UI_word_is_paused' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.a_ok)::int) = 0 AND (z.rstatus = 'suspended')) AS n FROM z
UNION ALL
  SELECT 'review_status_mastered' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.a_ok)::int) = 0 AND (z.rstatus = 'mastered')) AS n FROM z
UNION ALL
  SELECT 'enrollment_active' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.f_ok)::int) = 0 AND (z.enr = 'active')) AS n FROM z
UNION ALL
  SELECT 'enrollment_removed' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.f_ok)::int) = 0 AND (z.enr = 'removed')) AS n FROM z
UNION ALL
  SELECT 'enrollment_any_other_status' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.f_ok)::int) = 0 AND (z.enr IS NOT NULL AND z.enr NOT IN ('active', 'removed'))) AS n FROM z
UNION ALL
  SELECT 'enrollment_none' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.f_ok)::int) = 0 AND (z.enr IS NULL)) AS n FROM z
UNION ALL
  SELECT 'visibility_own_card' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.e_ok)::int) = 0 AND (z.own)) AS n FROM z
UNION ALL
  SELECT 'visibility_public_not_own' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.e_ok)::int) = 0 AND (NOT z.own AND z.vis = 'public')) AS n FROM z
UNION ALL
  SELECT 'visibility_friends_accepted_friendship' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.e_ok)::int) = 0 AND (NOT z.own AND z.vis = 'friends' AND z.fr_acc)) AS n FROM z
UNION ALL
  SELECT 'visibility_friends_pending_friendship_only' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.e_ok)::int) = 0 AND (NOT z.own AND z.vis = 'friends' AND NOT z.fr_acc AND z.fr_pend)) AS n FROM z
UNION ALL
  SELECT 'visibility_friends_other_friendship_status_only' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.e_ok)::int) = 0 AND (NOT z.own AND z.vis = 'friends' AND NOT z.fr_acc AND NOT z.fr_pend AND z.fr_any)) AS n FROM z
UNION ALL
  SELECT 'visibility_friends_no_friendship_row' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.e_ok)::int) = 0 AND (NOT z.own AND z.vis = 'friends' AND NOT z.fr_any)) AS n FROM z
UNION ALL
  SELECT 'visibility_private_not_own' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.e_ok)::int) = 0 AND (NOT z.own AND COALESCE(z.vis, '') NOT IN ('public', 'friends'))) AS n FROM z
UNION ALL
  SELECT 'card_is_concept_card' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.c_ok)::int) = 0 AND (z.qt = 'concept_card')) AS n FROM z
UNION ALL
  SELECT 'card_question_type_null' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.c_ok)::int) = 0 AND (z.qt IS NULL)) AS n FROM z
UNION ALL
  SELECT 'card_question_type_ordinary' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.c_ok)::int) = 0 AND (z.qt IS NOT NULL AND z.qt <> 'concept_card')) AS n FROM z
UNION ALL
  SELECT 'course_profile_course_null' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.d_ok)::int) = 0 AND (z.cl_null)) AS n FROM z
UNION ALL
  SELECT 'course_card_target_null_profile_course_set' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.d_ok)::int) = 0 AND (z.tc_null AND NOT z.cl_null)) AS n FROM z
UNION ALL
  SELECT 'course_equal' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.d_ok)::int) = 0 AND (z.course_equal)) AS n FROM z
UNION ALL
  SELECT 'course_different' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.d_ok)::int) = 0 AND (z.course_diff)) AS n FROM z
UNION ALL
  SELECT 'skip_until_null' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.b_ok)::int) = 0 AND (z.su IS NULL)) AS n FROM z
UNION ALL
  SELECT 'skip_until_exactly_yesterday' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.b_ok)::int) = 0 AND (z.su = z.today - 1)) AS n FROM z
UNION ALL
  SELECT 'skip_until_exactly_today' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.b_ok)::int) = 0 AND (z.su = z.today)) AS n FROM z
UNION ALL
  SELECT 'skip_until_exactly_tomorrow' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.b_ok)::int) = 0 AND (z.su = z.today + 1)) AS n FROM z
UNION ALL
  SELECT 'skip_until_earlier_than_yesterday' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.b_ok)::int) = 0 AND (z.su < z.today - 1)) AS n FROM z
UNION ALL
  SELECT 'skip_until_later_than_tomorrow' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.b_ok)::int) = 0 AND (z.su > z.today + 1)) AS n FROM z
UNION ALL
  SELECT 'next_review_date_null' AS cat, count(*) FILTER (WHERE (z.fails - (NOT z.g_ok)::int) = 0 AND (z.nrd IS NULL)) AS n FROM z
UNION ALL
  SELECT 'eligible_with_next_review_date_exactly_today' AS cat, count(*) FILTER (WHERE z.fails = 0 AND z.nrd = z.today) AS n FROM z
UNION ALL
  SELECT 'eligible_with_next_review_date_exactly_in_3_days' AS cat, count(*) FILTER (WHERE z.fails = 0 AND z.nrd = z.today + 3) AS n FROM z
UNION ALL
  SELECT 'eligible_with_next_review_date_overdue' AS cat, count(*) FILTER (WHERE z.fails = 0 AND z.nrd < z.today) AS n FROM z
UNION ALL
  SELECT 'eligible_with_next_review_date_later_than_3_days' AS cat, count(*) FILTER (WHERE z.fails = 0 AND z.nrd > z.today + 3) AS n FROM z
),
tzp AS (
  SELECT pr.id, t.utc_offset FROM pr JOIN pg_timezone_names t ON lower(t.name) = lower(pr.tz)
)
SELECT jsonb_build_object(
  'run', 'P3',
  'review_rows_examined', (SELECT count(*) FROM z),
  'coverage_counts', (SELECT jsonb_object_agg(cat, n ORDER BY cat) FROM cov),
  'NOT_COVERED_by_live_data', (SELECT COALESCE(jsonb_agg(cat ORDER BY cat), '[]'::jsonb) FROM cov WHERE n = 0),
  'profiles_with_current_utc_offset_exactly_plus_14h', (SELECT count(*) FROM tzp WHERE utc_offset = interval '14 hours'),
  'profiles_with_current_utc_offset_exactly_minus_12h', (SELECT count(*) FROM tzp WHERE utc_offset = interval '-12 hours'),
  'profiles_with_current_utc_offset_at_or_above_plus_12h', (SELECT count(*) FROM tzp WHERE utc_offset >= interval '12 hours'),
  'profiles_with_current_utc_offset_at_or_below_minus_5h', (SELECT count(*) FROM tzp WHERE utc_offset <= interval '-5 hours'),
  'reviews_status_check_and_friendship_status_values_for_reconciliation', jsonb_build_object(
      'friendship_statuses_present', (SELECT COALESCE(jsonb_agg(DISTINCT COALESCE(fr.status, '(null)') ORDER BY COALESCE(fr.status, '(null)')), '[]'::jsonb) FROM public.friendships fr),
      'enrollment_statuses_present', (SELECT COALESCE(jsonb_agg(DISTINCT COALESCE(e.status, '(null)') ORDER BY COALESCE(e.status, '(null)')), '[]'::jsonb) FROM public.my_cards_enrollment e))
) AS result;

-- ===== RUN P4: exact coverage of the brief C v6 C-7.5 item 5 boundary cases by live data, restricted to the days the 90-day window exercises, and the complete upper-end count (counts only; used to judge C-02_TEST U3) =====
WITH tzl AS MATERIALIZED (
  SELECT lower(z.name) AS nm, z.utc_offset FROM pg_timezone_names z
),
pr AS (
  SELECT p.id,
         CASE WHEN p.timezone IS NOT NULL AND lower(p.timezone) IN (SELECT nm FROM tzl) THEN p.timezone ELSE 'Asia/Kolkata' END AS tz
  FROM public.profiles p
),
pt AS (
  SELECT pr.id, pr.tz, (now() AT TIME ZONE pr.tz)::date AS today FROM pr
),
rvd AS (
  SELECT pt.id AS uid, (r.created_at AT TIME ZONE pt.tz)::date AS d, count(*) AS c
  FROM public.reviews r JOIN pt ON pt.id = r.user_id
  WHERE r.status = 'active'
  GROUP BY 1, 2
),
rd AS (
  SELECT a.user_id AS uid, a.activity_date AS d FROM public.user_activity_log a WHERE a.activity_type = 'review'
),
sd AS (
  SELECT s.user_id AS uid, s.session_date AS d,
         bool_or(s.source = 'manual') AS has_manual,
         bool_or(s.source IN ('study_mode', 'practice_mode')) AS has_in_app,
         bool_or(s.source IS NULL OR s.source NOT IN ('manual', 'study_mode', 'practice_mode')) AS has_other
  FROM public.study_sessions s GROUP BY 1, 2
),
dd AS (
  SELECT COALESCE(rd.uid, sd.uid) AS uid, COALESCE(rd.d, sd.d) AS d,
         (rd.uid IS NOT NULL) AS has_ral, (sd.uid IS NOT NULL) AS has_study,
         COALESCE(sd.has_manual, false) AS has_manual, COALESCE(sd.has_in_app, false) AS has_in_app, COALESCE(sd.has_other, false) AS has_other
  FROM rd FULL OUTER JOIN sd ON rd.uid = sd.uid AND rd.d = sd.d
),
w AS (
  SELECT dd.*, pt.today,
         EXISTS (SELECT 1 FROM rvd WHERE rvd.uid = dd.uid AND rvd.d = dd.d) AS has_rev
  FROM dd JOIN pt ON pt.id = dd.uid
  WHERE dd.d BETWEEN pt.today - 90 AND pt.today
),
cov AS (
  SELECT 'day_with_study_only_in_90d_window' AS cat, count(*) FILTER (WHERE has_study AND NOT has_ral) AS n FROM w
  UNION ALL SELECT 'day_with_review_activity_only_in_90d_window', count(*) FILTER (WHERE has_ral AND NOT has_study) FROM w
  UNION ALL SELECT 'day_with_review_activity_and_study_in_90d_window', count(*) FILTER (WHERE has_ral AND has_study) FROM w
  UNION ALL SELECT 'day_with_manual_study_only_in_90d_window', count(*) FILTER (WHERE has_manual AND NOT has_in_app) FROM w
  UNION ALL SELECT 'day_with_in_app_study_only_in_90d_window', count(*) FILTER (WHERE has_in_app AND NOT has_manual) FROM w
  UNION ALL SELECT 'day_with_manual_and_in_app_study_in_90d_window', count(*) FILTER (WHERE has_manual AND has_in_app) FROM w
  UNION ALL SELECT 'day_with_all_sources_review_rows_activity_row_manual_and_in_app_in_90d_window',
         count(*) FILTER (WHERE has_rev AND has_ral AND has_manual AND has_in_app) FROM w
  UNION ALL SELECT 'day_exactly_at_window_start_today_minus_90_with_any_row', count(*) FILTER (WHERE d = today - 90) FROM w
  UNION ALL SELECT 'day_exactly_today_minus_30_with_any_row', count(*) FILTER (WHERE d = today - 30) FROM w
  UNION ALL SELECT 'day_exactly_today_with_any_row', count(*) FILTER (WHERE d = today) FROM w
),
info AS (
  SELECT 'days_in_90d_window_with_an_unknown_or_null_source_expected_0' AS k, count(*) FILTER (WHERE has_other) AS n FROM w
  UNION ALL SELECT 'days_in_90d_window_with_active_review_rows_but_no_activity_row_and_no_study_not_listed_by_the_live_or_new_function',
         (SELECT count(*) FROM rvd JOIN pt ON pt.id = rvd.uid
          WHERE rvd.d BETWEEN pt.today - 90 AND pt.today
            AND NOT EXISTS (SELECT 1 FROM rd WHERE rd.uid = rvd.uid AND rd.d = rvd.d)
            AND NOT EXISTS (SELECT 1 FROM sd WHERE sd.uid = rvd.uid AND sd.d = rvd.d))
),
tzp AS (
  SELECT pt.id, t.utc_offset FROM pt JOIN pg_timezone_names t ON lower(t.name) = lower(pt.tz)
)
SELECT jsonb_build_object(
  'run', 'P4',
  'coverage_counts', (SELECT jsonb_object_agg(cat, n ORDER BY cat) FROM cov),
  'NOT_COVERED_by_live_data', (SELECT COALESCE(jsonb_agg(cat ORDER BY cat), '[]'::jsonb) FROM cov WHERE n = 0),
  'informational_counts', (SELECT jsonb_object_agg(k, n ORDER BY k) FROM info),
  'profiles_with_current_utc_offset_exactly_plus_14h', (SELECT count(*) FROM tzp WHERE utc_offset = interval '14 hours'),
  'profiles_with_current_utc_offset_exactly_minus_12h', (SELECT count(*) FROM tzp WHERE utc_offset = interval '-12 hours'),
  'profiles_with_current_utc_offset_exactly_plus_14h_and_a_study_or_activity_row_in_90d_window',
     (SELECT count(DISTINCT w.uid) FROM w JOIN tzp ON tzp.id = w.uid WHERE tzp.utc_offset = interval '14 hours'),
  'profiles_with_current_utc_offset_exactly_minus_12h_and_a_study_or_activity_row_in_90d_window',
     (SELECT count(DISTINCT w.uid) FROM w JOIN tzp ON tzp.id = w.uid WHERE tzp.utc_offset = interval '-12 hours'),
  'profiles_whose_local_date_differs_from_the_server_CURRENT_DATE', (SELECT count(*) FROM pt WHERE pt.today <> CURRENT_DATE),
  'upper_end_rows_the_new_window_drops_ALL_THREE_SOURCES', jsonb_build_object(
      'study_sessions_dated_after_profile_local_today', (SELECT count(*) FROM public.study_sessions s JOIN pt ON pt.id = s.user_id WHERE s.session_date > pt.today),
      'review_activity_log_days_dated_after_profile_local_today', (SELECT count(*) FROM rd JOIN pt ON pt.id = rd.uid WHERE rd.d > pt.today),
      'active_reviews_whose_profile_local_created_date_is_after_profile_local_today', (SELECT COALESCE(sum(rvd.c), 0) FROM rvd JOIN pt ON pt.id = rvd.uid WHERE rvd.d > pt.today))
) AS result;
