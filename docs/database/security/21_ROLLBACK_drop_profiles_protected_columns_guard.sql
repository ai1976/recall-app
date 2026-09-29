-- Name: [SCHEMA] ROLLBACK - remove the profiles protected-columns guard (19)
-- Description: Emergency revert. Only needed if the guard blocks a legitimate flow that 20_TEST did not
--   cover. Removing it re-opens the self-escalation path, so treat as temporary and report which flow broke.

DROP TRIGGER IF EXISTS trg_guard_profiles_protected_columns ON public.profiles;
DROP FUNCTION IF EXISTS public.fn_guard_profiles_protected_columns();
