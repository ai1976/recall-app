-- Name: [FUNCTIONS] Read-IDOR guards — group A (self-scoped user data)
-- Description: Guards SECURITY DEFINER functions that take p_user_id and return/modify that user's
-- private data, so a caller can only act on their OWN id (admins exempt). Fixes the read-side IDOR
-- found in 07_DIAGNOSTIC (attacker passing another student's UUID could read their study stats,
-- notifications, suspended cards, streak, badges) plus two writers the L5 audit's regex missed
-- (unsuspend_card, get_unnotified_badges). Bodies reproduced verbatim from 07 Block 2; the four
-- LANGUAGE sql functions are converted to plpgsql (same query wrapped in RETURN QUERY) so a RAISE
-- guard can be added — CREATE OR REPLACE permits the language change (signature/return unchanged).
-- Guard: `IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN RAISE`.

-- 1. get_due_forecast (sql -> plpgsql)
CREATE OR REPLACE FUNCTION public.get_due_forecast(p_user_id uuid)
 RETURNS TABLE(due_today integer, due_next_7 integer, due_next_30 integer)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  WITH latest_reviews AS (
    SELECT DISTINCT ON (flashcard_id) flashcard_id, next_review_date, skip_until
    FROM reviews WHERE user_id = p_user_id AND status = 'active'
    ORDER BY flashcard_id, created_at DESC
  )
  SELECT
    COUNT(CASE WHEN next_review_date::date <= CURRENT_DATE AND (skip_until IS NULL OR skip_until < CURRENT_DATE) THEN 1 END)::integer,
    COUNT(CASE WHEN next_review_date::date <= CURRENT_DATE + 7 AND (skip_until IS NULL OR skip_until < CURRENT_DATE) THEN 1 END)::integer,
    COUNT(CASE WHEN next_review_date::date <= CURRENT_DATE + 30 AND (skip_until IS NULL OR skip_until < CURRENT_DATE) THEN 1 END)::integer
  FROM latest_reviews;
END;
$function$;

-- 2. get_question_type_performance (sql -> plpgsql)
CREATE OR REPLACE FUNCTION public.get_question_type_performance(p_user_id uuid, p_course_level text DEFAULT NULL::text)
 RETURNS TABLE(question_type text, total_cards_available bigint, reviewed_count bigint, accuracy_pct numeric)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
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
  )
  SELECT
    ac.question_type,
    COUNT(DISTINCT ac.card_id),
    COUNT(DISTINCT ar.flashcard_id),
    CASE WHEN COUNT(ar.quality) = 0 THEN 0
    ELSE ROUND(COUNT(CASE WHEN ar.quality >= 3 THEN 1 END)::numeric / COUNT(ar.quality)::numeric * 100, 1) END
  FROM available_cards ac
  LEFT JOIN all_reviews ar ON ar.flashcard_id = ac.card_id
  GROUP BY ac.question_type
  ORDER BY COUNT(DISTINCT ac.card_id) DESC;
END;
$function$;

-- 3. get_study_heatmap (sql -> plpgsql)
CREATE OR REPLACE FUNCTION public.get_study_heatmap(p_user_id uuid, p_days integer DEFAULT 90)
 RETURNS TABLE(review_date date, review_count integer)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  WITH user_tz AS (
    SELECT COALESCE(timezone, 'Asia/Kolkata') AS tz FROM profiles WHERE id = p_user_id
  ),
  aggregated_reviews AS (
    SELECT (created_at AT TIME ZONE (SELECT tz FROM user_tz))::date AS rdate, COUNT(*)::integer AS cnt
    FROM reviews
    WHERE user_id = p_user_id AND status = 'active' AND created_at >= NOW() - (p_days || ' days')::interval
    GROUP BY 1
  )
  SELECT ual.activity_date, COALESCE(ar.cnt, 0)
  FROM user_activity_log ual
  LEFT JOIN aggregated_reviews ar ON ar.rdate = ual.activity_date
  WHERE ual.user_id = p_user_id AND ual.activity_type = 'review' AND ual.activity_date >= CURRENT_DATE - p_days
  ORDER BY ual.activity_date;
