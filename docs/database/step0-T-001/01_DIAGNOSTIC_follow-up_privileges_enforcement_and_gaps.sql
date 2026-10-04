-- Name: [DIAGNOSTIC] T-001 follow-up - effective privileges, content-lock enforcement, suspended accounts, own-card gap, course mapping, access-request correlation
--
-- Description: READ-ONLY follow-up to docs/database/step0-T-001/00_DIAGNOSTIC_pre-8.8.6_backlog_catalog.sql
-- (already run 04/10/2026). It answers the questions T-001 Rounds 12, 14 and 15 left OPEN and that design
-- brief A needs before its Gate 1:
--   F1  Effective table and column privileges of `authenticated` and `anon` (policies alone do not show
--       whether a role can actually write: S-1, S-2, S-5).
--   F2  Row-level-security state and policy definitions on the content and membership tables
--       (is the Tier B content lock enforced in the database, or only in the screens?).
--   F3A Live bodies of suspend_card, unsuspend_card, fn_course_change_archive_restore, course_change_affected
--       (repo-only until now).
--   F3B Live bodies of batch_group_access_denial, get_my_batch_groups, the get_browsable_* functions,
--       is_admin and the admin suspend/reactivate/user-action functions.
--   F4  Names of every function and policy whose source mentions account_type or suspended
--       (where is the Tier B rule and the suspended rule enforced, if anywhere?).
--   F5  The 59 own-card rows with a review but no My Cards enrollment (RUN 8): counts only, by review status,
--       owner role, card creation month, batch or not, and visibility.
--   F6  Card and note course mapping counts: how many have a NULL discipline_id, and whether discipline_id,
--       subject and target_course agree (design brief B card-to-course chain).
--   F7  Invite-token collisions, profile status values, and batch memberships by profile status and role
--       (can a suspended or wrong-role account hold a membership?).
--   F9  Length distribution of profiles.course_level (numbers only, never the values): needed to set one
--       length contract for the course label across profile, signup and study-session classification.
--   F8  Access-request correlation counts: case-insensitive versus exact email matches, requester ids,
--       duplicate open requests.
-- Privacy rule (same as the first diagnostic): no user-authored stored text is ever returned as a literal.
-- Stored text columns are bucketed to expected values plus 'unexpected_other', or only counted. Function
-- source, policy text, constraint text and table/column/function names are catalog text. Card creation is
-- reported as a month (YYYY-MM) only. No name, email, phone or identifier is selected.
-- Safety: every RUN is one SELECT or WITH ... SELECT returning one row with one json column named `result`.
-- No INSERT, UPDATE, DELETE, DDL, transaction control, or application-function call.
--
-- HOW TO RUN (ten runs: F1, F2, F3A, F3B, F4, F5, F6, F7, F8, F9): select the text of ONE run (from its first line to its closing semicolon),
-- click Run, copy the single result cell, and keep it unchanged. Save each result as an unedited raw export
-- file under docs/discussions/evidence/ named T-001_FU-<run>_<dd-mm-yyyy>.json (with a separate readable
-- rendering beside it only if wanted). An error is evidence: save the error text, do not edit and re-run.
-- Run only after QA has passed this exact file by hash and the Founder has authorized running that hash.

-- ============================================================================
-- RUN F1. Effective privileges (table level and selected column level) for authenticated and anon
-- ============================================================================
WITH r(role_name) AS (VALUES ('authenticated'), ('anon')),
t(tbl) AS (VALUES ('study_group_members'), ('study_groups'), ('admin_audit_log'), ('access_requests'),
                   ('profiles'), ('notes'), ('flashcards'), ('flashcard_decks'), ('study_sessions'),
                   ('content_group_shares'), ('my_cards_enrollment'), ('batch_group_professors'), ('reviews')),
