-- Name: [FUNCTIONS] update_deck_card_count — set target_course on auto-created deck rows
--
-- Description: 06_DIAGNOSTIC confirmed the bug: the trigger's auto-create-deck branch (fires when
-- a flashcard's INSERT finds no matching existing flashcard_decks row) never set target_course.
-- Live impact confirmed, not hypothetical: 2 decks (both belonging to the same professor, both
-- 'public', 34 cards total, created 07/04/2026 — five months before this diagnostic, unrelated to
-- Sprint 7.5's testing) have target_course = NULL. Because get_browsable_decks' course gate is
-- `v_user_role IN ('professor','admin','super_admin') OR fd.user_id = v_user_id OR
-- fd.target_course = v_user_course`, professors/admins bypass it entirely (which is why nobody
-- noticed) — but every STUDENT other than the owner has been unable to discover these 34 public
-- cards for 5+ months, since `NULL = v_user_course` is never true. get_recent_activity_feed has
-- the identical `fd.target_course = p_course_level` filter, so it's excluded from that too.
--
-- Fix: add target_course to the auto-create branch's INSERT column list, copied from the
-- triggering flashcard row (NEW.target_course), exactly the same way visibility already is.
-- Everything else reproduced verbatim from the live body (06_DIAGNOSTIC query 5), including the
-- visibility-widen fix already deployed in 04_FUNCTIONS.

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
        target_course, visibility, card_count
      ) VALUES (
        NEW.user_id, NEW.subject_id, NEW.topic_id,
        NEW.custom_subject, NEW.custom_topic,
        NEW.target_course, NEW.visibility, 1
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
