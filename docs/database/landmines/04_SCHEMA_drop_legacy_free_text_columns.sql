-- Name: [SCHEMA] Drop Legacy Free-Text Columns (blueprint.md §1.11 #7, #8)
-- Description: Drops notes.course / notes.subject / notes.topic (superseded by subject_id /
-- topic_id FKs + custom_subject / custom_topic) and upvotes.note_id (superseded by the
-- polymorphic content_type / target_id pair added 2026-01-24).
--
-- Audit trail:
--   - notes insert payload (NoteUpload.jsx) writes target_course, subject_id, topic_id,
--     custom_subject, custom_topic — never course/subject/topic. Grep for `.course`/`.subject`/
--     `.topic` as direct property access across src/ found zero references to these three raw
--     columns anywhere (all other hits are joined-relation objects like note.subject?.name,
--     unrelated form state like editGroupForm.course, or other tables' columns like
--     access_requests.course).
--   - upvotes writes/reads (UpvoteButton.jsx, MyContributions.jsx) use only content_type +
--     target_id; note_id is never read or written.
--   - DATABASE_SCHEMA.md's documented column lists for notes (§2.2) and the current upvotes
--     section (line ~2548, "Modified 2026-01-24 - Polymorphic") already omit these columns —
--     they're undocumented legacy, consistent with dead.
-- Live confirmation needed before deploy: 01_DIAGNOSTIC_landmine_l1_audit.sql query 5 (no
-- DEFAULT/writer surprises) and query 6 (no RLS policy predicate on these columns).
--
-- Deploy: immediately deployable, no frontend dependency (no client writes these columns).

ALTER TABLE public.notes
  DROP COLUMN IF EXISTS course,
  DROP COLUMN IF EXISTS subject,
  DROP COLUMN IF EXISTS topic;

ALTER TABLE public.upvotes
  DROP COLUMN IF EXISTS note_id;
