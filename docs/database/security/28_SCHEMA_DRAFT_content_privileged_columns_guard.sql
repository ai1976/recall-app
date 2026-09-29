-- Name: [SCHEMA] DRAFT - privileged-column guards on notes, flashcard_decks, flashcards, user_badges   *** DO NOT DEPLOY YET ***
-- Status: DRAFT. Deploy only after 29_TEST (proof) shows the writes really succeed today.
-- Description: 22 block G + block A show that the OWNER of a note/deck/card may write columns that carry
--   platform meaning, because the own-row UPDATE policies have no WITH CHECK (or, for flashcard_decks, only
--   `user_id = auth.uid()`):
--     notes / flashcard_decks : is_featured_on_landing, featured_nominated_by/at, featured_approved_by/at
--                               (the landing-page curation gate, D-featured, phase5/09-12), upvote_count,
--                               view_count (notes only)
--     flashcards              : is_verified ("Professor-verified content badge")
--     user_badges             : badge_id / earned_at / user_id (only is_public is meant to be client-edited -
--                               MyAchievements.jsx:49; there is no client INSERT policy, so badges are granted by
--                               award_badge() only)
--   Every LEGITIMATE writer is server-side and SECURITY DEFINER: the six featured RPCs
--   (nominate/approve/reject/unfeature_featured_*, phase5/11), update_upvote_counts /
--   fn_update_upvotes_counter (22 E-extra: SECURITY DEFINER, owner postgres), award_badge. A grep of src/ found
--   NO client UPDATE of any of these columns. So each guard constrains DIRECT client writes only
--   (current_user IN ('authenticated','anon'); SECURITY INVOKER, same mechanism as 19 and 24).
--
--   Rules for direct client writes (an admin - is_admin() - is left unconstrained, matching the existing
--   "Admins can update any ..." policies):
--     notes / flashcard_decks: featured columns may only move TOWARD "not featured" (true->false, value->NULL).
--        This is exactly what trg_autoclear_featured_* does when visibility leaves 'public', and it fires
--        BEFORE this guard (alphabetical trigger order: trg_autoclear_* < trg_guard_*), so an owner changing a
--        featured note's visibility still works. Setting/changing any of them is refused.
--        upvote_count / view_count: any change is refused; on INSERT they must be 0/NULL.
--     flashcards: is_verified may become TRUE only when is_professor_or_admin().
--     user_badges: user_id, badge_id, earned_at are immutable from a client (is_public and notified stay editable).
--   DELIBERATELY NOT GUARDED: flashcard_decks.card_count - its maintainer update_deck_card_count()'s security
--   mode is not confirmed, and a guard that blocked its write would break card creation. Low value (display only).
--   Run on its own. Verify with 30_TEST (to be written after 29). Revert with 31_ROLLBACK_DRAFT.

CREATE OR REPLACE FUNCTION public.fn_guard_notes_decks_privileged_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO public, extensions
AS $function$
DECLARE
  v_new jsonb := to_jsonb(NEW);
  v_old jsonb := CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE '{}'::jsonb END;
  k text;
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- Featured flag: may only be cleared, never set.
  IF (v_new->>'is_featured_on_landing') = 'true' AND (v_old->>'is_featured_on_landing') IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'Not permitted: featuring is decided by curation, not by the content owner' USING ERRCODE = '42501';
  END IF;

  -- Nomination / approval stamps: may only be cleared, never set or changed.
  FOREACH k IN ARRAY ARRAY['featured_nominated_by', 'featured_nominated_at', 'featured_approved_by', 'featured_approved_at'] LOOP
    IF (v_new->>k) IS NOT NULL AND (v_new->>k) IS DISTINCT FROM (v_old->>k) THEN
      RAISE EXCEPTION 'Not permitted: % is set by the curation workflow only', k USING ERRCODE = '42501';
    END IF;
  END LOOP;

  -- Server-maintained counters.
  FOREACH k IN ARRAY ARRAY['upvote_count', 'view_count'] LOOP
    IF v_new ? k THEN
      IF TG_OP = 'INSERT' AND COALESCE((v_new->>k)::int, 0) <> 0 THEN
        RAISE EXCEPTION 'Not permitted: % starts at 0', k USING ERRCODE = '42501';
      END IF;
      IF TG_OP = 'UPDATE' AND (v_new->>k) IS DISTINCT FROM (v_old->>k) THEN
        RAISE EXCEPTION 'Not permitted: % is maintained by the platform', k USING ERRCODE = '42501';
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_notes_privileged_columns ON public.notes;
CREATE TRIGGER trg_guard_notes_privileged_columns
  BEFORE INSERT OR UPDATE ON public.notes
  FOR EACH ROW EXECUTE FUNCTION public.fn_guard_notes_decks_privileged_columns();

DROP TRIGGER IF EXISTS trg_guard_decks_privileged_columns ON public.flashcard_decks;
CREATE TRIGGER trg_guard_decks_privileged_columns
  BEFORE INSERT OR UPDATE ON public.flashcard_decks
  FOR EACH ROW EXECUTE FUNCTION public.fn_guard_notes_decks_privileged_columns();

-- flashcards.is_verified -------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_guard_flashcards_is_verified()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.is_verified IS TRUE
     AND (TG_OP = 'INSERT' OR OLD.is_verified IS DISTINCT FROM TRUE)
     AND NOT public.is_professor_or_admin() THEN
    RAISE EXCEPTION 'Not permitted: only an educator or admin can mark content verified' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_flashcards_is_verified ON public.flashcards;
CREATE TRIGGER trg_guard_flashcards_is_verified
  BEFORE INSERT OR UPDATE ON public.flashcards
  FOR EACH ROW EXECUTE FUNCTION public.fn_guard_flashcards_is_verified();

-- user_badges -------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_guard_user_badges_client_writes()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO public, extensions
AS $function$
BEGIN
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;
  IF NEW.user_id IS DISTINCT FROM OLD.user_id
     OR NEW.badge_id IS DISTINCT FROM OLD.badge_id
     OR NEW.earned_at IS DISTINCT FROM OLD.earned_at THEN
    RAISE EXCEPTION 'Not permitted: a badge cannot be changed or re-assigned; only its visibility can' USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_guard_user_badges_client_writes ON public.user_badges;
CREATE TRIGGER trg_guard_user_badges_client_writes
  BEFORE UPDATE ON public.user_badges
  FOR EACH ROW EXECUTE FUNCTION public.fn_guard_user_badges_client_writes();
