-- [FUNCTIONS] ROLLBACK for 02 (Sprint 8.8.5e). Run only if the Rename button is reverted. Audit rows already written stay (append-only).
DROP FUNCTION IF EXISTS public.rename_batch_group(uuid, text);
