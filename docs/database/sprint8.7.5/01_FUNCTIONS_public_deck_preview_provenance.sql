-- Name: [FUNCTIONS] Add provenance to get_public_deck_preview
-- Description: Sprint 8.7.5 — closes the last D-21 display gap. Adds deck-level content
-- provenance (source type + name) to the anonymous public deck teaser RPC that powers
-- src/pages/public/DeckPreview.jsx. This function is SECURITY DEFINER and already sits on
-- the project's anon-allowlist (docs/database/security/04_SCHEMA_revoke_execute_grants.sql),
-- so resolving provenance inside it does NOT broaden anonymous access to
-- flashcard_batch_provenance (that table's RLS policy stays authenticated-only — see
-- docs/database/sprint8.7.4/01_SCHEMA_provenance_select_policy.sql). The RPC bypasses RLS as
-- owner, same pattern get_browsable_decks v7 already uses.
--
-- Mixed-batch handling is NOT new logic in this codebase — it is ported verbatim from
-- get_browsable_decks v7 (docs/database/sprint8.7.4/02_FUNCTIONS_get_browsable_decks_v7_provenance.sql,
-- lines ~124-131,156): a deck only gets a provenance badge when every PUBLIC card in it belongs
-- to the same batch_id. If the public cards span more than one batch_id, or the sole batch has
-- no provenance row (legacy pre-8.7.1 content), sole_batch_id is NULL, the provenance LEFT JOIN
-- resolves to NULL, and ProvenanceBadge (src/components/content/ProvenanceBadge.jsx) renders
-- nothing — no "Mixed source" or "Unknown" placeholder, consistent with every other surface.
--
-- The batch scan here is over ALL public cards matched to the deck (the same grouping-column
-- join card_count already uses), not just the 5 cards returned in preview_items — a deck whose
-- first 5 preview cards happen to share a batch but whose 6th+ public card is a different batch
-- must still suppress the badge, since the badge describes the whole public deck, not the teaser.
--
-- Two changes vs the live body (everything else reproduced verbatim from
-- docs/database/bugfixes/02_FUNCTIONS_fix_public_deck_preview_visibility.sql):
--   1. New CROSS JOIN LATERAL computing sole_batch_id over public cards in the deck (NULL if
--      the public cards span >1 batch_id), then LEFT JOIN flashcard_batch_provenance on it.
--   2. v_deck jsonb gains 'provenance_source_type' and 'provenance_source_name'.
--
-- Signature unchanged (p_deck_id uuid -> jsonb) -> safe in-place CREATE OR REPLACE, no caller change.
--
-- ROLLBACK: re-run docs/database/bugfixes/02_FUNCTIONS_fix_public_deck_preview_visibility.sql
-- (the prior body, without provenance fields).

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
  -- Deck metadata. card_count counts ONLY public cards in the deck (grouping-column join, same
  -- logic as the trigger) so the public page never reveals hidden-card totals. provenance_* is
  -- resolved from the sole batch_id among those same public cards, or NULL if mixed/legacy.
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
    'target_course', fd.target_course,
    'provenance_source_type', bp.content_source_type,
    'provenance_source_name', bp.content_source_name
  )
  INTO v_deck
  FROM flashcard_decks fd
  LEFT JOIN subjects s ON s.id = fd.subject_id
  LEFT JOIN topics   t ON t.id = fd.topic_id
  LEFT JOIN profiles p ON p.id = fd.user_id
  CROSS JOIN LATERAL (
    SELECT CASE WHEN count(DISTINCT fc.batch_id) = 1
                THEN (array_agg(fc.batch_id))[1]
                ELSE NULL
           END AS sole_batch_id
    FROM flashcards fc
    WHERE fc.user_id = fd.user_id
      AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
      AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
      AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
      AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
      AND fc.visibility = 'public'
  ) vc
  LEFT JOIN flashcard_batch_provenance bp ON bp.batch_id = vc.sole_batch_id
  WHERE fd.id = p_deck_id
    AND fd.visibility = 'public';

  IF v_deck IS NULL THEN
    RETURN NULL;
  END IF;

  -- First 5 PUBLIC flashcards — matched by grouping columns, same logic as the trigger.
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