p(priv) AS (VALUES ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'), ('TRUNCATE')),
c(tbl, col, priv) AS (VALUES ('study_groups', 'invite_token', 'SELECT'),
                             ('profiles', 'email', 'SELECT'),
                             ('profiles', 'account_type', 'UPDATE'),
                             ('profiles', 'role', 'UPDATE'),
                             ('profiles', 'status', 'UPDATE'),
                             ('profiles', 'access_request_ref', 'UPDATE'),
                             ('study_group_members', 'status', 'UPDATE'),
                             ('study_group_members', 'role', 'UPDATE'))
SELECT jsonb_build_object(
  'table_privileges', (SELECT jsonb_agg(jsonb_build_object(
        'table', t.tbl, 'role', r.role_name, 'privilege', p.priv,
        'granted', has_table_privilege(r.role_name, format('public.%I', t.tbl), p.priv)
      ) ORDER BY t.tbl, r.role_name, p.priv)
      FROM r CROSS JOIN t CROSS JOIN p),
  'column_privileges', (SELECT jsonb_agg(jsonb_build_object(
        'table', c.tbl, 'column', c.col, 'role', r.role_name, 'privilege', c.priv,
        'granted', has_column_privilege(r.role_name, format('public.%I', c.tbl), c.col, c.priv)
      ) ORDER BY c.tbl, c.col, r.role_name)
      FROM r CROSS JOIN c)
) AS result;

-- ============================================================================
-- RUN F2. Row-level security state and policy definitions (content, membership, enrollment, reviews)
-- ============================================================================
SELECT jsonb_build_object(
  'rls_state_all_public_tables', (SELECT jsonb_agg(jsonb_build_object(
        'table', c.relname, 'rls_enabled', c.relrowsecurity, 'rls_forced', c.relforcerowsecurity
      ) ORDER BY c.relname)
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relkind = 'r'),
  'policies', (SELECT jsonb_agg(jsonb_build_object(
        'table', tablename, 'name', policyname, 'cmd', cmd, 'permissive', permissive,
        'roles', roles, 'using', qual, 'check', with_check
      ) ORDER BY tablename, policyname)
      FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename IN ('notes', 'flashcards', 'flashcard_decks', 'content_group_shares',
                          'flashcard_batch_provenance', 'profiles', 'my_cards_enrollment', 'reviews',
                          'batch_group_professors', 'batch_group_archives'))
) AS result;

-- ============================================================================
-- RUN F3A. Live function bodies: card suspend / unsuspend and the course-change trigger function
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
  AND p.proname IN ('suspend_card', 'unsuspend_card', 'fn_course_change_archive_restore', 'course_change_affected');

-- ============================================================================
-- RUN F3B. Live function bodies: batch access, browsable listings, suspension and admin helpers
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
  AND (p.proname IN ('batch_group_access_denial', 'get_my_batch_groups', 'is_admin', 'admin_user_action_denial')
       OR p.proname LIKE 'get\_browsable\_%'
       OR p.proname ~* '(suspend_user|reactivate_user)');

-- ============================================================================
-- RUN F4. Where are account_type and suspended referenced? (names only, no bodies)
-- ============================================================================
SELECT jsonb_build_object(
  'functions_mentioning_account_type', (SELECT jsonb_agg(jsonb_build_object(
        'name', p.proname, 'args', pg_get_function_identity_arguments(p.oid)
      ) ORDER BY p.proname)
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.prosrc ILIKE '%account_type%'),
  'functions_mentioning_suspended', (SELECT jsonb_agg(jsonb_build_object(
        'name', p.proname, 'args', pg_get_function_identity_arguments(p.oid)
      ) ORDER BY p.proname)
      FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.prosrc ILIKE '%suspended%'),
  'policies_mentioning_account_type', (SELECT jsonb_agg(jsonb_build_object(
        'table', tablename, 'name', policyname, 'cmd', cmd
      ) ORDER BY tablename, policyname)
      FROM pg_policies
      WHERE schemaname = 'public'
        AND (COALESCE(qual, '') ILIKE '%account_type%' OR COALESCE(with_check, '') ILIKE '%account_type%')),
  'policies_mentioning_suspended', (SELECT jsonb_agg(jsonb_build_object(
        'table', tablename, 'name', policyname, 'cmd', cmd
      ) ORDER BY tablename, policyname)
      FROM pg_policies
      WHERE schemaname = 'public'
        AND (COALESCE(qual, '') ILIKE '%suspended%' OR COALESCE(with_check, '') ILIKE '%suspended%'))
) AS result;

-- ============================================================================
-- RUN F5. The own-card rows that have a review but no My Cards enrollment (counts only)
-- ============================================================================
WITH nr AS (
  SELECT r.user_id, r.flashcard_id,
         CASE WHEN r.status IN ('active', 'suspended', 'mastered') THEN r.status ELSE 'unexpected_other' END AS review_status,
         to_char(date_trunc('month', f.created_at), 'YYYY-MM') AS card_month,
         (f.batch_id IS NOT NULL) AS card_has_batch,
         CASE WHEN f.visibility IN ('private', 'friends', 'public') THEN f.visibility ELSE 'unexpected_other' END AS visibility,
         CASE WHEN p.role IN ('student', 'professor', 'admin', 'super_admin') THEN p.role ELSE 'unexpected_other' END AS owner_role
  FROM public.reviews r
  JOIN public.flashcards f ON f.id = r.flashcard_id AND f.user_id = r.user_id
  JOIN public.profiles p ON p.id = r.user_id
  WHERE NOT EXISTS (SELECT 1 FROM public.my_cards_enrollment e
                    WHERE e.user_id = r.user_id AND e.flashcard_id = r.flashcard_id)
)
SELECT jsonb_build_object(
  'own_reviewed_cards_total', (SELECT count(*) FROM public.reviews r
                               JOIN public.flashcards f ON f.id = r.flashcard_id AND f.user_id = r.user_id),
  'own_reviewed_cards_without_enrollment', (SELECT count(*) FROM nr),
  'students_affected', (SELECT count(DISTINCT user_id) FROM nr),
  'by_review_status', (SELECT jsonb_object_agg(review_status, n)
        FROM (SELECT review_status, count(*) AS n FROM nr GROUP BY 1) s),
  'by_owner_role', (SELECT jsonb_object_agg(owner_role, n)
        FROM (SELECT owner_role, count(*) AS n FROM nr GROUP BY 1) s),
  'by_card_creation_month', (SELECT jsonb_object_agg(card_month, n)
        FROM (SELECT card_month, count(*) AS n FROM nr GROUP BY 1) s),
  'by_batch_membership_of_card', (SELECT jsonb_object_agg(CASE WHEN card_has_batch THEN 'card_has_batch_id' ELSE 'card_without_batch_id' END, n)
        FROM (SELECT card_has_batch, count(*) AS n FROM nr GROUP BY 1) s),
  'by_visibility', (SELECT jsonb_object_agg(visibility, n)
        FROM (SELECT visibility, count(*) AS n FROM nr GROUP BY 1) s)
) AS result;

-- ============================================================================
-- RUN F6. Card and note course mapping: discipline_id, subject and target_course agreement (counts only)
-- ============================================================================
SELECT jsonb_build_object(
  'flashcards', (SELECT jsonb_build_object(
        'total', count(*),
        'discipline_id_null', count(*) FILTER (WHERE f.discipline_id IS NULL),
        'discipline_null_but_subject_present', count(*) FILTER (WHERE f.discipline_id IS NULL AND f.subject_id IS NOT NULL),
        'discipline_set_and_disagrees_with_subject', count(*) FILTER (WHERE f.discipline_id IS NOT NULL AND s.discipline_id IS NOT NULL AND f.discipline_id <> s.discipline_id),
        'target_course_differs_from_resolved_discipline_name', count(*) FILTER (WHERE COALESCE(f.discipline_id, s.discipline_id) IS NOT NULL AND f.target_course IS DISTINCT FROM d.name),
        'unresolvable_to_a_discipline', count(*) FILTER (WHERE COALESCE(f.discipline_id, s.discipline_id) IS NULL)
      )
      FROM public.flashcards f
      LEFT JOIN public.subjects s ON s.id = f.subject_id
      LEFT JOIN public.disciplines d ON d.id = COALESCE(f.discipline_id, s.discipline_id)),
  'notes', (SELECT jsonb_build_object(
        'total', count(*),
        'discipline_id_null', count(*) FILTER (WHERE n.discipline_id IS NULL),
        'discipline_null_but_subject_present', count(*) FILTER (WHERE n.discipline_id IS NULL AND n.subject_id IS NOT NULL),
        'discipline_set_and_disagrees_with_subject', count(*) FILTER (WHERE n.discipline_id IS NOT NULL AND s.discipline_id IS NOT NULL AND n.discipline_id <> s.discipline_id),
        'target_course_differs_from_resolved_discipline_name', count(*) FILTER (WHERE COALESCE(n.discipline_id, s.discipline_id) IS NOT NULL AND n.target_course IS DISTINCT FROM d.name),
        'unresolvable_to_a_discipline', count(*) FILTER (WHERE COALESCE(n.discipline_id, s.discipline_id) IS NULL)
      )
      FROM public.notes n
      LEFT JOIN public.subjects s ON s.id = n.subject_id
      LEFT JOIN public.disciplines d ON d.id = COALESCE(n.discipline_id, s.discipline_id))
) AS result;

-- ============================================================================
-- RUN F7. Invite-token collisions, profile status values, memberships by profile status and role (counts only)
-- ============================================================================
SELECT jsonb_build_object(
  'study_groups_total', (SELECT count(*) FROM public.study_groups),
  'invite_token_duplicates', (SELECT count(*) - count(DISTINCT invite_token) FROM public.study_groups),
  'profiles_by_status', (SELECT jsonb_agg(jsonb_build_object('profile_status', ps, 'profiles', n) ORDER BY n DESC)
        FROM (SELECT CASE WHEN status IN ('active', 'suspended') THEN status ELSE 'unexpected_other' END AS ps,
                     count(*) AS n
              FROM public.profiles GROUP BY 1) s),
  'memberships_by_profile_status_role_and_membership_status', (SELECT jsonb_agg(jsonb_build_object(
          'profile_status', ps, 'platform_role', pr, 'membership_status', ms,
          'is_batch_group', ib, 'rows', n
        ) ORDER BY n DESC)
        FROM (SELECT CASE WHEN p.status IN ('active', 'suspended') THEN p.status ELSE 'unexpected_other' END AS ps,
                     CASE WHEN p.role IN ('student', 'professor', 'admin', 'super_admin') THEN p.role ELSE 'unexpected_other' END AS pr,
                     CASE WHEN sgm.status IN ('invited', 'active', 'requested', 'closed') THEN sgm.status ELSE 'unexpected_other' END AS ms,
                     sg.is_batch_group AS ib,
                     count(*) AS n
              FROM public.study_group_members sgm
              JOIN public.study_groups sg ON sg.id = sgm.group_id
              JOIN public.profiles p ON p.id = sgm.user_id
              GROUP BY 1, 2, 3, 4) s)
) AS result;

-- ============================================================================
-- RUN F8. Access-request correlation: email matching, requester ids, duplicates (counts only)
-- ============================================================================
SELECT jsonb_build_object(
  'requests_total', (SELECT count(*) FROM public.access_requests),
  'with_email', (SELECT count(*) FROM public.access_requests a WHERE btrim(coalesce(a.email, '')) <> ''),
  'with_requester_user_id', (SELECT count(*) FROM public.access_requests a WHERE a.requester_user_id IS NOT NULL),
  'email_matches_a_profile_case_insensitively', (SELECT count(*) FROM public.access_requests a
        WHERE EXISTS (SELECT 1 FROM public.profiles p WHERE lower(btrim(p.email)) = lower(btrim(a.email)))),
  'email_matches_a_profile_exactly_as_typed', (SELECT count(*) FROM public.access_requests a
        WHERE EXISTS (SELECT 1 FROM public.profiles p WHERE p.email = a.email)),
  'requester_id_present_but_profile_email_differs_from_request_email', (SELECT count(*) FROM public.access_requests a
        WHERE a.requester_user_id IS NOT NULL
          AND EXISTS (SELECT 1 FROM public.profiles p
                      WHERE p.id = a.requester_user_id
                        AND lower(btrim(p.email)) IS DISTINCT FROM lower(btrim(a.email)))),
  'open_request_emails_that_appear_more_than_once', (SELECT count(*) FROM
        (SELECT lower(btrim(a.email)) AS k FROM public.access_requests a
         WHERE a.status = 'pending' AND btrim(coalesce(a.email, '')) <> ''
         GROUP BY 1 HAVING count(*) > 1) d)
) AS result;

-- ============================================================================
-- RUN F9. Length distribution of profiles.course_level (numbers only; the values themselves are never selected)
-- ============================================================================
SELECT jsonb_build_object(
  'profiles_total', count(*),
  'course_level_blank_or_null', count(*) FILTER (WHERE btrim(coalesce(p.course_level, '')) = ''),
  'length_1_to_60', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 1 AND 60),
  'length_61_to_80', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 61 AND 80),
  'length_81_to_100', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 81 AND 100),
  'length_over_100', count(*) FILTER (WHERE length(btrim(p.course_level)) > 100),
  'longest_length', max(length(btrim(p.course_level))),
  'with_leading_or_trailing_whitespace', count(*) FILTER (WHERE p.course_level IS NOT NULL AND p.course_level <> btrim(p.course_level)),
  'with_control_characters', count(*) FILTER (WHERE p.course_level ~ '[[:cntrl:]]'),
  'with_repeated_internal_whitespace', count(*) FILTER (WHERE p.course_level ~ '\s{2,}')
) AS result
FROM public.profiles p;
