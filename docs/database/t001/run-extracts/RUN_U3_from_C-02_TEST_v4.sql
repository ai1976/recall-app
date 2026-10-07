-- ===== RUN U3: all profiles, new function and live function against independent recomputations, common days and boundary delta =====
CREATE OR REPLACE FUNCTION pg_temp.c02_expected_new(p_days integer)
 RETURNS TABLE(uid uuid, d date, rc integer, ins integer, offs integer, tot integer, oth integer)
 LANGUAGE sql STABLE
AS $f$
  -- INDEPENDENT recomputation of the C-7.3 rule: window = [local today - p_days, local today] for all three sources
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

CREATE OR REPLACE FUNCTION pg_temp.c02_expected_old(p_days integer)
 RETURNS TABLE(uid uuid, d date, rc integer, tot integer)
 LANGUAGE sql STABLE
AS $f$
  -- INDEPENDENT recomputation of the LIVE function's own predicates: reviews from the instant now() - p_days, the server's CURRENT_DATE - p_days
  -- for the other two sources, no upper end
  WITH u AS (SELECT p.id, COALESCE(p.timezone, 'Asia/Kolkata') AS tz FROM public.profiles p),
  rv AS (
    SELECT u.id AS uid, (r.created_at AT TIME ZONE u.tz)::date AS d, count(*)::integer AS c
    FROM u JOIN public.reviews r ON r.user_id = u.id
    WHERE r.status = 'active' AND r.created_at >= now() - make_interval(days => p_days)
    GROUP BY 1, 2
  ),
  al AS (
    SELECT a.user_id AS uid, a.activity_date AS d FROM public.user_activity_log a
    WHERE a.activity_type = 'review' AND a.activity_date >= CURRENT_DATE - p_days
  ),
  st AS (
    SELECT s.user_id AS uid, s.session_date AS d, sum(s.duration_seconds)::integer AS tot FROM public.study_sessions s
    WHERE s.session_date >= CURRENT_DATE - p_days GROUP BY 1, 2
  ),
  days AS (SELECT al.uid, al.d FROM al UNION SELECT st.uid, st.d FROM st)
  SELECT days.uid, days.d, COALESCE(rv.c, 0), COALESCE(st.tot, 0)
  FROM days
  LEFT JOIN rv ON rv.uid = days.uid AND rv.d = days.d
  LEFT JOIN st ON st.uid = days.uid AND st.d = days.d
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c02_u3() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_admin uuid; v_ids uuid[]; v_u uuid; v_row jsonb;
  v_days integer;
  v_new jsonb; v_old jsonb;
  v_out jsonb := '[]'::jsonb;
  n_new_mis integer; n_old_mis integer; n_other integer; n_common_mis integer;
  n_only_new integer; n_only_old integer; n_rows_new integer; n_rows_old integer; n_common_rows integer;
  v_only_new_rc bigint; v_only_new_tot bigint; v_only_old_rc bigint; v_only_old_tot bigint;
