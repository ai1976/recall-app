-- ===== RUN T3: all profiles, public functions against the Review composition and an independent recomputation; helper at six dates =====
CREATE OR REPLACE FUNCTION pg_temp.c01_expected(p_offset integer)
 RETURNS TABLE(uid uuid, nrd date, today date)
 LANGUAGE sql STABLE
AS $f$
  -- INDEPENDENT recomputation of the C-6.1 rule plus the v6 null rule, written in a different form from the helper
  WITH u AS (
    SELECT p.id, p.course_level AS cl,
           ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + p_offset) AS today
    FROM public.profiles p
  )
  SELECT u.id, r.next_review_date, u.today
  FROM u
  JOIN public.reviews r ON r.user_id = u.id
  JOIN public.flashcards f ON f.id = r.flashcard_id
  WHERE r.status = 'active'
    AND r.next_review_date IS NOT NULL
    AND COALESCE(r.skip_until, DATE '-infinity') <= u.today
    AND f.question_type IS NOT NULL AND f.question_type <> 'concept_card'
    AND (u.cl IS NULL OR COALESCE(f.target_course, u.cl) = u.cl)
    AND EXISTS (SELECT 1 FROM public.my_cards_enrollment e
                WHERE e.user_id = u.id AND e.flashcard_id = r.flashcard_id AND e.status = 'active')
    AND (
      f.user_id = u.id
      OR f.visibility = 'public'
      OR (f.visibility = 'friends' AND f.user_id IN (
            SELECT CASE WHEN fr.user_id = u.id THEN fr.friend_id ELSE fr.user_id END
            FROM public.friendships fr
            WHERE fr.status = 'accepted' AND u.id IN (fr.user_id, fr.friend_id)))
    )
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c01_t3() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_admin uuid; v_ids uuid[]; v_u uuid;
  v_fc jsonb := '{}'::jsonb; v_bk jsonb := '{}'::jsonb; v_q jsonb := '{}'::jsonb;
  v_row jsonb; v_cnt integer;
  rec record;
  n_cmp integer := 0; n_day0 integer := 0; n_fc integer := 0; n_bk integer := 0; n_sum integer := 0; n_q integer := 0;
  v_f jsonb; v_b0 integer;
  v_off integer;
  v_helper jsonb := '[]'::jsonb;
  v_with_due integer := 0;
