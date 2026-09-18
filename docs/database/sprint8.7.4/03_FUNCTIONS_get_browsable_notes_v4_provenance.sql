-- Name: [FUNCTIONS] get_browsable_notes v4 — provenance passthrough
--
-- Description: Sprint 8.7.4 adds two additive, non-breaking-for-callers return
-- columns, content_source_type / content_source_name, straight off the notes
-- row itself. No ambiguity here unlike flashcards/decks — a note IS the unit
-- of provenance (row-level, set once at creation by trg_require_note_provenance,
-- 8.7.1), not an aggregation of many creation events like a flashcard deck.
-- Legacy pre-8.7.1 notes simply have NULL in both columns already; no LEFT JOIN
-- or extra lookup needed, unlike the flashcards side.
--
-- CORRECTION (same as every prior get_browsable_* version bump): adding a
-- return column changes the function's result type, so plain CREATE OR REPLACE
-- does NOT work — the existing zero-arg function must be DROPped explicitly first.
--
-- Every existing caller (BrowseNotes.jsx's `supabase.rpc('get_browsable_notes')`
-- call) is unaffected by the two new columns.
--
-- NOT verbatim from v3, one deliberate addition beyond the two new columns:
-- v3 (docs/database/study-groups/30_FUNCTION_get_browsable_notes_v3.sql) had no
-- `SET search_path` clause at all — every other SECURITY DEFINER function in
-- this codebase pins it (unquoted, per the L3 `17c` outage lesson — see
-- landmines/17c_HOTFIX_repin_search_path_APPLY_ONLY.sql and get_study_queue's
-- own comment on the same rule). Found while reproducing this function for the
-- DROP+CREATE this sprint already requires; pinning it now closes that gap
-- rather than reproducing a known-risky omission verbatim.

DROP FUNCTION IF EXISTS get_browsable_notes();

CREATE OR REPLACE FUNCTION get_browsable_notes()
RETURNS TABLE (
  id UUID,
  user_id UUID,
  title TEXT,
  description TEXT,
  image_url TEXT,
  target_course TEXT,
  subject_id UUID,
  topic_id UUID,
  custom_subject TEXT,
  custom_topic TEXT,
  tags TEXT[],
  visibility TEXT,
  upvote_count INTEGER,
  created_at TIMESTAMPTZ,
  author_name TEXT,
  author_role TEXT,
  subject_name TEXT,
  topic_name TEXT,
  content_source_type TEXT,
  content_source_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, extensions
AS $$
DECLARE
  v_user_id     UUID;
  v_user_role   TEXT;
  v_user_course TEXT;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Fetch the caller's role and enrolled course in one round-trip
  -- NOTE: Must use profiles.id (not bare "id") because RETURNS TABLE declares
  -- an output column also named "id", causing ambiguity error 42702.
  SELECT role, course_level
    INTO v_user_role, v_user_course
    FROM profiles
   WHERE profiles.id = v_user_id;

  RETURN QUERY
  SELECT DISTINCT
    n.id,
    n.user_id,
    n.title,
    n.description,
    n.image_url,
    n.target_course,
    n.subject_id,
    n.topic_id,
    n.custom_subject,
    n.custom_topic,
    n.tags,
    n.visibility,
    n.upvote_count,
    n.created_at,
    p.full_name  AS author_name,
    p.role       AS author_role,
    COALESCE(s.name,   n.custom_subject, 'Other')   AS subject_name,
    COALESCE(top.name, n.custom_topic,   'General') AS topic_name,
    n.content_source_type,
    n.content_source_name
  FROM notes n
  JOIN profiles p     ON p.id   = n.user_id
  LEFT JOIN subjects s   ON s.id   = n.subject_id
  LEFT JOIN topics   top ON top.id = n.topic_id
  WHERE
    -- VISIBILITY GATE: must pass at least one visibility rule
    (
      n.user_id = v_user_id                          -- own notes (any visibility)
      OR n.visibility = 'public'                     -- public notes
      OR (                                           -- friends-only notes
        n.visibility = 'friends'
        AND EXISTS (
          SELECT 1 FROM friendships f
           WHERE f.status = 'accepted'
             AND (
               (f.user_id = v_user_id AND f.friend_id = n.user_id)
               OR (f.friend_id = v_user_id AND f.user_id = n.user_id)
             )
        )
      )
      OR EXISTS (                                    -- group-shared notes (active members only)
        SELECT 1 FROM content_group_shares cgs
        JOIN study_group_members sgm ON sgm.group_id = cgs.group_id
         WHERE cgs.content_type = 'note'
           AND cgs.content_id   = n.id
           AND sgm.user_id      = v_user_id
           AND sgm.status       = 'active'
      )
    )

    -- COURSE GATE: professors/admins bypass; students see own course + own content
    AND (
      v_user_role IN ('professor', 'admin', 'super_admin')
      OR n.user_id      = v_user_id          -- author always sees own creation
      OR n.target_course = v_user_course     -- matches student's enrolled course
    )

  ORDER BY n.created_at DESC;
END;
$$;

-- PostgREST: pick up the changed return signature
NOTIFY pgrst, 'reload schema';
