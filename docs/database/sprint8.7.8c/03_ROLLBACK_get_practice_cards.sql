-- Name: [ROLLBACK] get_practice_cards
-- Description: Drops the Sprint 8.7.8c get_practice_cards RPC. Only run this if the function must
-- be fully removed (e.g. superseded by a later revision under a new file). Frontend code that calls
-- get_practice_cards must be rolled back FIRST if this is deployed, per project convention.

DROP FUNCTION IF EXISTS public.get_practice_cards(uuid, uuid, text);

NOTIFY pgrst, 'reload schema';
