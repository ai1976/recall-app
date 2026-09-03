-- Name: [DIAGNOSTIC] SRS Ladder Epic — Phase 0 ground-truth measurements
--
-- Description:
--   Read-only introspection for the SRS Ladder Epic Phase 0. Run each block
--   separately in the Supabase SQL Editor and paste the results back into
--   docs/active/design-review/srs-ladder-proposal.md (the "Phase 0 measured
--   numbers" tables). NOTHING here writes. No ROLLBACK needed — every block is
--   a pure SELECT.
--
--   Blocks:
--     Q1  reviews.status distinct values + row counts   (is 'mastered' already live?)
--     Q2  reviews.status CHECK constraint definition     (exact allowed list)
--     Q3  reviews.repetition histogram
--     Q4  reviews.easiness distribution
--     Q5  reviews total row count + table size + backfill sizing
--     Q6  reviews.next_review_date COLUMN TYPE           (DATE vs timestamp — confirm)
--     Q7  reviews_user_flashcard_unique — one row per (user,card)? (confirm)
--     Q8  profiles.course_level distinct values + counts
--     Q9  flashcards.target_course distinct values + counts
--     Q10 course DRIFT — active reviews whose card target_course != owner course_level
--     Q11 question_type distinct values on flashcards (curve coverage)
--     Q12 per-student due-count baseline sample (for the Phase 2 before/after check)
--
-- ============================================================================
-- Q1 — reviews.status distinct values + row counts
--     Needed: MASTERED design. The epic proposes status='mastered'; confirm it
--     is NOT already a live value and see what else exists beyond active/suspended.
-- ============================================================================
SELECT status, COUNT(*) AS rows
FROM reviews
GROUP BY status
ORDER BY rows DESC;

-- ============================================================================
-- Q2 — the CHECK constraint on reviews.status (exact allowed list)
--     Needed: Phase 1 must ALTER this to add 'mastered'. Capture the current
--     definition verbatim so the ALTER is a precise superset.
-- ============================================================================
SELECT con.conname, pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
WHERE rel.relname = 'reviews'
  AND nsp.nspname = 'public'
  AND con.contype = 'c'
ORDER BY con.conname;

-- ============================================================================
-- Q3 — reviews.repetition histogram
--     Needed: the repetition -> rung migration mapping + the rung cap. Shows how
--     many rows would land on each rung and how heavy the tail is.
-- ============================================================================
SELECT
  repetition,
  COUNT(*)                                            AS rows,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)  AS pct
FROM reviews
GROUP BY repetition
ORDER BY repetition;

-- Q3b — bucketed view (rungs 0..7 with an overflow bucket)
SELECT
  LEAST(repetition, 8) AS repetition_bucket,   -- 8 = "8 or more"
  COUNT(*)             AS rows
FROM reviews
GROUP BY LEAST(repetition, 8)
ORDER BY repetition_bucket;

-- ============================================================================
-- Q4 — reviews.easiness distribution
--     Needed: whether easiness can act as a governor on the rung cap for
--     heavily-reviewed-but-struggling cards. StudyMode writes 2.3 (Hard) /
--     2.5 (Medium) / 2.6 (Easy), so this is effectively "last grade".
-- ============================================================================
SELECT
  ROUND(easiness::numeric, 2) AS easiness,
  COUNT(*)                    AS rows
FROM reviews
GROUP BY ROUND(easiness::numeric, 2)
ORDER BY easiness;

-- Q4b — cross-tab: how many high-repetition rows also have low easiness
--       (these are the cards a naive repetition->rung map would wrongly push near MASTERED)
SELECT
  CASE WHEN repetition >= 7 THEN '7+' ELSE repetition::text END AS repetition_band,
  CASE
    WHEN easiness <= 2.35 THEN 'low (<=2.35, last=Hard)'
    WHEN easiness <= 2.55 THEN 'mid (~2.5, last=Medium)'
    ELSE 'high (>2.55, last=Easy)'
  END AS easiness_band,
  COUNT(*) AS rows
FROM reviews
GROUP BY 1, 2
ORDER BY 1, 2;

-- ============================================================================
-- Q5 — reviews total rows + table size + backfill sizing
--     Needed: Phase 2 batch plan. NOTE: an in-place UPDATE of one integer column
--     produces ~zero client egress (egress = data leaving to clients); the Free-plan
--     risk here is DB size (500 MB) + disk IO, both negligible for a smallint column.
-- ============================================================================
SELECT
  (SELECT COUNT(*) FROM reviews)                          AS total_review_rows,
  pg_size_pretty(pg_total_relation_size('public.reviews')) AS table_total_size,
  pg_size_pretty(pg_relation_size('public.reviews'))       AS heap_size,
  pg_size_pretty(pg_indexes_size('public.reviews'))        AS indexes_size;

