-- Name: [FUNCTIONS] Fix get_public_deck_preview to only expose public cards
-- Description: Closes the visibility leak confirmed by 01_DIAGNOSTIC. This SECURITY DEFINER RPC
-- powers the PUBLIC /deck/:id teaser page (src/pages/public/DeckPreview.jsx) and bypasses RLS.
-- It already gates the DECK on visibility='public'; this replace adds the missing per-card gate so
-- the preview shows ONLY cards whose own visibility='public'. Because this is an anonymous public
-- teaser, `public` is the correct and only filter here — there is no reliable authenticated viewer
-- to be owner/friend/admin (unlike the in-app StudyMode query, which is RLS-protected and already
-- correct). is_public was dropped in Landmine L2 (03/07/2026); visibility is the sole gate.
--
-- Two changes vs the live body (everything else reproduced verbatim from
-- docs/database/phase5/07_FUNCTIONS_cap_public_deck_preview_at_5.sql, confirmed by 01_DIAGNOSTIC q1):
--   1. preview_items inner subquery: + `AND fc.visibility = 'public'` (the leak fix).
--   2. deck metadata card_count: was `fd.card_count` (trigger-maintained TOTAL, includes private
--      cards -> a public page revealing how many hidden cards exist). Now a correlated count of
--      PUBLIC grouped cards only, so the "X of N items" header is honest on the public page.
--      (The shared denormalized fd.card_count column is untouched; owner-facing deck tiles that
--      read it directly still show the full count, which is correct for the owner.)
--   3. preview_items inner subquery: + `ORDER BY fc.created_at` before LIMIT 5, so the teaser is
--      the deterministic FIRST 5 public cards (the live body's LIMIT 5 had no inner ORDER BY, so
--      it took an arbitrary 5 that jsonb_agg then re-sorted). Cosmetic determinism only.
--
-- Signature unchanged (p_deck_id uuid -> jsonb) -> safe in-place CREATE OR REPLACE, no caller change.
--
-- ROLLBACK: re-run docs/database/phase5/07_FUNCTIONS_cap_public_deck_preview_at_5.sql (the prior body).

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
  -- Deck metadata. card_count now counts ONLY public cards in the deck (grouping-column join,
  -- same logic as the trigger) so the public page never reveals hidden-card totals.
  SELECT jsonb_build_object(
    'id',            fd.id,
    'name',          fd.name,
    'subject',       COALESCE(s.name, fd.custom_subject),
    'topic',         COALESCE(t.name, fd.custom_topic),
    'card_count',    (
      SELECT count(*)
      FROM flashcards fcc
      WHERE fcc.user_id = fd.user_id
        AND (fcc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
        AND (fcc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
        AND (fcc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
        AND (fcc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
        AND fcc.visibility = 'public'
    ),
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

  -- First 5 PUBLIC flashcards — matched by grouping columns, same logic as the trigger.
  -- The `fc.visibility = 'public'` predicate is the leak fix.
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
      AND fc.visibility = 'public'
    ORDER BY fc.created_at
    LIMIT 5
  ) fc;

  RETURN jsonb_build_object(
    'deck',          v_deck,
    'preview_items', COALESCE(v_items, '[]'::jsonb)
  );
END;
$function$;

NOTIFY pgrst, 'reload schema';
