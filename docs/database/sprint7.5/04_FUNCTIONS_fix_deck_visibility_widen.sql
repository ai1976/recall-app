-- Name: [FUNCTIONS] update_deck_card_count — widen deck visibility to match its most-permissive card
--
-- Description: Bug found during Sprint 7.5 live testing (pre-existing, platform-wide, unrelated to
-- MCQ): flashcard_decks.visibility is set once — either by FlashcardCreate.jsx's explicit deck
-- INSERT, or by this trigger's own auto-create-on-first-card branch — and NEVER re-widened when a
-- later card with a more permissive visibility is added to the same (user, subject, topic) group.
-- A deck created 'private' that later gains 'public' cards stays invisible in
-- get_recent_activity_feed and get_browsable_decks (both gate on the DECK's visibility column),
-- even though the individual flashcards.visibility is correct. 00_DIAGNOSTIC query 3/4 confirmed
-- 4 live decks already desynced this way (3 belonging to other users, not from this session's
-- testing) — see 05_FIX for the one-time backfill of those.
--
-- Fix: when the UPDATE branch finds an existing deck row (the common case — most inserts land in
-- an already-existing deck), widen its visibility in the SAME statement if the new flashcard's
-- visibility is more permissive (private < friends < public). Never narrows — a deck's visibility
-- only ever gets wider over time, which is the safe direction (matches the "asymmetrically safer
-- default" reasoning already used elsewhere in this project, e.g. D-10). The auto-create branch
-- (NOT FOUND) is untouched — it already sets visibility = NEW.visibility correctly for a deck's
-- very first card. DELETE branch, auto-delete-when-empty, and the "UPDATE OF deck_id" trigger
-- condition are all untouched. Live body reproduced verbatim from 00_DIAGNOSTIC query 1 except for
-- the one UPDATE statement below.
--
-- Note (out of scope, flagged not fixed here): the auto-create (NOT FOUND) branch also does not
-- set target_course on the new flashcard_decks row, which the live trigger body confirms was never
-- actually added despite bugs.md's "[Mar 2, 2026]" entry describing it as part of that fix. Every
-- deck created via FlashcardCreate.jsx's own explicit path already gets target_course set by that
-- app code, so this has only been dormant for decks whose first-ever card went straight through
-- this trigger's auto-create branch (i.e. bulk upload into a brand-new subject/topic with no prior
-- deck). Worth a separate diagnostic to size the blast radius before touching it — not done here to
-- keep this patch scoped to the visibility bug the operator asked for.

CREATE OR REPLACE FUNCTION public.update_deck_card_count()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'extensions'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE flashcard_decks
    SET card_count = card_count + 1,
        visibility = CASE
          WHEN (CASE visibility     WHEN 'public' THEN 2 WHEN 'friends' THEN 1 ELSE 0 END)
             < (CASE NEW.visibility WHEN 'public' THEN 2 WHEN 'friends' THEN 1 ELSE 0 END)
          THEN NEW.visibility
          ELSE visibility
        END
    WHERE user_id = NEW.user_id
      AND (subject_id     IS NOT DISTINCT FROM NEW.subject_id)
      AND (topic_id       IS NOT DISTINCT FROM NEW.topic_id)
      AND (custom_subject IS NOT DISTINCT FROM NEW.custom_subject)
      AND (custom_topic   IS NOT DISTINCT FROM NEW.custom_topic);

    IF NOT FOUND THEN
      INSERT INTO flashcard_decks (
        user_id, subject_id, topic_id,
        custom_subject, custom_topic,
        visibility, card_count
      ) VALUES (
        NEW.user_id, NEW.subject_id, NEW.topic_id,
        NEW.custom_subject, NEW.custom_topic,
        NEW.visibility, 1
      );
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    UPDATE flashcard_decks
    SET card_count = GREATEST(card_count - 1, 0)
    WHERE user_id = OLD.user_id
      AND (subject_id     IS NOT DISTINCT FROM OLD.subject_id)
      AND (topic_id       IS NOT DISTINCT FROM OLD.topic_id)
      AND (custom_subject IS NOT DISTINCT FROM OLD.custom_subject)
      AND (custom_topic   IS NOT DISTINCT FROM OLD.custom_topic);

    -- Auto-delete deck when it becomes empty
    DELETE FROM flashcard_decks
    WHERE user_id = OLD.user_id
      AND (subject_id     IS NOT DISTINCT FROM OLD.subject_id)
      AND (topic_id       IS NOT DISTINCT FROM OLD.topic_id)
      AND (custom_subject IS NOT DISTINCT FROM OLD.custom_subject)
      AND (custom_topic   IS NOT DISTINCT FROM OLD.custom_topic)
      AND card_count = 0;

  END IF;

  RETURN NULL;
END;
$function$;
