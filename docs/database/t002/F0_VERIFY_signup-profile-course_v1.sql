-- Name: [DIAGNOSTIC] T-002 F0 VERIFY (v1) - what Signup stored as the profile course for the F0 test account
--
-- Description: TIER 0, read-only (one SELECT; it writes nothing). Run once after the Founder signed up the test account anandmore+t002b@outlook.com with the custom course typed as '  CFA Level 1  '
-- (spaces around). Expected: course_level is exactly CFA Level 1 (bracketed shows [CFA Level 1], len 11, trimmed true). Save the grid unchanged as
-- docs/discussions/evidence/T-002_F0-signup-profile-raw_09-10-2026.raw.txt. Note: until B-03 is live nothing in the database enforces the rule, so this proves the F0 frontend only.

SELECT p.id, p.full_name, p.role,
       p.course_level,
       '[' || coalesce(p.course_level, '(null)') || ']' AS bracketed,
       length(p.course_level) AS len,
       (p.course_level = btrim(p.course_level)) AS trimmed
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.id
 WHERE u.email = 'anandmore+t002b@outlook.com';
