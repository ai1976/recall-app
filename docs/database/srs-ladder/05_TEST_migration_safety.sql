-- Name: [TEST] SRS Ladder Epic — Phase 2 migration safety (due-count stability + schedule integrity)
--
-- Description:
--   Wraps the Phase 2 backfill (04_MIGRATION) with a before/after safety check, per the epic's
--   acceptance criteria:
--     • per-student get_study_queue() due-count MUST be materially unchanged (no overdue /
--       mastered pile) — the backfill only writes `rung`, and get_study_queue never filters on it,
--       so the correct expected delta is EXACTLY 0 for every student.
--     • next_review_date / status / skip_until MUST be byte-identical for every row.
--     • every review row ends with a non-NULL rung.
--
--   ── HOW TO RUN ──
--     1. Run PART A  (this file, top section)         → creates 3 baseline tables, prints totals.
--     2. Run 04_MIGRATION_backfill_rung.sql           → the backfill (commits).
--     3. Run PART B  (this file, bottom section)      → compares, prints diffs, drops baselines.
--   PART A and PART B are separate submissions on purpose (04 commits between them).
--   The baseline tables are real (committed) `public._srs_ladder_*` tables; PART B drops them.

-- ══════════════════════════════════════════════════════════════════════════════
-- ██  PART A  — run BEFORE 04_MIGRATION  ██
-- ══════════════════════════════════════════════════════════════════════════════

DROP TABLE IF EXISTS public._srs_ladder_row_baseline;
DROP TABLE IF EXISTS public._srs_ladder_due_baseline;
DROP TABLE IF EXISTS public._srs_ladder_due_after;

-- full per-row schedule snapshot (7,824 tiny rows)
CREATE TABLE public._srs_ladder_row_baseline AS
SELECT id, next_review_date, status, skip_until, rung
FROM public.reviews;

-- per-student TRUE due-count via get_study_queue (impersonating each student)
CREATE TABLE public._srs_ladder_due_baseline (
  user_id   uuid PRIMARY KEY,
  full_name text,
  due_count integer
);

DO $$
DECLARE v_u uuid; v_n text; v_c integer;
BEGIN
  FOR v_u, v_n IN
    SELECT id, full_name FROM public.profiles WHERE role = 'student'
  LOOP
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_u, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_c FROM public.get_study_queue(v_u);
    INSERT INTO public._srs_ladder_due_baseline VALUES (v_u, v_n, v_c);
  END LOOP;
  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

SELECT
  (SELECT count(*) FROM public._srs_ladder_row_baseline)                      AS rows_snapshotted,
  (SELECT count(*) FROM public._srs_ladder_due_baseline)                      AS students_snapshotted,
  (SELECT COALESCE(sum(due_count), 0) FROM public._srs_ladder_due_baseline)   AS total_due_before;

-- ⏸  STOP. Now run 04_MIGRATION_backfill_rung.sql, then run PART B below.


-- ══════════════════════════════════════════════════════════════════════════════
-- ██  PART B  — run AFTER 04_MIGRATION  ██
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. schedule integrity — expect rows_with_changed_schedule = 0
SELECT count(*) AS rows_with_changed_schedule
FROM public.reviews r
JOIN public._srs_ladder_row_baseline b USING (id)
WHERE r.next_review_date IS DISTINCT FROM b.next_review_date
   OR r.status           IS DISTINCT FROM b.status
   OR r.skip_until        IS DISTINCT FROM b.skip_until;

-- 2. rung fully backfilled — expect reviews_still_null_rung = 0
SELECT count(*) AS reviews_still_null_rung FROM public.reviews WHERE rung IS NULL;

-- 3. recompute per-student due-count and diff against the baseline
CREATE TABLE public._srs_ladder_due_after (
  user_id   uuid PRIMARY KEY,
  due_count integer
);

DO $$
DECLARE v_u uuid; v_c integer;
BEGIN
  FOR v_u IN SELECT user_id FROM public._srs_ladder_due_baseline LOOP
    PERFORM set_config('request.jwt.claims',
      json_build_object('sub', v_u, 'role', 'authenticated')::text, true);
    SELECT count(*) INTO v_c FROM public.get_study_queue(v_u);
    INSERT INTO public._srs_ladder_due_after VALUES (v_u, v_c);
  END LOOP;
  PERFORM set_config('request.jwt.claims', NULL, true);
END $$;

-- expect ZERO rows (backfill must not move any student's due-count)
SELECT b.full_name, b.due_count AS before, a.due_count AS after,
       a.due_count - b.due_count AS delta
FROM public._srs_ladder_due_baseline b
JOIN public._srs_ladder_due_after a USING (user_id)
WHERE a.due_count <> b.due_count
ORDER BY abs(a.due_count - b.due_count) DESC;

-- summary line
SELECT
  (SELECT COALESCE(sum(due_count),0) FROM public._srs_ladder_due_baseline) AS total_due_before,
  (SELECT COALESCE(sum(due_count),0) FROM public._srs_ladder_due_after)    AS total_due_after,
  (SELECT count(*) FROM public._srs_ladder_due_after a
     JOIN public._srs_ladder_due_baseline b USING (user_id)
     WHERE a.due_count <> b.due_count)                                     AS students_with_changed_due;

-- 4. resulting rung distribution
SELECT rung, count(*) AS rows FROM public.reviews GROUP BY rung ORDER BY rung;

-- 5. cleanup
DROP TABLE public._srs_ladder_row_baseline;
DROP TABLE public._srs_ladder_due_baseline;
DROP TABLE public._srs_ladder_due_after;
