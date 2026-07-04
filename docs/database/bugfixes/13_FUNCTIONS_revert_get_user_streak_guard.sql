-- Name: [FUNCTIONS] Revert get_user_streak self-only guard (it's social/cross-user data)
-- Description: 08_FUNCTIONS (read-IDOR pass) wrongly guarded get_user_streak to self-only. But a
-- streak is SOCIAL data, shown to friends/following/group members: get_following_with_stats,
-- get_my_friends_with_stats, and get_batch_group_member_stats all call get_user_streak(OTHER_user)
-- to display it — the guard made those RAISE 'Access denied', breaking those pages for non-admins.
-- This restores the original unguarded body (a streak integer is low-sensitivity and already shown
-- socially). Body verbatim from 07 Block 2; search_path kept pinned (unquoted). MISCLASSIFICATION
-- fix — the other group-A guards stand (no cross-user internal callers per the caller sweep).

CREATE OR REPLACE FUNCTION public.get_user_streak(p_user_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO public, extensions
AS $function$
DECLARE
    v_user_tz TEXT;
    v_today DATE;
    v_yesterday DATE;
    v_streak INTEGER := 0;
    v_check_date DATE;
    v_study_dates DATE[];
    v_most_recent_date DATE;
BEGIN
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
