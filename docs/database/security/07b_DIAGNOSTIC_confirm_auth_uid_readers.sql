-- Name: [DIAGNOSTIC] Confirm auth.uid()-referencing p_user_id functions constrain to it
-- Description: 07's Block 1 flagged get_unread_notification_count + mark_notifications_read as
-- referencing auth.uid() while also taking p_user_id. Dump their bodies to confirm they filter on
-- auth.uid() (safe) rather than trusting p_user_id (IDOR). mark_notifications_read is a WRITER.
-- Read-only.
SELECT proname, pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname IN ('get_unread_notification_count', 'mark_notifications_read')
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;

-- Also dump the 5 professor-analytics functions (keyed by p_professor_id, no auth.uid() check) so we
-- can decide the guard: self-only (auth.uid() = p_professor_id) OR self-or-admin. Confirm from the
-- frontend whether a non-owner (admin) ever views another professor's analytics.
SELECT proname, pg_get_functiondef(oid) AS definition
FROM pg_proc
WHERE proname IN ('get_professor_overview','get_professor_subject_engagement',
                  'get_professor_top_cards','get_professor_weak_cards','get_professor_weekly_reach')
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;
