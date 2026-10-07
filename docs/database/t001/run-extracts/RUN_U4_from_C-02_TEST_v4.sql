-- ===== RUN U4: small and data-derived windows, so the window start falls on LISTED live days (v3; QA Round 100; Founder Option A) =====
-- U3 tests the contract windows 90 and 30. The live data show a listed day exactly at today minus 30 and today, but none exactly at today minus 90, so U4
-- derives further windows from the data: the distinct offsets (local today minus the date) of every listed day, from the review activity log and the
-- study sessions, between 0 and 90 days; eight of them chosen evenly by rank (so the smallest and the largest are always among them), plus the fixed
-- windows 0 (today only), 1 and 7. For each window p_days the new function is compared, for EVERY profile as an administrator, with the independent
-- recomputation (both directions, duplicates counted), other_seconds is checked to be 0, and the number of listed rows that sit exactly on the window
-- start and exactly on today is reported, so the edge cases are exercised and counted, not assumed. Windows 30 and 90 stay in U3.
CREATE OR REPLACE FUNCTION pg_temp.c02_expected_new(p_days integer)
 RETURNS TABLE(uid uuid, d date, rc integer, ins integer, offs integer, tot integer, oth integer)
 LANGUAGE sql STABLE
AS $f$
  WITH u AS (
    SELECT p.id, COALESCE(p.timezone, 'Asia/Kolkata') AS tz,
           (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date AS today
    FROM public.profiles p
  ),
  rv AS (
    SELECT u.id AS uid, (r.created_at AT TIME ZONE u.tz)::date AS d, count(*)::integer AS c
    FROM u JOIN public.reviews r ON r.user_id = u.id
    WHERE r.status = 'active'
      AND (r.created_at AT TIME ZONE u.tz)::date >= u.today - p_days
      AND (r.created_at AT TIME ZONE u.tz)::date <= u.today
    GROUP BY 1, 2
  ),
  al AS (
    SELECT u.id AS uid, a.activity_date AS d
    FROM u JOIN public.user_activity_log a ON a.user_id = u.id
    WHERE a.activity_type = 'review' AND a.activity_date >= u.today - p_days AND a.activity_date <= u.today
  ),
  st AS (
    SELECT u.id AS uid, s.session_date AS d,
           sum(s.duration_seconds)::integer AS tot,
           COALESCE(sum(s.duration_seconds) FILTER (WHERE s.source IN ('study_mode', 'practice_mode')), 0)::integer AS ins,
           COALESCE(sum(s.duration_seconds) FILTER (WHERE s.source = 'manual'), 0)::integer AS offs
    FROM u JOIN public.study_sessions s ON s.user_id = u.id
    WHERE s.session_date >= u.today - p_days AND s.session_date <= u.today
    GROUP BY 1, 2
  ),
  days AS (SELECT al.uid, al.d FROM al UNION SELECT st.uid, st.d FROM st)
  SELECT days.uid, days.d, COALESCE(rv.c, 0), COALESCE(st.ins, 0), COALESCE(st.offs, 0), COALESCE(st.tot, 0),
         COALESCE(st.tot, 0) - COALESCE(st.ins, 0) - COALESCE(st.offs, 0)
  FROM days
  LEFT JOIN rv ON rv.uid = days.uid AND rv.d = days.d
  LEFT JOIN st ON st.uid = days.uid AND st.d = days.d
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c02_u4() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_admin uuid; v_ids uuid[]; v_u uuid; v_row jsonb; v_new jsonb;
  v_offs integer[]; v_days integer[]; v_d integer; i integer; n integer;
  v_out jsonb := '[]'::jsonb;
  n_mis integer; n_other integer; n_rows integer; n_start integer; n_today integer;
BEGIN
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'U4', 'error', 'no administrator profile found; the test cannot run');
  END IF;
  SELECT array_agg(p.id ORDER BY p.id) INTO v_ids FROM public.profiles p;

  SELECT array_agg(z.o ORDER BY z.o) INTO v_offs FROM (
    SELECT DISTINCT ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - d.d) AS o
    FROM public.profiles p
    JOIN (SELECT a.user_id AS uid, a.activity_date AS d FROM public.user_activity_log a WHERE a.activity_type = 'review'
          UNION
          SELECT s.user_id, s.session_date FROM public.study_sessions s) d ON d.uid = p.id
    WHERE ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - d.d) BETWEEN 0 AND 90
  ) z;
  n := COALESCE(array_length(v_offs, 1), 0);
  v_days := ARRAY[0, 1, 7];
  IF n > 0 THEN
    FOR i IN 0..7 LOOP
      v_days := v_days || v_offs[1 + (i * (n - 1)) / 7];
    END LOOP;
  END IF;
  SELECT array_agg(DISTINCT x ORDER BY x) INTO v_days FROM unnest(v_days) x;

  FOREACH v_d IN ARRAY v_days LOOP
    v_new := '{}'::jsonb;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    FOREACH v_u IN ARRAY v_ids LOOP
      SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.review_date), '[]'::jsonb) INTO v_row FROM public.get_study_heatmap_split(v_u, v_d) h;
      v_new := v_new || jsonb_build_object(v_u::text, v_row);
    END LOOP;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true);

    SELECT count(*) INTO n_mis FROM (
      (SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'in_app_seconds')::integer AS ins,
              (e ->> 'offline_seconds')::integer AS offs, (e ->> 'study_seconds')::integer AS tot, (e ->> 'other_seconds')::integer AS oth
       FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
       EXCEPT ALL SELECT x.uid, x.d, x.rc, x.ins, x.offs, x.tot, x.oth FROM pg_temp.c02_expected_new(v_d) x)
      UNION ALL
      (SELECT x.uid, x.d, x.rc, x.ins, x.offs, x.tot, x.oth FROM pg_temp.c02_expected_new(v_d) x
       EXCEPT ALL
       SELECT j.k::uuid, (e ->> 'review_date')::date, (e ->> 'review_count')::integer, (e ->> 'in_app_seconds')::integer,
              (e ->> 'offline_seconds')::integer, (e ->> 'study_seconds')::integer, (e ->> 'other_seconds')::integer
       FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e)
    ) m;
    SELECT count(*) INTO n_other FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e WHERE (e ->> 'other_seconds')::integer <> 0;
    SELECT count(*) INTO n_rows FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e;
    SELECT count(*) FILTER (WHERE (e ->> 'review_date')::date = (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - v_d),
           count(*) FILTER (WHERE (e ->> 'review_date')::date = (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date)
      INTO n_start, n_today
    FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
    JOIN public.profiles p ON p.id = j.k::uuid;

    v_out := v_out || jsonb_build_object(
      'p_days', v_d, 'rows', n_rows,
      'mismatching_rows_against_the_independent_recomputation', n_mis,
      'rows_with_other_seconds_not_zero', n_other,
      'listed_rows_exactly_on_the_window_start', n_start,
      'listed_rows_exactly_on_today', n_today,
      'pass', (n_mis = 0 AND n_other = 0));
  END LOOP;
  RETURN jsonb_build_object(
    'run', 'U4', 'profiles', array_length(v_ids, 1), 'derived_distinct_listed_day_offsets_available', n,
    'p_days_tested', to_jsonb(v_days), 'by_window', v_out,
    'windows_greater_than_0_whose_start_falls_on_a_listed_row',
      (SELECT count(*) FROM jsonb_array_elements(v_out) e WHERE (e ->> 'p_days')::integer > 0 AND (e ->> 'listed_rows_exactly_on_the_window_start')::integer > 0),
    'windows_greater_than_0_tested', (SELECT count(*) FROM jsonb_array_elements(v_out) e WHERE (e ->> 'p_days')::integer > 0),
    'all_passed', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_out) e WHERE (e ->> 'pass')::boolean IS NOT TRUE));
END;
$$;
SELECT pg_temp.c02_u4() AS result;
