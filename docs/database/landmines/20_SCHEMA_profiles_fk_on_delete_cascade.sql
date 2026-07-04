-- Name: [SCHEMA] profiles FK -> auth.users ON DELETE CASCADE (+ attribution FKs -> SET NULL)
-- Description: L4 — fix the last catalogued landmine (§1.11 "Newly found Jun 30"). Deleting a user
-- from the Supabase Auth dashboard fails ("Database error deleting user") because
-- profiles.id -> auth.users.id is ON DELETE NO ACTION. This makes it CASCADE. But cascading through
-- profiles would hit 8 downstream FKs that are themselves NO ACTION (per 19_DIAGNOSTIC Block 2) —
-- all ATTRIBUTION columns on OTHER users' content (contributed_by / creator_id / featured_*_by /
-- resolved_by), never the owner (owner = user_id, already CASCADE). Those 8 become SET NULL so a
-- deleted approver/contributor nulls the attribution instead of deleting someone else's content.
-- All 8 columns confirmed nullable (19 follow-up + DATABASE_SCHEMA). One transaction.
--
-- HARD PREREQUISITE: 19_DIAGNOSTIC run and Block 2 matches the 8 NO ACTION FKs handled below.
--
-- ROLLBACK (restores exact prior state):
--   -- attribution FKs back to NO ACTION:
--   ALTER TABLE public.notes           DROP CONSTRAINT notes_contributed_by_fkey,           ADD CONSTRAINT notes_contributed_by_fkey           FOREIGN KEY (contributed_by)        REFERENCES public.profiles(id);
--   ALTER TABLE public.notes           DROP CONSTRAINT notes_featured_approved_by_fkey,     ADD CONSTRAINT notes_featured_approved_by_fkey     FOREIGN KEY (featured_approved_by)  REFERENCES public.profiles(id);
--   ALTER TABLE public.notes           DROP CONSTRAINT notes_featured_nominated_by_fkey,    ADD CONSTRAINT notes_featured_nominated_by_fkey    FOREIGN KEY (featured_nominated_by) REFERENCES public.profiles(id);
--   ALTER TABLE public.flashcards      DROP CONSTRAINT flashcards_contributed_by_fkey,      ADD CONSTRAINT flashcards_contributed_by_fkey      FOREIGN KEY (contributed_by)        REFERENCES public.profiles(id);
--   ALTER TABLE public.flashcards      DROP CONSTRAINT flashcards_creator_id_fkey,          ADD CONSTRAINT flashcards_creator_id_fkey          FOREIGN KEY (creator_id)            REFERENCES public.profiles(id);
--   ALTER TABLE public.flashcard_decks DROP CONSTRAINT flashcard_decks_featured_approved_by_fkey,  ADD CONSTRAINT flashcard_decks_featured_approved_by_fkey  FOREIGN KEY (featured_approved_by)  REFERENCES public.profiles(id);
--   ALTER TABLE public.flashcard_decks DROP CONSTRAINT flashcard_decks_featured_nominated_by_fkey, ADD CONSTRAINT flashcard_decks_featured_nominated_by_fkey FOREIGN KEY (featured_nominated_by) REFERENCES public.profiles(id);
--   ALTER TABLE public.content_flags   DROP CONSTRAINT content_flags_resolved_by_fkey,       ADD CONSTRAINT content_flags_resolved_by_fkey       FOREIGN KEY (resolved_by)           REFERENCES public.profiles(id);
--   -- profiles back to NO ACTION:
--   ALTER TABLE public.profiles DROP CONSTRAINT profiles_id_fkey, ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id);

BEGIN;

-- Safety: abort if any target column is unexpectedly NOT NULL (SET NULL would be invalid).
DO $$
DECLARE v_bad text;
BEGIN
  SELECT string_agg(format('%s.%s', table_name, column_name), ', ')
    INTO v_bad
  FROM information_schema.columns
  WHERE table_schema = 'public' AND is_nullable = 'NO'
    AND (
      (table_name = 'notes'           AND column_name IN ('contributed_by','featured_approved_by','featured_nominated_by')) OR
      (table_name = 'flashcards'      AND column_name IN ('contributed_by','creator_id')) OR
      (table_name = 'flashcard_decks' AND column_name IN ('featured_approved_by','featured_nominated_by')) OR
      (table_name = 'content_flags'   AND column_name IN ('resolved_by'))
    );
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'Abort: these attribution columns are NOT NULL, cannot SET NULL: %', v_bad;
  END IF;
END $$;

-- 1. Attribution FKs (NO ACTION -> SET NULL). Deleting an approver/contributor/creator nulls the
--    attribution on content owned by someone else; it does NOT delete that content.
ALTER TABLE public.notes
  DROP CONSTRAINT notes_contributed_by_fkey,
  ADD  CONSTRAINT notes_contributed_by_fkey FOREIGN KEY (contributed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.notes
  DROP CONSTRAINT notes_featured_approved_by_fkey,
  ADD  CONSTRAINT notes_featured_approved_by_fkey FOREIGN KEY (featured_approved_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.notes
  DROP CONSTRAINT notes_featured_nominated_by_fkey,
  ADD  CONSTRAINT notes_featured_nominated_by_fkey FOREIGN KEY (featured_nominated_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.flashcards
  DROP CONSTRAINT flashcards_contributed_by_fkey,
  ADD  CONSTRAINT flashcards_contributed_by_fkey FOREIGN KEY (contributed_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.flashcards
  DROP CONSTRAINT flashcards_creator_id_fkey,
  ADD  CONSTRAINT flashcards_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.flashcard_decks
  DROP CONSTRAINT flashcard_decks_featured_approved_by_fkey,
  ADD  CONSTRAINT flashcard_decks_featured_approved_by_fkey FOREIGN KEY (featured_approved_by) REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.flashcard_decks
  DROP CONSTRAINT flashcard_decks_featured_nominated_by_fkey,
  ADD  CONSTRAINT flashcard_decks_featured_nominated_by_fkey FOREIGN KEY (featured_nominated_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.content_flags
  DROP CONSTRAINT content_flags_resolved_by_fkey,
  ADD  CONSTRAINT content_flags_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- 2. The headline fix: profiles.id -> auth.users.id NO ACTION -> CASCADE. Deleting an auth.users
--    row now deletes its profiles row (which then cascades / set-nulls per the child FKs above).
ALTER TABLE public.profiles
  DROP CONSTRAINT profiles_id_fkey,
  ADD  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

COMMIT;

-- Post-deploy: run 21_TEST_verify_profiles_cascade.sql.
