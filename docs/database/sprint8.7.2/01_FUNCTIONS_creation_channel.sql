-- Name: [FUNCTIONS] Sprint 8.7.2 — create_flashcard_batches gains p_creation_channel + scenario fix
--
-- Description: Restores flashcard creation service (broken since 8.7.1 deployed the
-- provenance gate without a migrated frontend) and closes the flashcards.source bug
-- in the same migration. Two changes to the RPC deployed in
-- docs/database/sprint8.7/02_FUNCTIONS_create_flashcard_batches.sql:
--
--   1. New p_creation_channel parameter ('manual' | 'bulk_upload' | 'gemini_import',
--      validated server-side — Postgres does not support column-style CHECK on a
--      function parameter). Every row this RPC inserts now gets
--      flashcards.source = p_creation_channel explicitly, never the column default.
--      Confirmed live (00_DIAGNOSTIC_pre_restore.sql, section 5b) that 100% of
--      production flashcards.source values are 'manual' today, including rows that
--      must have come from bulk upload — the pre-migration BulkUploadFlashcards.jsx
--      insert never set `source` at all, silently taking the column default. This is
--      the bug being closed.
--
--   2. scenario column added to the INSERT list. The 8.7.1 RPC's column list omitted
--      it entirely even though it's a real, actively-used column (Sprint 7.10,
--      case_study_mcq — see docs/reference/DATABASE_SCHEMA.md line ~243). Migrating
--      either frontend path to the 8.7.1 RPC as deployed would have silently dropped
--      scenario text for every case_study_mcq card. Found during 8.7.2 Step 0 live
--      diagnostic, not in the original spec — fixed here because it's required for
--      case_study_mcq to keep working through the migrated frontend paths (in scope
--      per the sprint's own §4.4 verification requirement), not scope creep.
--
-- *** SECURITY-CRITICAL — READ BEFORE MODIFYING ***
-- Same caveat as 8.7.1: FORCE ROW LEVEL SECURITY is not set on flashcards or
-- flashcard_batch_provenance, so this SECURITY DEFINER function running as table
-- owner is completely invisible to RLS. Every authorization guarantee (auth.uid()-
-- derived ownership, the D-10 verdict-type gate) is reproduced explicitly in the
-- function body, not delegated to RLS.
--
-- MIGRATION SAFETY: adding a parameter changes the function's identity arguments
-- (Postgres overload identity is by parameter TYPES, not names/defaults) —
-- CREATE OR REPLACE with a 4-arg signature would NOT replace the existing 3-arg
-- function, it would create a second overload alongside it. Confirmed live
-- (00_DIAGNOSTIC section 1-2) that only the 3-arg overload currently exists, and
-- that nothing in production successfully calls it today (the frontend's direct
-- flashcards insert is what's broken — this RPC has zero live callers to protect).
-- Safe to DROP the 3-arg overload outright rather than carry it forward as dead
-- surface area.

BEGIN;

DROP FUNCTION IF EXISTS public.create_flashcard_batches(text, text, jsonb);

CREATE FUNCTION public.create_flashcard_batches(
  p_source_type text,
  p_source_name text,
  p_batches jsonb,
  p_creation_channel text
)
RETURNS TABLE(batch_id uuid, card_count integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_uid             uuid;
  v_is_prof_admin   boolean;
  v_verdict_types   text[] := ARRAY['mcq','mcq_multi','match_the_following','case_study_mcq','correct_incorrect','fitb'];
  v_batch           jsonb;
  v_card            jsonb;
  v_batch_id        uuid;
  v_seen_batch_ids  uuid[] := '{}';
  v_qtype           text;
  v_row_count       integer;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Access denied: authentication required';
  END IF;

  -- ── input validation ──────────────────────────────────────────────
  IF p_source_type IS NULL OR p_source_type NOT IN ('official_body', 'original_creator') THEN
    RAISE EXCEPTION 'p_source_type must be ''official_body'' or ''original_creator''';
  END IF;
  IF p_source_name IS NULL OR btrim(p_source_name) = '' THEN
    RAISE EXCEPTION 'p_source_name is required and cannot be blank';
  END IF;
  IF p_creation_channel IS NULL OR p_creation_channel NOT IN ('manual', 'bulk_upload', 'gemini_import') THEN
    RAISE EXCEPTION 'p_creation_channel must be ''manual'', ''bulk_upload'', or ''gemini_import''';
  END IF;
  IF p_batches IS NULL OR jsonb_typeof(p_batches) <> 'array' OR jsonb_array_length(p_batches) = 0 THEN
    RAISE EXCEPTION 'p_batches must be a non-empty JSON array';
  END IF;

  v_is_prof_admin := public.is_professor_or_admin();

  -- ── pass 1: validate every batch/card before writing anything ─────────
  FOR v_batch IN SELECT * FROM jsonb_array_elements(p_batches)
  LOOP
    IF jsonb_typeof(v_batch) <> 'object' THEN
      RAISE EXCEPTION 'Each batch must be a JSON object';
    END IF;

    IF v_batch->>'batch_id' IS NULL THEN
      RAISE EXCEPTION 'Every batch requires a batch_id';
    END IF;

    BEGIN
      v_batch_id := (v_batch->>'batch_id')::uuid;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'Invalid batch_id (not a UUID): %', v_batch->>'batch_id';
    END;

    IF v_batch_id = ANY(v_seen_batch_ids) THEN
      RAISE EXCEPTION 'batch_id % repeated within one call', v_batch_id;
    END IF;
    v_seen_batch_ids := array_append(v_seen_batch_ids, v_batch_id);

    IF EXISTS (SELECT 1 FROM public.flashcard_batch_provenance p WHERE p.batch_id = v_batch_id) THEN
      RAISE EXCEPTION 'batch_id % already has a provenance record — cannot be reused or overwritten', v_batch_id;
    END IF;

    IF jsonb_typeof(v_batch->'cards') IS DISTINCT FROM 'array' OR jsonb_array_length(v_batch->'cards') = 0 THEN
      RAISE EXCEPTION 'Batch % must have a non-empty cards array', v_batch_id;
    END IF;

    FOR v_card IN SELECT * FROM jsonb_array_elements(v_batch->'cards')
    LOOP
      IF jsonb_typeof(v_card) <> 'object' THEN
        RAISE EXCEPTION 'Each card must be a JSON object (batch %)', v_batch_id;
      END IF;

      -- card-level batch_id, if present, cannot contradict the enclosing batch —
      -- prefer deriving from the enclosing batch rather than trusting the card value
      IF (v_card ? 'batch_id') AND (v_card->>'batch_id') IS NOT NULL
         AND (v_card->>'batch_id')::uuid IS DISTINCT FROM v_batch_id THEN
        RAISE EXCEPTION 'Card batch_id % contradicts enclosing batch_id %', v_card->>'batch_id', v_batch_id;
      END IF;

      -- caller cannot inject server-derived ownership/verification fields
      IF (v_card ? 'user_id') OR (v_card ? 'contributed_by') OR (v_card ? 'creator_id')
         OR (v_card ? 'content_creator_id') OR (v_card ? 'is_verified') THEN
        RAISE EXCEPTION 'Card payload must not include user_id/contributed_by/creator_id/content_creator_id/is_verified — these are server-derived';
      END IF;

      v_qtype := v_card->>'question_type';
      IF v_qtype IS NULL THEN
        RAISE EXCEPTION 'Card is missing question_type (batch %)', v_batch_id;
      END IF;

      -- reproduce D-10 verdict-type gate (flashcards_gate_verdict_types_insert)
      -- since RLS does not see this SECURITY DEFINER function at all
      IF v_qtype = ANY(v_verdict_types) AND NOT v_is_prof_admin THEN
        RAISE EXCEPTION 'Only professors/admins may author verdict-bearing question_type "%"', v_qtype;
      END IF;

      IF (v_card->>'front_text') IS NULL THEN
        RAISE EXCEPTION 'Card is missing front_text (batch %)', v_batch_id;
      END IF;
      IF (v_card->>'back_text') IS NULL AND v_qtype <> 'concept_card' THEN
        RAISE EXCEPTION 'Card is missing back_text (batch %)', v_batch_id;
      END IF;
    END LOOP;
  END LOOP;

  -- ── pass 2: insert provenance + cards (any failure here aborts the whole call) ──
  FOR v_batch IN SELECT * FROM jsonb_array_elements(p_batches)
  LOOP
    v_batch_id := (v_batch->>'batch_id')::uuid;

    INSERT INTO public.flashcard_batch_provenance (batch_id, content_source_type, content_source_name, created_by)
    VALUES (v_batch_id, p_source_type, p_source_name, v_uid);

    INSERT INTO public.flashcards (
      user_id, contributed_by, creator_id, content_creator_id,
      deck_id, note_id, discipline_id, target_course, subject_id, topic_id,
      custom_subject, custom_topic, front_text, back_text,
      front_image_url, back_image_url, tags, visibility, is_verified,
      difficulty, batch_id, batch_description, question_type, options,
      correct_answer, points_to_remember, explanation, subtype, scenario, source
    )
    SELECT
      v_uid, v_uid, v_uid, NULL,
      NULLIF(c->>'deck_id', '')::uuid, NULLIF(c->>'note_id', '')::uuid, NULLIF(c->>'discipline_id', '')::uuid,
      c->>'target_course', NULLIF(c->>'subject_id', '')::uuid, NULLIF(c->>'topic_id', '')::uuid,
      c->>'custom_subject', c->>'custom_topic', c->>'front_text', c->>'back_text',
      c->>'front_image_url', c->>'back_image_url',
      COALESCE((SELECT array_agg(x) FROM jsonb_array_elements_text(COALESCE(c->'tags', '[]'::jsonb)) x), '{}'),
      COALESCE(c->>'visibility', 'private'), false,
      COALESCE(c->>'difficulty', 'medium'), v_batch_id, c->>'batch_description',
      c->>'question_type', c->'options', c->>'correct_answer',
      c->'points_to_remember', c->'explanation', c->>'subtype', c->>'scenario', p_creation_channel
    FROM jsonb_array_elements(v_batch->'cards') c;

    GET DIAGNOSTICS v_row_count = ROW_COUNT;
    batch_id := v_batch_id;
    card_count := v_row_count;
    RETURN NEXT;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public.create_flashcard_batches(text, text, jsonb, text) IS
  'SECURITY DEFINER, owner postgres. Only path that can populate flashcard_batch_provenance. Reproduces auth.uid()-derived ownership and the D-10 verdict-type professor/admin gate manually because FORCE ROW LEVEL SECURITY is not set on flashcards, so RLS does not apply to this function running as table owner. Atomic: one provenance row per batch_id + all cards for that batch, or the whole call rolls back. p_creation_channel (added Sprint 8.7.2) is written to every inserted row''s flashcards.source explicitly, never the column default — manual | bulk_upload | gemini_import. scenario (added Sprint 8.7.2) carries case_study_mcq case text through, which the Sprint 8.7.1 version of this function omitted.';

-- Revoke from anon explicitly, not just PUBLIC: this project has a default-privileges
-- rule that grants EXECUTE on new public-schema functions directly to anon/authenticated
-- (confirmed live in 8.7.1 via 03_TEST/T8b — REVOKE ... FROM PUBLIC alone left anon able
-- to execute this function). Deliberately NOT granted to anon.
REVOKE ALL ON FUNCTION public.create_flashcard_batches(text, text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_flashcard_batches(text, text, jsonb, text) TO authenticated;

COMMIT;
