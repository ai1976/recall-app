-- Name: [DIAGNOSTIC] T-001 follow-up (v2) - effective privileges, row-level security, function bodies, own-card gap, course mapping, access-request duplicates, course-label length
--
-- Description: READ-ONLY follow-up to docs/database/step0-T-001/00_DIAGNOSTIC_pre-8.8.6_backlog_catalog.sql
-- (already run 04/10/2026). It answers the questions T-001 left OPEN that design briefs A and B need before
-- their Gate 1. Ten runs, each one statement returning one row with one json column named `result`:
--   F1  Effective table privileges (SELECT, INSERT, UPDATE, DELETE, TRUNCATE) of `authenticated` and `anon`
--       on 13 tables, and effective column privileges on 8 selected columns. Policies alone do not show
--       whether a role can actually write (open S-1, S-2, S-5).
--   F2  Row-level-security state of every public table, and the policy definitions on 15 tables: the content
--       tables (notes, flashcards, flashcard_decks, content_group_shares, flashcard_batch_provenance), the
--       membership tables (study_group_members, study_groups, batch_group_professors, batch_group_archives),
--       access_requests, study_sessions, admin_audit_log, profiles, my_cards_enrollment and reviews.
--       (Is the Tier B content lock enforced in the database? What can a preserved rejected or removed
--       membership row read? What guards access_requests and study_sessions?)
--   F3A Live bodies of suspend_card, unsuspend_card, fn_course_change_archive_restore, course_change_affected.
--   F3B Live bodies of batch_group_access_denial, get_my_batch_groups, is_admin, admin_user_action_denial,
--       every get_browsable_* function, and the functions whose name contains suspend_user or reactivate_user.
--   F4  Names (not bodies) of every function and policy whose source mentions account_type or suspended.
--   F5  The own-card rows that have a review but no My Cards enrollment (59 due rows seen in RUN 8): counts
--       by review status, owner role, card creation month, batch or not, and visibility.
--   F6  Course mapping of flashcards and notes, resolved SUBJECT FIRST (the subject's discipline is the
--       canonical course, then the stored discipline_id), with each disagreement counted independently:
--       subject missing, stored discipline missing, both present and agree, both present and disagree,
--       target_course versus the subject-derived discipline name, target_course versus the stored
--       discipline name, and rows resolvable by neither.
--   F7  Invite-token duplicates among study_groups, profile status values, and memberships by profile
--       status, platform role, membership status and batch or not.
--   F8  Access-request duplicates and contact-email facts, split by authenticated and anonymous requests and
--       by request target (request type, content type, content id): missing versus present contact email,
--       a contact email that differs from the requester's profile email (only when both exist), open
--       duplicate groups per authenticated requester and target, open repeat groups per anonymous
--       contact email and target, and email matches to profiles (case-insensitive versus exact).
--   F9  Length bands of profiles.course_level (numbers only; the values themselves are never selected).
-- Privacy rule: no user-authored stored text is ever returned as a literal. Stored text columns are bucketed
-- to expected values plus 'unexpected_other', or only counted or measured. Function source, policy text,
-- constraint text and table, column and function names are catalog text. Card creation is reported as a
-- month (YYYY-MM) only. No name, email, phone or identifier is selected.
-- Safety: every RUN is one SELECT or WITH ... SELECT. No INSERT, UPDATE, DELETE, DDL, transaction control,
-- or application-function call.
--
-- HOW TO RUN (ten runs: F1, F2, F3A, F3B, F4, F5, F6, F7, F8, F9): select the text of ONE run (from its first
-- line to its closing semicolon), click Run, copy the single result cell, and keep it unchanged. Save each
-- result as an unedited raw export file under docs/discussions/evidence/ named
-- T-001_FU-<run>_<dd-mm-yyyy>.json (with a separate readable rendering beside it only if wanted). An error is
-- evidence: save the error text, do not edit and re-run.
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
-- RUN F2. Row-level security state (all public tables) and policy definitions (15 tables, see header)
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
                          'flashcard_batch_provenance',
                          'study_group_members', 'study_groups', 'batch_group_professors', 'batch_group_archives',
                          'access_requests', 'study_sessions', 'admin_audit_log',
                          'profiles', 'my_cards_enrollment', 'reviews'))
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
-- RUN F6. Course mapping of flashcards and notes, SUBJECT FIRST; every disagreement counted independently
--   subject-derived discipline = subjects.discipline_id reached through subject_id (the canonical course)
--   stored discipline          = flashcards.discipline_id / notes.discipline_id
-- ============================================================================
WITH fc AS (
  SELECT f.subject_id,
         f.discipline_id AS stored_discipline_id,
         f.target_course,
         s.discipline_id AS subject_discipline_id,
         ds.name AS subject_discipline_name,
         dst.name AS stored_discipline_name
  FROM public.flashcards f
  LEFT JOIN public.subjects s ON s.id = f.subject_id
  LEFT JOIN public.disciplines ds ON ds.id = s.discipline_id
  LEFT JOIN public.disciplines dst ON dst.id = f.discipline_id
),
nt AS (
  SELECT n.subject_id,
         n.discipline_id AS stored_discipline_id,
         n.target_course,
         s.discipline_id AS subject_discipline_id,
         ds.name AS subject_discipline_name,
         dst.name AS stored_discipline_name
  FROM public.notes n
  LEFT JOIN public.subjects s ON s.id = n.subject_id
  LEFT JOIN public.disciplines ds ON ds.id = s.discipline_id
  LEFT JOIN public.disciplines dst ON dst.id = n.discipline_id
)
SELECT jsonb_build_object(
  'flashcards', (SELECT jsonb_build_object(
        'total', count(*),
        'subject_id_null', count(*) FILTER (WHERE subject_id IS NULL),
        'stored_discipline_id_null', count(*) FILTER (WHERE stored_discipline_id IS NULL),
        'subject_present_but_stored_discipline_null', count(*) FILTER (WHERE subject_id IS NOT NULL AND stored_discipline_id IS NULL),
        'subject_derived_and_stored_discipline_both_present_and_agree', count(*) FILTER (WHERE subject_discipline_id IS NOT NULL AND stored_discipline_id IS NOT NULL AND subject_discipline_id = stored_discipline_id),
        'subject_derived_and_stored_discipline_both_present_and_disagree', count(*) FILTER (WHERE subject_discipline_id IS NOT NULL AND stored_discipline_id IS NOT NULL AND subject_discipline_id <> stored_discipline_id),
        'target_course_equals_subject_derived_discipline_name', count(*) FILTER (WHERE subject_discipline_name IS NOT NULL AND target_course = subject_discipline_name),
        'target_course_differs_from_subject_derived_discipline_name', count(*) FILTER (WHERE subject_discipline_name IS NOT NULL AND target_course IS DISTINCT FROM subject_discipline_name),
        'target_course_differs_from_stored_discipline_name', count(*) FILTER (WHERE stored_discipline_name IS NOT NULL AND target_course IS DISTINCT FROM stored_discipline_name),
        'no_subject_derived_discipline_but_stored_discipline_present', count(*) FILTER (WHERE subject_discipline_id IS NULL AND stored_discipline_id IS NOT NULL),
        'resolvable_by_neither_subject_nor_stored_discipline', count(*) FILTER (WHERE subject_discipline_id IS NULL AND stored_discipline_id IS NULL)
      ) FROM fc),
  'notes', (SELECT jsonb_build_object(
        'total', count(*),
        'subject_id_null', count(*) FILTER (WHERE subject_id IS NULL),
        'stored_discipline_id_null', count(*) FILTER (WHERE stored_discipline_id IS NULL),
        'subject_present_but_stored_discipline_null', count(*) FILTER (WHERE subject_id IS NOT NULL AND stored_discipline_id IS NULL),
        'subject_derived_and_stored_discipline_both_present_and_agree', count(*) FILTER (WHERE subject_discipline_id IS NOT NULL AND stored_discipline_id IS NOT NULL AND subject_discipline_id = stored_discipline_id),
        'subject_derived_and_stored_discipline_both_present_and_disagree', count(*) FILTER (WHERE subject_discipline_id IS NOT NULL AND stored_discipline_id IS NOT NULL AND subject_discipline_id <> stored_discipline_id),
        'target_course_equals_subject_derived_discipline_name', count(*) FILTER (WHERE subject_discipline_name IS NOT NULL AND target_course = subject_discipline_name),
        'target_course_differs_from_subject_derived_discipline_name', count(*) FILTER (WHERE subject_discipline_name IS NOT NULL AND target_course IS DISTINCT FROM subject_discipline_name),
        'target_course_differs_from_stored_discipline_name', count(*) FILTER (WHERE stored_discipline_name IS NOT NULL AND target_course IS DISTINCT FROM stored_discipline_name),
        'no_subject_derived_discipline_but_stored_discipline_present', count(*) FILTER (WHERE subject_discipline_id IS NULL AND stored_discipline_id IS NOT NULL),
        'resolvable_by_neither_subject_nor_stored_discipline', count(*) FILTER (WHERE subject_discipline_id IS NULL AND stored_discipline_id IS NULL)
      ) FROM nt)
) AS result;

