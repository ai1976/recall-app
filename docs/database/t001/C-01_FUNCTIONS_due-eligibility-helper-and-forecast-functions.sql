-- Name: [FUNCTIONS] T-001 C-01 (v1) - shared due-eligibility helper and the two forecast functions that read it (brief C v6, point 6)
--
-- Description: PERSISTENT DDL. Implements brief C v6 (20647dbce877, Gate 1 given by the Founder on 07/10/2026), C-6.1 to C-6.3: ONE internal
-- helper holds the due-eligibility rule; get_due_forecast and get_due_forecast_buckets read from it, so the badge, the Progress tile, the Dashboard strip
-- and Forward Load can no longer drift from each other or from the Review page. Run ONLY after: (a) QA has passed this exact file by hash and the Founder
-- has approved it (Gate 2); (b) the pre-check diagnostic 10 (docs/database/step0-T-001/10_*.sql) has been run and its saved result reconciled with
-- C-01_ROLLBACK (byte comparison of the two live definitions). The Supabase SQL Editor runs one selection in ONE transaction; this file contains no
-- verification and no ROLLBACK. Verification is the separate file C-01_TEST; undo is the separate file C-01_ROLLBACK.
--
-- What changes:
--   1. NEW public.fn_due_eligible_dates(p_user_id uuid, p_today date) RETURNS TABLE(due_date date): the next_review_date of every review that is
--      due-eligible for p_user_id on p_today under C-6.1 (a) to (f) plus the v6 null rule:
--        (a) reviews.status = 'active'
--        (b) skip_until is null or not later than p_today
--        (c) the card is not a concept_card (the live predicate f.question_type <> 'concept_card'; a null question_type is excluded, as live)
--        (d) course: the profile course_level is null, or the card target_course is null or equal (the live predicate)
--        (e) visibility: own card, public card, or a friends card of an accepted friendship in either direction (the live predicate)
--        (f) NEW: an ACTIVE my_cards_enrollment row for the card (the boundary of get_my_cards)
--        (g) NEW in brief C v6 (D-C5): next_review_date is not null (C-00 evidence: 671 null rows, 590 active, 14 users)
--      It is SECURITY DEFINER with a pinned search_path, takes the target user and date as parameters, and returns only that user's dates. It is NOT
--      executable by PUBLIC, anon, authenticated or service_role (C-6.3 invariants 1 to 4); only the two definer RPCs below reach it, through their owner.
--   2. get_due_forecast(uuid): same signature, return type, caller-is-target-or-admin guard, local-today rule and error text as live; the counts are taken
--      from the helper. due_next_7 and due_next_30 keep the live cumulative meaning (<= today + 7, <= today + 30).
--   3. get_due_forecast_buckets(uuid): same signature, return type, guard, local-today rule, eight-bucket spine and day thresholds as live; the days_out
--      values come from the helper. Because of (g) a null date is no longer counted in bucket 7; because of (f) cards without an active enrollment are no
--      longer counted anywhere (the Review page already hides them).
--   4. The ACLs are set explicitly: the helper has no grant to any application role; the two public RPCs keep the live ceiling (authenticated,
--      postgres, service_role; no anon, no PUBLIC), re-asserted by REVOKE and GRANT.
--
-- Evidence relied on (all saved): live function bodies and grants docs/discussions/evidence/T-001_RUN-1B_04-10-2026.md and T-001_RUN-2_04-10-2026.md;
-- role and default-privilege facts (objects created by postgres are default-granted to anon, authenticated and service_role, so the REVOKE below is
-- required, not decoration) T-001_FU4-*; auth.uid() and is_admin() bodies T-001_FU8-E3_07-10-2026.json; null dates and the trigger and callee reading of
-- reviews T-001_C00-*_07-10-2026.*. my_cards_enrollment columns (user_id, flashcard_id, status) and its (user_id, flashcard_id) uniqueness are taken from
-- the saved add_to_my_cards body (ON CONFLICT (user_id, flashcard_id)) and are CONFIRMED from the catalog by the pre-check diagnostic 10 before this
-- file runs; a duplicate enrollment row per (user, card) would double-count in the helper's join and the TEST asserts it cannot.
-- Lock order: none taken (read-only functions); CREATE OR REPLACE takes the catalog locks of the function rows only.
-- Not changed here: get_study_queue, get_my_cards, any table, any trigger, any policy, any data.

