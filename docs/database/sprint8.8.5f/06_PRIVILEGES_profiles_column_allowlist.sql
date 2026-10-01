-- [SCHEMA] Profile privacy - STEP 3 of 3: explicit column allow-list on profiles (Sprint 8.8.5f). RUN ONLY AFTER the frontend (step 2) is LIVE.
-- Description: Replaces the table-wide SELECT grant with a real column allow-list. A table-level SELECT would defeat any column
--   restriction, so ALL privileges are revoked from anon and authenticated first, then re-granted explicitly:
--     anon           : nothing at all on profiles (every public page reads through SECURITY DEFINER functions)
--     authenticated  : SELECT only on the allow-listed columns = every column EXCEPT email and access_request_ref;
--                      INSERT / UPDATE / DELETE exactly as today (RLS + the D-45 write guard still decide; this sprint does not
--                      change write rights). TRUNCATE, TRIGGER and REFERENCES are NOT re-granted (they were granted by default and
--                      RLS cannot stop TRUNCATE).
--   Admins keep reading emails through admin_read_profiles (03); users see their own email from their login session.
--   Any column added to profiles LATER is invisible to the app roles until it is granted here explicitly (safe default).
--   Remaining profile fields (goals, timezone, exam date, onboarding flags, account type, status) stay readable by every signed-in
--   user for now: a dedicated visibility classification is a recorded follow-up, NOT a statement that they are public.
-- Self-guard (aborts with a clear message, nothing changes): (1) any RLS policy anywhere that mentions profiles AND email /
--   access_request_ref (a policy sub-select runs with the caller's privileges and would start failing); (2) any view OR materialized
--   view over profiles; (3) admin_read_profiles / search_users_for_group_invite / the new get_author_profile are not deployed yet.
-- Rollback: 08. Test: 07.

DO $g$
DECLARE d text;
BEGIN
  SELECT string_agg(tablename || '.' || policyname, ', ') INTO d
    FROM pg_policies
   WHERE (COALESCE(qual, '') || ' ' || COALESCE(with_check, '')) ILIKE '%profiles%'
     AND (COALESCE(qual, '') || ' ' || COALESCE(with_check, '')) ~* '\y(email|access_request_ref)\y';
  IF d IS NOT NULL THEN
    RAISE EXCEPTION 'Aborted: RLS policies read profiles.email / access_request_ref and would break: %', d;
  END IF;

  SELECT string_agg(viewname, ', ') INTO d FROM pg_views WHERE schemaname = 'public' AND definition ILIKE '%profiles%';
  IF d IS NOT NULL THEN
    RAISE EXCEPTION 'Aborted: views read profiles: %', d;
  END IF;

  -- Materialized views too (00 block D found none on 01/10/2026; this guards against later drift).
  SELECT string_agg(matviewname, ', ') INTO d FROM pg_matviews WHERE schemaname = 'public' AND definition ILIKE '%profiles%';
  IF d IS NOT NULL THEN
    RAISE EXCEPTION 'Aborted: materialized views read profiles: %', d;
  END IF;

  -- Replacement functions must exist, and get_author_profile must no longer mention email in its CODE (SQL comments are stripped
  -- first, so the comment "-- Profile (no email)" in the hardened body cannot trip this guard). 04 test P4 checks the same expression.
  IF to_regprocedure('public.admin_read_profiles(uuid[],text[],text[],uuid[],integer)') IS NULL
     OR to_regprocedure('public.search_users_for_group_invite(uuid,text)') IS NULL
     OR to_regprocedure('public.get_author_profile(uuid,uuid)') IS NULL THEN
    RAISE EXCEPTION 'Aborted: run 03 (step 1) first - a replacement function is missing';
  END IF;
  IF regexp_replace(pg_get_functiondef(to_regprocedure('public.get_author_profile(uuid,uuid)')), '--[^\n]*', '', 'g') ~* '\yemail\y' THEN
    RAISE EXCEPTION 'Aborted: get_author_profile still returns email - run 03 (step 1) first';
  END IF;
END $g$;

REVOKE ALL ON TABLE public.profiles FROM anon;
REVOKE ALL ON TABLE public.profiles FROM authenticated;

GRANT SELECT (id, full_name, role, course_level, institution, account_type, status, created_at, timezone,
              daily_review_goal, daily_study_goal_minutes, exam_date, exam_month,
              has_dismissed_exam_prompt, has_dismissed_goal_prompt, has_seen_onboarding, updated_at)
  ON public.profiles TO authenticated;

GRANT INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
