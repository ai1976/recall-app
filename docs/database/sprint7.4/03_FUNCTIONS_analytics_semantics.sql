-- Name: [FUNCTIONS] Sprint 7.4 — two-measure analytics semantics (recall success + answer accuracy)
--
-- Description:
--   Run AFTER 01_SCHEMA + 02_FUNCTIONS are committed (review_events must
--   exist). Pure DROP + CREATE (see note below on why not CREATE OR REPLACE);
--   let it COMMIT, then 04_TEST verifies in its own submission.
--
--   Both RPCs: same signature as live (introspected via Phase 0, Q6a/Q6b —
--   preserved exactly), `accuracy_pct` renamed to `recall_success_pct`
--   (computation UNCHANGED — same quality-based formula, same source table,
--   purely a rename), plus two new columns: `graded_count` (count of
--   review_events rows for that question_type with is_correct IS NOT NULL)
--   and `answer_accuracy_pct` (NULL when graded_count = 0 — drives the
--   "No graded answers yet" frontend state).
--
--   DROP + CREATE instead of CREATE OR REPLACE: PostgreSQL identifies a
--   function for CREATE OR REPLACE purposes by its IN-argument signature
--   only, and RETURNS TABLE columns are technically OUT parameters — but
--   this project already hit exactly this shape of change once before
--   (02_FUNCTIONS_srs_ladder_engine.sql, get_study_queue, "DROP + CREATE to
--   append `rung`") and chose DROP+CREATE deliberately there rather than
--   risk a live "cannot change return type" error. Same call here, for the
--   same reason. Grants are NOT preserved by DROP — both re-issued explicitly
--   below, copied verbatim from the live grants.
--
--   Join-shape note (why a plain LEFT JOIN would have double-counted):
--   review_events is append-only (many rows per card over time), while the
--   existing `all_reviews` / `reviews r` joins are at-most-one-row-per-card.
--   Joining review_events straight into those CTEs would fan out the
--   existing recall_success_pct COUNT()s. Both queries below instead
--   pre-aggregate review_events into a one-row-per-key CTE first, so the
--   original recall_success_pct arithmetic is untouched byte-for-byte.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. get_question_type_performance — student, Progress.jsx
-- ═══════════════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.get_question_type_performance(uuid, text);

CREATE FUNCTION public.get_question_type_performance(p_user_id uuid, p_course_level text DEFAULT NULL::text)
 RETURNS TABLE (
   question_type         text,
   total_cards_available  bigint,
   reviewed_count         bigint,
   recall_success_pct     numeric,
   graded_count           integer,
   answer_accuracy_pct    numeric
 )
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  WITH available_cards AS (
    SELECT f.id AS card_id, COALESCE(f.question_type, 'flashcard') AS question_type
    FROM flashcards f
    WHERE (p_course_level IS NULL OR f.target_course = p_course_level)
      AND (f.visibility = 'public' OR f.user_id = p_user_id)
      AND COALESCE(f.question_type, 'flashcard') <> 'concept_card'
  ),
  all_reviews AS (
    SELECT r.flashcard_id, r.quality
    FROM reviews r JOIN available_cards ac ON ac.card_id = r.flashcard_id
    WHERE r.user_id = p_user_id AND r.status = 'active'
  ),
  graded_agg AS (
    -- pre-aggregated to exactly one row per flashcard_id, so joining it below
    -- cannot fan out all_reviews's existing one-row-per-card cardinality.
    SELECT re.flashcard_id,
           COUNT(*) FILTER (WHERE re.is_correct IS NOT NULL)::int AS graded_count,
           COUNT(*) FILTER (WHERE re.is_correct IS TRUE)::int     AS correct_count
    FROM review_events re
    WHERE re.user_id = p_user_id
    GROUP BY re.flashcard_id
  )
  SELECT
    ac.question_type,
    COUNT(DISTINCT ac.card_id),
    COUNT(DISTINCT ar.flashcard_id),
    CASE WHEN COUNT(ar.quality) = 0 THEN 0
    ELSE ROUND(COUNT(CASE WHEN ar.quality >= 3 THEN 1 END)::numeric / COUNT(ar.quality)::numeric * 100, 1) END,
    COALESCE(SUM(ga.graded_count), 0)::integer,
    CASE WHEN COALESCE(SUM(ga.graded_count), 0) = 0 THEN NULL
    ELSE ROUND(SUM(ga.correct_count)::numeric / SUM(ga.graded_count)::numeric * 100, 1) END
  FROM available_cards ac
  LEFT JOIN all_reviews ar ON ar.flashcard_id = ac.card_id
  LEFT JOIN graded_agg ga  ON ga.flashcard_id = ac.card_id
  GROUP BY ac.question_type
  ORDER BY COUNT(DISTINCT ac.card_id) DESC;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_question_type_performance(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_question_type_performance(uuid, text) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. get_educator_accuracy_by_qtype — professor, Dashboard.jsx
-- ═══════════════════════════════════════════════════════════════════════════════
DROP FUNCTION IF EXISTS public.get_educator_accuracy_by_qtype(uuid, text);

CREATE FUNCTION public.get_educator_accuracy_by_qtype(
  p_professor_id uuid,
  p_course_level text
)
 RETURNS TABLE (
   question_type       text,
   total_graded         integer,
   hits                 integer,
   recall_success_pct   numeric,
   graded_count         integer,
   answer_accuracy_pct  numeric
 )
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_professor_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another educator''s cohort';
  END IF;

  RETURN QUERY
  WITH prof_cards AS (
    SELECT f.id, f.question_type
    FROM flashcards f
    WHERE f.user_id = p_professor_id
      AND f.target_course = p_course_level
      AND f.question_type <> 'concept_card'
  ),
  graded_agg AS (
    -- one row per question_type (cohort-wide, all students' graded events on
    -- this professor's cards) — computed independently of the prof_cards/
    -- reviews fan-out join below, then broadcast-joined back via MAX().
    SELECT pc.question_type,
           COUNT(*) FILTER (WHERE re.is_correct IS NOT NULL)::int AS graded_count,
           COUNT(*) FILTER (WHERE re.is_correct IS TRUE)::int     AS correct_count
    FROM prof_cards pc
    JOIN review_events re ON re.flashcard_id = pc.id
    GROUP BY pc.question_type
  )
  SELECT
    pc.question_type,
    COUNT(*) FILTER (WHERE r.quality > 0)::int,
    COUNT(*) FILTER (WHERE r.quality IN (3, 5))::int,
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE r.quality IN (3, 5))
            / NULLIF(COUNT(*) FILTER (WHERE r.quality > 0), 0),
      1
    ),
    COALESCE(MAX(ga.graded_count), 0),
    CASE WHEN COALESCE(MAX(ga.graded_count), 0) = 0 THEN NULL
    ELSE ROUND(MAX(ga.correct_count)::numeric / MAX(ga.graded_count)::numeric * 100, 1) END
  FROM prof_cards pc
  JOIN reviews r ON r.flashcard_id = pc.id
  LEFT JOIN graded_agg ga ON ga.question_type = pc.question_type
  GROUP BY pc.question_type
  HAVING COUNT(*) FILTER (WHERE r.quality > 0) > 0
  ORDER BY COUNT(*) FILTER (WHERE r.quality > 0) DESC;
END;
$function$;

REVOKE ALL     ON FUNCTION public.get_educator_accuracy_by_qtype(uuid, text) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_educator_accuracy_by_qtype(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