-- ============================================================================
-- RUN F7. Invite-token duplicates, profile status values, memberships by profile status and role (counts only)
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
-- RUN F8. Access-request duplicates and contact-email facts, by authenticated versus anonymous and by target
--   authenticated = requester_user_id is not null; anonymous = requester_user_id is null
--   target        = (request_type, content_type, content_id); platform-level requests have no content
--   open          = status is pending or contacted (the two statuses that still await a decision)
--   contact email = the typed email, lower-cased and trimmed; a blank value is treated as missing, not as a value
-- ============================================================================
WITH a AS (
  SELECT x.id, x.request_type, x.status, x.content_type, x.content_id, x.requester_user_id,
         x.email AS raw_email,
         NULLIF(lower(btrim(x.email)), '') AS contact_email
  FROM public.access_requests x
),
pe AS (
  SELECT p.id, NULLIF(lower(btrim(p.email)), '') AS profile_email, p.email AS raw_profile_email
  FROM public.profiles p
)
SELECT jsonb_build_object(
  'requests_total', (SELECT count(*) FROM a),
  'open_requests_total', (SELECT count(*) FROM a WHERE status IN ('pending', 'contacted')),
  'by_request_type', (SELECT jsonb_object_agg(rt, n)
        FROM (SELECT CASE WHEN request_type IN ('student_access', 'institute_inquiry', 'educator_application')
                          THEN request_type ELSE 'unexpected_other' END AS rt, count(*) AS n
              FROM a GROUP BY 1) s),
  'authenticated_requests', (SELECT count(*) FROM a WHERE requester_user_id IS NOT NULL),
  'anonymous_requests', (SELECT count(*) FROM a WHERE requester_user_id IS NULL),
  'contact_email_missing', (SELECT count(*) FROM a WHERE contact_email IS NULL),
  'contact_email_present', (SELECT count(*) FROM a WHERE contact_email IS NOT NULL),
  'authenticated_contact_email_missing', (SELECT count(*) FROM a WHERE requester_user_id IS NOT NULL AND contact_email IS NULL),
  'authenticated_contact_and_profile_email_both_present_and_different', (SELECT count(*) FROM a
        JOIN pe ON pe.id = a.requester_user_id
        WHERE a.contact_email IS NOT NULL AND pe.profile_email IS NOT NULL AND a.contact_email <> pe.profile_email),
  'anonymous_contact_email_equals_a_profile_email_case_insensitively', (SELECT count(*) FROM a
        WHERE a.requester_user_id IS NULL AND a.contact_email IS NOT NULL
          AND EXISTS (SELECT 1 FROM pe WHERE pe.profile_email = a.contact_email)),
  'anonymous_contact_email_equals_a_profile_email_exactly_as_typed', (SELECT count(*) FROM a
        WHERE a.requester_user_id IS NULL AND a.contact_email IS NOT NULL
          AND EXISTS (SELECT 1 FROM pe WHERE pe.raw_profile_email = a.raw_email)),
  'open_authenticated_duplicate_groups_by_requester_and_target', (SELECT jsonb_build_object(
          'groups_with_more_than_one_open_request', count(*),
          'requests_in_those_groups', coalesce(sum(n), 0))
        FROM (SELECT count(*) AS n FROM a
              WHERE a.status IN ('pending', 'contacted') AND a.requester_user_id IS NOT NULL
              GROUP BY a.requester_user_id, a.request_type, coalesce(a.content_type, ''), coalesce(a.content_id::text, '')
              HAVING count(*) > 1) g),
  'open_anonymous_repeat_groups_by_contact_email_and_target', (SELECT jsonb_build_object(
          'groups_with_more_than_one_open_request', count(*),
          'requests_in_those_groups', coalesce(sum(n), 0))
        FROM (SELECT count(*) AS n FROM a
              WHERE a.status IN ('pending', 'contacted') AND a.requester_user_id IS NULL AND a.contact_email IS NOT NULL
              GROUP BY a.contact_email, a.request_type, coalesce(a.content_type, ''), coalesce(a.content_id::text, '')
              HAVING count(*) > 1) g),
  'open_anonymous_requests_without_contact_email', (SELECT count(*) FROM a
        WHERE a.status IN ('pending', 'contacted') AND a.requester_user_id IS NULL AND a.contact_email IS NULL)
) AS result;

