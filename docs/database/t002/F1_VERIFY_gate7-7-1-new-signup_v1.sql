-- Name: [DIAGNOSTIC] T-002 F1 Gate 7 test 7.1 - the new sign-up stored the chosen course
-- Description: READ-ONLY (Tier 0). Shows the profile created by the real sign-up of 7.1 (anandmore+t002c@outlook.com):
--   course_level must be 'CA Intermediate', role 'student'. Nothing is written.
-- Version: v1 (10/10/2026)

SELECT 'F1_VERIFY_7-1_v1' AS tool_version,
       p.id, p.email, p.full_name, p.role, p.account_type, p.status, p.course_level, p.created_at
FROM public.profiles p
WHERE lower(p.email) = lower('anandmore+t002c@outlook.com');
