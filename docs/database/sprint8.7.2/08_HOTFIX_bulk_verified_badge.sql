-- Name: [FIX] Sprint 8.7.2 hotfix — restore verified badge for professor/admin bulk uploads
--
-- Description: Code-review finding, fixed before shipping (not a post-deploy incident).
-- Pre-8.7.2, BulkUploadFlashcards.jsx set `is_verified: isProfessor || isAdmin || isSuperAdmin`
-- on every row — professor/admin bulk uploads showed the verified badge in StudyMode.jsx.
-- create_flashcard_batches() (both the 8.7.1 original and 8.7.2's p_creation_channel
-- revision) hardcoded `is_verified = false` for every inserted row with no role branch.
-- Because the RPC had zero live callers before 8.7.2's frontend migration, this hardcoded
-- `false` never actually reached production until today — the migration activates a real
-- regression rather than introducing a new one. This hotfix restores the prior behavior
-- using the function's own server-computed `v_is_prof_admin` (already computed for the
-- D-10 gate), gated on `p_creation_channel = 'bulk_upload'` to match exactly what the old
-- direct-insert code did — never a caller-supplied value, so this does not reopen the
-- privilege-escalation concern the SECURITY-CRITICAL comment on this function warns about.
-- Manual creation (`p_creation_channel = 'manual'`) is unaffected — it never set
-- is_verified=true even for professors pre-8.7.1, and continues not to.
--
-- Same 4-arg signature as 01_FUNCTIONS_creation_channel.sql — CREATE OR REPLACE is safe
-- here (no identity-argument change, unlike the 3-arg -> 4-arg migration in that file).

BEGIN;

CREATE OR REPLACE FUNCTION public.create_flashcard_batches(
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
      COALESCE(c->>'visibility', 'private'),
      (p_creation_channel = 'bulk_upload' AND v_is_prof_admin),  -- restores pre-8.7.1 bulk-upload verified-badge behavior; server-derived, never caller-supplied
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
  'SECURITY DEFINER, owner postgres. Only path that can populate flashcard_batch_provenance. Reproduces auth.uid()-derived ownership and the D-10 verdict-type professor/admin gate manually because FORCE ROW LEVEL SECURITY is not set on flashcards, so RLS does not apply to this function running as table owner. Atomic: one provenance row per batch_id + all cards for that batch, or the whole call rolls back. p_creation_channel (Sprint 8.7.2) is written to every inserted row''s flashcards.source explicitly, never the column default. scenario (Sprint 8.7.2) carries case_study_mcq case text through. is_verified (Sprint 8.7.2 hotfix) is true only when p_creation_channel=''bulk_upload'' AND the caller is professor/admin (server-derived via is_professor_or_admin(), restoring pre-8.7.1 bulk-upload behavior) — false for every manual-channel row, matching pre-8.7.1 manual-creation behavior which never set is_verified=true.';

-- Grants unchanged from 01_FUNCTIONS_creation_channel.sql — CREATE OR REPLACE on the same
-- signature does not reset them, but re-asserting is cheap insurance.
REVOKE ALL ON FUNCTION public.create_flashcard_batches(text, text, jsonb, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_flashcard_batches(text, text, jsonb, text) TO authenticated;

COMMIT;
