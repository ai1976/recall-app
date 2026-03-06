-- Name: [SCHEMA] Add composite course+user indexes for course-aware browsing
-- Description: Adds composite B-tree indexes on (target_course, user_id) for flashcard_decks
-- and notes tables. These optimize the course-gate AND clause in the v3 browsable RPCs:
--   WHERE (role IN ('professor',...) OR user_id = v_user_id OR target_course = v_user_course)
-- The composite index serves both the course-match path and the user-id author-exception path.
-- IF NOT EXISTS makes this safe to run multiple times.

CREATE INDEX IF NOT EXISTS idx_flashcard_decks_course_user
  ON flashcard_decks (target_course, user_id);

CREATE INDEX IF NOT EXISTS idx_notes_course_user
  ON notes (target_course, user_id);