-- ============================================================================
-- Q6 — CONFIRM reviews.next_review_date column type
--     blueprint.md §185 says DATE; DATABASE_SCHEMA.md §298 says timestamp.
--     The migration must NOT touch this column; still, the engine needs the
--     real type. Also check skip_until + last_reviewed_at while we're here.
-- ============================================================================
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'reviews'
ORDER BY ordinal_position;

-- ============================================================================
-- Q7 — CONFIRM one review row per (user_id, flashcard_id)
--     Needed: if the UNIQUE constraint holds, the backfill is a single-pass
--     UPDATE with no DISTINCT ON needed.
-- ============================================================================
SELECT user_id, flashcard_id, COUNT(*) AS dup_rows
FROM reviews
GROUP BY user_id, flashcard_id
HAVING COUNT(*) > 1
LIMIT 20;
-- (expect 0 rows)

-- ============================================================================
-- Q8 — profiles.course_level distinct values + counts
-- ============================================================================
SELECT COALESCE(course_level, '<NULL>') AS course_level, COUNT(*) AS users
FROM profiles
GROUP BY course_level
ORDER BY users DESC;

-- ============================================================================
-- Q9 — flashcards.target_course distinct values + counts
-- ============================================================================
SELECT COALESCE(target_course, '<NULL>') AS target_course, COUNT(*) AS cards
FROM flashcards
GROUP BY target_course
ORDER BY cards DESC;

-- ============================================================================
-- Q10 — COURSE DRIFT impact
--     Active reviews whose card's target_course does NOT exact-match the
--     owning student's course_level (both non-null). These are cards the
--     course-filtered get_study_queue silently drops.
-- ============================================================================
SELECT
  COUNT(*)                                  AS drifted_active_reviews,
  COUNT(DISTINCT r.user_id)                 AS students_affected,
  COUNT(DISTINCT f.id)                      AS distinct_cards
FROM reviews r
JOIN flashcards f ON f.id = r.flashcard_id
JOIN profiles  p ON p.id = r.user_id
WHERE r.status = 'active'
  AND p.course_level IS NOT NULL
  AND f.target_course IS NOT NULL
  AND f.target_course <> p.course_level;

-- Q10b — the actual mismatched (owner_course, card_course) pairs, most common first
SELECT p.course_level AS owner_course, f.target_course AS card_course, COUNT(*) AS active_reviews
FROM reviews r
JOIN flashcards f ON f.id = r.flashcard_id
JOIN profiles  p ON p.id = r.user_id
WHERE r.status = 'active'
  AND p.course_level IS NOT NULL
  AND f.target_course IS NOT NULL
  AND f.target_course <> p.course_level
GROUP BY 1, 2
ORDER BY active_reviews DESC
LIMIT 40;

-- ============================================================================
-- Q11 — question_type coverage (which curves the config table must resolve)
-- ============================================================================
SELECT COALESCE(question_type, '<NULL>') AS question_type, COUNT(*) AS cards
FROM flashcards
GROUP BY question_type
ORDER BY cards DESC;

-- ============================================================================
-- Q12 — per-student due-count BASELINE sample (Phase 2 before/after safety check)
--     Captures the raw "active + due today (server date)" count per student for
--     the 15 students with the most due rows. Re-run the identical query
--     immediately after the Phase 2 backfill; the numbers must be unchanged
--     (the backfill only writes the rung column, never next_review_date).
--     NOTE: this is a raw baseline (server CURRENT_DATE, no course/visibility
--     filter) — it is a MIGRATION-STABILITY probe, not the get_study_queue
--     number. The Phase 2 verification also diffs get_study_queue() per student.
-- ============================================================================
SELECT
  r.user_id,
  p.full_name,
  p.course_level,
  COUNT(*) FILTER (
    WHERE r.status = 'active'
      AND r.next_review_date::date <= CURRENT_DATE
      AND (r.skip_until IS NULL OR r.skip_until <= CURRENT_DATE)
  ) AS due_today_raw,
  COUNT(*) FILTER (WHERE r.status = 'active')   AS active_rows_total
FROM reviews r
JOIN profiles p ON p.id = r.user_id
GROUP BY r.user_id, p.full_name, p.course_level
ORDER BY due_today_raw DESC
LIMIT 15;
