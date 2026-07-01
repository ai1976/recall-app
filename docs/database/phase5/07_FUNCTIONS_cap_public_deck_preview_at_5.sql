-- Name: [FUNCTIONS] Cap Public Deck Preview at 5 Cards
-- Description: get_public_deck_preview currently caps preview_items at LIMIT 10 (confirmed
-- via pg_get_functiondef in 01_DIAGNOSTIC_introspect_preview_rpcs.sql). Sprint 2 locks teaser
-- depth at 5 cards across both the hero demo and DeckPreview, so this CREATE OR REPLACE drops
-- the inner LIMIT from 10 to 5. Signature is unchanged (still p_deck_id uuid -> jsonb), so this
-- is a safe in-place replace — no caller changes needed. Everything else (deck metadata query,
-- the 5-grouping-column flashcard join, front_text-only preview_items — no back_text, DeckPreview
-- shows questions and does not flip) is reproduced verbatim from the live function body.

CREATE OR REPLACE FUNCTION public.get_public_deck_preview(p_deck_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_deck  jsonb;
  v_items jsonb;
BEGIN
  -- Deck metadata (unchanged — this part was already working)
  SELECT jsonb_build_object(
    'id',            fd.id,
    'name',          fd.name,
    'subject',       COALESCE(s.name, fd.custom_subject),
    'topic',         COALESCE(t.name, fd.custom_topic),
    'card_count',    fd.card_count,
    'creator_id',    fd.user_id,
    'creator_name',  p.full_name,
    'target_course', fd.target_course
  )
  INTO v_deck
  FROM flashcard_decks fd
  LEFT JOIN subjects s ON s.id = fd.subject_id
  LEFT JOIN topics   t ON t.id = fd.topic_id
  LEFT JOIN profiles p ON p.id = fd.user_id
  WHERE fd.id = p_deck_id
    AND fd.visibility = 'public';

  IF v_deck IS NULL THEN
    RETURN NULL;
  END IF;

  -- First 5 flashcards — matched by grouping columns, same logic as the trigger
  SELECT jsonb_agg(
    jsonb_build_object('front_text', fc.front_text)
    ORDER BY fc.created_at
  )
  INTO v_items
  FROM (
    SELECT fc.front_text, fc.created_at
    FROM flashcards fc
    JOIN flashcard_decks fd ON
        fc.user_id = fd.user_id
      AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
      AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
      AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
      AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
    WHERE fd.id = p_deck_id
    LIMIT 5
  ) fc;

  RETURN jsonb_build_object(
    'deck',          v_deck,
    'preview_items', COALESCE(v_items, '[]'::jsonb)
  );
END;
$function$;
