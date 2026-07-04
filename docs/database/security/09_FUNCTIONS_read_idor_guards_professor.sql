-- Name: [FUNCTIONS] Read-IDOR guards — professor analytics
-- Description: get_professor_overview / _subject_engagement / _top_cards / _weak_cards /
-- _weekly_reach take p_professor_id and return that professor's content analytics + student
-- engagement, with no auth.uid() check — any authenticated user could pass another professor's UUID.
-- Frontend (ProfessorAnalytics.jsx) always passes `p_professor_id: user.id` (self), so guard to
-- self-or-admin. Bodies verbatim from 07b; guard added after BEGIN. Pure SQL, no frontend dependency.

CREATE OR REPLACE FUNCTION public.get_professor_overview(p_professor_id uuid, p_course_level text)
 RETURNS TABLE(total_cards_published bigint, total_students_reached bigint, total_reviews bigint, avg_quality numeric)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_professor_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another professor''s analytics';
  END IF;
  RETURN QUERY
  WITH prof_cards AS (
    SELECT id FROM flashcards WHERE user_id = p_professor_id AND target_course = p_course_level
  ),
  card_count AS (SELECT COUNT(*) AS cnt FROM prof_cards),
  review_stats AS (
    SELECT COUNT(DISTINCT r.user_id) AS students_reached, COUNT(r.id) AS total_reviews,
           ROUND(AVG(r.quality)::NUMERIC, 1) AS avg_quality
    FROM reviews r WHERE r.flashcard_id IN (SELECT id FROM prof_cards)
  )
  SELECT cc.cnt::BIGINT, rs.students_reached::BIGINT, rs.total_reviews::BIGINT, rs.avg_quality
  FROM card_count cc CROSS JOIN review_stats rs;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_professor_subject_engagement(p_professor_id uuid, p_course_level text)
 RETURNS TABLE(subject_name text, card_count bigint, unique_students bigint, total_reviews bigint, avg_quality numeric)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_professor_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another professor''s analytics';
  END IF;
  RETURN QUERY
  SELECT COALESCE(s.name, f.custom_subject, 'Uncategorized'), COUNT(DISTINCT f.id)::BIGINT,
         COUNT(DISTINCT r.user_id)::BIGINT, COUNT(r.id)::BIGINT, ROUND(AVG(r.quality)::NUMERIC, 1)
  FROM flashcards f
  LEFT JOIN subjects s ON s.id = f.subject_id
  LEFT JOIN reviews r ON r.flashcard_id = f.id
  WHERE f.user_id = p_professor_id AND f.target_course = p_course_level
  GROUP BY COALESCE(s.name, f.custom_subject, 'Uncategorized')
  ORDER BY COUNT(r.id) DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_professor_top_cards(p_professor_id uuid, p_course_level text)
 RETURNS TABLE(card_id uuid, front_text text, subject_name text, total_reviews bigint, avg_quality numeric)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_professor_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another professor''s analytics';
  END IF;
  RETURN QUERY
  SELECT f.id, LEFT(f.front_text, 100), COALESCE(s.name, f.custom_subject, 'Uncategorized'),
         COUNT(r.id)::BIGINT, ROUND(AVG(r.quality)::NUMERIC, 1)
  FROM flashcards f
  LEFT JOIN subjects s ON s.id = f.subject_id
  JOIN reviews r ON r.flashcard_id = f.id
  WHERE f.user_id = p_professor_id AND f.target_course = p_course_level
  GROUP BY f.id, f.front_text, COALESCE(s.name, f.custom_subject, 'Uncategorized')
  ORDER BY COUNT(r.id) DESC, ROUND(AVG(r.quality)::NUMERIC, 1) DESC
  LIMIT 10;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_professor_weak_cards(p_professor_id uuid, p_course_level text)
 RETURNS TABLE(card_id uuid, front_text text, subject_name text, avg_quality numeric, review_count bigint)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_professor_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another professor''s analytics';
  END IF;
  RETURN QUERY
  SELECT f.id, LEFT(f.front_text, 100), COALESCE(s.name, f.custom_subject, 'Uncategorized'),
         ROUND(AVG(r.quality)::NUMERIC, 1), COUNT(r.id)::BIGINT
  FROM flashcards f
  LEFT JOIN subjects s ON s.id = f.subject_id
  JOIN reviews r ON r.flashcard_id = f.id
  WHERE f.user_id = p_professor_id AND f.target_course = p_course_level
  GROUP BY f.id, f.front_text, COALESCE(s.name, f.custom_subject, 'Uncategorized')
  HAVING COUNT(r.id) >= 3
  ORDER BY ROUND(AVG(r.quality)::NUMERIC, 1) ASC, COUNT(r.id) DESC
  LIMIT 10;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_professor_weekly_reach(p_professor_id uuid, p_course_level text)
 RETURNS TABLE(week_start date, new_students integer)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_professor_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another professor''s analytics';
  END IF;
  RETURN QUERY
  WITH prof_cards AS (
    SELECT id FROM flashcards WHERE user_id = p_professor_id AND target_course = p_course_level
  ),
  first_reviews AS (
    SELECT r.user_id, date_trunc('week', MIN(r.created_at))::date AS first_week
    FROM reviews r WHERE r.flashcard_id IN (SELECT id FROM prof_cards)
    GROUP BY r.user_id
  ),
  date_spine AS (
    SELECT generate_series(
      date_trunc('week', CURRENT_DATE - INTERVAL '7 weeks'),
      date_trunc('week', CURRENT_DATE),
      INTERVAL '1 week'
    )::date AS week_start
  )
  SELECT ds.week_start, COUNT(fr.user_id)::INTEGER
  FROM date_spine ds
  LEFT JOIN first_reviews fr ON fr.first_week = ds.week_start
  GROUP BY ds.week_start
  ORDER BY ds.week_start;
END;
$function$;
