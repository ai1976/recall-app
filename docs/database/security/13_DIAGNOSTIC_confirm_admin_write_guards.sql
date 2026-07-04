-- Name: [DIAGNOSTIC] Confirm admin-write guards + log_review_activity status
-- Description: 12's residual sweep flagged 3 writers taking p_user_id without a literal auth.uid().
-- enroll_user_in_batch_group + notify_access_granted are admin actions (AdminDashboard passes the
-- TARGET user's id) — they must be guarded by is_admin()/role (which internally uses auth.uid(), so
-- they wouldn't contain the literal). Dump their bodies to confirm the guard exists. log_review_activity
-- has no frontend caller (internal helper) — dump it too to confirm and to lock it to internal-only.
-- Read-only.
SELECT proname, pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname IN ('enroll_user_in_batch_group', 'notify_access_granted', 'log_review_activity')
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;