END;
$function$;

-- 4. get_subject_mastery_v1 (sql -> plpgsql)
CREATE OR REPLACE FUNCTION public.get_subject_mastery_v1(p_user_id uuid, p_course_level text DEFAULT NULL::text)
 RETURNS TABLE(subject_id uuid, subject_name text, total_cards bigint, reviewed_count bigint, mastery_pct numeric, due_count bigint)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  WITH available_cards AS (
    SELECT f.id AS card_id, f.subject_id, f.custom_subject
    FROM flashcards f
    WHERE (p_course_level IS NULL OR f.target_course = p_course_level)
      AND (f.visibility = 'public' OR f.user_id = p_user_id)
      AND COALESCE(f.question_type, 'flashcard') <> 'concept_card'
  ),
  latest_reviews AS (
    SELECT DISTINCT ON (r.flashcard_id) r.flashcard_id, r.quality, r.next_review_date, r.skip_until
    FROM reviews r WHERE r.user_id = p_user_id AND r.status = 'active'
    ORDER BY r.flashcard_id, r.created_at DESC
  )
  SELECT
    s.id,
    COALESCE(s.name, ac.custom_subject, 'Uncategorized'),
    COUNT(DISTINCT ac.card_id),
    COUNT(DISTINCT lr.flashcard_id),
    CASE WHEN COUNT(DISTINCT ac.card_id) = 0 THEN 0
    ELSE ROUND(COUNT(DISTINCT CASE WHEN lr.quality >= 3 THEN lr.flashcard_id END)::numeric / COUNT(DISTINCT ac.card_id)::numeric * 100, 1) END,
    COUNT(DISTINCT CASE WHEN lr.next_review_date::date <= CURRENT_DATE AND (lr.skip_until IS NULL OR lr.skip_until < CURRENT_DATE) THEN lr.flashcard_id END)
  FROM available_cards ac
  LEFT JOIN subjects s ON s.id = ac.subject_id
  LEFT JOIN latest_reviews lr ON lr.flashcard_id = ac.card_id
  GROUP BY s.id, COALESCE(s.name, ac.custom_subject, 'Uncategorized')
  ORDER BY COUNT(DISTINCT ac.card_id) DESC, COALESCE(s.name, ac.custom_subject, 'Uncategorized');
END;
$function$;

