-- Name: [FUNCTIONS] Get Featured Landing Content
-- Description: SECURITY DEFINER RPC for the unauthenticated landing page (hero demo /
-- teaser section). Returns curated public decks and notes flagged is_featured_on_landing.
-- Card exposure is hard-capped at exactly 5 per deck server-side (never a full deck) because
-- featured content is intentionally public and therefore scrapable. Notes return metadata +
-- a short description snippet only — never the note body (NotePreview already gates that).
-- Mirrors the join/column conventions of get_public_deck_preview and get_public_note_preview
-- (introspected in 01_DIAGNOSTIC_introspect_preview_rpcs.sql):
--   - flashcards are fetched via the 5-grouping-column join (user_id, subject_id, topic_id,
--     custom_subject, custom_topic with IS NOT DISTINCT FROM) — NEVER fc.deck_id, which is
--     never populated and always returns 0 rows.
--   - answer/question columns are fc.front_text / fc.back_text / fc.question_type.
--   - notes.description is a real column (confirmed via get_public_note_preview's body,
--     which selects n.description directly) — used here as the snippet field, defensively
--     truncated to 200 chars.
-- Both WHERE clauses double-guard on visibility = 'public' even though the auto-clear
-- triggers (04_SCHEMA) already enforce this, per the sprint's explicit double-guard requirement.
-- Ends with NOTIFY pgrst so PostgREST picks up the new function immediately.

CREATE OR REPLACE FUNCTION public.get_featured_landing_content()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_decks jsonb;
  v_notes jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(d), '[]'::jsonb)
  INTO v_decks
  FROM (
    SELECT jsonb_build_object(
      'id',           fd.id,
      'name',         fd.name,
      'subject',      COALESCE(s.name, fd.custom_subject),
      'topic',        COALESCE(t.name, fd.custom_topic),
      'card_count',   fd.card_count,
      'upvote_count', fd.upvote_count,
      'creator_name', p.full_name,
      'cards',        COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'front_text',    c.front_text,
            'back_text',     c.back_text,
            'question_type', c.question_type
          )
          ORDER BY c.created_at, c.id
        )
        FROM (
          SELECT fc.front_text, fc.back_text, fc.question_type, fc.created_at, fc.id
          FROM flashcards fc
          WHERE fc.user_id = fd.user_id
            AND (fc.subject_id     IS NOT DISTINCT FROM fd.subject_id)
            AND (fc.topic_id       IS NOT DISTINCT FROM fd.topic_id)
            AND (fc.custom_subject IS NOT DISTINCT FROM fd.custom_subject)
            AND (fc.custom_topic   IS NOT DISTINCT FROM fd.custom_topic)
          ORDER BY fc.created_at, fc.id
          LIMIT 5
        ) c
      ), '[]'::jsonb)
    ) AS d
    FROM flashcard_decks fd
    LEFT JOIN subjects s ON s.id = fd.subject_id
    LEFT JOIN topics   t ON t.id = fd.topic_id
    LEFT JOIN profiles p ON p.id = fd.user_id
    WHERE fd.is_featured_on_landing = true
      AND fd.visibility = 'public'
    ORDER BY fd.upvote_count DESC, fd.created_at DESC
    LIMIT 12
  ) sub;

  SELECT COALESCE(jsonb_agg(n), '[]'::jsonb)
  INTO v_notes
  FROM (
    SELECT jsonb_build_object(
      'id',           nt.id,
      'title',        nt.title,
      'subject',      COALESCE(s.name, nt.custom_subject),
      'topic',        COALESCE(t.name, nt.custom_topic),
      'author_name',  p.full_name,
      'upvote_count', nt.upvote_count,
      'description',  LEFT(nt.description, 200)
    ) AS n
    FROM notes nt
    LEFT JOIN subjects s ON s.id = nt.subject_id
    LEFT JOIN topics   t ON t.id = nt.topic_id
    LEFT JOIN profiles p ON p.id = nt.user_id
    WHERE nt.is_featured_on_landing = true
      AND nt.visibility = 'public'
    ORDER BY nt.upvote_count DESC, nt.created_at DESC
    LIMIT 12
  ) sub;

  RETURN jsonb_build_object('decks', v_decks, 'notes', v_notes);
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_featured_landing_content() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
