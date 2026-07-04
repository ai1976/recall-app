-- Name: [DIAGNOSTIC] Full internal-caller sweep for all guarded functions
-- Description: get_user_streak's guard broke 3 social functions (following/friends/batch stats) that
-- call it cross-user. Confirm whether any OTHER guarded function (get_user_badges — returns PRIVATE
-- badges, can't just be unguarded; the 5 professor fns; unsuspend_card; the rest of group A) is also
-- called cross-user internally. Any caller here that passes a NON-self id is currently broken by the
-- guard. Read-only.

-- 1. Every function that internally references any guarded function.
SELECT p.proname AS caller, m.target
FROM pg_proc p,
LATERAL (VALUES
  ('get_due_forecast'),('get_question_type_performance'),('get_recent_notifications'),
  ('get_study_heatmap'),('get_study_time_stats'),('get_subject_mastery_v1'),
  ('get_suspended_cards'),('get_unnotified_badges'),('unsuspend_card'),('get_user_badges'),
  ('get_professor_overview'),('get_professor_subject_engagement'),('get_professor_top_cards'),
  ('get_professor_weak_cards'),('get_professor_weekly_reach')
) AS m(target)
WHERE p.pronamespace = 'public'::regnamespace
  AND p.proname <> m.target
  AND pg_get_functiondef(p.oid) ILIKE '%' || m.target || '%'
ORDER BY m.target, caller;

-- 2. Bodies of the 3 functions the get_user_streak guard broke — to see EVERY guarded fn they call
--    (e.g. do they also call get_user_badges cross-user?), so the fix is complete, not whack-a-mole.
SELECT proname, pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname IN ('get_following_with_stats','get_my_friends_with_stats','get_batch_group_member_stats')
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;
