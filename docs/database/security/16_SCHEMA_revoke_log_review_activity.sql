-- Name: [SCHEMA] Lock log_review_activity to internal-only
-- Description: log_review_activity(p_user_id, p_review_timestamp) has no frontend caller (14 Block 1:
-- called only by the trigger function fn_badge_check_reviews, which runs SECURITY DEFINER as owner).
-- It took p_user_id with no guard, so an authenticated user could inject fake activity-log entries for
-- any user. It should never be a REST endpoint — revoke EXECUTE from anon+authenticated (it was
-- missed in L5's internal list). The internal call from fn_badge_check_reviews is unaffected
-- (privilege is checked against the definer, not the session role). Robust REVOKE-from-PUBLIC pattern.

REVOKE EXECUTE ON FUNCTION public.log_review_activity(uuid, timestamptz) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.log_review_activity(uuid, timestamptz) TO service_role;
