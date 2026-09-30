-- [DIAGNOSTIC] After a REAL Grant Access by Shailaja: was it applied, logged once, and notified exactly once?
-- Description: READ-ONLY. Run after Shailaja has granted access to a real student on the live site (30/09/2026 live check).
--   For every grant in the last 24 hours it shows who granted, whether the student is now enrolled, and how many
--   'access_granted' notifications that student received in the same window (expected: exactly 1 each).
-- Run as one block.

SELECT l.created_at,
       pr.full_name  AS granted_by,
       pr.role       AS granter_role,
       t.full_name   AS student,
       t.account_type AS student_account_type_now,
       l.details->>'via' AS via,
       (SELECT count(*) FROM public.notifications n
         WHERE n.user_id = l.target_user_id AND n.type = 'access_granted'
           AND n.created_at >= l.created_at - interval '1 minute') AS access_granted_notifications
FROM public.admin_audit_log l
LEFT JOIN public.profiles pr ON pr.id = l.admin_id
LEFT JOIN public.profiles t  ON t.id = l.target_user_id
WHERE l.action = 'grant_access' AND l.created_at >= now() - interval '24 hours'
ORDER BY l.created_at DESC;