BEGIN
  SELECT p.id INTO v_admin FROM public.profiles p WHERE p.role IN ('admin', 'super_admin') ORDER BY p.id LIMIT 1;
  IF v_admin IS NULL THEN
    RETURN jsonb_build_object('run', 'T3', 'error', 'no administrator profile found; the test cannot run');
  END IF;
  SELECT array_agg(p.id ORDER BY p.id) INTO v_ids FROM public.profiles p;

  -- the public functions are called as the platform calls them: role authenticated, an administrator's token
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);
  SET LOCAL ROLE authenticated;
  FOREACH v_u IN ARRAY v_ids LOOP
    SELECT to_jsonb(f) INTO v_row FROM public.get_due_forecast(v_u) f;
    v_fc := v_fc || jsonb_build_object(v_u::text, v_row);
    SELECT jsonb_agg(b.scheduled_count ORDER BY b.bucket_index) INTO v_row FROM public.get_due_forecast_buckets(v_u) b;
    v_bk := v_bk || jsonb_build_object(v_u::text, v_row);
    SELECT count(*) INTO v_cnt FROM (
      SELECT x.flashcard_id FROM public.get_study_queue(v_u) x
      INTERSECT
      SELECT m.id FROM public.get_my_cards(v_u) m
    ) i;
    v_q := v_q || jsonb_build_object(v_u::text, v_cnt);
  END LOOP;
  RESET ROLE;
  PERFORM set_config('request.jwt.claims', '', true);

  FOR rec IN
    SELECT p.id AS uid,
           COALESCE(a.t0, 0) AS t0, COALESCE(a.t7, 0) AS t7, COALESCE(a.t30, 0) AS t30,
           COALESCE(a.cnt_all, 0) AS cnt_all,
           COALESCE(a.b, ARRAY[0, 0, 0, 0, 0, 0, 0, 0]) AS b
    FROM public.profiles p
    LEFT JOIN (
      SELECT z.uid,
             count(*) AS cnt_all,
             count(*) FILTER (WHERE z.nrd <= z.today) AS t0,
             count(*) FILTER (WHERE z.nrd <= z.today + 7) AS t7,
             count(*) FILTER (WHERE z.nrd <= z.today + 30) AS t30,
             ARRAY[count(*) FILTER (WHERE z.bi = 0), count(*) FILTER (WHERE z.bi = 1), count(*) FILTER (WHERE z.bi = 2),
                   count(*) FILTER (WHERE z.bi = 3), count(*) FILTER (WHERE z.bi = 4), count(*) FILTER (WHERE z.bi = 5),
                   count(*) FILTER (WHERE z.bi = 6), count(*) FILTER (WHERE z.bi = 7)]::integer[] AS b
      FROM (
        SELECT e.uid, e.nrd, e.today,
               (SELECT count(*) FROM unnest(ARRAY[1, 2, 5, 10, 22, 60, 135]) th WHERE (e.nrd - e.today) >= th) AS bi
        FROM pg_temp.c01_expected(0) e
      ) z
      GROUP BY z.uid
    ) a ON a.uid = p.id
    ORDER BY p.id
  LOOP
    n_cmp := n_cmp + 1;
    v_f := v_fc -> (rec.uid::text);
    v_b0 := ((v_bk -> (rec.uid::text)) -> 0)::text::integer;
    IF rec.t0 > 0 THEN v_with_due := v_with_due + 1; END IF;
    IF (v_f ->> 'due_today')::integer <> v_b0 OR (v_f ->> 'due_today')::integer <> rec.t0 THEN n_day0 := n_day0 + 1; END IF;
    IF (v_q ->> (rec.uid::text))::integer <> rec.t0 THEN n_q := n_q + 1; END IF;
    IF (v_f ->> 'due_next_7')::integer <> rec.t7 OR (v_f ->> 'due_next_30')::integer <> rec.t30 THEN n_fc := n_fc + 1; END IF;
    IF (v_bk -> (rec.uid::text)) <> to_jsonb(rec.b) THEN n_bk := n_bk + 1; END IF;
    IF (SELECT COALESCE(sum(x::text::integer), 0) FROM jsonb_array_elements(v_bk -> (rec.uid::text)) x) <> rec.cnt_all THEN n_sum := n_sum + 1; END IF;
  END LOOP;

  -- the helper itself, as its owner, against the recomputation, for every profile at six dates
  FOREACH v_off IN ARRAY ARRAY[-1, 0, 1, 7, 30, 400] LOOP
    SELECT count(*) INTO v_cnt FROM (
      SELECT COALESCE(a.uid, b.uid) AS uid
      FROM (SELECT e.uid, count(*) AS c, md5(string_agg(e.nrd::text, ',' ORDER BY e.nrd)) AS h
            FROM pg_temp.c01_expected(v_off) e GROUP BY e.uid) a
      FULL OUTER JOIN (
        SELECT p.id AS uid, count(*) AS c, md5(string_agg(h.due_date::text, ',' ORDER BY h.due_date)) AS h
        FROM public.profiles p
        CROSS JOIN LATERAL public.fn_due_eligible_dates(
              p.id, ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + v_off)) h
        GROUP BY p.id
      ) b ON a.uid = b.uid
      WHERE a.uid IS NULL OR b.uid IS NULL OR a.c <> b.c OR a.h <> b.h
    ) m;
    v_helper := v_helper || jsonb_build_object('today_offset_days', v_off, 'profiles_whose_helper_set_differs', v_cnt);
  END LOOP;

  RETURN jsonb_build_object(
    'run', 'T3',
    'profiles_compared', n_cmp,
    'profiles_with_something_due_today', v_with_due,
    'day_zero_mismatches', n_day0,
    'review_composition_mismatches', n_q,
    'cumulative_7_30_mismatches', n_fc,
    'bucket_vector_mismatches', n_bk,
    'bucket_sum_mismatches', n_sum,
    'helper_at_six_dates', v_helper,
    'all_passed', (n_cmp > 0 AND n_day0 = 0 AND n_q = 0 AND n_fc = 0 AND n_bk = 0 AND n_sum = 0
                   AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_helper) e WHERE (e ->> 'profiles_whose_helper_set_differs')::integer <> 0)));
END;
$$;
SELECT pg_temp.c01_t3() AS result;
