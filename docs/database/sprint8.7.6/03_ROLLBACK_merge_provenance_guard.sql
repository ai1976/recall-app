-- Name: [SCHEMA] Rollback Sprint 8.7.6 merge provenance triggers
-- Description: Removes both triggers and both functions. Restores pre-8.7.6 behaviour (unguarded merge).
--   Does not touch any data. Run alone.
DROP TRIGGER IF EXISTS trg_guard_flashcard_batch_move      ON public.flashcards;
DROP TRIGGER IF EXISTS trg_cleanup_orphan_batch_provenance ON public.flashcards;
DROP FUNCTION IF EXISTS public.fn_guard_flashcard_batch_move();
DROP FUNCTION IF EXISTS public.fn_cleanup_orphan_batch_provenance();