-- 5. get_recent_notifications (plpgsql — guard only)
CREATE OR REPLACE FUNCTION public.get_recent_notifications(p_user_id uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(id uuid, user_id uuid, actor_id uuid, type text, title text, message text, is_read boolean, metadata jsonb, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  SELECT n.id, n.user_id, n.actor_id, n.type, n.title, n.message, n.is_read, n.metadata, n.created_at, n.updated_at
  FROM notifications n
  WHERE n.user_id = p_user_id
  ORDER BY n.updated_at DESC
  LIMIT p_limit;
END;
$function$;

-- 6. get_study_time_stats (plpgsql — guard only)
CREATE OR REPLACE FUNCTION public.get_study_time_stats(p_user_id uuid, p_local_date date)
 RETURNS TABLE(today_seconds bigint, week_seconds bigint, today_sessions bigint, week_sessions bigint)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
DECLARE
  v_week_start date;
  v_week_end   date;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  v_week_start := date_trunc('week', p_local_date)::date;
  v_week_end   := v_week_start + 6;
  RETURN QUERY
  SELECT
    COALESCE(SUM(CASE WHEN s.session_date = p_local_date THEN s.duration_seconds ELSE 0 END), 0)::bigint,
    COALESCE(SUM(CASE WHEN s.session_date BETWEEN v_week_start AND v_week_end THEN s.duration_seconds ELSE 0 END), 0)::bigint,
    COUNT(CASE WHEN s.session_date = p_local_date THEN 1 END)::bigint,
    COUNT(CASE WHEN s.session_date BETWEEN v_week_start AND v_week_end THEN 1 END)::bigint
  FROM public.study_sessions s
  WHERE s.user_id = p_user_id;
END;
$function$;

-- 7. get_suspended_cards (plpgsql — guard only)
CREATE OR REPLACE FUNCTION public.get_suspended_cards(p_user_id uuid)
 RETURNS TABLE(review_id uuid, flashcard_id uuid, front_text text, back_text text, subject_name text, topic_name text, suspended_at timestamp with time zone)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  SELECT r.id, r.flashcard_id, f.front_text, f.back_text,
    COALESCE(s.name, f.custom_subject), COALESCE(t.name, f.custom_topic), r.created_at
  FROM reviews r
  JOIN flashcards f ON f.id = r.flashcard_id
  LEFT JOIN subjects s ON s.id = f.subject_id
  LEFT JOIN topics t ON t.id = f.topic_id
  WHERE r.user_id = p_user_id AND r.status = 'suspended'
  ORDER BY COALESCE(s.name, f.custom_subject, 'ZZZ'), f.front_text;
END;
$function$;

-- 8. get_user_streak (plpgsql — guard only)
CREATE OR REPLACE FUNCTION public.get_user_streak(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
DECLARE
  v_user_tz TEXT; v_today DATE; v_yesterday DATE; v_streak INTEGER := 0;
  v_check_date DATE; v_study_dates DATE[]; v_most_recent_date DATE;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  SELECT COALESCE(timezone, 'UTC') INTO v_user_tz FROM profiles WHERE id = p_user_id;
  v_today := (NOW() AT TIME ZONE v_user_tz)::DATE;
  v_yesterday := v_today - INTERVAL '1 day';
  SELECT ARRAY_AGG(DISTINCT (created_at AT TIME ZONE v_user_tz)::DATE ORDER BY (created_at AT TIME ZONE v_user_tz)::DATE DESC)
    INTO v_study_dates FROM reviews WHERE user_id = p_user_id;
  IF v_study_dates IS NULL OR array_length(v_study_dates, 1) IS NULL THEN RETURN 0; END IF;
  v_most_recent_date := v_study_dates[1];
  IF v_most_recent_date != v_today AND v_most_recent_date != v_yesterday THEN RETURN 0; END IF;
  IF v_most_recent_date = v_yesterday THEN v_check_date := v_yesterday; ELSE v_check_date := v_today; END IF;
  WHILE v_check_date = ANY(v_study_dates) LOOP
    v_streak := v_streak + 1;
    v_check_date := v_check_date - INTERVAL '1 day';
    IF v_streak >= 365 THEN EXIT; END IF;
  END LOOP;
  RETURN v_streak;
END;
$function$;

-- 9. get_unnotified_badges (plpgsql, reads + marks notified — guard blocks cross-user read AND write)
CREATE OR REPLACE FUNCTION public.get_unnotified_badges(p_user_id uuid)
 RETURNS TABLE(badge_key text, badge_name text, description text, icon_key text)
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot read another user''s data';
  END IF;
  RETURN QUERY
  SELECT bd.key, bd.name, bd.description, bd.icon_key
  FROM user_badges ub JOIN badge_definitions bd ON bd.id = ub.badge_id
  WHERE ub.user_id = p_user_id AND ub.notified = false;

  UPDATE user_badges SET notified = true WHERE user_id = p_user_id AND notified = false;
END;
$function$;

-- 10. unsuspend_card (plpgsql, write — the L5-missed card-scheduling IDOR)
CREATE OR REPLACE FUNCTION public.unsuspend_card(p_user_id uuid, p_flashcard_id uuid)
 RETURNS void
 LANGUAGE plpgsql SECURITY DEFINER SET search_path TO public, extensions
AS $function$
DECLARE
  v_user_tz TEXT; v_today DATE;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Access denied: cannot modify another user''s review state';
  END IF;
  SELECT COALESCE(timezone, 'Asia/Kolkata') INTO v_user_tz FROM profiles WHERE id = p_user_id;
  v_today := (NOW() AT TIME ZONE v_user_tz)::DATE;
  UPDATE reviews SET status = 'active', next_review_date = v_today
  WHERE user_id = p_user_id AND flashcard_id = p_flashcard_id AND status = 'suspended';
END;
$function$;