-- 1. The helper -----------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_due_eligible_dates(p_user_id uuid, p_today date)
 RETURNS TABLE(due_date date)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_course_level text;
BEGIN
  SELECT pr.course_level
  INTO v_course_level
  FROM public.profiles pr
  WHERE pr.id = p_user_id;

  RETURN QUERY
  SELECT r.next_review_date
  FROM public.reviews r
  JOIN public.flashcards f
    ON f.id = r.flashcard_id
  JOIN public.my_cards_enrollment e
    ON e.user_id = r.user_id
   AND e.flashcard_id = r.flashcard_id
   AND e.status = 'active'
  WHERE r.user_id = p_user_id
    AND r.next_review_date IS NOT NULL
    AND r.status = 'active'
    AND (r.skip_until IS NULL OR r.skip_until <= p_today)
    AND f.question_type <> 'concept_card'
    AND (
      v_course_level IS NULL
      OR f.target_course IS NULL
      OR f.target_course = v_course_level
    )
    AND (
      f.user_id = p_user_id
      OR f.visibility = 'public'
      OR (
        f.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM public.friendships fr
          WHERE fr.status = 'accepted'
            AND (
              (fr.user_id = p_user_id AND fr.friend_id = f.user_id)
              OR (fr.friend_id = p_user_id AND fr.user_id = f.user_id)
            )
        )
      )
    );
END;
$function$;

-- The helper is internal: revoke everything from every role that default privileges or PUBLIC could have given it (C-6.3 invariant 1).
REVOKE ALL ON FUNCTION public.fn_due_eligible_dates(uuid, date) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_due_eligible_dates(uuid, date) FROM anon, authenticated, service_role;

-- 2. get_due_forecast ------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_due_forecast(p_user_id uuid)
 RETURNS TABLE(due_today integer, due_next_7 integer, due_next_30 integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_today        date;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;

  SELECT
    (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date
  INTO v_today
  FROM profiles p
  WHERE p.id = p_user_id;

  IF v_today IS NULL THEN
    v_today := CURRENT_DATE;
  END IF;

  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE d.due_date <= v_today)::int,
    COUNT(*) FILTER (WHERE d.due_date <= v_today + 7)::int,
    COUNT(*) FILTER (WHERE d.due_date <= v_today + 30)::int
  FROM public.fn_due_eligible_dates(p_user_id, v_today) d;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_due_forecast(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_due_forecast(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_due_forecast(uuid) TO authenticated, service_role;

-- 3. get_due_forecast_buckets ----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_due_forecast_buckets(p_user_id uuid)
 RETURNS TABLE(bucket_index integer, bucket_label text, scheduled_count integer)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_today        date;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;

  SELECT
    (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date
  INTO v_today
  FROM profiles p
  WHERE p.id = p_user_id;

  IF v_today IS NULL THEN
    v_today := CURRENT_DATE;
  END IF;

  RETURN QUERY
  WITH spine(bucket_index, bucket_label) AS (
    VALUES (0,'Today'),(1,'1d'),(2,'3d'),(3,'6d'),(4,'2w'),(5,'1mo'),(6,'3mo'),(7,'6mo+')
  ),
  scheduled AS (
    SELECT (d.due_date - v_today) AS days_out
    FROM public.fn_due_eligible_dates(p_user_id, v_today) d
  ),
  bucketed AS (
    SELECT
      CASE
        WHEN days_out <  1   THEN 0   -- overdue + today
        WHEN days_out <  2   THEN 1   -- centre 1d
        WHEN days_out <  5   THEN 2   -- centre 3d   (2..4)
        WHEN days_out < 10   THEN 3   -- centre 6d   (5..9)
        WHEN days_out < 22   THEN 4   -- centre 2w   (10..21)
        WHEN days_out < 60   THEN 5   -- centre 1mo  (22..59)
        WHEN days_out < 135  THEN 6   -- centre 3mo  (60..134)
        ELSE 7                        -- 6mo+        (135..)
      END AS bi
    FROM scheduled
  )
  SELECT s.bucket_index, s.bucket_label, COALESCE(COUNT(b.bi), 0)::int
  FROM spine s
  LEFT JOIN bucketed b ON b.bi = s.bucket_index
  GROUP BY s.bucket_index, s.bucket_label
  ORDER BY s.bucket_index;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_due_forecast_buckets(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_due_forecast_buckets(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.get_due_forecast_buckets(uuid) TO authenticated, service_role;
