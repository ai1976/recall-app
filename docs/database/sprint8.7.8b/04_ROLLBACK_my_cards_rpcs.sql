-- Name: [ROLLBACK] Sprint 8.7.8b — My Cards enrollment + Practice attempts
--
-- Description: Cleanly removes everything this sprint introduced: the four RPCs, the two tables
-- (and their indexes/constraints/grants, dropped automatically with the tables), and nothing else.
-- Does not touch apply_review, submit_review, srs_ladder_curves, srs_ladder_rules, get_study_queue,
-- suspend_card, unsuspend_card, reset_card, or any pre-existing table/data — those are frozen and
-- were never modified by this sprint's deploy files.
--
-- Review before running. Safe to run even if only part of the sprint was deployed (every
-- statement is IF EXISTS / IF EXISTS-safe).

DROP FUNCTION IF EXISTS public.add_to_my_cards(uuid, uuid);
DROP FUNCTION IF EXISTS public.remove_from_my_cards(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_my_cards(uuid);
DROP FUNCTION IF EXISTS public.log_practice_attempt(uuid, uuid, boolean);

DROP TABLE IF EXISTS public.practice_attempts;
DROP TABLE IF EXISTS public.my_cards_enrollment;

NOTIFY pgrst, 'reload schema';
