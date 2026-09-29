-- Name: [SCHEMA] ROLLBACK - remove the content / badge privileged-column guards (28)
-- Status: DRAFT (pairs with 28). Only needed if a real flow breaks that 30_TEST did not cover
--   (client INSERT of notes/decks is the one path 30 does not exercise). Removing these re-opens
--   self-featuring, fake upvotes/verified badges and badge re-labelling - treat as temporary.

DROP TRIGGER IF EXISTS trg_guard_notes_privileged_columns   ON public.notes;
DROP TRIGGER IF EXISTS trg_guard_decks_privileged_columns   ON public.flashcard_decks;
DROP TRIGGER IF EXISTS trg_guard_flashcards_is_verified     ON public.flashcards;
DROP TRIGGER IF EXISTS trg_guard_user_badges_client_writes  ON public.user_badges;

DROP FUNCTION IF EXISTS public.fn_guard_notes_decks_privileged_columns();
DROP FUNCTION IF EXISTS public.fn_guard_flashcards_is_verified();
DROP FUNCTION IF EXISTS public.fn_guard_user_badges_client_writes();
