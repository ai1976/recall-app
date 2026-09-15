-- Name: [SCHEMA] Sprint 8.0 follow-up — retire fn_auto_enroll_batch_group entirely
-- Description: Quality Auditor review of the Sprint 8.0 report caught a gap: the
-- trigger's course-change cleanup branch (removing a student from their OLD
-- matched batch group) still resolved that group by the same course+institution
-- LIMIT 1 lookup as the removed "add" branch. That's the same guessing problem
-- on the removal side — a course change could silently drop a student from the
-- wrong batch (one they never meant to leave), contradicting the agreed rule
-- that batch membership only ever changes through an explicit action, never a
-- course-level match.
--
-- Since the "add" branch was already removed in 02_FUNCTIONS, removing this
-- last "remove" branch leaves the function doing nothing at all. Rather than
-- leave a dead trigger installed, this drops both the trigger and the function
-- outright — batch membership changes now come ONLY from join_group_by_token,
-- enroll_user_in_batch_group, approve_batch_join_request, and
-- reject_batch_join_request (plus the pre-existing, explicitly admin-invoked
-- remove_group_member/leave_group for the ordinary group flow).
--
-- Run AFTER 01/02/03. Safe to run standalone — DROP ... IF EXISTS.

DROP TRIGGER IF EXISTS trg_auto_enroll_batch_group ON profiles;
DROP FUNCTION IF EXISTS public.fn_auto_enroll_batch_group();