BEGIN
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'U3', 'error', 'no administrator profile found; the test cannot run');
  END IF;
  SELECT array_agg(p.id ORDER BY p.id) INTO v_ids FROM public.profiles p;

  FOREACH v_days IN ARRAY ARRAY[90, 30] LOOP
    v_new := '{}'::jsonb; v_old := '{}'::jsonb;
    PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
    SET LOCAL ROLE authenticated;
    FOREACH v_u IN ARRAY v_ids LOOP
      SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.review_date), '[]'::jsonb) INTO v_row FROM public.get_study_heatmap_split(v_u, v_days) h;
      v_new := v_new || jsonb_build_object(v_u::text, v_row);
      SELECT COALESCE(jsonb_agg(to_jsonb(h) ORDER BY h.review_date), '[]'::jsonb) INTO v_row FROM public.get_study_heatmap(v_u, v_days) h;
      v_old := v_old || jsonb_build_object(v_u::text, v_row);
    END LOOP;
    RESET ROLE;
    PERFORM set_config('request.jwt.claims', '', true);

    -- (1) the new function against its independent recomputation, both directions, with duplicates counted
    SELECT count(*) INTO n_new_mis FROM (
      (SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'in_app_seconds')::integer AS ins,
              (e ->> 'offline_seconds')::integer AS offs, (e ->> 'study_seconds')::integer AS tot, (e ->> 'other_seconds')::integer AS oth
       FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
       EXCEPT ALL SELECT x.uid, x.d, x.rc, x.ins, x.offs, x.tot, x.oth FROM pg_temp.c02_expected_new(v_days) x)
      UNION ALL
      (SELECT x.uid, x.d, x.rc, x.ins, x.offs, x.tot, x.oth FROM pg_temp.c02_expected_new(v_days) x
       EXCEPT ALL
       SELECT j.k::uuid, (e ->> 'review_date')::date, (e ->> 'review_count')::integer, (e ->> 'in_app_seconds')::integer,
              (e ->> 'offline_seconds')::integer, (e ->> 'study_seconds')::integer, (e ->> 'other_seconds')::integer
       FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e)
    ) m;
    -- (1b) other_seconds is 0 on every day
    SELECT count(*) INTO n_other FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e WHERE (e ->> 'other_seconds')::integer <> 0;
    SELECT count(*) INTO n_rows_new FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e;

    -- (2) the live function against its own independent recomputation
    SELECT count(*) INTO n_old_mis FROM (
      (SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'study_seconds')::integer AS tot
       FROM jsonb_each(v_old) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
       EXCEPT ALL SELECT x.uid, x.d, x.rc, x.tot FROM pg_temp.c02_expected_old(v_days) x)
      UNION ALL
      (SELECT x.uid, x.d, x.rc, x.tot FROM pg_temp.c02_expected_old(v_days) x
       EXCEPT ALL
       SELECT j.k::uuid, (e ->> 'review_date')::date, (e ->> 'review_count')::integer, (e ->> 'study_seconds')::integer
       FROM jsonb_each(v_old) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e)
    ) m;
    SELECT count(*) INTO n_rows_old FROM jsonb_each(v_old) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e;

    -- (3) old versus new on the common day set (full local days wholly inside both windows), both directions
    WITH nw AS (
      SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'study_seconds')::integer AS tot
      FROM jsonb_each(v_new) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
    ),
    od AS (
      SELECT j.k::uuid AS uid, (e ->> 'review_date')::date AS d, (e ->> 'review_count')::integer AS rc, (e ->> 'study_seconds')::integer AS tot
      FROM jsonb_each(v_old) j(k, v) CROSS JOIN LATERAL jsonb_array_elements(j.v) e
    ),
    win AS (
      SELECT p.id AS uid,
             GREATEST((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date - v_days,
                      ((now() - make_interval(days => v_days)) AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + 1,
                      CURRENT_DATE - v_days) AS lo,
             (now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date AS hi
      FROM public.profiles p
    ),
    nc AS (SELECT nw.* FROM nw JOIN win ON win.uid = nw.uid AND nw.d BETWEEN win.lo AND win.hi),
    oc AS (SELECT od.* FROM od JOIN win ON win.uid = od.uid AND od.d BETWEEN win.lo AND win.hi)
    SELECT (SELECT count(*) FROM ((SELECT * FROM nc EXCEPT ALL SELECT * FROM oc) UNION ALL (SELECT * FROM oc EXCEPT ALL SELECT * FROM nc)) q),
           (SELECT count(*) FROM nc),
           (SELECT count(*) FROM nw) - (SELECT count(*) FROM nc),
           (SELECT count(*) FROM od) - (SELECT count(*) FROM oc),
           (SELECT COALESCE(sum(nw.rc), 0) - COALESCE((SELECT sum(nc.rc) FROM nc), 0) FROM nw),
           (SELECT COALESCE(sum(nw.tot), 0) - COALESCE((SELECT sum(nc.tot) FROM nc), 0) FROM nw),
           (SELECT COALESCE(sum(od.rc), 0) - COALESCE((SELECT sum(oc.rc) FROM oc), 0) FROM od),
           (SELECT COALESCE(sum(od.tot), 0) - COALESCE((SELECT sum(oc.tot) FROM oc), 0) FROM od)
    INTO n_common_mis, n_common_rows, n_only_new, n_only_old, v_only_new_rc, v_only_new_tot, v_only_old_rc, v_only_old_tot;

    v_out := v_out || jsonb_build_object(
      'p_days', v_days,
      'new_rows', n_rows_new, 'live_rows', n_rows_old,
      'new_function_vs_independent_recomputation_mismatching_rows', n_new_mis,
      'new_rows_with_other_seconds_not_zero', n_other,
      'live_function_vs_its_own_independent_recomputation_mismatching_rows', n_old_mis,
      'common_day_rows_compared', n_common_rows,
      'common_day_old_vs_new_mismatching_rows', n_common_mis,
      'boundary_new_rows_outside_common_set', n_only_new,
      'boundary_live_rows_outside_common_set', n_only_old,
      'boundary_new_side_review_count_and_study_seconds_outside_common_set', jsonb_build_array(v_only_new_rc, v_only_new_tot),
      'boundary_live_side_review_count_and_study_seconds_outside_common_set', jsonb_build_array(v_only_old_rc, v_only_old_tot),
      'pass', (n_new_mis = 0 AND n_other = 0 AND n_old_mis = 0 AND n_common_mis = 0 AND n_rows_new > 0));
  END LOOP;
  RETURN jsonb_build_object('run', 'U3', 'profiles', array_length(v_ids, 1), 'by_window', v_out,
    'all_passed', NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_out) e WHERE (e ->> 'pass')::boolean IS NOT TRUE));
END;
$$;
SELECT pg_temp.c02_u3() AS result;
