-- ===== RUN T5: date-boundary probes on REAL rows (v3; QA Round 100; Founder Option A) =====
-- The helper takes the date as a parameter, so a live row can be put exactly on a rule boundary by moving "today" instead of writing any data. For every
-- active review with a skip_until the helper is called, for that review's user, at skip_until minus 1, skip_until and skip_until plus 1 (the skip is then
-- exactly tomorrow, exactly today and exactly yesterday relative to the probe date); for every active review with a next_review_date, at that date minus 3,
-- minus 1, the date itself and plus 1 (the card is then due exactly in 3 days, tomorrow, today and overdue by one day). Each (user, date) result is compared,
-- as a multiset of dates, with an independently written recomputation at the same probe date. The run also counts the decisive live rows for each
-- boundary relation so that a relation with no row is reported, never assumed. This is the heaviest run (several thousand helper calls): run it last.
CREATE OR REPLACE FUNCTION pg_temp.c01_probes() RETURNS TABLE(uid uuid, p date)
 LANGUAGE sql STABLE
AS $f$
  SELECT r.user_id, (r.skip_until + v.k)::date
  FROM public.reviews r CROSS JOIN (VALUES (-1), (0), (1)) v(k)
  WHERE r.status = 'active' AND r.skip_until IS NOT NULL
  UNION
  SELECT r.user_id, (r.next_review_date + v.k)::date
  FROM public.reviews r CROSS JOIN (VALUES (-3), (-1), (0), (1)) v(k)
  WHERE r.status = 'active' AND r.next_review_date IS NOT NULL
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c01_rows_at() RETURNS TABLE(uid uuid, p date, nrd date, su date)
 LANGUAGE sql STABLE
AS $f$
  -- every (probe, review) pair of the probe's user that satisfies every rule condition EXCEPT the skip rule, with the probe date as "today"
  SELECT pr.uid, pr.p, r.next_review_date, r.skip_until
  FROM pg_temp.c01_probes() pr
  JOIN public.profiles u ON u.id = pr.uid
  JOIN public.reviews r ON r.user_id = pr.uid
  JOIN public.flashcards f ON f.id = r.flashcard_id
  WHERE r.status = 'active'
    AND r.next_review_date IS NOT NULL
    AND f.question_type IS NOT NULL AND f.question_type <> 'concept_card'
    AND (u.course_level IS NULL OR COALESCE(f.target_course, u.course_level) = u.course_level)
    AND EXISTS (SELECT 1 FROM public.my_cards_enrollment e
                WHERE e.user_id = pr.uid AND e.flashcard_id = r.flashcard_id AND e.status = 'active')
    AND (
      f.user_id = pr.uid
      OR f.visibility = 'public'
      OR (f.visibility = 'friends' AND f.user_id IN (
            SELECT CASE WHEN fr.user_id = pr.uid THEN fr.friend_id ELSE fr.user_id END
            FROM public.friendships fr
            WHERE fr.status = 'accepted' AND pr.uid IN (fr.user_id, fr.friend_id)))
    )
$f$;

CREATE OR REPLACE FUNCTION pg_temp.c01_t5() RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE
  v_pairs integer; v_mis integer; v_rel jsonb;
BEGIN
  SELECT count(*) INTO v_pairs FROM pg_temp.c01_probes();
  SELECT count(*) INTO v_mis FROM (
    SELECT COALESCE(a.uid, b.uid) AS uid
    FROM (SELECT x.uid, x.p, count(*) AS c, md5(string_agg(x.nrd::text, ',' ORDER BY x.nrd)) AS h
          FROM pg_temp.c01_rows_at() x
          WHERE COALESCE(x.su, DATE '-infinity') <= x.p
          GROUP BY x.uid, x.p) a
    FULL OUTER JOIN (
      SELECT pr.uid, pr.p, count(*) AS c, md5(string_agg(hh.due_date::text, ',' ORDER BY hh.due_date)) AS h
      FROM pg_temp.c01_probes() pr
      CROSS JOIN LATERAL public.fn_due_eligible_dates(pr.uid, pr.p) hh
      GROUP BY pr.uid, pr.p
    ) b ON a.uid = b.uid AND a.p = b.p
    WHERE a.uid IS NULL OR b.uid IS NULL OR a.c <> b.c OR a.h <> b.h
  ) m;
  SELECT jsonb_build_object(
    'skip_until_exactly_yesterday_rows', count(*) FILTER (WHERE x.su = x.p - 1),
    'skip_until_exactly_today_rows', count(*) FILTER (WHERE x.su = x.p),
    'skip_until_exactly_tomorrow_rows', count(*) FILTER (WHERE x.su = x.p + 1),
    'due_exactly_today_and_not_skipped_rows', count(*) FILTER (WHERE x.nrd = x.p AND COALESCE(x.su, DATE '-infinity') <= x.p),
    'due_exactly_in_3_days_rows', count(*) FILTER (WHERE x.nrd = x.p + 3 AND COALESCE(x.su, DATE '-infinity') <= x.p),
    'due_exactly_tomorrow_rows', count(*) FILTER (WHERE x.nrd = x.p + 1 AND COALESCE(x.su, DATE '-infinity') <= x.p),
    'overdue_by_exactly_one_day_rows', count(*) FILTER (WHERE x.nrd = x.p - 1 AND COALESCE(x.su, DATE '-infinity') <= x.p))
  INTO v_rel
  FROM pg_temp.c01_rows_at() x;
  RETURN jsonb_build_object(
    'run', 'T5',
    'probe_pairs_user_and_date', v_pairs,
    'pairs_whose_helper_result_differs_from_the_recomputation', v_mis,
    'decisive_live_rows_by_boundary_relation', v_rel,
    'boundary_relations_with_no_decisive_row',
      (SELECT COALESCE(jsonb_agg(e.key ORDER BY e.key), '[]'::jsonb) FROM jsonb_each(v_rel) e WHERE (e.value)::text::integer = 0),
    'all_passed', (v_pairs > 0 AND v_mis = 0));
END;
$$;
SELECT pg_temp.c01_t5() AS result;