-- ============================================================================
-- RUN F9. Length bands of profiles.course_level (numbers only; the values themselves are never selected)
-- ============================================================================
SELECT jsonb_build_object(
  'profiles_total', count(*),
  'course_level_blank_or_null', count(*) FILTER (WHERE btrim(coalesce(p.course_level, '')) = ''),
  'length_1_to_60', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 1 AND 60),
  'length_61_to_80', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 61 AND 80),
  'length_81_to_100', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 81 AND 100),
  'length_101_to_120', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 101 AND 120),
  'length_121_to_160', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 121 AND 160),
  'length_161_to_200', count(*) FILTER (WHERE length(btrim(p.course_level)) BETWEEN 161 AND 200),
  'length_over_200', count(*) FILTER (WHERE length(btrim(p.course_level)) > 200),
  'longest_length', max(length(btrim(p.course_level))),
  'with_leading_or_trailing_whitespace', count(*) FILTER (WHERE p.course_level IS NOT NULL AND p.course_level <> btrim(p.course_level)),
  'with_control_characters', count(*) FILTER (WHERE p.course_level ~ '[[:cntrl:]]'),
  'with_repeated_internal_whitespace', count(*) FILTER (WHERE p.course_level ~ '\s{2,}')
) AS result
FROM public.profiles p;
