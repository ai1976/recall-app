-- ===== RUN T4: the null date (brief C v6, D-C5) =====
CREATE OR REPLACE FUNCTION pg_temp.c01_t4() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_null_rows_returned integer; v_off integer; v_cnt integer; v_per jsonb := '[]'::jsonb;
BEGIN
  FOREACH v_off IN ARRAY ARRAY[-1, 0, 1, 7, 30, 400, 20000] LOOP
    SELECT count(*) INTO v_cnt
    FROM public.profiles p
    CROSS JOIN LATERAL public.fn_due_eligible_dates(
          p.id, ((now() AT TIME ZONE COALESCE(p.timezone, 'Asia/Kolkata'))::date + v_off)) h
    WHERE h.due_date IS NULL;
    v_per := v_per || jsonb_build_object('today_offset_days', v_off, 'helper_rows_with_a_null_date', v_cnt);
  END LOOP;
  SELECT COALESCE(sum((e ->> 'helper_rows_with_a_null_date')::integer), 0) INTO v_null_rows_returned FROM jsonb_array_elements(v_per) e;
  RETURN jsonb_build_object(
    'run', 'T4',
    'active_reviews_with_a_null_date_that_exist', (SELECT count(*) FROM public.reviews r WHERE r.status = 'active' AND r.next_review_date IS NULL),
    'users_holding_them', (SELECT count(DISTINCT r.user_id) FROM public.reviews r WHERE r.status = 'active' AND r.next_review_date IS NULL),
    'helper_rows_with_a_null_date_by_date', v_per,
    'null_rows_returned_in_total', v_null_rows_returned,
    'all_passed', v_null_rows_returned = 0);
END;
$$;
SELECT pg_temp.c01_t4() AS result;
