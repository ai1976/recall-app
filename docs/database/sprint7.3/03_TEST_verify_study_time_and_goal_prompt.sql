-- [TEST] Verify Sprint 7.3-B/7.3-C SQL deployed correctly
-- Description: Run after both migrations above. Confirms the new profiles
-- column exists and defaults to false, and that get_study_time_stats' new
-- split columns sum back to the existing combined totals for the calling
-- user (in_app + offline == combined, for both today and this week).

-- 1. Column exists, defaults false for existing rows
SELECT count(*) FILTER (WHERE has_dismissed_goal_prompt IS NOT false) AS unexpected_non_false
FROM public.profiles;
-- expect: 0

-- 2. Split columns sum back to combined totals for the calling user
SELECT
  today_seconds,
  today_seconds_in_app + today_seconds_offline AS today_split_sum,
  week_seconds,
  week_seconds_in_app + week_seconds_offline AS week_split_sum
FROM get_study_time_stats(auth.uid(), CURRENT_DATE);
-- expect: today_seconds = today_split_sum, week_seconds = week_split_sum
